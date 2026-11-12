import 'dart:io';

import 'package:flutter/services.dart';
import 'package:sampan/core/constants/protocol_constants.dart';

/// Snapshot of device magnetometer compass heading and offline satellite
/// GNSS coordinates.
class DeviceSensorSnapshot {
  const DeviceSensorSnapshot({
    required this.headingDegrees,
    required this.latitude,
    required this.longitude,
    required this.speedMetersPerSecond,
    required this.isCompassCalibrated,
    required this.isHardwareGnss,
  });

  final double headingDegrees;
  final double latitude;
  final double longitude;
  final double speedMetersPerSecond;
  final bool isCompassCalibrated;
  final bool isHardwareGnss;
}

/// Raw BLE advertisement frame received from the platform scanner.
class RawBleAdvertisement {
  const RawBleAdvertisement({
    required this.deviceAddress,
    required this.rssiDbm,
    required this.payload,
  });

  final String deviceAddress;
  final int rssiDbm;
  final Uint8List payload;
}

/// Platform channel abstraction isolating native Android BLE, GNSS,
/// Magnetometer, and APK file path inspection.
class NativeBridge {
  const NativeBridge();

  static const MethodChannel _channel = MethodChannel('sampan.mesh/native');

  /// Returns the persistent internal application files directory on Android
  /// (`applicationContext.filesDir.absolutePath`) so on-device identity,
  /// peers, and messages are stored in non-volatile storage rather than cache.
  Future<String?> getAppDataDirectory() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return null;
    }
    try {
      final String? dir = await _channel.invokeMethod<String>('getAppDataDir');
      if (dir != null && dir.isNotEmpty) {
        return dir;
      }
    } on Object {
      // Fallback when running on non-Android platforms or tests.
    }
    return null;
  }

  /// Returns the path to the currently installed Android APK (`sourceDir`)
  /// so the embedded `shelf` server can stream it over SoftAP Wi-Fi at 25 MB/s
  /// with zero internet connectivity (Section 4, Module 3).
  Future<String?> getInstalledApkPath() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return null;
    }
    try {
      final String? path = await _channel.invokeMethod<String>('getApkPath');
      if (path != null && path.isNotEmpty && File(path).existsSync()) {
        return path;
      }
    } on Object {
      // Fallback when running in tests or non-Android platforms.
    }
    return null;
  }

  /// Queries the installed Android package `versionName` via `PackageManager`.
  Future<String> getInstalledAppVersion() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return SampanConstants.appVersion;
    }
    try {
      final String? ver = await _channel.invokeMethod<String>('getAppVersion');
      if (ver != null && ver.trim().isNotEmpty) {
        return ver.trim();
      }
    } on Object {
      // Fallback to compile-time version on non-Android platforms or tests.
    }
    return SampanConstants.appVersion;
  }

  /// Opens an `https` link in the user's browser. Used for app updates: the
  /// browser downloads the release APK quickly and shows Android's own
  /// "Install / Update" prompt. Returns `false` if no browser could open it.
  Future<bool> openUrlInBrowser(String url) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return true;
    }
    try {
      final bool? opened = await _channel.invokeMethod<bool>(
        'openUrl',
        <String, dynamic>{'url': url},
      );
      return opened ?? false;
    } on Object {
      return false;
    }
  }

  /// Enumerates non-loopback IPv4 LAN/Hotspot addresses (`192.168.43.1`, etc.).
  Future<List<String>> getLocalIpv4Addresses() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return const <String>['192.168.43.1'];
    }

    final Set<String> addresses = <String>{};
    try {
      final List<NetworkInterface> interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final NetworkInterface iface in interfaces) {
        for (final InternetAddress addr in iface.addresses) {
          if (!addr.isLoopback && addr.address.isNotEmpty) {
            addresses.add(addr.address);
          }
        }
      }
    } on Object {
      // Ignore interface enumeration errors in restricted environments.
    }

    if (addresses.isEmpty) {
      try {
        final List<dynamic>? nativeIps =
            await _channel.invokeMethod<List<dynamic>>('getLocalIpAddresses');
        if (nativeIps != null) {
          for (final dynamic ip in nativeIps) {
            if (ip is String && ip.isNotEmpty) {
              addresses.add(ip);
            }
          }
        }
      } on Object {
        // Ignore platform channel errors in test environments.
      }
    }

    if (addresses.isEmpty) {
      addresses.add('192.168.43.1');
    }
    return addresses.toList(growable: false);
  }

  /// Requests Android 12+ BLE (`BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE`,
  /// `BLUETOOTH_CONNECT`) and offline GNSS (`ACCESS_FINE_LOCATION`) runtime
  /// permissions on physical devices.
  Future<bool> requestRuntimePermissions() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return true;
    }
    try {
      final bool? granted =
          await _channel.invokeMethod<bool>('requestPermissions');
      return granted ?? false;
    } on Object {
      return false;
    }
  }

  /// Queries the native Android SensorManager (Magnetometer + Accelerometer)
  /// and LocationManager (`GPS_PROVIDER`).
  Future<DeviceSensorSnapshot?> getHardwareSensorSnapshot() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return null;
    }
    try {
      final Map<dynamic, dynamic>? raw = await _channel
          .invokeMethod<Map<dynamic, dynamic>>('getSensorSnapshot');
      if (raw == null) return null;
      return DeviceSensorSnapshot(
        headingDegrees: (raw['headingDegrees'] as num?)?.toDouble() ?? 0.0,
        latitude: (raw['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (raw['longitude'] as num?)?.toDouble() ?? 0.0,
        speedMetersPerSecond: (raw['speedMps'] as num?)?.toDouble() ?? 0.0,
        isCompassCalibrated: (raw['isCalibrated'] as bool?) ?? true,
        isHardwareGnss: (raw['hasGpsFix'] as bool?) ?? false,
      );
    } on Object {
      return null;
    }
  }

  /// Broadcasts the compact 28-byte BLE Telemetry Packet (`0x53 0x50`) via
  /// native `BluetoothLeAdvertiser`.
  Future<bool> advertiseBleTelemetry(Uint8List packet28Bytes) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return true;
    }
    try {
      final bool? ok = await _channel.invokeMethod<bool>(
        'startBleAdvertising',
        <String, dynamic>{'payload': packet28Bytes},
      );
      return ok ?? false;
    } on Object {
      return false;
    }
  }

  /// Fetches recently scanned 28-byte Sampan BLE advertisements from the
  /// native `BluetoothLeScanner`.
  Future<List<RawBleAdvertisement>> pollScannedBleAdvertisements() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return const <RawBleAdvertisement>[];
    }
    try {
      final List<dynamic>? rawList =
          await _channel.invokeMethod<List<dynamic>>('pollBleScanResults');
      if (rawList == null) return const <RawBleAdvertisement>[];

      final List<RawBleAdvertisement> out = <RawBleAdvertisement>[];
      for (final dynamic item in rawList) {
        if (item is Map<dynamic, dynamic>) {
          final Uint8List? payload = item['payload'] as Uint8List?;
          if (payload != null) {
            out.add(
              RawBleAdvertisement(
                deviceAddress: (item['address'] as String?) ?? 'unknown',
                rssiDbm: (item['rssi'] as num?)?.toInt() ?? -70,
                payload: payload,
              ),
            );
          }
        }
      }
      return out;
    } on Object {
      return const <RawBleAdvertisement>[];
    }
  }
}
