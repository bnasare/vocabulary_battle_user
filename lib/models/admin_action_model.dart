import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAction {
  final String id;
  final String performedBy;
  final String actionType;
  final String? sessionId;
  final Map<String, dynamic> details;
  final DateTime timestamp;
  final bool requiresConfirmation;
  final String? confirmedBy;

  AdminAction({
    required this.id,
    required this.performedBy,
    required this.actionType,
    this.sessionId,
    required this.details,
    required this.timestamp,
    this.requiresConfirmation = false,
    this.confirmedBy,
  });

  factory AdminAction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminAction(
      id: doc.id,
      performedBy: data['performedBy'] ?? '',
      actionType: data['actionType'] ?? '',
      sessionId: data['sessionId'],
      details: Map<String, dynamic>.from(data['details'] ?? {}),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      requiresConfirmation: data['requiresConfirmation'] ?? false,
      confirmedBy: data['confirmedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'performedBy': performedBy,
      'actionType': actionType,
      if (sessionId != null) 'sessionId': sessionId,
      'details': details,
      'timestamp': Timestamp.fromDate(timestamp),
      'requiresConfirmation': requiresConfirmation,
      if (confirmedBy != null) 'confirmedBy': confirmedBy,
    };
  }

  AdminAction copyWith({
    String? id,
    String? performedBy,
    String? actionType,
    String? sessionId,
    Map<String, dynamic>? details,
    DateTime? timestamp,
    bool? requiresConfirmation,
    String? confirmedBy,
  }) {
    return AdminAction(
      id: id ?? this.id,
      performedBy: performedBy ?? this.performedBy,
      actionType: actionType ?? this.actionType,
      sessionId: sessionId ?? this.sessionId,
      details: details ?? this.details,
      timestamp: timestamp ?? this.timestamp,
      requiresConfirmation: requiresConfirmation ?? this.requiresConfirmation,
      confirmedBy: confirmedBy ?? this.confirmedBy,
    );
  }

  String get actionDescription {
    switch (actionType) {
      case 'createGame':
        return 'Created a new game session';
      case 'deleteGame':
        return 'Deleted game session';
      case 'resetDatabase':
        return 'Reset database for new game';
      case 'modifyDeadline':
        return 'Modified submission deadline';
      case 'startBattle':
        return 'Manually started battle';
      case 'endGame':
        return 'Ended game session';
      case 'sendReminder':
        return 'Sent reminder notification';
      default:
        return 'Performed action: $actionType';
    }
  }
}

/// Model for app notifications
class AppNotification {
  final String id;
  final String type;
  final String recipientId;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime sentAt;
  final bool read;

  AppNotification({
    required this.id,
    required this.type,
    required this.recipientId,
    required this.title,
    required this.body,
    this.data = const {},
    required this.sentAt,
    this.read = false,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      type: data['type'] ?? '',
      recipientId: data['recipientId'] ?? '',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: data['read'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'recipientId': recipientId,
      'title': title,
      'body': body,
      'data': data,
      'sentAt': Timestamp.fromDate(sentAt),
      'read': read,
    };
  }

  AppNotification copyWith({
    String? id,
    String? type,
    String? recipientId,
    String? title,
    String? body,
    Map<String, dynamic>? data,
    DateTime? sentAt,
    bool? read,
  }) {
    return AppNotification(
      id: id ?? this.id,
      type: type ?? this.type,
      recipientId: recipientId ?? this.recipientId,
      title: title ?? this.title,
      body: body ?? this.body,
      data: data ?? this.data,
      sentAt: sentAt ?? this.sentAt,
      read: read ?? this.read,
    );
  }
}
