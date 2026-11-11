import 'dart:convert';
import 'dart:typed_data';

import 'package:sampan/core/constants/protocol_constants.dart';
import 'package:sampan/core/crypto/identity_crypto_service.dart';
import 'package:sampan/core/math/geo_math.dart';
import 'package:sampan/core/protocol/wire_protocol.dart';
import 'package:sampan/data/database/local_database.dart';
import 'package:sampan/data/models/identity_profile.dart';
import 'package:sampan/data/models/message_model.dart';
import 'package:sampan/data/models/peer_model.dart';
import 'package:sampan/data/services/native_bridge.dart';

/// Tier 1 BLE Mesh Engine handling 28-byte Telemetry Advertising/Scanning,
/// GATT Chat/SOS framing, and Virtual Leash RSSI monitoring (Section 3, 4 & 6).
class BleMeshService {
  BleMeshService({
    required LocalDatabase database,
    required IdentityCryptoService cryptoService,
    NativeBridge nativeBridge = const NativeBridge(),
  })  : _database = database,
        _cryptoService = cryptoService,
        _nativeBridge = nativeBridge;

  final LocalDatabase _database;
  final IdentityCryptoService _cryptoService;
  final NativeBridge _nativeBridge;

  static const String _caravanSharedContextKey =
      'sampan:v1:caravan:bay-of-bengal-mesh';

  Uint8List? _lastAdvertisedPacket;
  Uint8List? get lastAdvertisedPacket => _lastAdvertisedPacket;

  /// Builds and broadcasts the local user's 28-byte BLE Telemetry Packet
  /// (Section 6.1).
  Future<Uint8List> broadcastOwnTelemetry({
    required IdentityProfile identity,
    required double latitude,
    required double longitude,
    required double speedMetersPerSecond,
  }) async {
    final TelemetryPacket packet = TelemetryPacket(
      isGuide: identity.isGuide,
      latitude: latitude,
      longitude: longitude,
      speedMetersPerSecond: speedMetersPerSecond,
      truncatedKeyHex: identity.truncated14ByteHex,
    );
    final Uint8List encoded = SampanWireProtocol.encodeTelemetryPacket(packet);
    _lastAdvertisedPacket = encoded;
    await _nativeBridge.advertiseBleTelemetry(encoded);
    return encoded;
  }

  /// Processes a raw 28-byte BLE Telemetry Advertisement received over the air,
  /// evaluates the Virtual Leash threshold (`-85 dBm` for `> 45s`), and
  /// updates the reactive `Peers` table.
  Future<PeerModel?> ingestRawTelemetryFrame({
    required Uint8List rawBytes,
    required int rssiDbm,
    DateTime? receivedAt,
  }) async {
    final TelemetryPacket decoded =
        SampanWireProtocol.decodeTelemetryPacket(rawBytes);
    final DateTime now = receivedAt ?? DateTime.now();

    final PeerModel? existing =
        _database.findPeerByTruncatedKey(decoded.truncatedKeyHex);

    final VirtualLeashEvaluation leash = GeoMath.evaluateVirtualLeash(
      currentRssiDbm: rssiDbm,
      weakSignalSince: existing?.weakSignalSince,
      now: now,
    );

    // When Virtual Leash is tripped (> 45s below -85 dBm), freeze the
    // companion's last-known GPS coordinates on the radar (Section 4, Module 1).
    final double effectiveLat =
        (leash.isTripped && existing?.lastLatitude != null)
            ? existing!.lastLatitude!
            : decoded.latitude;
    final double effectiveLon =
        (leash.isTripped && existing?.lastLongitude != null)
            ? existing!.lastLongitude!
            : decoded.longitude;

    final PeerModel updated = existing != null
        ? existing.copyWith(
            role: decoded.role,
            lastLatitude: effectiveLat,
            lastLongitude: effectiveLon,
            lastSeen: now,
            rssiDbm: rssiDbm,
            speedMetersPerSecond: decoded.speedMetersPerSecond,
            weakSignalSince: leash.weakSignalSince,
            clearWeakSignalSince: !leash.isWeakSignal,
            isLeashFrozen: leash.isTripped,
          )
        : PeerModel(
            id: decoded.truncatedKeyHex.padRight(64, '0'),
            displayName: decoded.isGuide
                ? 'Guide-${decoded.truncatedKeyHex.substring(0, 4)}'
                : 'Peer-${decoded.truncatedKeyHex.substring(0, 4)}',
            avatarIcon: decoded.isGuide ? '⛵' : '🏄',
            colorHex: decoded.isGuide ? 0xFFE08244 : 0xFF006877,
            role: decoded.role,
            lastLatitude: effectiveLat,
            lastLongitude: effectiveLon,
            lastSeen: now,
            rssiDbm: rssiDbm,
            speedMetersPerSecond: decoded.speedMetersPerSecond,
            weakSignalSince: leash.weakSignalSince,
            isLeashFrozen: leash.isTripped,
          );

    await _database.upsertPeer(updated);
    return updated;
  }

  /// Polls native BLE scanner and ingests any newly discovered Sampan frames.
  Future<int> pollAndIngestScannedFrames() async {
    final List<RawBleAdvertisement> frames =
        await _nativeBridge.pollScannedBleAdvertisements();
    int ingested = 0;
    for (final RawBleAdvertisement frame in frames) {
      if (frame.payload.length == SampanConstants.telemetryPacketByteLength) {
        try {
          await ingestRawTelemetryFrame(
            rawBytes: frame.payload,
            rssiDbm: frame.rssiDbm,
          );
          ingested++;
        } on Object {
          // Ignore malformed foreign BLE advertisements.
        }
      }
    }
    return ingested;
  }

  /// Builds an encrypted GATT Chat frame or high-priority unencrypted SOS
  /// Digital Megaphone frame (Section 4.2 & Section 6.2).
  Future<Uint8List> buildOutgoingMessageFrame({
    required IdentityProfile sender,
    required String content,
    required bool isSos,
    String? recipientPublicKeyHex,
  }) async {
    final Uint8List payloadBytes;
    if (isSos) {
      // Section 4, Module 2: SOS is a high-priority unencrypted broadcast
      // packet so any nearby device can immediately decode and sound alarm.
      payloadBytes = Uint8List.fromList(utf8.encode(content));
    } else {
      final String contextKey = recipientPublicKeyHex != null
          ? _derivePairContextKey(sender.publicKeyHex, recipientPublicKeyHex)
          : _caravanSharedContextKey;
      payloadBytes = await _cryptoService.encryptChatPayload(
        plaintext: content,
        channelContextKey: contextKey,
      );
    }

    final WireMessagePacket wirePacket = WireMessagePacket(
      version: SampanConstants.protocolVersion,
      packetType: isSos
          ? SampanConstants.packetTypeSos
          : SampanConstants.packetTypeChat,
      senderPublicKeyHex: sender.publicKeyHex,
      destinationPublicKeyHex: recipientPublicKeyHex,
      payloadBytes: payloadBytes,
    );

    return SampanWireProtocol.encodeWireMessagePacket(wirePacket);
  }

  /// Decodes an incoming GATT Chat or SOS frame and stores it in [LocalDatabase].
  Future<MessageModel> ingestIncomingMessageFrame({
    required Uint8List rawFrameBytes,
    required String localUserPublicKeyHex,
  }) async {
    final WireMessagePacket packet =
        SampanWireProtocol.decodeWireMessagePacket(rawFrameBytes);

    String cleartext;
    if (packet.isSos) {
      cleartext = packet.payloadUtf8;
    } else {
      final String contextKey = packet.isBroadcast
          ? _caravanSharedContextKey
          : _derivePairContextKey(
              packet.senderPublicKeyHex,
              packet.destinationPublicKeyHex ?? localUserPublicKeyHex,
            );
      cleartext = await _cryptoService.decryptChatPayload(
        concatenatedBytes: packet.payloadBytes,
        channelContextKey: contextKey,
      );
    }

    final PeerModel? knownSender =
        _database.getPeerById(packet.senderPublicKeyHex);
    final DateTime now = DateTime.now();

    final MessageModel message = MessageModel(
      id: 'ble-${now.microsecondsSinceEpoch}-${packet.senderPublicKeyHex.substring(0, 6)}',
      senderId: packet.senderPublicKeyHex,
      senderName: knownSender?.displayName ??
          'Peer-${packet.senderPublicKeyHex.substring(0, 4)}',
      senderRole: knownSender?.role ?? 'traveler',
      recipientId: packet.destinationPublicKeyHex,
      content: cleartext,
      type: packet.isSos ? 'sos' : 'text',
      latitude: knownSender?.lastLatitude,
      longitude: knownSender?.lastLongitude,
      timestamp: now,
      isDelivered: true,
      isEncrypted: !packet.isSos,
    );

    await _database.insertMessage(message);
    return message;
  }

  static String _derivePairContextKey(String keyA, String keyB) {
    final List<String> sorted = <String>[
      keyA.toLowerCase(),
      keyB.toLowerCase(),
    ]..sort();
    return 'sampan:v1:dm:${sorted[0]}:${sorted[1]}';
  }
}
