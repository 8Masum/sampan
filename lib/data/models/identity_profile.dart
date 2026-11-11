import 'package:flutter/foundation.dart';
import 'package:sampan/core/crypto/identity_crypto_service.dart';

/// User's local zero-cloud cryptographic identity (Section 5.1).
@immutable
class IdentityProfile {
  const IdentityProfile({
    required this.publicKeyHex,
    required this.privateSeedHex,
    required this.displayName,
    required this.avatarIcon,
    required this.colorHex,
    required this.role,
    required this.createdAt,
  });

  final String publicKeyHex;
  final String privateSeedHex;
  final String displayName;
  final String avatarIcon;
  final int colorHex;

  /// Either `'guide'` (Tour Guide / Host) or `'traveler'` (Traveler / Guest).
  final String role;
  final DateTime createdAt;

  bool get isGuide => role == 'guide';

  String get fingerprintUri =>
      IdentityCryptoService.formatPublicFingerprint(publicKeyHex);

  String get truncated14ByteHex => publicKeyHex.length >= 28
      ? publicKeyHex.substring(0, 28)
      : publicKeyHex.padRight(28, '0');

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'publicKeyHex': publicKeyHex,
      'privateSeedHex': privateSeedHex,
      'displayName': displayName,
      'avatarIcon': avatarIcon,
      'colorHex': colorHex,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory IdentityProfile.fromJson(Map<String, dynamic> json) {
    return IdentityProfile(
      publicKeyHex: json['publicKeyHex'] as String,
      privateSeedHex: json['privateSeedHex'] as String,
      displayName: json['displayName'] as String,
      avatarIcon: json['avatarIcon'] as String,
      colorHex: json['colorHex'] as int,
      role: json['role'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
