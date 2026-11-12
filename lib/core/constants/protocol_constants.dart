/// Core protocol, radio, and application constants for Sampan (সাম্পান).
///
/// Matches the specifications in `SAMPAN_BLUEPRINT.md` (Sections 1–6).
library;

class SampanConstants {
  const SampanConstants._();

  static const String appName = 'Sampan';
  static const String appNameBengali = 'সাম্পান';
  static const String tagline = 'Find your people, even offline.';
  static const String appVersion = '2.0.1';
  static const String logoAssetPath = 'Logo/Sampan.png';

  /// GitHub Release OTA Auto-Update Endpoints.
  static const String githubOwner = '8Masum';
  static const String githubRepo = 'sampan';
  static const String githubLatestReleaseApiUrl =
      'https://api.github.com/repos/$githubOwner/$githubRepo/releases/latest';
  static const String githubLatestApkDownloadUrl =
      'https://github.com/$githubOwner/$githubRepo/releases/latest/download/Sampan.apk';

  /// Open 128-bit BLE Service & Characteristic UUIDs (Section 3 & 6).
  static const String bleServiceUuid = '00005350-0000-1000-8000-00805f9b34fb';
  static const String bleTelemetryCharacteristicUuid =
      '00005351-0000-1000-8000-00805f9b34fb';
  static const String bleChatCharacteristicUuid =
      '00005352-0000-1000-8000-00805f9b34fb';

  /// Binary Wire Protocol Framing (Section 6.1 & 6.2).
  static const int magicByte0 = 0x53; // 'S'
  static const int magicByte1 = 0x50; // 'P'
  static const int protocolVersion = 0x01;

  static const int packetTypeTelemetry = 0x01;
  static const int packetTypeChat = 0x02;
  static const int packetTypeSos = 0x99;

  static const int roleByteGuide = 0x00;
  static const int roleByteTraveler = 0x01;

  static const int telemetryPacketByteLength = 28;
  static const int truncatedPublicKeyLength = 14;
  static const int ed25519PublicKeyLength = 32;
  static const int chatPacketHeaderByteLength = 68;

  /// Virtual Leash & Compass Homing Thresholds (Section 2.2 & 4.1).
  static const int virtualLeashRssiThresholdDbm = -85;
  static const int virtualLeashTimeoutSeconds = 45;
  static const double compassAlignmentToleranceDegrees = 10.0;
  static const double earthRadiusMeters = 6371000.0;

  /// Zero-Install SoftAP Hotspot Hub (Section 4.3).
  static const int softApDefaultPort = 8080;
  static const String softApDefaultSsid = 'Sampan-Beach-Hub-01';

  /// Onboarding Avatars & Identity Palette (Section 5.1).
  static const List<String> avatarIcons = <String>[
    '⛵',
    '🏄',
    '🐬',
    '🌴',
    '🧭',
    '🛟',
    '⚓',
    '🐚',
  ];

  static const List<int> identityColorHexes = <int>[
    0xFF6755EF, // Electric Violet (Brand Primary)
    0xFF4F3CD6, // Deep Iris
    0xFFE84A8A, // Expressive Berry Rose
    0xFF00A896, // Mint Teal
    0xFF3A86FF, // Sky Cobalt
    0xFF8338EC, // Vivid Orchid
  ];
}
