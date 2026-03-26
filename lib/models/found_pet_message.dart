class FoundPetMessage {
  final String id;
  final String reportId;
  final String senderName;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  const FoundPetMessage({
    required this.id,
    required this.reportId,
    required this.senderName,
    required this.message,
    required this.createdAt,
    required this.isRead,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reportId': reportId,
      'senderName': senderName,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory FoundPetMessage.fromMap(Map<String, dynamic> map) {
    return FoundPetMessage(
      id: map['id'] as String,
      reportId: map['reportId'] as String,
      senderName: map['senderName'] as String? ?? '',
      message: map['message'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      isRead: map['isRead'] as bool? ?? false,
    );
  }

  FoundPetMessage copyWith({
    String? id,
    String? reportId,
    String? senderName,
    String? message,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return FoundPetMessage(
      id: id ?? this.id,
      reportId: reportId ?? this.reportId,
      senderName: senderName ?? this.senderName,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
