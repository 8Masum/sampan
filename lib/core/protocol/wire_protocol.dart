import 'dart:convert';
import 'dart:typed_data';

import 'package:sampan/core/constants/protocol_constants.dart';

/// Compact 28-byte BLE Telemetry Packet (Section 6.1 of `SAMPAN_BLUEPRINT.md`).
///
/// Layout:
/// - Bytes 0..1  (2B): Magic `0x53 0x50` ('S', 'P')
/// - Byte  2     (1B): Type `0x01` (Telemetry)
/// - Byte  3     (1B): Role (`0x00` = guide, `0x01` = traveler)
/// - Bytes 4..7  (4B): Latitude (`float32`, big-endian)
/// - Bytes 8..11 (4B): Longitude (`float32`, big-endian)
/// - Bytes 12..13(2B): Speed in cm/s (`uint16`, big-endian)
/// - Bytes 14..27(14B): Truncated Ephemeral/Public Key (14 bytes = 28 hex chars)
class TelemetryPacket {
  const TelemetryPacket({
    required this.isGuide,
    required this.latitude,
    required this.longitude,
    required this.speedMetersPerSecond,
    required this.truncatedKeyHex,
  });

  final bool isGuide;
  final double latitude;
  final double longitude;
  final double speedMetersPerSecond;
  final String truncatedKeyHex;

  String get role => isGuide ? 'guide' : 'traveler';
}

/// Binary GATT Chat & SOS Packet (Section 6.2 of `SAMPAN_BLUEPRINT.md`).
///
/// Layout:
/// - Byte  0     (1B): Protocol Version (`0x01`)
/// - Byte  1     (1B): Packet Type (`0x02` = Chat, `0x99` = SOS Megaphone)
/// - Bytes 2..33 (32B): Sender Ed25519 Public Key
/// - Bytes 34..65(32B): Destination Ed25519 Public Key (all zeros = broadcast)
/// - Bytes 66..67(2B): Payload Length (`uint16`, big-endian)
/// - Bytes 68..N (Var): Encrypted / UTF-8 Payload bytes
class WireMessagePacket {
  const WireMessagePacket({
    required this.version,
    required this.packetType,
    required this.senderPublicKeyHex,
    required this.destinationPublicKeyHex,
    required this.payloadBytes,
  });

  final int version;
  final int packetType;
  final String senderPublicKeyHex;

  /// Null or all-zeros indicates caravan broadcast.
  final String? destinationPublicKeyHex;
  final Uint8List payloadBytes;

  bool get isSos => packetType == SampanConstants.packetTypeSos;
  bool get isBroadcast =>
      destinationPublicKeyHex == null ||
      destinationPublicKeyHex!.isEmpty ||
      RegExp(r'^0+$').hasMatch(destinationPublicKeyHex!);

  String get payloadUtf8 => utf8.decode(payloadBytes, allowMalformed: true);
}

/// Binary wire encoder/decoder for Sampan BLE GATT framing (Section 6).
class SampanWireProtocol {
  const SampanWireProtocol._();

  static const int maxPayloadLength = 65535;

  /// Encodes a [TelemetryPacket] into a fixed 28-byte BLE advertisement buffer.
  static Uint8List encodeTelemetryPacket(TelemetryPacket packet) {
    if (packet.latitude.isNaN ||
        packet.latitude.isInfinite ||
        packet.latitude < -90.0 ||
        packet.latitude > 90.0) {
      throw ArgumentError.value(
        packet.latitude,
        'latitude',
        'Latitude must be within [-90.0, 90.0].',
      );
    }
    if (packet.longitude.isNaN ||
        packet.longitude.isInfinite ||
        packet.longitude < -180.0 ||
        packet.longitude > 180.0) {
      throw ArgumentError.value(
        packet.longitude,
        'longitude',
        'Longitude must be within [-180.0, 180.0].',
      );
    }

    final ByteData data =
        ByteData(SampanConstants.telemetryPacketByteLength);
    data.setUint8(0, SampanConstants.magicByte0);
    data.setUint8(1, SampanConstants.magicByte1);
    data.setUint8(2, SampanConstants.packetTypeTelemetry);
    data.setUint8(
      3,
      packet.isGuide
          ? SampanConstants.roleByteGuide
          : SampanConstants.roleByteTraveler,
    );
    data.setFloat32(4, packet.latitude, Endian.big);
    data.setFloat32(8, packet.longitude, Endian.big);

    final int speedCmPerSec = (packet.speedMetersPerSecond.isNaN ||
            packet.speedMetersPerSecond.isInfinite ||
            packet.speedMetersPerSecond < 0)
        ? 0
        : (packet.speedMetersPerSecond * 100.0).round().clamp(0, 65535);
    data.setUint16(12, speedCmPerSec, Endian.big);

    final Uint8List keyBytes = _hexToFixedBytes(
      packet.truncatedKeyHex,
      SampanConstants.truncatedPublicKeyLength,
    );
    final Uint8List buffer = data.buffer.asUint8List();
    buffer.setRange(14, 28, keyBytes);
    return buffer;
  }

  /// Decodes a 28-byte BLE advertisement buffer into a [TelemetryPacket].
  static TelemetryPacket decodeTelemetryPacket(Uint8List bytes) {
    if (bytes.length != SampanConstants.telemetryPacketByteLength) {
      throw FormatException(
        'Invalid telemetry packet length: expected '
        '${SampanConstants.telemetryPacketByteLength}, got ${bytes.length}.',
      );
    }

    final ByteData data = ByteData.sublistView(bytes);
    final int magic0 = data.getUint8(0);
    final int magic1 = data.getUint8(1);
    if (magic0 != SampanConstants.magicByte0 ||
        magic1 != SampanConstants.magicByte1) {
      throw FormatException(
        'Invalid Sampan magic bytes: 0x${magic0.toRadixString(16)} '
        '0x${magic1.toRadixString(16)}.',
      );
    }

    final int packetType = data.getUint8(2);
    if (packetType != SampanConstants.packetTypeTelemetry) {
      throw FormatException(
        'Unexpected telemetry packet type: 0x${packetType.toRadixString(16)}.',
      );
    }

    final int roleByte = data.getUint8(3);
    final double latitude = data.getFloat32(4, Endian.big);
    final double longitude = data.getFloat32(8, Endian.big);
    if (latitude.isNaN ||
        latitude.isInfinite ||
        latitude < -90.0 ||
        latitude > 90.0 ||
        longitude.isNaN ||
        longitude.isInfinite ||
        longitude < -180.0 ||
        longitude > 180.0) {
      throw const FormatException(
        'Decoded telemetry coordinates out of valid geographic bounds.',
      );
    }

    final int speedCmPerSec = data.getUint16(12, Endian.big);
    final String keyHex = bytesToHex(bytes.sublist(14, 28));

    return TelemetryPacket(
      isGuide: roleByte == SampanConstants.roleByteGuide,
      latitude: latitude,
      longitude: longitude,
      speedMetersPerSecond: speedCmPerSec / 100.0,
      truncatedKeyHex: keyHex,
    );
  }

  /// Encodes a [WireMessagePacket] into a binary GATT frame (Section 6.2).
  static Uint8List encodeWireMessagePacket(WireMessagePacket packet) {
    if (packet.payloadBytes.length > maxPayloadLength) {
      throw ArgumentError.value(
        packet.payloadBytes.length,
        'payloadBytes',
        'Payload exceeds uint16 maximum length ($maxPayloadLength bytes).',
      );
    }
    if (packet.packetType != SampanConstants.packetTypeChat &&
        packet.packetType != SampanConstants.packetTypeSos) {
      throw ArgumentError.value(
        packet.packetType,
        'packetType',
        'Unsupported wire packet type.',
      );
    }

    final int totalLength =
        SampanConstants.chatPacketHeaderByteLength + packet.payloadBytes.length;
    final Uint8List buffer = Uint8List(totalLength);
    final ByteData header = ByteData.sublistView(buffer);

    header.setUint8(0, packet.version);
    header.setUint8(1, packet.packetType);

    final Uint8List senderBytes = _hexToFixedBytes(
      packet.senderPublicKeyHex,
      SampanConstants.ed25519PublicKeyLength,
    );
    buffer.setRange(2, 34, senderBytes);

    final Uint8List destBytes = (packet.destinationPublicKeyHex == null ||
            packet.destinationPublicKeyHex!.isEmpty)
        ? Uint8List(SampanConstants.ed25519PublicKeyLength)
        : _hexToFixedBytes(
            packet.destinationPublicKeyHex!,
            SampanConstants.ed25519PublicKeyLength,
          );
    buffer.setRange(34, 66, destBytes);

    header.setUint16(66, packet.payloadBytes.length, Endian.big);
    buffer.setRange(68, totalLength, packet.payloadBytes);
    return buffer;
  }

  /// Decodes a binary GATT frame into a [WireMessagePacket] (Section 6.2).
  static WireMessagePacket decodeWireMessagePacket(Uint8List bytes) {
    if (bytes.length < SampanConstants.chatPacketHeaderByteLength) {
      throw FormatException(
        'Packet too short for GATT header: expected at least '
        '${SampanConstants.chatPacketHeaderByteLength} bytes, got ${bytes.length}.',
      );
    }

    final ByteData header = ByteData.sublistView(bytes);
    final int version = header.getUint8(0);
    if (version != SampanConstants.protocolVersion) {
      throw FormatException('Unsupported protocol version: $version.');
    }

    final int packetType = header.getUint8(1);
    if (packetType != SampanConstants.packetTypeChat &&
        packetType != SampanConstants.packetTypeSos) {
      throw FormatException(
        'Invalid message packet type: 0x${packetType.toRadixString(16)}.',
      );
    }

    final int declaredLength = header.getUint16(66, Endian.big);
    final int expectedTotal =
        SampanConstants.chatPacketHeaderByteLength + declaredLength;
    if (bytes.length != expectedTotal) {
      throw FormatException(
        'Payload length mismatch: header declared $declaredLength bytes '
        '(total $expectedTotal), but buffer has ${bytes.length} bytes.',
      );
    }

    final String senderHex = bytesToHex(bytes.sublist(2, 34));
    final Uint8List destSlice = bytes.sublist(34, 66);
    final bool isAllZeros = destSlice.every((int b) => b == 0);
    final String? destHex = isAllZeros ? null : bytesToHex(destSlice);
    final Uint8List payload = Uint8List.fromList(bytes.sublist(68));

    return WireMessagePacket(
      version: version,
      packetType: packetType,
      senderPublicKeyHex: senderHex,
      destinationPublicKeyHex: destHex,
      payloadBytes: payload,
    );
  }

  static String bytesToHex(List<int> bytes) {
    final StringBuffer sb = StringBuffer();
    for (final int b in bytes) {
      sb.write((b & 0xFF).toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static Uint8List _hexToFixedBytes(String rawHex, int targetByteLength) {
    final String cleaned = rawHex
        .replaceFirst(RegExp('^sampan:ed25519:', caseSensitive: false), '')
        .replaceAll(RegExp('[^0-9a-fA-F]'), '')
        .toLowerCase();
    final Uint8List result = Uint8List(targetByteLength);
    final int pairs = (cleaned.length ~/ 2).clamp(0, targetByteLength);
    for (int i = 0; i < pairs; i++) {
      result[i] = int.parse(cleaned.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}
