import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';
import { createSampanSoftApHub } from './softap-hub-server.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');

// ============================================================================
// Reference Implementation matching lib/core/math/geo_math.dart &
// lib/core/protocol/wire_protocol.dart (Sections 4 & 6 of SAMPAN_BLUEPRINT.md)
// ============================================================================

const EARTH_RADIUS_M = 6371000.0;
const degToRad = (d) => d * (Math.PI / 180.0);
const radToDeg = (r) => r * (180.0 / Math.PI);

function normalizeDegrees(d) {
  if (!Number.isFinite(d)) return 0.0;
  const mod = d % 360.0;
  return mod < 0 ? mod + 360.0 : mod;
}

function calculateBearingDegrees(startLat, startLon, endLat, endLon) {
  if (startLat === endLat && startLon === endLon) return 0.0;
  const lat1 = degToRad(startLat);
  const lat2 = degToRad(endLat);
  const dLambda = degToRad(endLon - startLon);
  const y = Math.sin(dLambda) * Math.cos(lat2);
  const x =
    Math.cos(lat1) * Math.sin(lat2) -
    Math.sin(lat1) * Math.cos(lat2) * Math.cos(dLambda);
  return normalizeDegrees(radToDeg(Math.atan2(y, x)));
}

function calculateRelativeNeedleAngle(targetBearingDeg, deviceHeadingDeg) {
  return normalizeDegrees(targetBearingDeg - deviceHeadingDeg);
}

function shortestAngularDelta(fromDeg, toDeg) {
  const diff = normalizeDegrees(toDeg - fromDeg);
  return diff > 180.0 ? diff - 360.0 : diff;
}

function isAlignedWithTarget(targetBearingDeg, deviceHeadingDeg, toleranceDeg = 10.0) {
  return Math.abs(shortestAngularDelta(deviceHeadingDeg, targetBearingDeg)) <= toleranceDeg;
}

function calculateHaversineDistanceMeters(startLat, startLon, endLat, endLon) {
  if (startLat === endLat && startLon === endLon) return 0.0;
  const dLat = degToRad(endLat - startLat);
  const dLon = degToRad(endLon - startLon);
  const lat1 = degToRad(startLat);
  const lat2 = degToRad(endLat);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLon / 2) ** 2;
  const c = 2 * Math.atan2(Math.sqrt(Math.min(1, a)), Math.sqrt(Math.max(0, 1 - a)));
  return EARTH_RADIUS_M * c;
}

function evaluateVirtualLeash(currentRssiDbm, weakSignalSinceMs, nowMs, thresholdDbm = -85, timeoutSec = 45) {
  if (currentRssiDbm >= thresholdDbm) {
    return { isWeakSignal: false, isTripped: false, weakDurationSeconds: 0, weakSignalSinceMs: null };
  }
  const startMs = weakSignalSinceMs ?? nowMs;
  const elapsedSec = Math.max(0, Math.floor((nowMs - startMs) / 1000));
  return {
    isWeakSignal: true,
    isTripped: elapsedSec > timeoutSec,
    weakDurationSeconds: elapsedSec,
    weakSignalSinceMs: startMs,
  };
}

function encodeTelemetryPacket({ isGuide, latitude, longitude, speedMetersPerSecond, truncatedKeyHex }) {
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90) {
    throw new RangeError('Invalid latitude');
  }
  if (!Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    throw new RangeError('Invalid longitude');
  }
  const buf = Buffer.alloc(28);
  buf.writeUInt8(0x53, 0); // 'S'
  buf.writeUInt8(0x50, 1); // 'P'
  buf.writeUInt8(0x01, 2); // Telemetry
  buf.writeUInt8(isGuide ? 0x00 : 0x01, 3);
  buf.writeFloatBE(latitude, 4);
  buf.writeFloatBE(longitude, 8);
  const speedCm = Math.max(0, Math.min(65535, Math.round((speedMetersPerSecond || 0) * 100)));
  buf.writeUInt16BE(speedCm, 12);
  const keyBytes = Buffer.from(truncatedKeyHex.padEnd(28, '0').slice(0, 28), 'hex');
  keyBytes.copy(buf, 14, 0, 14);
  return buf;
}

function decodeTelemetryPacket(buf) {
  if (buf.length !== 28) throw new Error('Expected 28-byte telemetry packet');
  if (buf[0] !== 0x53 || buf[1] !== 0x50) throw new Error('Invalid magic bytes');
  if (buf[2] !== 0x01) throw new Error('Unexpected packet type');
  const isGuide = buf[3] === 0x00;
  const latitude = buf.readFloatBE(4);
  const longitude = buf.readFloatBE(8);
  if (!Number.isFinite(latitude) || latitude < -90 || latitude > 90 || !Number.isFinite(longitude) || longitude < -180 || longitude > 180) {
    throw new Error('Coordinates out of bounds');
  }
  const speedMetersPerSecond = buf.readUInt16BE(12) / 100.0;
  const truncatedKeyHex = buf.subarray(14, 28).toString('hex');
  return { isGuide, latitude, longitude, speedMetersPerSecond, truncatedKeyHex };
}

function encodeWireMessagePacket({ version = 0x01, packetType, senderPublicKeyHex, destinationPublicKeyHex, payloadBuffer }) {
  if (payloadBuffer.length > 65535) throw new RangeError('Payload exceeds uint16');
  const buf = Buffer.alloc(68 + payloadBuffer.length);
  buf.writeUInt8(version, 0);
  buf.writeUInt8(packetType, 1);
  Buffer.from(senderPublicKeyHex.padEnd(64, '0').slice(0, 64), 'hex').copy(buf, 2, 0, 32);
  if (destinationPublicKeyHex) {
    Buffer.from(destinationPublicKeyHex.padEnd(64, '0').slice(0, 64), 'hex').copy(buf, 34, 0, 32);
  }
  buf.writeUInt16BE(payloadBuffer.length, 66);
  payloadBuffer.copy(buf, 68);
  return buf;
}

function decodeWireMessagePacket(buf) {
  if (buf.length < 68) throw new Error('Packet shorter than 68-byte GATT header');
  const version = buf.readUInt8(0);
  if (version !== 0x01) throw new Error('Unsupported version');
  const packetType = buf.readUInt8(1);
  if (packetType !== 0x02 && packetType !== 0x99) throw new Error('Invalid packet type');
  const declaredLen = buf.readUInt16BE(66);
  if (buf.length !== 68 + declaredLen) throw new Error('Payload length mismatch');
  const senderPublicKeyHex = buf.subarray(2, 34).toString('hex');
  const destSlice = buf.subarray(34, 66);
  const isAllZero = destSlice.every((b) => b === 0);
  const destinationPublicKeyHex = isAllZero ? null : destSlice.toString('hex');
  const payloadBuffer = buf.subarray(68);
  return { version, packetType, senderPublicKeyHex, destinationPublicKeyHex, payloadBuffer };
}

// ============================================================================
// Automated Verification Tests
// ============================================================================

test('Module 1 Math: Bearing, Relative Needle Angle, Alignment & Haversine', () => {
  assert.ok(Math.abs(calculateBearingDegrees(21.0, 91.0, 22.0, 91.0) - 0.0) < 0.01);
  assert.ok(Math.abs(calculateBearingDegrees(0.0, 90.0, 0.0, 91.0) - 90.0) < 0.01);
  assert.ok(Math.abs(calculateBearingDegrees(22.0, 91.0, 21.0, 91.0) - 180.0) < 0.01);
  assert.equal(calculateBearingDegrees(21.4272, 91.9702, 21.4272, 91.9702), 0.0);

  // Relative needle wrap-around
  assert.equal(calculateRelativeNeedleAngle(10.0, 350.0), 20.0);
  assert.equal(calculateRelativeNeedleAngle(45.0, 15.0), 30.0);

  // +/-10 degree alignment across 0/360 boundary
  assert.equal(isAlignedWithTarget(355.0, 4.0, 10.0), true);
  assert.equal(isAlignedWithTarget(355.0, 6.0, 10.0), false);

  // Laboni Point to Sugandha Beach Haversine distance
  const dist = calculateHaversineDistanceMeters(21.4272, 91.9702, 21.4195, 91.9756);
  assert.ok(dist > 950 && dist < 1100, `Expected ~1020m, got ${dist}`);
});

test('Module 1 Virtual Leash: -85 dBm threshold and >45s continuous timeout', () => {
  const t0 = 1_700_000_000_000;
  // At -85 dBm (not strictly below -85 dBm)
  const atBoundary = evaluateVirtualLeash(-85, null, t0);
  assert.equal(atBoundary.isWeakSignal, false);
  assert.equal(atBoundary.isTripped, false);

  // Drops to -89 dBm at t0
  const weak0 = evaluateVirtualLeash(-89, null, t0);
  assert.equal(weak0.isWeakSignal, true);
  assert.equal(weak0.isTripped, false);

  // At +45s (boundary: not >45s yet)
  const weak45 = evaluateVirtualLeash(-89, weak0.weakSignalSinceMs, t0 + 45_000);
  assert.equal(weak45.isTripped, false);

  // At +46s (>45s -> TRIPPED!)
  const weak46 = evaluateVirtualLeash(-89, weak0.weakSignalSinceMs, t0 + 46_000);
  assert.equal(weak46.isTripped, true);
  assert.equal(weak46.weakDurationSeconds, 46);
});

test('Section 6.1: 28-Byte BLE Telemetry Packet binary framing & validation', () => {
  const pkt = encodeTelemetryPacket({
    isGuide: true,
    latitude: 21.4272,
    longitude: 91.9702,
    speedMetersPerSecond: 1.35,
    truncatedKeyHex: '7a8b9c0d1e2f3a4b5c6d7e8f9a0b',
  });
  assert.equal(pkt.length, 28);
  assert.equal(pkt[0], 0x53);
  assert.equal(pkt[1], 0x50);
  assert.equal(pkt[2], 0x01);
  assert.equal(pkt[3], 0x00);

  const decoded = decodeTelemetryPacket(pkt);
  assert.equal(decoded.isGuide, true);
  assert.ok(Math.abs(decoded.latitude - 21.4272) < 0.0001);
  assert.ok(Math.abs(decoded.longitude - 91.9702) < 0.0001);
  assert.ok(Math.abs(decoded.speedMetersPerSecond - 1.35) < 0.01);
  assert.equal(decoded.truncatedKeyHex, '7a8b9c0d1e2f3a4b5c6d7e8f9a0b');

  // Edge cases
  assert.throws(() => encodeTelemetryPacket({ isGuide: false, latitude: 95, longitude: 90, speedMetersPerSecond: 0, truncatedKeyHex: '00' }));
  assert.throws(() => decodeTelemetryPacket(Buffer.alloc(10)));
});

test('Section 6.2: Chat & SOS GATT Packet framing & Ed25519 + ChaCha20-Poly1305 E2EE', () => {
  const { publicKey, privateKey } = crypto.generateKeyPairSync('ed25519');
  const rawPubHex = publicKey.export({ type: 'spki', format: 'der' }).subarray(-32).toString('hex');
  assert.equal(rawPubHex.length, 64);

  // ChaCha20-Poly1305 AEAD encryption round-trip
  const key = crypto.createHash('sha256').update('sampan:v1:caravan:bay-of-bengal-mesh').digest();
  const nonce = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('chacha20-poly1305', key, nonce, { authTagLength: 16 });
  const plaintext = Buffer.from('Regroup at Laboni Point red lifeguard stand at 17:30!', 'utf8');
  const encrypted = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  const tag = cipher.getAuthTag();
  const wirePayload = Buffer.concat([nonce, encrypted, tag]);

  const gattFrame = encodeWireMessagePacket({
    packetType: 0x02,
    senderPublicKeyHex: rawPubHex,
    destinationPublicKeyHex: null,
    payloadBuffer: wirePayload,
  });
  assert.equal(gattFrame.length, 68 + wirePayload.length);

  const decodedFrame = decodeWireMessagePacket(gattFrame);
  assert.equal(decodedFrame.packetType, 0x02);
  assert.equal(decodedFrame.senderPublicKeyHex, rawPubHex);
  assert.equal(decodedFrame.destinationPublicKeyHex, null);

  // Decrypt payload
  const rxNonce = decodedFrame.payloadBuffer.subarray(0, 12);
  const rxTag = decodedFrame.payloadBuffer.subarray(decodedFrame.payloadBuffer.length - 16);
  const rxCiphertext = decodedFrame.payloadBuffer.subarray(12, decodedFrame.payloadBuffer.length - 16);
  const decipher = crypto.createDecipheriv('chacha20-poly1305', key, rxNonce, { authTagLength: 16 });
  decipher.setAuthTag(rxTag);
  const decrypted = Buffer.concat([decipher.update(rxCiphertext), decipher.final()]).toString('utf8');
  assert.equal(decrypted, 'Regroup at Laboni Point red lifeguard stand at 17:30!');
});

test('Codebase Integrity: Dart imports, balanced delimiters, and lint hygiene', () => {
  function collectDartFiles(dir) {
    const out = [];
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) out.push(...collectDartFiles(full));
      else if (entry.name.endsWith('.dart')) out.push(full);
    }
    return out;
  }

  const dartFiles = [
    ...collectDartFiles(path.join(ROOT, 'lib')),
    ...collectDartFiles(path.join(ROOT, 'test')),
  ];
  assert.ok(dartFiles.length >= 16, `Expected >=16 Dart files, found ${dartFiles.length}`);

  for (const file of dartFiles) {
    const content = fs.readFileSync(file, 'utf8');
    const rel = path.relative(ROOT, file);

    // 1. Check all package:sampan/... imports resolve to existing files in lib/
    const importRegex = /import\s+['"]package:sampan\/([^'"]+)['"]/g;
    let match;
    while ((match = importRegex.exec(content)) !== null) {
      const targetPath = path.join(ROOT, 'lib', match[1]);
      assert.ok(
        fs.existsSync(targetPath),
        `Broken import in ${rel}: package:sampan/${match[1]} does not exist`,
      );
    }

    // 2. Ensure no deprecated withOpacity calls or raw print() statements in lib/
    if (rel.startsWith('lib')) {
      assert.equal(
        /\bprint\s*\(/.test(content),
        false,
        `Disallowed print() found in ${rel}`,
      );
      assert.equal(
        /\.withOpacity\s*\(/.test(content),
        false,
        `Deprecated .withOpacity() found in ${rel}; use .withAlpha() instead`,
      );
      assert.equal(
        /import\s+['"]dart:ui['"]/.test(content) &&
          /import\s+['"]package:flutter\/material\.dart['"]/.test(content),
        false,
        `Redundant dart:ui import alongside material.dart in ${rel}`,
      );
      if (content.includes('PlatformDispatcher')) {
        assert.equal(
          /import\s+['"]package:flutter\/foundation\.dart['"]/.test(content),
          true,
          `File ${rel} uses PlatformDispatcher and must import package:flutter/foundation.dart`,
        );
      }
    }

    // 3. Enforce strict-inference (no untyped final variables) and lowerCamelCase getters
    const lines = content.split(/\r?\n/);
    lines.forEach((line, idx) => {
      assert.equal(
        /^\s*final\s+[a-zA-Z0-9_]+\s*=/.test(line),
        false,
        `Untyped final variable at ${rel}:${idx + 1}: ${line.trim()}`,
      );
      assert.equal(
        /\b(get|set)\s+[A-Z]/.test(line),
        false,
        `UpperCamelCase getter/setter at ${rel}:${idx + 1}: ${line.trim()}`,
      );
    });
  }

  // 4. Verify widget_smoke_test.dart ensures visibility before tapping onboarding CTA
  const widgetTestContent = fs.readFileSync(
    path.join(ROOT, 'test', 'widget_smoke_test.dart'),
    'utf8',
  );
  assert.ok(
    widgetTestContent.includes('tester.ensureVisible'),
    'widget_smoke_test.dart must call tester.ensureVisible before tapping scrollable buttons',
  );

  // 5. Verify Android MainActivity.kt strips 2-byte 0x5350 header for addManufacturerData
  // so legacy BLE advertisement PDU stays <= 31 bytes (2B AD + 2B 0x5350 + 26B body = 30B)
  const mainActivityKt = fs.readFileSync(
    path.join(
      ROOT,
      'android',
      'app',
      'src',
      'main',
      'kotlin',
      'com',
      'themasum',
      'sampan',
      'MainActivity.kt',
    ),
    'utf8',
  );
  assert.ok(
    mainActivityKt.includes('payload28Bytes.copyOfRange(2, 28)'),
    'MainActivity.kt must strip 2-byte magic prefix when calling addManufacturerData(0x5350, ...) to stay within 31-byte BLE PDU limit',
  );
  assert.ok(
    mainActivityKt.includes('onRequestPermissionsResult'),
    'MainActivity.kt must handle onRequestPermissionsResult to start BLE/GNSS after user grants permissions',
  );
});

test('Module 3 SoftAP Hub: Zero-Install Portal HTML, live HTTP server, SOS ingestion & APK route', async () => {
  const hub = createSampanSoftApHub({
    hostName: "Tanvir's <Guide>",
    hostLandmark: "Cox's Bazar — Laboni Point",
    hostLatitude: 21.4272,
    hostLongitude: 91.9702,
  });

  const html = hub.getPortalHtml();
  assert.ok(html.includes('Sampan (সাম্পান)'));
  assert.ok(html.includes('/download/sampan.apk'));
  assert.ok(html.includes('#004D5A'));
  assert.ok(html.includes('Tanvir&#39;s &lt;Guide&gt;'), 'Host name must be HTML-escaped');
  assert.ok(html.includes('Cox&#39;s Bazar'), 'Landmark must be HTML-escaped');
  assert.ok(html.includes('<script>'), 'Portal HTML must include client-side <script>');
  assert.ok(html.includes('function sendText()'), 'Portal HTML must define sendText()');
  assert.ok(html.includes('function sendMegaphone()'), 'Portal HTML must define sendMegaphone()');
  assert.ok(html.includes('function sendLocation()'), 'Portal HTML must define sendLocation()');
  assert.ok(html.includes("new EventSource('/events')"), 'Portal HTML must connect to /events SSE');

  const sosMsg = hub.processIncomingPost(
    JSON.stringify({
      senderId: 'web-1',
      sender: 'Rahim',
      role: 'Guest',
      type: 'sos',
      text: 'Separated near Laboni Point red lifeguard stand!',
    }),
  );
  assert.equal(sosMsg.type, 'sos');
  assert.equal(hub.getStats().messagesCount, 2);

  // Reject empty messages
  assert.throws(() => hub.processIncomingPost(JSON.stringify({ text: '   ' })));

  // Execute embedded browser <script> inside a VM sandbox to verify client JS logic
  const scriptMatch = html.match(/<script>([\s\S]*?)<\/script>/);
  assert.ok(scriptMatch, 'Expected <script> tag in SoftAP portal HTML');

  const appendedNodes = [];
  const postedBodies = [];
  const elements = {
    username: { value: '' },
    role: { value: 'Guest' },
    'chat-container': {
      scrollHeight: 200,
      scrollTop: 0,
      appendChild: (node) => appendedNodes.push(node),
    },
    'msg-input': { value: 'Hello from cox bazar beach!' },
  };

  let eventSourceInstance = null;
  const sandbox = {
    Math,
    Set,
    String,
    JSON,
    document: {
      getElementById: (id) => elements[id],
      createElement: (tag) => ({ tag, className: '', innerHTML: '' }),
    },
    navigator: {
      vibrate: () => true,
    },
    EventSource: function MockEventSource(url) {
      this.url = url;
      eventSourceInstance = this;
    },
    fetch: async (url, opts) => {
      postedBodies.push({ url, body: opts.body });
      hub.processIncomingPost(opts.body);
      return { ok: true, status: 200 };
    },
    prompt: (_title, defaultVal) => defaultVal,
  };

  vm.runInNewContext(scriptMatch[1], sandbox);
  assert.ok(eventSourceInstance, 'EventSource should be initialized');
  assert.equal(eventSourceInstance.url, '/events');

  // Simulate receiving an SSE message in the browser
  eventSourceInstance.onmessage({
    data: JSON.stringify({
      id: 'sse-1',
      senderId: 'guide-1',
      sender: 'Tanvir',
      role: 'Host',
      type: 'text',
      text: 'Regroup <now>',
      time: '17:15',
    }),
  });
  assert.equal(appendedNodes.length, 1);
  assert.ok(appendedNodes[0].innerHTML.includes('Regroup &lt;now&gt;'));

  // Simulate clicking Send in the browser
  await sandbox.sendText();
  assert.equal(postedBodies.length, 1);
  assert.equal(hub.getStats().messagesCount, 3);

  // Simulate clicking Share Offline GPS fallback (verifies apostrophe in landmark does not break JS)
  await sandbox.sendLocation();
  assert.equal(postedBodies.length, 2);
  assert.equal(hub.getStats().messagesCount, 4);
});

