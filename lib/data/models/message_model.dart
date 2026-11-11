import 'package:flutter/foundation.dart';

/// Immutable message record matching the `Messages` schema in Section 5.2
/// of `SAMPAN_BLUEPRINT.md`.
@immutable
class MessageModel {
  const MessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.content,
    required this.type,
    required this.timestamp,
    this.recipientId,
    this.latitude,
    this.longitude,
    this.landmarkName,
    this.isDelivered = false,
    this.isEncrypted = true,
  });

  /// UUID v4 or packet hash — Primary Key in `Messages` table.
  final String id;

  /// References `Peers.id` (Sender's Ed25519 public key hex).
  final String senderId;
  final String senderName;
  final String senderRole;

  /// `null` indicates Caravan Group Ring broadcast; non-null indicates 1-to-1 DM.
  final String? recipientId;

  /// Decrypted UTF-8 text or SOS emergency broadcast payload.
  final String content;

  /// Message classification: `'text'` | `'sos'` | `'gps_ping'`.
  final String type;

  /// Optional attached GNSS latitude.
  final double? latitude;

  /// Optional attached GNSS longitude.
  final double? longitude;

  /// Optional attached offline landmark chip name (e.g., `'Laboni Point'`).
  final String? landmarkName;

  final DateTime timestamp;
  final bool isDelivered;
  final bool isEncrypted;

  bool get isSos => type == 'sos';
  bool get isGpsPing => type == 'gps_ping';
  bool get isDirectMessage => recipientId != null && recipientId!.isNotEmpty;

  MessageModel copyWith({
    bool? isDelivered,
  }) {
    return MessageModel(
      id: id,
      senderId: senderId,
      senderName: senderName,
      senderRole: senderRole,
      recipientId: recipientId,
      content: content,
      type: type,
      latitude: latitude,
      longitude: longitude,
      landmarkName: landmarkName,
      timestamp: timestamp,
      isDelivered: isDelivered ?? this.isDelivered,
      isEncrypted: isEncrypted,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'recipientId': recipientId,
      'content': content,
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
      'landmarkName': landmarkName,
      'timestamp': timestamp.toIso8601String(),
      'isDelivered': isDelivered ? 1 : 0,
      'isEncrypted': isEncrypted ? 1 : 0,
    };
  }

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] as String,
      senderId: map['senderId'] as String,
      senderName: (map['senderName'] as String?) ?? 'Peer',
      senderRole: (map['senderRole'] as String?) ?? 'traveler',
      recipientId: map['recipientId'] as String?,
      content: map['content'] as String,
      type: map['type'] as String,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      landmarkName: map['landmarkName'] as String?,
      timestamp: DateTime.parse(map['timestamp'] as String),
      isDelivered: map['isDelivered'] == true || map['isDelivered'] == 1,
      isEncrypted: map['isEncrypted'] == null ||
          map['isEncrypted'] == true ||
          map['isEncrypted'] == 1,
    );
  }
}
