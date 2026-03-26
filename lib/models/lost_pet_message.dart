class LostPetMessage {
  final String id;
  final String reportId;
  final String senderName;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  LostPetMessage({
    required this.id,
    required this.reportId,
    required this.senderName,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reportId': reportId,
      'senderName': senderName,
      'message': message,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
    };
  }

  factory LostPetMessage.fromJson(Map<String, dynamic> json) {
    return LostPetMessage(
      id: json['id'],
      reportId: json['reportId'],
      senderName: json['senderName'] ?? '',
      message: json['message'],
      createdAt: DateTime.parse(json['createdAt']),
      isRead: json['isRead'] ?? false,
    );
  }

  LostPetMessage copyWith({
    String? id,
    String? reportId,
    String? senderName,
    String? message,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return LostPetMessage(
      id: id ?? this.id,
      reportId: reportId ?? this.reportId,
      senderName: senderName ?? this.senderName,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
