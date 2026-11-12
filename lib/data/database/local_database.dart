import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sampan/data/models/identity_profile.dart';
import 'package:sampan/data/models/message_model.dart';
import 'package:sampan/data/models/peer_model.dart';
import 'package:sampan/data/models/spot_model.dart';
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
  final Map<String, SpotModel> _spotsById = <String, SpotModel>{};
  String? _hotspotSsid;
  String? _hotspotPassword;

  final StreamController<List<PeerModel>> _peersController =
      StreamController<List<PeerModel>>.broadcast();
  final StreamController<List<MessageModel>> _messagesController =
      StreamController<List<MessageModel>>.broadcast();
  final StreamController<List<SpotModel>> _spotsController =
      StreamController<List<SpotModel>>.broadcast();

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

      final List<dynamic>? spotsRaw = decoded['spots'] as List<dynamic>?;
      if (spotsRaw != null) {
        _spotsById.clear();
        for (final dynamic item in spotsRaw) {
          final SpotModel spot =
              SpotModel.fromMap(item as Map<String, dynamic>);
          _spotsById[spot.id] = spot;
        }
      }

      final Map<String, dynamic>? hotspotRaw =
          decoded['hotspot'] as Map<String, dynamic>?;
      if (hotspotRaw != null) {
        _hotspotSsid = hotspotRaw['ssid'] as String?;
        _hotspotPassword = hotspotRaw['password'] as String?;
      }

      _emitPeers();
      _emitMessages();
      _emitSpots();
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

  /// Peer IDs of the demo companions that app versions before 3.0.0 seeded
  /// on first launch. Real peers never use these keys.
  static const Set<String> legacyDemoPeerIds = <String>{
    '7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b3c4d5e6f3f9c',
    '9f8e7d6c5b4a3f2e1d0c9b8a7f6e5d4c3b2a1f0e9d8c7b6a5f4e3d2c1b0a8821',
    '3c4d5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b4410',
    '5b6c7d8e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a9902',
  };

  static const String _legacyDemoMessagePrefix = 'seed-msg-';

  /// Removes the demo companions and messages seeded by app versions before
  /// 3.0.0, so upgraded installs only show real people nearby.
  /// Returns `true` when anything was removed.
  Future<bool> removeLegacyDemoData() async {
    final int peersBefore = _peersById.length;
    final int messagesBefore = _messages.length;
    _peersById.removeWhere(
      (String id, PeerModel _) => legacyDemoPeerIds.contains(id),
    );
    _messages.removeWhere(
      (MessageModel m) =>
          m.id.startsWith(_legacyDemoMessagePrefix) ||
          legacyDemoPeerIds.contains(m.senderId),
    );
    final bool changed = peersBefore != _peersById.length ||
        messagesBefore != _messages.length;
    if (!changed) return false;
    _emitPeers();
    _emitMessages();
    await _persistToDisk();
    return true;
  }

  /// User-created Spots, newest first.
  List<SpotModel> get currentSpots {
    final List<SpotModel> sorted = _spotsById.values.toList()
      ..sort((SpotModel a, SpotModel b) => b.createdAt.compareTo(a.createdAt));
    return List<SpotModel>.unmodifiable(sorted);
  }

  /// Reactive stream of user-created Spots.
  Stream<List<SpotModel>> watchSpots() async* {
    yield currentSpots;
    yield* _spotsController.stream;
  }

  Future<void> upsertSpot(SpotModel spot) async {
    _spotsById[spot.id] = spot;
    _emitSpots();
    await _persistToDisk();
  }

  Future<void> deleteSpot(String spotId) async {
    if (_spotsById.remove(spotId) == null) return;
    _emitSpots();
    await _persistToDisk();
  }

  /// Phone hotspot name & password the host typed in, used only to render
  /// the "join Wi-Fi" QR code on this device. Stored in app-private storage.
  String? get hotspotSsid => _hotspotSsid;
  String? get hotspotPassword => _hotspotPassword;

  Future<void> saveHotspotCredentials({
    required String ssid,
    required String password,
  }) async {
    final String cleanSsid = ssid.trim();
    _hotspotSsid = cleanSsid.isEmpty ? null : cleanSsid;
    _hotspotPassword = password.isEmpty ? null : password;
    await _persistToDisk();
  }

  Future<void> clearAll() async {
    _identity = null;
    _peersById.clear();
    _messages.clear();
    _spotsById.clear();
    _hotspotSsid = null;
    _hotspotPassword = null;
    _emitPeers();
    _emitMessages();
    _emitSpots();
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

  void _emitSpots() {
    if (!_spotsController.isClosed) {
      _spotsController.add(currentSpots);
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
        'spots': _spotsById.values.map((SpotModel s) => s.toMap()).toList(),
        'hotspot': <String, dynamic>{
          'ssid': _hotspotSsid,
          'password': _hotspotPassword,
        },
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
    await _spotsController.close();
  }
}
