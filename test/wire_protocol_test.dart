import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sampan/core/constants/protocol_constants.dart';
import 'package:sampan/core/protocol/wire_protocol.dart';

void main() {
  group('SampanWireProtocol — Binary BLE GATT Framing (Section 6)', () {
    test('encodes and decodes 28-byte Telemetry Packet accurately', () {
      const TelemetryPacket original = TelemetryPacket(
        isGuide: true,
        latitude: 21.4272,
        longitude: 91.9702,
        speedMetersPerSecond: 1.45,
        truncatedKeyHex: '7a8b9c0d1e2f3a4b5c6d7e8f9a0b',
      );

      final Uint8List wireBytes =
          SampanWireProtocol.encodeTelemetryPacket(original);

      expect(wireBytes.length, equals(28));
      expect(wireBytes[0], equals(0x53)); // 'S'
      expect(wireBytes[1], equals(0x50)); // 'P'
      expect(wireBytes[2], equals(0x01)); // Telemetry Type
      expect(wireBytes[3], equals(0x00)); // Guide Role

      final TelemetryPacket decoded =
          SampanWireProtocol.decodeTelemetryPacket(wireBytes);

      expect(decoded.isGuide, isTrue);
      expect(decoded.latitude, closeTo(21.4272, 0.0001));
      expect(decoded.longitude, closeTo(91.9702, 0.0001));
      expect(decoded.speedMetersPerSecond, closeTo(1.45, 0.01));
      expect(
        decoded.truncatedKeyHex,
        equals('7a8b9c0d1e2f3a4b5c6d7e8f9a0b'),
      );
    });

    test('rejects corrupted telemetry packets and invalid coordinates', () {
      expect(
        () => SampanWireProtocol.decodeTelemetryPacket(Uint8List(12)),
        throwsFormatException,
      );

      final Uint8List badMagic = Uint8List(28);
      badMagic[0] = 0x00;
      badMagic[1] = 0x00;
      expect(
        () => SampanWireProtocol.decodeTelemetryPacket(badMagic),
        throwsFormatException,
      );

      expect(
        () => SampanWireProtocol.encodeTelemetryPacket(
          const TelemetryPacket(
            isGuide: false,
            latitude: 95.0, // Invalid latitude > 90
            longitude: 91.97,
            speedMetersPerSecond: 1.0,
            truncatedKeyHex: '7a8b9c0d1e2f3a4b5c6d7e8f9a0b',
          ),
        ),
        throwsArgumentError,
      );
    });

    test('encodes and decodes Chat & SOS GATT packets (Section 6.2)', () {
      const String senderHex =
          '7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f3f9c';
      final Uint8List sosPayload = Uint8List.fromList(
        utf8.encode('🚨 SOS Alert from Rahim: Separated near Laboni Point!'),
      );

      final WireMessagePacket outgoing = WireMessagePacket(
        version: SampanConstants.protocolVersion,
        packetType: SampanConstants.packetTypeSos,
        senderPublicKeyHex: senderHex,
        destinationPublicKeyHex: null, // Broadcast
        payloadBytes: sosPayload,
      );

      final Uint8List encoded =
          SampanWireProtocol.encodeWireMessagePacket(outgoing);
      expect(encoded.length, equals(68 + sosPayload.length));

      final WireMessagePacket decoded =
          SampanWireProtocol.decodeWireMessagePacket(encoded);

      expect(decoded.isSos, isTrue);
      expect(decoded.isBroadcast, isTrue);
      expect(decoded.senderPublicKeyHex, equals(senderHex));
      expect(decoded.destinationPublicKeyHex, isNull);
      expect(
        decoded.payloadUtf8,
        equals('🚨 SOS Alert from Rahim: Separated near Laboni Point!'),
      );
    });
  });
}
