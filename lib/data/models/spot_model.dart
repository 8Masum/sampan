import 'package:flutter/foundation.dart';

/// A place the user saved at their own GPS location (e.g. "Meeting point",
/// "Parking"). Spots work anywhere on Earth, fully offline, and can be shared
/// to the group or used as a compass target to walk back to.
@immutable
class SpotModel {
  const SpotModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
  });

  /// Maximum spot name length shown on chips and in chat.
  static const int maxNameLength = 24;

  final String id;
  final String name;
  final String emoji;
  final double latitude;
  final double longitude;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'emoji': emoji,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory SpotModel.fromMap(Map<String, dynamic> map) {
    return SpotModel(
      id: map['id'] as String,
      name: map['name'] as String,
      emoji: map['emoji'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
