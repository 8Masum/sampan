import fs from 'node:fs';
import http from 'node:http';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));

/**
 * Creates a Sampan Zero-Install SoftAP Hub instance (Module 3 of SAMPAN_BLUEPRINT.md).
 * Serves the Coastal M3 responsive browser portal, real-time SSE stream (/events),
 * SOS Digital Megaphone & GPS ping endpoint (/send), telemetry (/status),
 * and local 25 MB/s P2P APK transfer endpoint (/download/sampan.apk).
 */
export function createSampanSoftApHub(options = {}) {
  const hostName = options.hostName || 'Tanvir Ahmed (Guide)';
  const hostLandmark = options.hostLandmark || 'Laboni Point';
  const hostLatitude = options.hostLatitude ?? 21.4272;
  const hostLongitude = options.hostLongitude ?? 91.9702;
  const apkFilePath = options.apkFilePath || null;

  const messages = [
    {
      id: 'seed-1',
      senderId: 'host-guide',
      sender: hostName,
      role: 'Host',
      type: 'text',
      text: `Caravan check-in at ${hostLandmark} (${hostLatitude.toFixed(4)}°N, ${hostLongitude.toFixed(4)}°E). Connected via Sampan SoftAP Hub!`,
      time: '17:00',
    },
  ];
  const sseClients = new Set();
  let apkDownloadsCount = 0;

  function broadcastSse(msg) {
    const frame = `data: ${JSON.stringify(msg)}\n\n`;
    for (const res of sseClients) {
      res.write(frame);
    }
  }

  function getPortalHtml() {
    const coords = `${hostLatitude.toFixed(4)}°N, ${hostLongitude.toFixed(4)}°E`;
    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Sampan (সাম্পান) — Zero-Install Beach & Trail Hub</title>
  <style>
    :root {
      --ocean-deep: #004D5A;
      --ocean-container: #A1EFFF;
      --sunset-amber: #E08244;
      --seafoam: #2A9D8F;
      --sandy-dune: #FAF8F5;
      --lifeguard-red: #BA1A1A;
      --surface-card: #FFFFFF;
      --text-main: #171C1E;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
    body { background: var(--sandy-dune); color: var(--text-main); display: flex; flex-direction: column; height: 100dvh; }
    header { background: var(--ocean-deep); color: #fff; padding: 12px 16px; display: flex; justify-content: space-between; align-items: center; }
    .brand-title { font-size: 17px; font-weight: 800; }
    .brand-sub { font-size: 11px; color: var(--ocean-container); margin-top: 2px; }
    .pill { font-size: 11px; padding: 5px 10px; border-radius: 999px; background: rgba(42, 157, 143, 0.25); color: var(--ocean-container); border: 1px solid var(--ocean-container); font-weight: 700; }
    .apk-banner { background: linear-gradient(90deg, #004D5A, #2A9D8F); padding: 10px 16px; display: flex; justify-content: space-between; align-items: center; gap: 10px; color: #fff; text-decoration: none; font-size: 13px; font-weight: 700; border-bottom: 2px solid var(--sunset-amber); }
    .apk-btn { background: var(--sunset-amber); color: #fff; padding: 6px 12px; border-radius: 999px; font-size: 12px; font-weight: 800; white-space: nowrap; }
    .host-bar { background: #EBF6F8; padding: 8px 16px; font-size: 12px; color: var(--ocean-deep); border-bottom: 1px solid #C9E2E7; display: flex; justify-content: space-between; flex-wrap: wrap; gap: 6px; font-weight: 600; }
    #setup-bar { background: var(--surface-card); padding: 8px 16px; border-bottom: 1px solid #E0E4E6; display: flex; gap: 8px; align-items: center; }
    #setup-bar input, #setup-bar select { border: 1.5px solid #BFC8CB; padding: 7px 10px; border-radius: 10px; font-size: 13px; background: var(--sandy-dune); color: var(--text-main); font-weight: 600; }
    #setup-bar input { flex: 1; }
    #action-bar { background: #FFF5F4; border-bottom: 1px solid #FFDAD6; padding: 9px 16px; display: flex; gap: 8px; align-items: center; }
    .sos-btn { background: var(--lifeguard-red); color: #fff; border: none; padding: 9px 14px; border-radius: 12px; font-weight: 800; font-size: 13px; cursor: pointer; flex: 1; }
    .gps-btn { background: var(--sunset-amber); color: #fff; border: none; padding: 9px 14px; border-radius: 12px; font-weight: 800; font-size: 13px; cursor: pointer; }
    #chat-container { flex: 1; overflow-y: auto; padding: 14px 16px; display: flex; flex-direction: column; gap: 10px; }
    .msg { max-width: 85%; padding: 10px 14px; border-radius: 16px; font-size: 14px; line-height: 1.4; word-break: break-word; }
    .msg.incoming { background: var(--surface-card); align-self: flex-start; border: 1px solid #DCE3E6; }
    .msg.outgoing { background: var(--ocean-deep); color: #fff; align-self: flex-end; }
    .msg.alert { background: #FFDAD6; border: 2px solid var(--lifeguard-red); color: #410002; align-self: center; width: 100%; text-align: center; font-weight: 800; }
    .msg-meta { font-size: 11px; opacity: 0.78; margin-bottom: 4px; display: flex; justify-content: space-between; gap: 8px; font-weight: 700; }
    footer { background: var(--surface-card); border-top: 1px solid #DCE3E6; padding: 10px 16px; display: flex; gap: 8px; }
    footer input { flex: 1; border: 1.5px solid #BFC8CB; padding: 10px 14px; border-radius: 999px; font-size: 14px; outline: none; }
    footer button { background: var(--ocean-deep); color: #fff; border: none; padding: 10px 20px; border-radius: 999px; font-weight: 800; cursor: pointer; }
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
    <span>🧭 Host: ${hostName}</span>
    <span>📍 ${hostLandmark} (${coords})</span>
  </div>
  <div id="setup-bar">
    <select id="role"><option value="Guest" selected>Traveler</option><option value="Host">Guide</option></select>
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
        postMessage({ type: 'gps_ping', text: '📍 Checked in near ${hostLandmark}' });
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
        () => postMessage({ type: 'gps_ping', text: '📍 Checked in near ${hostLandmark}' }),
        { enableHighAccuracy: true, timeout: 8000 }
      );
    }

    function escapeHtml(s) {
      return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    }
  </script>
</body>
</html>`;
  }

  function processIncomingPost(rawBody) {
    const parsed = JSON.parse(rawBody);
    const text = String(parsed.text || '').trim();
    if (!text) {
      throw new Error('Empty message text');
    }
    const msg = {
      id: `msg-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
      senderId: parsed.senderId || 'guest',
      sender: String(parsed.sender || 'Traveler').trim() || 'Traveler',
      role: parsed.role === 'Host' ? 'Host' : 'Guest',
      type: parsed.type === 'sos' || parsed.type === 'alert' ? 'sos' : (parsed.type || 'text'),
      text,
      latitude: parsed.latitude ?? null,
      longitude: parsed.longitude ?? null,
      time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
    };
    messages.push(msg);
    if (messages.length > 100) messages.shift();
    broadcastSse(msg);
    return msg;
  }

  const server = http.createServer((req, res) => {
    const url = req.url || '/';
    if (
      url === '/' ||
      url === '/index.html' ||
      url.startsWith('/generate_204') ||
      url.startsWith('/hotspot-detect')
    ) {
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(getPortalHtml());
    } else if (url === '/status' && req.method === 'GET') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(
        JSON.stringify({
          app: 'Sampan',
          ssid: 'Sampan-Beach-Hub-01',
          hostName,
          landmark: hostLandmark,
          hostLatitude,
          hostLongitude,
          connectedClients: sseClients.size,
          apkDownloadsCount,
        }),
      );
    } else if (url === '/events' && req.method === 'GET') {
      res.writeHead(200, {
        'Content-Type': 'text/event-stream; charset=utf-8',
        'Cache-Control': 'no-cache',
        Connection: 'keep-alive',
        'Access-Control-Allow-Origin': '*',
      });
      res.write('retry: 2000\n\n');
      for (const m of messages) {
        res.write(`data: ${JSON.stringify(m)}\n\n`);
      }
      sseClients.add(res);
      req.on('close', () => sseClients.delete(res));
    } else if (url === '/send' && req.method === 'POST') {
      let body = '';
      req.on('data', (chunk) => {
        body += chunk;
      });
      req.on('end', () => {
        try {
          const msg = processIncomingPost(body);
          res.writeHead(200, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ status: 'ok', id: msg.id }));
        } catch (err) {
          res.writeHead(400, { 'Content-Type': 'application/json' });
          res.end(JSON.stringify({ error: err.message }));
        }
      });
    } else if (url === '/download/sampan.apk' && req.method === 'GET') {
      apkDownloadsCount += 1;
      if (apkFilePath && fs.existsSync(apkFilePath)) {
        const stat = fs.statSync(apkFilePath);
        res.writeHead(200, {
          'Content-Type': 'application/vnd.android.package-archive',
          'Content-Disposition': 'attachment; filename="Sampan.apk"',
          'Content-Length': String(stat.size),
        });
        fs.createReadStream(apkFilePath).pipe(res);
      } else {
        res.writeHead(200, {
          'Content-Type': 'text/plain; charset=utf-8',
          'X-Sampan-P2P-Mode': 'simulation-fallback',
        });
        res.end('Sampan P2P APK Transfer Endpoint Ready (/download/sampan.apk).');
      }
    } else {
      res.writeHead(302, { Location: '/' });
      res.end();
    }
  });

  return {
    server,
    messages,
    getPortalHtml,
    processIncomingPost,
    getStats: () => ({
      messagesCount: messages.length,
      connectedClients: sseClients.size,
      apkDownloadsCount,
    }),
  };
}

if (process.argv[1] && path.resolve(process.argv[1]) === path.resolve(fileURLToPath(import.meta.url))) {
  const port = Number(process.env.PORT || 8080);
  const hub = createSampanSoftApHub();
  hub.server.listen(port, '0.0.0.0', () => {
    const nets = os.networkInterfaces();
    console.log('\n======================================================');
    console.log('⛵ Sampan (সাম্পান) — Zero-Install SoftAP Hub Running');
    console.log('======================================================');
    for (const name of Object.keys(nets)) {
      for (const net of nets[name] || []) {
        if (net.family === 'IPv4' && !net.internal) {
          console.log(` 👉 Hotspot / LAN URL: http://${net.address}:${port}`);
        }
      }
    }
    console.log(` 👉 Local URL:         http://localhost:${port}`);
    console.log('======================================================\n');
  });
}
