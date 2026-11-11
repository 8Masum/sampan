import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sampan/data/models/identity_profile.dart';
import 'package:sampan/data/models/message_model.dart';
import 'package:sampan/data/models/peer_model.dart';
import 'package:sampan/data/services/native_bridge.dart';

/// Local-first, reactive database for Sampan (`Peers` and `Messages` tables
/// defined in Section 5.2 of `SAMPAN_BLUEPRINT.md`).
///
/// Provides Drift-style reactive `watchPeers()` and `watchMessages()` streams
/// backed by an indexed in-memory cache and atomic on-device persistence.
class LocalDatabase {
  LocalDatabase({
    String? storageFilePath,
    bool resolvePersistentPath = false,
    NativeBridge nativeBridge = const NativeBridge(),
  })  : _storageFilePath = storageFilePath,
        _resolvePersistentPath = resolvePersistentPath,
        _nativeBridge = nativeBridge;

  String? _storageFilePath;
  final bool _resolvePersistentPath;
  final NativeBridge _nativeBridge;

  String? get storageFilePath => _storageFilePath;

  /// Canonical SQLite DDL statements matching Section 5.2.
  static const String kPeersTableSql = '''
CREATE TABLE IF NOT EXISTS peers (
  id TEXT PRIMARY KEY NOT NULL,
  display_name TEXT NOT NULL CHECK(length(display_name) BETWEEN 1 AND 32),
  avatar_icon TEXT NOT NULL,
  color_hex INTEGER NOT NULL,
  role TEXT NOT NULL,
  last_latitude REAL,
  last_longitude REAL,
  last_seen TEXT NOT NULL,
  rssi_dbm INTEGER NOT NULL DEFAULT -62,
  speed_mps REAL NOT NULL DEFAULT 0.0
);
''';

  static const String kMessagesTableSql = '''
CREATE TABLE IF NOT EXISTS messages (
  id TEXT PRIMARY KEY NOT NULL,
  sender_id TEXT NOT NULL REFERENCES peers(id),
  recipient_id TEXT,
  content TEXT NOT NULL,
  type TEXT NOT NULL,
  latitude REAL,
  longitude REAL,
  landmark_name TEXT,
  timestamp TEXT NOT NULL,
  is_delivered INTEGER NOT NULL DEFAULT 0
);
''';

  IdentityProfile? _identity;
  final Map<String, PeerModel> _peersById = <String, PeerModel>{};
  final List<MessageModel> _messages = <MessageModel>[];

  final StreamController<List<PeerModel>> _peersController =
      StreamController<List<PeerModel>>.broadcast();
  final StreamController<List<MessageModel>> _messagesController =
      StreamController<List<MessageModel>>.broadcast();

  IdentityProfile? get identity => _identity;

  List<PeerModel> get currentPeers {
    final List<PeerModel> list = _peersById.values.toList()
      ..sort((PeerModel a, PeerModel b) {
        if (a.isGuide != b.isGuide) {
          return a.isGuide ? -1 : 1;
        }
        return a.displayName.compareTo(b.displayName);
      });
    return List<PeerModel>.unmodifiable(list);
  }

  List<MessageModel> get currentMessages {
    final List<MessageModel> sorted = List<MessageModel>.of(_messages)
      ..sort(
        (MessageModel a, MessageModel b) => a.timestamp.compareTo(b.timestamp),
      );
    return List<MessageModel>.unmodifiable(sorted);
  }

  /// Reactive stream of all discovered caravan peers (`watch()`).
  Stream<List<PeerModel>> watchPeers() async* {
    yield currentPeers;
    yield* _peersController.stream;
  }

  /// Reactive stream of all messages (`watch()`).
  Stream<List<MessageModel>> watchMessages() async* {
    yield currentMessages;
    yield* _messagesController.stream;
  }

  /// Loads persisted snapshot from disk if [storageFilePath] was configured.
  Future<void> initialize() async {
    if (_resolvePersistentPath) {
      final String? appDir = await _nativeBridge.getAppDataDirectory();
      if (appDir != null && appDir.isNotEmpty) {
        _storageFilePath =
            '$appDir${Platform.pathSeparator}sampan_local_store.json';
      }
    }
    final String? path = _storageFilePath;
    if (path == null) return;
    try {
      final File file = File(path);
      if (!file.existsSync()) return;
      final String raw = await file.readAsString();
      if (raw.trim().isEmpty) return;
      final Map<String, dynamic> decoded =
          jsonDecode(raw) as Map<String, dynamic>;

      if (decoded['identity'] != null) {
        _identity = IdentityProfile.fromJson(
          decoded['identity'] as Map<String, dynamic>,
        );
      }

      final List<dynamic>? peersRaw = decoded['peers'] as List<dynamic>?;
      if (peersRaw != null) {
        _peersById.clear();
        for (final dynamic item in peersRaw) {
          final PeerModel peer =
              PeerModel.fromMap(item as Map<String, dynamic>);
          _peersById[peer.id] = peer;
        }
      }

      final List<dynamic>? messagesRaw = decoded['messages'] as List<dynamic>?;
      if (messagesRaw != null) {
        _messages.clear();
        for (final dynamic item in messagesRaw) {
          _messages.add(MessageModel.fromMap(item as Map<String, dynamic>));
        }
      }

      _emitPeers();
      _emitMessages();
    } on Object {
      // Corrupted or unreadable local cache is ignored safely.
    }
  }

  Future<void> saveIdentity(IdentityProfile profile) async {
    _identity = profile;
    await _persistToDisk();
  }

  Future<void> upsertPeer(PeerModel peer) async {
    _peersById[peer.id] = peer;
    _emitPeers();
    await _persistToDisk();
  }

  PeerModel? getPeerById(String id) => _peersById[id];

  /// Finds a peer whose full hex public key starts with the 14-byte
  /// (28-character) truncated key from a 28-byte BLE advertisement packet.
  PeerModel? findPeerByTruncatedKey(String truncatedKeyHex) {
    final String clean = truncatedKeyHex.toLowerCase();
    for (final PeerModel peer in _peersById.values) {
      if (peer.id.toLowerCase().startsWith(clean)) {
        return peer;
      }
    }
    return null;
  }

  Future<void> insertMessage(MessageModel message) async {
    final int existingIndex =
        _messages.indexWhere((MessageModel m) => m.id == message.id);
    if (existingIndex >= 0) {
      _messages[existingIndex] = message;
    } else {
      _messages.add(message);
    }
    _emitMessages();
    await _persistToDisk();
  }

  Future<void> markMessageDelivered(String messageId) async {
    final int index =
        _messages.indexWhere((MessageModel m) => m.id == messageId);
    if (index < 0) return;
    _messages[index] = _messages[index].copyWith(isDelivered: true);
    _emitMessages();
    await _persistToDisk();
  }

  List<MessageModel> getCaravanBroadcastMessages() {
    return currentMessages
        .where((MessageModel m) => !m.isDirectMessage)
        .toList(growable: false);
  }

  List<MessageModel> getDirectMessagesWithPeer({
    required String myId,
    required String peerId,
  }) {
    return currentMessages.where((MessageModel m) {
      return (m.senderId == myId && m.recipientId == peerId) ||
          (m.senderId == peerId && m.recipientId == myId);
    }).toList(growable: false);
  }

  /// Seeds initial Cox's Bazar caravan companions so the Compass Radar,
  /// Virtual Leash, and Caravan Chat are immediately interactive offline.
  Future<void> seedDemoCaravanIfEmpty() async {
    if (_peersById.isNotEmpty) return;

    final DateTime now = DateTime.now();
    final List<PeerModel> demoPeers = <PeerModel>[
      PeerModel(
        id: '7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f3f9c',
        displayName: 'Tanvir Ahmed',
        avatarIcon: '⛵',
        colorHex: 0xFF6755EF,
        role: 'guide',
        lastLatitude: 21.4278,
        lastLongitude: 91.9708,
        lastSeen: now,
        rssiDbm: -56,
        speedMetersPerSecond: 1.1,
      ),
      PeerModel(
        id: '9f8e7d6c5b4a3f2e1d0c9b8a7f6e5d4c3b2a1f0e9d8c7b6a5f4e3d2c1b0a8821',
        displayName: 'Rahim Uddin',
        avatarIcon: '🏄',
        colorHex: 0xFF4F3CD6,
        role: 'traveler',
        lastLatitude: 21.4264,
        lastLongitude: 91.9715,
        lastSeen: now.subtract(const Duration(seconds: 6)),
        rssiDbm: -68,
        speedMetersPerSecond: 0.8,
      ),
      PeerModel(
        id: '3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b4410',
        displayName: 'Nusrat Jahan',
        avatarIcon: '🐬',
        colorHex: 0xFFE84A8A,
        role: 'traveler',
        lastLatitude: 21.4281,
        lastLongitude: 91.9694,
        lastSeen: now.subtract(const Duration(seconds: 12)),
        rssiDbm: -74,
        speedMetersPerSecond: 0.5,
      ),
      PeerModel(
        id: '5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a9902',
        displayName: 'Arif Hasan',
        avatarIcon: '🌴',
        colorHex: 0xFF00A896,
        role: 'traveler',
        lastLatitude: 21.4255,
        lastLongitude: 91.9729,
        lastSeen: now.subtract(const Duration(seconds: 19)),
        rssiDbm: -81,
        speedMetersPerSecond: 1.4,
      ),
    ];

    for (final PeerModel peer in demoPeers) {
      _peersById[peer.id] = peer;
    }

    _messages.addAll(<MessageModel>[
      MessageModel(
        id: 'seed-msg-1',
        senderId: demoPeers[0].id,
        senderName: demoPeers[0].displayName,
        senderRole: demoPeers[0].role,
        content: 'Let’s meet by the red flag at Laboni Point at 5:30 PM.',
        type: 'text',
        latitude: 21.4278,
        longitude: 91.9708,
        landmarkName: 'Laboni Point',
        timestamp: now.subtract(const Duration(minutes: 4)),
        isDelivered: true,
      ),
      MessageModel(
        id: 'seed-msg-2',
        senderId: demoPeers[1].id,
        senderName: demoPeers[1].displayName,
        senderRole: demoPeers[1].role,
        content: '📍 Walking north toward Laboni Point now!',
        type: 'gps_ping',
        latitude: 21.4264,
        longitude: 91.9715,
        landmarkName: 'Laboni Point',
        timestamp: now.subtract(const Duration(minutes: 2)),
        isDelivered: true,
      ),
    ]);

    _emitPeers();
    _emitMessages();
    await _persistToDisk();
  }

  Future<void> clearAll() async {
    _identity = null;
    _peersById.clear();
    _messages.clear();
    _emitPeers();
    _emitMessages();
    await _persistToDisk();
  }

  void _emitPeers() {
    if (!_peersController.isClosed) {
      _peersController.add(currentPeers);
    }
  }

  void _emitMessages() {
    if (!_messagesController.isClosed) {
      _messagesController.add(currentMessages);
    }
  }

  Future<void> _persistToDisk() async {
    final String? path = _storageFilePath;
    if (path == null) return;
    try {
      final File file = File(path);
      file.parent.createSync(recursive: true);
      final Map<String, dynamic> snapshot = <String, dynamic>{
        'identity': _identity?.toJson(),
        'peers': _peersById.values.map((PeerModel p) => p.toMap()).toList(),
        'messages': _messages.map((MessageModel m) => m.toMap()).toList(),
      };
      final String encoded = jsonEncode(snapshot);
      final File tmpFile = File('$path.tmp');
      await tmpFile.writeAsString(encoded, flush: true);
      try {
        tmpFile.renameSync(path);
      } on Object {
        await file.writeAsString(encoded, flush: true);
      }
    } on Object {
      // Ignore file I/O errors in restricted or read-only sandboxes.
    }
  }

  Future<void> dispose() async {
    await _peersController.close();
    await _messagesController.close();
  }
}
