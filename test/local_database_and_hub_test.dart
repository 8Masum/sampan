import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sampan/core/crypto/identity_crypto_service.dart';
import 'package:sampan/core/net/join_qr_payload.dart';
import 'package:sampan/core/protocol/wire_protocol.dart';
import 'package:sampan/data/database/local_database.dart';
import 'package:sampan/data/models/identity_profile.dart';
import 'package:sampan/data/models/message_model.dart';
import 'package:sampan/data/models/peer_model.dart';
import 'package:sampan/data/models/spot_model.dart';
import 'package:sampan/data/services/ble_mesh_service.dart';
import 'package:sampan/data/services/softap_hub_service.dart';

void main() {
  group('IdentityCryptoService, LocalDatabase, BleMesh & SoftApHub', () {
    test('generates Ed25519 identity, signs/verifies, and encrypts with ChaCha20',
        () async {
      final IdentityCryptoService crypto = IdentityCryptoService();
      final GeneratedKeyIdentity id = await crypto.generateIdentity();

      expect(id.publicKeyHex.length, equals(64));
      expect(id.fingerprintUri, startsWith('sampan:ed25519:'));
      expect(id.truncated14ByteHex.length, equals(28));

      final String sig = await crypto.signPayload(
        privateSeedHex: id.privateSeedHex,
        message: 'Meet at Laboni Point',
      );
      final bool verified = await crypto.verifySignature(
        publicKeyHex: id.publicKeyHex,
        message: 'Meet at Laboni Point',
        signatureHex: sig,
      );
      expect(verified, isTrue);

      final Uint8List cipher = await crypto.encryptChatPayload(
        plaintext: 'Secret Caravan Coordinate: 21.4272, 91.9702',
        channelContextKey: 'caravan-shared-key',
      );
      final String clear = await crypto.decryptChatPayload(
        concatenatedBytes: cipher,
        channelContextKey: 'caravan-shared-key',
      );
      expect(clear, equals('Secret Caravan Coordinate: 21.4272, 91.9702'));
    });

    test('BleMeshService freezes peer coordinates when Virtual Leash trips',
        () async {
      final LocalDatabase db = LocalDatabase();
      final IdentityCryptoService crypto = IdentityCryptoService();
      final BleMeshService mesh = BleMeshService(
        database: db,
        cryptoService: crypto,
      );

      final DateTime t0 = DateTime.utc(2026, 11, 11, 10, 0, 0);
      const String peerId =
          '7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f3f9c';

      await db.upsertPeer(
        PeerModel(
          id: peerId,
          displayName: 'Tanvir Guide',
          avatarIcon: '⛵',
          colorHex: 0xFFE08244,
          role: 'guide',
          lastLatitude: 21.4272,
          lastLongitude: 91.9702,
          lastSeen: t0,
          rssiDbm: -90,
          weakSignalSince: t0,
        ),
      );

      // Frame arrives 50 seconds later with RSSI -91 dBm (< -85 dBm for > 45s)
      // and shifted GPS coordinates: coordinates must remain frozen at (21.4272, 91.9702)!
      final Uint8List frame = SampanWireProtocol.encodeTelemetryPacket(
        const TelemetryPacket(
          isGuide: true,
          latitude: 21.5000,
          longitude: 92.1000,
          speedMetersPerSecond: 1.2,
          truncatedKeyHex: '7a8b9c0d1e2f3a4b5c6d7e8f9a0b',
        ),
      );

      final PeerModel? updated = await mesh.ingestRawTelemetryFrame(
        rawBytes: frame,
        rssiDbm: -91,
        receivedAt: t0.add(const Duration(seconds: 50)),
      );

      expect(updated, isNotNull);
      expect(updated!.isLeashFrozen, isTrue);
      expect(updated.lastLatitude, closeTo(21.4272, 0.0001));
      expect(updated.lastLongitude, closeTo(91.9702, 0.0001));

      await db.dispose();
    });

    test('SoftApHubService serves Zero-Install Portal, POST /send, and APK route',
        () async {
      final LocalDatabase db = LocalDatabase();
      await db.saveIdentity(
        IdentityProfile(
          publicKeyHex:
              '7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f3f9c',
          privateSeedHex:
              '7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f3f9c',
          displayName: 'Tanvir Ahmed',
          avatarIcon: '⛵',
          colorHex: 0xFFE08244,
          role: 'guide',
          createdAt: DateTime.utc(2026, 11, 11),
        ),
      );

      final SoftApHubService hub = SoftApHubService(database: db)
        ..updateHostLocation(
          latitude: 21.4272,
          longitude: 91.9702,
          landmark: "Cox's Bazar — Laboni Point",
        );
      final int port = await hub.startServer(port: 0);
      expect(port, greaterThan(0));

      final HttpClient client = HttpClient();
      try {
        // 1. GET / serves Zero-Install Portal HTML with safe JS/HTML escaping
        final HttpClientRequest getReq =
            await client.get('127.0.0.1', port, '/');
        final HttpClientResponse getRes = await getReq.close();
        expect(getRes.statusCode, equals(200));
        final String html = await utf8.decoder.bind(getRes).join();
        expect(html, contains('Sampan (সাম্পান)'));
        expect(html, contains('/download/sampan.apk'));
        expect(html, contains('Cox&#39;s Bazar'));
        expect(html, contains('"📍 Checked in near Cox\'s Bazar — Laboni Point"'));

        // 2. POST /send injects SOS alert and GPS peer coordinates into LocalDatabase
        final HttpClientRequest postReq =
            await client.post('127.0.0.1', port, '/send');
        postReq.headers.contentType = ContentType.json;
        postReq.write(
          jsonEncode(<String, dynamic>{
            'senderId': 'web-guest-1',
            'sender': 'Rahim (Browser)',
            'role': 'Guest',
            'type': 'sos',
            'latitude': 21.4265,
            'longitude': 91.9712,
            'text': 'Need guide near red lifeguard stand!',
          }),
        );
        final HttpClientResponse postRes = await postReq.close();
        await postRes.drain<void>();
        expect(postRes.statusCode, equals(200));

        final List<MessageModel> msgs = db.currentMessages;
        expect(msgs.any((MessageModel m) => m.isSos), isTrue);
        final PeerModel? guestPeer = db.getPeerById('web-guest-1');
        expect(guestPeer, isNotNull);
        expect(guestPeer!.lastLatitude, closeTo(21.4265, 0.0001));

        // 3. GET /download/sampan.apk increments transfer counter
        final HttpClientRequest apkReq =
            await client.get('127.0.0.1', port, '/download/sampan.apk');
        final HttpClientResponse apkRes = await apkReq.close();
        await apkRes.drain<void>();
        expect(apkRes.statusCode, equals(200));
        expect(hub.apkDownloadsCount, equals(1));
      } finally {
        client.close(force: true);
        await hub.stopServer();
        await db.dispose();
      }
    });

    test(
        'LocalDatabase persists and reloads identity, peers, messages, spots, '
        'and hotspot settings atomically',
        () async {
      final Directory tmpDir =
          await Directory.systemTemp.createTemp('sampan_db_test_');
      final String dbFile =
          '${tmpDir.path}${Platform.pathSeparator}sampan_test_store.json';

      try {
        final LocalDatabase db1 = LocalDatabase(storageFilePath: dbFile);
        await db1.saveIdentity(
          IdentityProfile(
            publicKeyHex:
                '7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f3f9c',
            privateSeedHex:
                '7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f3f9c',
            displayName: 'Tanvir Ahmed',
            avatarIcon: '⛵',
            colorHex: 0xFFE08244,
            role: 'guide',
            createdAt: DateTime.utc(2026, 11, 11),
          ),
        );
        await db1.upsertPeer(
          PeerModel(
            id: 'ab'.padRight(64, '0'),
            displayName: 'Sofia',
            avatarIcon: '🎒',
            colorHex: 0xFF00A896,
            role: 'traveler',
            lastLatitude: -33.8688,
            lastLongitude: 151.2093,
            lastSeen: DateTime.utc(2026, 11, 12),
          ),
        );
        await db1.insertMessage(
          MessageModel(
            id: 'msg-1',
            senderId: 'ab'.padRight(64, '0'),
            senderName: 'Sofia',
            senderRole: 'traveler',
            content: 'Hello from Sydney',
            type: 'text',
            timestamp: DateTime.utc(2026, 11, 12, 9),
          ),
        );
        await db1.upsertSpot(
          SpotModel(
            id: 'spot-1',
            name: 'Parking',
            emoji: '🚗',
            latitude: -33.8688,
            longitude: 151.2093,
            createdAt: DateTime.utc(2026, 11, 12, 8),
          ),
        );
        await db1.saveHotspotCredentials(ssid: 'Trip Phone', password: 'p;w');
        await db1.dispose();

        final LocalDatabase db2 = LocalDatabase(storageFilePath: dbFile);
        await db2.initialize();
        expect(db2.identity, isNotNull);
        expect(db2.identity!.displayName, equals('Tanvir Ahmed'));
        expect(db2.currentPeers.length, equals(1));
        expect(db2.currentMessages.length, equals(1));
        expect(db2.currentSpots.single.name, equals('Parking'));
        expect(db2.currentSpots.single.latitude, closeTo(-33.8688, 1e-9));
        expect(db2.hotspotSsid, equals('Trip Phone'));
        expect(db2.hotspotPassword, equals('p;w'));

        await db2.deleteSpot('spot-1');
        expect(db2.currentSpots, isEmpty);
        await db2.dispose();
      } finally {
        if (tmpDir.existsSync()) {
          await tmpDir.delete(recursive: true);
        }
      }
    });

    test('removeLegacyDemoData drops pre-3.0 demo peers and seed messages only',
        () async {
      final LocalDatabase db = LocalDatabase();
      final String demoId = LocalDatabase.legacyDemoPeerIds.first;
      final String realId = 'cd'.padRight(64, '0');
      final DateTime now = DateTime.utc(2026, 11, 12);
      for (final String id in <String>[demoId, realId]) {
        await db.upsertPeer(
          PeerModel(
            id: id,
            displayName: id == demoId ? 'Demo' : 'Real',
            avatarIcon: '⛵',
            colorHex: 0xFF6755EF,
            role: 'traveler',
            lastSeen: now,
          ),
        );
      }
      for (final String msgId in <String>['seed-msg-1', 'msg-real']) {
        await db.insertMessage(
          MessageModel(
            id: msgId,
            senderId: msgId == 'msg-real' ? realId : demoId,
            senderName: 'x',
            senderRole: 'traveler',
            content: 'hi',
            type: 'text',
            timestamp: now,
          ),
        );
      }

      expect(await db.removeLegacyDemoData(), isTrue);
      expect(db.currentPeers.single.id, equals(realId));
      expect(db.currentMessages.single.id, equals('msg-real'));
      expect(await db.removeLegacyDemoData(), isFalse);
      await db.dispose();
    });

    test('JoinQrPayload builds camera-readable Wi-Fi and hub codes', () {
      expect(
        JoinQrPayload.wifi(ssid: 'Trip Phone', password: 'secret'),
        equals('WIFI:T:WPA;S:Trip Phone;P:secret;;'),
      );
      expect(
        JoinQrPayload.wifi(ssid: r'Cafe;"A":1,\', password: r'p;w'),
        equals(r'WIFI:T:WPA;S:Cafe\;\"A\"\:1\,\\;P:p\;w;;'),
      );
      expect(
        JoinQrPayload.wifi(ssid: 'Open Hub', password: ''),
        equals('WIFI:T:nopass;S:Open Hub;;'),
      );
      expect(
        JoinQrPayload.hubUrl(ip: '192.168.43.1', port: 8080),
        equals('http://192.168.43.1:8080'),
      );
    });
  });
}
