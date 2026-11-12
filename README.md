<p align="center">
  <img src="Logo/Sampan.png" width="140" height="140" alt="Sampan Logo" />
</p>

<h1 align="center">Sampan (সাম্পান)</h1>

<p align="center">
  <strong>Local-First, Zero-Cloud P2P Mesh for Travel &amp; Co-Presence</strong><br>
  <em>"Find your people, even offline." — 100% Offline • Zero-Cloud • Material Design 3 Expressive</em>
</p>

<p align="center">
  <a href="https://github.com/8Masum/sampan/releases/latest">
    <img src="https://img.shields.io/github/v/release/8Masum/sampan?color=6755EF&label=Latest%20Release&logo=github" alt="Latest Release" />
  </a>
  <a href="https://github.com/8Masum/sampan/actions/workflows/build-apk.yml">
    <img src="https://github.com/8Masum/sampan/actions/workflows/build-apk.yml/badge.svg?branch=main" alt="Build and Release" />
  </a>
  <a href="#security--cryptography">
    <img src="https://img.shields.io/badge/Crypto-Ed25519_%2B_ChaCha20-6755EF.svg" alt="Ed25519 + ChaCha20-Poly1305" />
  </a>
  <a href="#architecture">
    <img src="https://img.shields.io/badge/Mesh-BLE_%2B_SoftAP_Hub-4F3CD6.svg" alt="BLE + SoftAP Hub" />
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-3B82F6.svg" alt="MIT License" />
  </a>
</p>

<p align="center">
  <a href="https://github.com/8Masum/sampan/releases/latest/download/Sampan.apk">
    <img src="https://img.shields.io/badge/Download_APK-Sampan.apk-6755EF?style=for-the-badge&logo=android&logoColor=F4FF90" alt="Download APK" />
  </a>
</p>

---

## 🌊 Overview

During peak travel seasons or emergencies in crowded and remote destinations (e.g., **Cox's Bazar beach**, mountain trekking routes, outdoor festivals), cellular networks suffer catastrophic congestion or complete blackout. Tour guides (hosts) and travelers (guests) get separated in noisy crowds where shouting names fails.

Named after the traditional crescent-shaped wooden boats navigating the turbulent waters of the Bay of Bengal, **Sampan (সাম্পান)** is an **offline-first, zero-cloud social and safety network**. It empowers smartphones to communicate directly with one another over **Bluetooth Low Energy (BLE)** and **Local Wi-Fi Hotspots (SoftAP)** without cellular towers, satellite subscriptions, or cloud servers.

```text
       _____                                          
      /     \    S A M P A N  (সাম্পান)               
  ___/_______\___ "Navigating crowds, tides, and trails together."
  \             / 100% Offline • Zero-Cloud • Material Design 3
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
```

### Core Tenet: `$0.00` Infrastructure Cost
- **Zero Cloud Servers**: No AWS, Firebase, or Supabase hosting bills.
- **Pure Local-First Integrity**: All user identities, messages, and waypoints live in local on-device storage and replicate purely peer-to-peer (P2P).
- **Zero Registration**: Under-10-second onboarding generates an on-device **Ed25519** keypair (`sampan:ed25519:7a8b...3f9c`) without phone numbers, emails, or SMS verification.

---

## 📱 Quick Download & Auto-Update

| Release | File | Action |
| :--- | :--- | :--- |
| **Latest Release** | `Sampan.apk` | [**Download Raw APK**](https://github.com/8Masum/sampan/releases/latest/download/Sampan.apk) |
| **Checksums** | `SHA256SUMS.txt` | [**View File Hashes**](https://github.com/8Masum/sampan/releases/latest/download/SHA256SUMS.txt) |
| **All Releases** | Release changelogs & tags | [**View GitHub Releases**](https://github.com/8Masum/sampan/releases) |

- **Built-in GitHub Release OTA Auto-Update**: Whenever internet is available, Sampan silently checks `8Masum/sampan/releases/latest` (or tap the **System Update** icon in the top bar) to download `Sampan.apk` and launch Android's native package installer in-place.
- **Offline Caravan Propagation**: Once the Tour Guide updates their app via GitHub Releases, any traveler connecting to the Guide's **SoftAP Hotspot Hub** (`/download/sampan.apk`) automatically receives the newly updated APK offline at 25 MB/s.

---

## ✨ The Three Core Modules

### 🧭 Module 1: Directional Compass Radar & "Virtual Leash"
- **3D-Styled Compass Homing Dial**: Interactive, 60/120 FPS custom canvas radar with spring physics (`Curves.elasticOut`) rendering heading and distance to guides and companions.
- **Sensor Fusion Engine**: Combines offline satellite GNSS coordinates $(\text{lat}_1, \text{lon}_1)$, companion BLE/SoftAP telemetry $(\text{lat}_2, \text{lon}_2)$, and magnetometer heading $\alpha \in [0^\circ, 360^\circ)$ to compute exact forward azimuth $(\beta)$, relative needle angle $(\beta - \alpha) \pmod{360^\circ}$, and Great-Circle Haversine distance (`85m away`).
- **Haptic Alignment Lock**: Subtle tactile ticks when pointing within $\pm 10^\circ$ of your target companion.
- **The "Virtual Leash"**: If a companion's BLE beacon RSSI drops below `-85 dBm` for `> 45` continuous seconds, Sampan triggers a heavy haptic/visual alarm and freezes their last-known GPS coordinates and bearing on the radar.

### 🚨 Module 2: Offline Caravan Chat & Digital Megaphone (SOS)
- **Concentric Rings of Communication**:
  1. **Caravan Group Ring**: ChaCha20-Poly1305 authenticated encrypted broadcast chat between the Tour Guide and all registered guests.
  2. **Direct P2P DMs**: 1-to-1 encrypted conversations between companions.
  3. **The Digital Megaphone (SOS)**: High-priority unencrypted emergency broadcast with bearing and distance telemetry (`🚨 SOS Alert from Rahim: "Separated near Laboni Point red lifeguard stand!" [Bearing: 035°, 110m]`).
- **Offline Landmark Pings**: Pre-loaded Cox's Bazar & coastal landmark chips (`🏖️ Laboni Point`, `🌊 Sugandha Beach`, `🐬 Kolatoli Point`, `🪨 Inani Coral Reef`, `⛰️ Himchari Waterfall`, `⚓ Saint Martin Jetty`) for one-tap situational sharing.

### 📡 Module 3: Zero-Install SoftAP Hotspot Portal
Solves the "cold-start" adoption dilemma when travelers haven't pre-installed the app:
1. **Host SoftAP Activation**: The Tour Guide enables their phone Wi-Fi hotspot (`Sampan-Beach-Hub-01`).
2. **Embedded Dart Server**: Sampan launches a background `shelf` HTTP & Server-Sent Events (SSE) server on port `8080`.
3. **Instant Browser Access**: Unregistered guests connect to Wi-Fi and open `http://192.168.43.1:8080` in Chrome or Safari for live group chat, offline GPS sharing, and SOS alerts.
4. **Direct 25 MB/s P2P APK Download**: Guests can tap **`⚡ Download Native Sampan App`** (`/download/sampan.apk`) to transfer the full Android APK directly from the Host's phone in `< 5` seconds without internet.

---

## 🎨 Minimalist Material Design 3 Expressive Palette (v2.0.0)

| Token Role | Hex Code | Visual Metaphor & Purpose |
| :--- | :--- | :--- |
| **Brand Primary (Electric Violet)** | `#6755EF` | Official Sampan brand primary; anchors hero cards, radar dial, and outgoing bubbles. |
| **Brand Accent (Acid Lime)** | `#F4FF90` | Official Sampan brand highlight; powers hero CTAs, target lock pills, and compass needle. |
| **Primary Container (Soft Lavender)** | `#DDD4FF` / `#261E4A` | Sculptural M3 containers, incoming chat bubbles, and metric tiles. |
| **Surface Canvas** | `#F7F5FF` *(Light)* / `#0E0A1F` *(Dark)* | Airy lavender-white light canvas & deep cosmic violet dark canvas. |
| **Error / SOS** | `#BA1A1A` / `#FF5449` | High-priority SOS broadcast and Safety Leash drift alerts. |

Includes a one-tap **Sunlight High-Contrast Mode (`☀️ >7:1`)** in the top app bar that boosts contrast ratios and font weights for direct tropical beach sunlight.

---

<a id="architecture"></a>
## 📐 Architecture & Binary Wire Protocol

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        SAMPAN APPLICATION LAYER                        │
│   Flutter 3.x (Dart 3) • Material Design 3 • Riverpod 2.x State Engine │
├────────────────────────────────────────────────────────────────────────┤
│                           CORE V1 MODULES                              │
│  ┌───────────────────────┐ ┌────────────────────┐ ┌──────────────────┐ │
│  │ Module 1: Radar Homing│ │ Module 2: Chat/SOS │ │ Module 3: SoftAP │ │
│  │ Compass & Distance    │ │ Offline Messaging  │ │ Zero-Install Hub │ │
│  └───────────────────────┘ └────────────────────┘ └──────────────────┘ │
├────────────────────────────────────────────────────────────────────────┤
│                       SECURITY & LOCAL STORAGE                         │
│  - Ed25519 / ChaCha20-Poly1305 AEAD (Zero-Server E2EE)                 │
│  - Local-First Reactive Store (Peers & Messages SQLite Schema)         │
├────────────────────────────────┬───────────────────────────────────────┤
│    TIER 1: BLE MESH ENGINE     │       TIER 2: LOCAL SOFTAP HUB        │
│  - 28B Telemetry Packet (0x5350│  - Dart shelf HTTP / SSE Server       │
│  - 68B+ GATT Chat/SOS Framing  │  - Zero-Install Browser Web Client    │
│  - Virtual Leash (-85dBm / 45s)│  - 25 MB/s Local P2P APK Streamer     │
└────────────────────────────────┴───────────────────────────────────────┘
```

### Telemetry Packet (28 Bytes — Fits Legacy 31-Byte BLE Advertisement)
```text
┌───────────┬──────────┬──────────┬──────────┬──────────┬──────────┬──────────┐
│ Magic (2B)│ Type (1B)│ Role (1B)│ Lat (4B) │ Lon (4B) │ Spd (2B) │ EpKey(14)│
│  0x53 0x50│   0x01   │   0x00   │  float32 │  float32 │  uint16  │ truncated│
└───────────┴──────────┴──────────┴──────────┴──────────┴──────────┴──────────┘
```

### Chat & SOS Packet (L2CAP / GATT Write Characteristic)
```text
┌───────────┬──────────┬────────────┬────────────┬─────────────┬─────────────┐
│ Vers (1B) │ Type (1B)│ Sender(32B)│ Dest (32B) │ Payload Len │ Encrypted   │
│   0x01    │ 0x02/0x99│   Ed25519  │  Ed25519   │   uint16    │ Payload     │
└───────────┴──────────┴────────────┴────────────┴─────────────┴─────────────┘
```

---

## 💻 Development, Verification & Publishing

### 1. Run Protocol, Geo-Math & SoftAP Verification Suite (Node.js)
```bash
node --test scripts/verify-all.mjs
```

### 2. Run Standalone Desktop SoftAP Hub Preview (Node.js)
```bash
node scripts/softap-hub-server.mjs
```

### 3. Run Flutter Analyzer, Tests & APK Build
```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

### 4. Push to GitHub & Trigger Automated APK Release
Run the included PowerShell publisher script:
```powershell
.\scripts\push-to-github.ps1
```
*(Or `./scripts/push-to-github.sh` in Git Bash)*

---

## 📄 License

This project is open-source under the [MIT License](LICENSE).
