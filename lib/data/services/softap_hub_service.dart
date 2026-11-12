import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:sampan/core/constants/protocol_constants.dart';
import 'package:sampan/data/database/local_database.dart';
import 'package:sampan/data/models/identity_profile.dart';
import 'package:sampan/data/models/message_model.dart';
import 'package:sampan/data/models/peer_model.dart';
import 'package:sampan/data/services/native_bridge.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Tier 2 Zero-Install SoftAP Hotspot Portal powered by an embedded Dart
/// `shelf` server (Section 4, Module 3 of `SAMPAN_BLUEPRINT.md`).
class SoftApHubService {
  SoftApHubService({
    required LocalDatabase database,
    NativeBridge nativeBridge = const NativeBridge(),
  })  : _database = database,
        _nativeBridge = nativeBridge;

  final LocalDatabase _database;
  final NativeBridge _nativeBridge;

  HttpServer? _server;
  StreamSubscription<List<MessageModel>>? _dbMessagesSub;
  final Set<StreamController<List<int>>> _sseControllers =
      <StreamController<List<int>>>{};
  final Set<String> _broadcastedMessageIds = <String>{};
  final StreamController<void> _statsController =
      StreamController<void>.broadcast();

  int _apkDownloadsCount = 0;
  double _hostLatitude = 21.4272;
  double _hostLongitude = 91.9702;
  String _hostLandmark = 'Laboni Point';

  bool get isRunning => _server != null;
  int get activePort => _server?.port ?? SampanConstants.softApDefaultPort;
  int get connectedClientsCount => _sseControllers.length;
  int get apkDownloadsCount => _apkDownloadsCount;
  Stream<void> get onStatsChanged => _statsController.stream;

  void _notifyStatsChanged() {
    if (!_statsController.isClosed) {
      _statsController.add(null);
    }
  }

  void updateHostLocation({
    required double latitude,
    required double longitude,
    String? landmark,
  }) {
    _hostLatitude = latitude;
    _hostLongitude = longitude;
    if (landmark != null && landmark.isNotEmpty) {
      _hostLandmark = landmark;
    }
  }

  /// Starts the embedded `shelf` HTTP/SSE server on `0.0.0.0:[port]`.
  Future<int> startServer({
    int port = SampanConstants.softApDefaultPort,
  }) async {
    if (_server != null) {
      return _server!.port;
    }

    final Handler handler = const Pipeline()
        .addMiddleware(_corsMiddleware())
        .addHandler(_handleRequest);

    _server = await shelf_io.serve(
      handler,
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );

    _broadcastedMessageIds
      ..clear()
      ..addAll(_database.currentMessages.map((MessageModel m) => m.id));

    _dbMessagesSub = _database.watchMessages().listen((List<MessageModel> all) {
      for (final MessageModel msg in all) {
        if (_broadcastedMessageIds.add(msg.id)) {
          _broadcastSseMessage(msg);
        }
      }
    });

    return _server!.port;
  }

  /// Stops the embedded `shelf` server and closes all active SSE streams.
  Future<void> stopServer() async {
    await _dbMessagesSub?.cancel();
    _dbMessagesSub = null;
    _broadcastedMessageIds.clear();

    for (final StreamController<List<int>> controller
        in _sseControllers.toList()) {
      await controller.close();
    }
    _sseControllers.clear();

    final HttpServer? srv = _server;
    _server = null;
    if (srv != null) {
      await srv.close(force: true);
    }
  }

  Middleware _corsMiddleware() {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok(
            '',
            headers: <String, String>{
              'Access-Control-Allow-Origin': '*',
              'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
              'Access-Control-Allow-Headers': 'Content-Type',
            },
          );
        }
        final Response response = await innerHandler(request);
        return response.change(
          headers: <String, String>{
            ...response.headers,
            'Access-Control-Allow-Origin': '*',
          },
        );
      };
    };
  }

  Future<Response> _handleRequest(Request request) async {
    final String path = '/${request.url.path}';

    // 1. Zero-install Web Portal & Captive Portal detection endpoints
    if (path == '/' ||
        path == '/index.html' ||
        path.startsWith('/generate_204') ||
        path.startsWith('/hotspot-detect') ||
        path.startsWith('/ncsi.txt')) {
      return Response.ok(
        buildZeroInstallPortalHtml(),
        headers: <String, String>{
          'Content-Type': 'text/html; charset=utf-8',
          'Cache-Control': 'no-store',
        },
      );
    }

    // 2. Host status & Caravan telemetry JSON
    if (path == '/status' && request.method == 'GET') {
      final IdentityProfile? host = _database.identity;
      final Map<String, dynamic> status = <String, dynamic>{
        'app': SampanConstants.appName,
        'ssid': SampanConstants.softApDefaultSsid,
        'hostName': host?.displayName ?? 'Tour Guide',
        'hostRole': host?.role ?? 'guide',
        'hostLatitude': _hostLatitude,
        'hostLongitude': _hostLongitude,
        'landmark': _hostLandmark,
        'connectedClients': connectedClientsCount,
        'peersInMesh': _database.currentPeers.length,
        'apkDownloads': _apkDownloadsCount,
      };
      return Response.ok(
        jsonEncode(status),
        headers: <String, String>{'Content-Type': 'application/json'},
      );
    }

    // 3. Server-Sent Events (SSE) live stream for browser guests
    if (path == '/events' && request.method == 'GET') {
      final StreamController<List<int>> controller =
          StreamController<List<int>>();
      _sseControllers.add(controller);
      _notifyStatsChanged();

      controller.onCancel = () {
        _sseControllers.remove(controller);
        _notifyStatsChanged();
      };

      // Send retry interval and recent caravan history immediately
      controller.add(utf8.encode('retry: 2000\n\n'));
      for (final MessageModel msg in _database.getCaravanBroadcastMessages()) {
        final String payload = jsonEncode(_messageToPortalJson(msg));
        controller.add(utf8.encode('data: $payload\n\n'));
      }

      return Response.ok(
        controller.stream,
        headers: <String, String>{
          'Content-Type': 'text/event-stream; charset=utf-8',
          'Cache-Control': 'no-cache',
          'Connection': 'keep-alive',
        },
        context: <String, Object>{'shelf.io.buffer_output': false},
      );
    }

    // 4. Receive chat, GPS ping, or SOS callout from browser guest
    if (path == '/send' && request.method == 'POST') {
      try {
        final String body = await request.readAsString();
        final Map<String, dynamic> data =
            jsonDecode(body) as Map<String, dynamic>;
        final String senderName =
            ((data['sender'] as String?) ?? 'Guest').trim();
        final String text = ((data['text'] as String?) ?? '').trim();
        final String rawType = (data['type'] as String?) ?? 'text';
        if (text.isEmpty) {
          return Response.badRequest(body: 'Empty message text');
        }

        final String normalizedType = switch (rawType) {
          'alert' || 'sos' => 'sos',
          'gps_ping' => 'gps_ping',
          _ => 'text',
        };

        final DateTime now = DateTime.now();
        final String resolvedSenderId =
            (data['senderId'] as String?) ?? 'softap-guest';
        final String resolvedSenderName =
            senderName.isEmpty ? 'Beach Guest' : senderName;
        final String rawRole =
            (data['role'] as String?)?.toLowerCase() ?? 'traveler';
        final String resolvedRole =
            (rawRole == 'host' || rawRole == 'guide') ? 'guide' : 'traveler';
        final double? lat = (data['latitude'] as num?)?.toDouble();
        final double? lon = (data['longitude'] as num?)?.toDouble();

        final MessageModel message = MessageModel(
          id: 'softap-${now.microsecondsSinceEpoch}',
          senderId: resolvedSenderId,
          senderName: resolvedSenderName,
          senderRole: resolvedRole,
          content: text,
          type: normalizedType,
          latitude: lat,
          longitude: lon,
          landmarkName: data['landmark'] as String?,
          timestamp: now,
          isDelivered: true,
          isEncrypted: false,
        );

        if (lat != null && lon != null) {
          final PeerModel? existing = _database.getPeerById(resolvedSenderId);
          final PeerModel peerUpdate = existing != null
              ? existing.copyWith(
                  displayName: resolvedSenderName,
                  role: resolvedRole,
                  lastLatitude: lat,
                  lastLongitude: lon,
                  lastSeen: now,
                )
              : PeerModel(
                  id: resolvedSenderId,
                  displayName: resolvedSenderName.length > 32
                      ? resolvedSenderName.substring(0, 32)
                      : resolvedSenderName,
                  avatarIcon: resolvedRole == 'guide' ? '⛵' : '🏄',
                  colorHex: resolvedRole == 'guide' ? 0xFF6755EF : 0xFF4F3CD6,
                  role: resolvedRole,
                  lastLatitude: lat,
                  lastLongitude: lon,
                  lastSeen: now,
                  rssiDbm: -55,
                );
          await _database.upsertPeer(peerUpdate);
        }

        await _database.insertMessage(message);
        return Response.ok(
          jsonEncode(<String, dynamic>{'status': 'ok', 'id': message.id}),
          headers: <String, String>{'Content-Type': 'application/json'},
        );
      } on Object {
        return Response.badRequest(body: 'Invalid JSON payload');
      }
    }

    // 5. Direct 25 MB/s P2P APK Download over Local Wi-Fi (Section 4, Module 3)
    if (path == '/download/sampan.apk' && request.method == 'GET') {
      _apkDownloadsCount++;
      _notifyStatsChanged();
      final String? apkPath = await _nativeBridge.getInstalledApkPath();
      if (apkPath != null) {
        final File apkFile = File(apkPath);
        if (apkFile.existsSync()) {
          return Response.ok(
            apkFile.openRead(),
            headers: <String, String>{
              'Content-Type': 'application/vnd.android.package-archive',
              'Content-Disposition': 'attachment; filename="Sampan.apk"',
              'Content-Length': apkFile.lengthSync().toString(),
            },
          );
        }
      }

      // Fallback when tested on desktop/CI outside an installed Android APK
      return Response.ok(
        'Sampan Local P2P APK Transfer Endpoint Ready. '
        'On an Android Host device, this endpoint streams applicationInfo.sourceDir '
        '(Sampan.apk) at ~25 MB/s over local SoftAP Wi-Fi with zero internet.',
        headers: <String, String>{
          'Content-Type': 'text/plain; charset=utf-8',
          'X-Sampan-P2P-Mode': 'simulation-fallback',
        },
      );
    }

    // Captive portal fallback redirect to `/`
    return Response.found('/');
  }

  void _broadcastSseMessage(MessageModel msg) {
    if (msg.isDirectMessage || _sseControllers.isEmpty) return;
    final String encoded =
        'data: ${jsonEncode(_messageToPortalJson(msg))}\n\n';
    final List<int> bytes = utf8.encode(encoded);
    for (final StreamController<List<int>> client
        in _sseControllers.toList()) {
      if (!client.isClosed) {
        client.add(bytes);
      }
    }
  }

  static Map<String, dynamic> _messageToPortalJson(MessageModel msg) {
    final String hh = msg.timestamp.hour.toString().padLeft(2, '0');
    final String mm = msg.timestamp.minute.toString().padLeft(2, '0');
    return <String, dynamic>{
      'id': msg.id,
      'senderId': msg.senderId,
      'sender': msg.senderName,
      'role': msg.senderRole == 'guide' ? 'Host' : 'Guest',
      'type': msg.isSos ? 'alert' : msg.type,
      'text': msg.content,
      'latitude': msg.latitude,
      'longitude': msg.longitude,
      'landmark': msg.landmarkName,
      'time': '$hh:$mm',
    };
  }

  static String _escapeHtml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Generates the Zero-Install Responsive Web Client HTML (Section 4, Module 3)
  /// styled with Sampan's Playful Material Design 3 Coastal Maritime Palette.
  String buildZeroInstallPortalHtml() {
    final IdentityProfile? host = _database.identity;
    final String hostName =
        _escapeHtml(host?.displayName ?? 'Tanvir Ahmed (Guide)');
    final String safeLandmarkHtml = _escapeHtml(_hostLandmark);
    final String safeCheckinJsLiteral =
        jsonEncode('📍 Checked in near $_hostLandmark');
    final String coords =
        '${_hostLatitude.toStringAsFixed(4)}°N, ${_hostLongitude.toStringAsFixed(4)}°E';

    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Sampan (সাম্পান) — Zero-Install Beach & Trail Hub</title>
  <style>
    :root {
      --ocean-deep: #6755EF;
      --ocean-container: #DDD4FF;
      --sunset-amber: #F4FF90;
      --seafoam: #4F3CD6;
      --sandy-dune: #F7F5FF;
      --lifeguard-red: #BA1A1A;
      --surface-card: #FFFFFF;
      --text-main: #1B1145;
      --text-muted: #564C7A;
      --legacy-ocean: #004D5A;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
    body { background: var(--sandy-dune); color: var(--text-main); display: flex; flex-direction: column; height: 100dvh; }
    header { background: var(--ocean-deep); color: #fff; padding: 14px 18px; display: flex; justify-content: space-between; align-items: center; }
    .brand-title { font-size: 18px; font-weight: 900; letter-spacing: -0.2px; color: var(--sunset-amber); }
    .brand-sub { font-size: 11px; color: #fff; opacity: 0.85; margin-top: 2px; }
    .pill { font-size: 11px; padding: 6px 12px; border-radius: 999px; background: var(--sunset-amber); color: var(--text-main); font-weight: 800; }
    .apk-banner { background: var(--ocean-container); padding: 10px 18px; display: flex; justify-content: space-between; align-items: center; gap: 10px; color: var(--text-main); text-decoration: none; font-size: 13px; font-weight: 800; }
    .apk-btn { background: var(--ocean-deep); color: var(--sunset-amber); padding: 6px 14px; border-radius: 999px; font-size: 12px; font-weight: 800; white-space: nowrap; }
    .host-bar { background: #EFEAFF; padding: 8px 18px; font-size: 12px; color: var(--text-main); display: flex; justify-content: space-between; flex-wrap: wrap; gap: 6px; font-weight: 700; }
    #setup-bar { background: var(--surface-card); padding: 8px 18px; display: flex; gap: 8px; align-items: center; }
    #setup-bar input, #setup-bar select { border: none; padding: 9px 14px; border-radius: 999px; font-size: 13px; background: #EFEAFF; color: var(--text-main); font-weight: 700; }
    #setup-bar input { flex: 1; }
    #action-bar { background: var(--surface-card); padding: 8px 18px 10px; display: flex; gap: 8px; align-items: center; }
    .sos-btn { background: var(--lifeguard-red); color: #fff; border: none; padding: 10px 16px; border-radius: 999px; font-weight: 800; font-size: 13px; cursor: pointer; flex: 1; }
    .gps-btn { background: var(--ocean-container); color: var(--text-main); border: none; padding: 10px 16px; border-radius: 999px; font-weight: 800; font-size: 13px; cursor: pointer; }
    #chat-container { flex: 1; overflow-y: auto; padding: 16px 18px; display: flex; flex-direction: column; gap: 10px; }
    .msg { max-width: 85%; padding: 12px 16px; border-radius: 22px; font-size: 14px; line-height: 1.4; word-break: break-word; }
    .msg.incoming { background: var(--ocean-container); color: var(--text-main); align-self: flex-start; }
    .msg.outgoing { background: var(--ocean-deep); color: #fff; align-self: flex-end; }
    .msg.alert { background: #FFDAD6; border: 2px solid var(--lifeguard-red); color: #410002; align-self: center; width: 100%; text-align: center; font-weight: 800; }
    .msg-meta { font-size: 11px; opacity: 0.78; margin-bottom: 4px; display: flex; justify-content: space-between; gap: 8px; font-weight: 700; }
    footer { background: var(--surface-card); padding: 10px 18px 14px; display: flex; gap: 8px; }
    footer input { flex: 1; border: none; background: #EFEAFF; padding: 12px 18px; border-radius: 999px; font-size: 14px; outline: none; }
    footer button { background: var(--ocean-deep); color: var(--sunset-amber); border: none; padding: 12px 22px; border-radius: 999px; font-weight: 900; cursor: pointer; }
  </style>
</head>
<body>
  <header>
    <div>
      <div class="brand-title">⛵ Sampan (সাম্পান)</div>
      <div class="brand-sub">Zero-Cloud SoftAP Rendezvous Portal</div>
    </div>
    <div class="pill">📡 Hotspot Connected</div>
  </header>

  <a class="apk-banner" href="/download/sampan.apk">
    <span>⚡ Download Native Sampan App (Fast Local Transfer • No Internet Needed)</span>
    <span class="apk-btn">Get APK</span>
  </a>

  <div class="host-bar">
    <span>🧭 Host: $hostName</span>
    <span>📍 $safeLandmarkHtml ($coords)</span>
  </div>

  <div id="setup-bar">
    <select id="role">
      <option value="Guest" selected>Traveler</option>
      <option value="Host">Guide</option>
    </select>
    <input type="text" id="username" placeholder="Your Name (e.g., Rahim)">
  </div>

  <div id="action-bar">
    <button class="sos-btn" onclick="sendMegaphone()">🚨 SOS Digital Megaphone</button>
    <button class="gps-btn" onclick="sendLocation()">📍 Share Offline GPS</button>
  </div>

  <div id="chat-container"></div>

  <footer>
    <input type="text" id="msg-input" placeholder="Message caravan offline..." onkeydown="if(event.key==='Enter') sendText()">
    <button onclick="sendText()">Send</button>
  </footer>

  <script>
    const myId = 'web-' + Math.random().toString(36).substring(2, 9);
    const seenIds = new Set();
    const usernameInput = document.getElementById('username');
    const roleSelect = document.getElementById('role');
    const chatContainer = document.getElementById('chat-container');
    const msgInput = document.getElementById('msg-input');
    usernameInput.value = 'Traveler-' + myId.substring(4, 8);

    const evtSource = new EventSource('/events');
    evtSource.onmessage = (e) => {
      const data = JSON.parse(e.data);
      if (data.id && seenIds.has(data.id)) return;
      if (data.id) seenIds.add(data.id);
      renderMessage(data);
    };

    function renderMessage(msg) {
      const div = document.createElement('div');
      const isMe = msg.senderId === myId;
      if (msg.type === 'alert' || msg.type === 'sos') {
        div.className = 'msg alert';
        div.innerHTML = '🚨 <strong>SOS ALERT from ' + escapeHtml(msg.sender) + ':</strong> ' + escapeHtml(msg.text);
        if (navigator.vibrate) navigator.vibrate([300, 120, 300, 120, 400]);
      } else {
        div.className = 'msg ' + (isMe ? 'outgoing' : 'incoming');
        div.innerHTML = '<div class="msg-meta"><span>' + escapeHtml(msg.sender) + ' (' + escapeHtml(msg.role) + ')</span><span>' + escapeHtml(msg.time || '') + '</span></div>' + escapeHtml(msg.text);
      }
      chatContainer.appendChild(div);
      chatContainer.scrollTop = chatContainer.scrollHeight;
    }

    async function postMessage(payload) {
      payload.senderId = myId;
      payload.sender = usernameInput.value.trim() || 'Traveler';
      payload.role = roleSelect.value;
      await fetch('/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
    }

    function sendText() {
      const text = msgInput.value.trim();
      if (!text) return;
      msgInput.value = '';
      postMessage({ type: 'text', text });
    }

    function sendMegaphone() {
      const text = prompt('🚨 Broadcast Emergency SOS Megaphone to Caravan:', 'Separated near Laboni Point red lifeguard stand! Please ping bearing.');
      if (text) postMessage({ type: 'sos', text });
    }

    function sendLocation() {
      if (!navigator.geolocation) {
        postMessage({ type: 'gps_ping', text: $safeCheckinJsLiteral });
        return;
      }
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          const lat = pos.coords.latitude.toFixed(5);
          const lon = pos.coords.longitude.toFixed(5);
          postMessage({
            type: 'gps_ping',
            latitude: pos.coords.latitude,
            longitude: pos.coords.longitude,
            text: '📍 Offline Satellite GPS: ' + lat + ', ' + lon + ' (±' + Math.round(pos.coords.accuracy) + 'm)'
          });
        },
        () => postMessage({ type: 'gps_ping', text: $safeCheckinJsLiteral }),
        { enableHighAccuracy: true, timeout: 8000 }
      );
    }

    function escapeHtml(s) {
      return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#39;');
    }
  </script>
</body>
</html>''';
  }
}
