import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

// Initialize Uuid instance
final _uuid = Uuid();

@immutable
class Message {
  final String id;
  final String content;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final DateTime timestamp;
  final bool isCurrentUser;

  Message({
    String? id,
    required this.content,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    DateTime? timestamp,
    bool? isCurrentUser,
  })  : id = id ?? _uuid.v4(),
        timestamp = timestamp ?? DateTime.now(),
        isCurrentUser = isCurrentUser ?? false;

  Message copyWith({
    String? id,
    String? content,
    String? senderId,
    String? senderName,
    String? senderAvatar,
    DateTime? timestamp,
    bool? isCurrentUser,
  }) {
    return Message(
      id: id ?? this.id,
      content: content ?? this.content,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      timestamp: timestamp ?? this.timestamp,
      isCurrentUser: isCurrentUser ?? this.isCurrentUser,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'content': content,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isCurrentUser': isCurrentUser,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String? ?? '',
      content: map['content'] as String? ?? '',
      senderId: map['senderId'] as String? ?? '',
      senderName: map['senderName'] as String? ?? 'Unknown',
      senderAvatar: map['senderAvatar'] as String?,
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.now(),
      isCurrentUser: map['isCurrentUser'] as bool? ?? false,
    );
  }
}
