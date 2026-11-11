import 'package:flutter/foundation.dart';
import 'package:sampan/core/crypto/identity_crypto_service.dart';

/// Immutable peer record matching the `Peers` schema in Section 5.2
/// of `SAMPAN_BLUEPRINT.md`.
@immutable
class PeerModel {
  const PeerModel({
    required this.id,
    required this.displayName,
    required this.avatarIcon,
    required this.colorHex,
    required this.role,
    required this.lastSeen,
    this.lastLatitude,
    this.lastLongitude,
    this.rssiDbm = -62,
    this.speedMetersPerSecond = 0.0,
    this.weakSignalSince,
    this.isLeashFrozen = false,
  });

  /// Public Key (Hex) — Primary Key in `Peers` table.
  final String id;

  /// Display name (`1..32` chars).
  final String displayName;

  /// Avatar symbol (`⛵`, `🏄`, `🐬`, `🌴`, etc.).
  final String avatarIcon;

  /// ARGB 32-bit identity color hex.
  final int colorHex;

  /// Either `'guide'` or `'traveler'`.
  final String role;

  /// Last known offline GNSS latitude.
  final double? lastLatitude;

  /// Last known offline GNSS longitude.
  final double? lastLongitude;

  /// Timestamp of last received BLE/SoftAP frame.
  final DateTime lastSeen;

  /// Latest BLE RSSI signal strength in dBm (e.g., `-58` strong, `-92` weak).
  final int rssiDbm;

  /// Latest movement speed in meters/second.
  final double speedMetersPerSecond;

  /// Timestamp when RSSI first dropped below `-85 dBm` continuously.
  final DateTime? weakSignalSince;

  /// True when Virtual Leash tripped (`< -85 dBm` for `> 45s`) and
  /// coordinates are frozen on the radar.
  final bool isLeashFrozen;

  bool get isGuide => role == 'guide';

  String get fingerprintUri =>
      IdentityCryptoService.formatPublicFingerprint(id);

  PeerModel copyWith({
    String? id,
    String? displayName,
    String? avatarIcon,
    int? colorHex,
    String? role,
    double? lastLatitude,
    double? lastLongitude,
    DateTime? lastSeen,
    int? rssiDbm,
    double? speedMetersPerSecond,
    DateTime? weakSignalSince,
    bool clearWeakSignalSince = false,
    bool? isLeashFrozen,
  }) {
    return PeerModel(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarIcon: avatarIcon ?? this.avatarIcon,
      colorHex: colorHex ?? this.colorHex,
      role: role ?? this.role,
      lastLatitude: lastLatitude ?? this.lastLatitude,
      lastLongitude: lastLongitude ?? this.lastLongitude,
      lastSeen: lastSeen ?? this.lastSeen,
      rssiDbm: rssiDbm ?? this.rssiDbm,
      speedMetersPerSecond: speedMetersPerSecond ?? this.speedMetersPerSecond,
      weakSignalSince: clearWeakSignalSince
          ? null
          : (weakSignalSince ?? this.weakSignalSince),
      isLeashFrozen: isLeashFrozen ?? this.isLeashFrozen,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'displayName': displayName,
      'avatarIcon': avatarIcon,
      'colorHex': colorHex,
      'role': role,
      'lastLatitude': lastLatitude,
      'lastLongitude': lastLongitude,
      'lastSeen': lastSeen.toIso8601String(),
      'rssiDbm': rssiDbm,
      'speedMetersPerSecond': speedMetersPerSecond,
      'weakSignalSince': weakSignalSince?.toIso8601String(),
      'isLeashFrozen': isLeashFrozen ? 1 : 0,
    };
  }

  factory PeerModel.fromMap(Map<String, dynamic> map) {
    return PeerModel(
      id: map['id'] as String,
      displayName: map['displayName'] as String,
      avatarIcon: map['avatarIcon'] as String,
      colorHex: map['colorHex'] as int,
      role: map['role'] as String,
      lastLatitude: (map['lastLatitude'] as num?)?.toDouble(),
      lastLongitude: (map['lastLongitude'] as num?)?.toDouble(),
      lastSeen: DateTime.parse(map['lastSeen'] as String),
      rssiDbm: (map['rssiDbm'] as num?)?.toInt() ?? -62,
      speedMetersPerSecond:
          (map['speedMetersPerSecond'] as num?)?.toDouble() ?? 0.0,
      weakSignalSince: map['weakSignalSince'] != null
          ? DateTime.parse(map['weakSignalSince'] as String)
          : null,
      isLeashFrozen:
          map['isLeashFrozen'] == true || map['isLeashFrozen'] == 1,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PeerModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          displayName == other.displayName &&
          avatarIcon == other.avatarIcon &&
          colorHex == other.colorHex &&
          role == other.role &&
          lastLatitude == other.lastLatitude &&
          lastLongitude == other.lastLongitude &&
          lastSeen == other.lastSeen &&
          rssiDbm == other.rssiDbm &&
          speedMetersPerSecond == other.speedMetersPerSecond &&
          weakSignalSince == other.weakSignalSince &&
          isLeashFrozen == other.isLeashFrozen;

  @override
  int get hashCode => Object.hash(
        id,
        displayName,
        avatarIcon,
        colorHex,
        role,
        lastLatitude,
        lastLongitude,
        lastSeen,
        rssiDbm,
        speedMetersPerSecond,
        weakSignalSince,
        isLeashFrozen,
      );
}
