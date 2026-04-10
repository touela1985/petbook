class LostPetMessage {
  final String id;
  final String reportId;
  final String senderName;
  final String? senderUserId;
  final String? receiverUserId;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  LostPetMessage({
    required this.id,
    required this.reportId,
    required this.senderName,
    this.senderUserId,
    this.receiverUserId,
    required this.message,
    required this.createdAt,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reportId': reportId,
      'senderName': senderName,
      'senderUserId': senderUserId,
      'receiverUserId': receiverUserId,
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
      senderUserId: json['senderUserId'] as String?,
      receiverUserId: json['receiverUserId'] as String?,
      message: json['message'],
      createdAt: DateTime.parse(json['createdAt']),
      isRead: json['isRead'] ?? false,
    );
  }

  LostPetMessage copyWith({
    String? id,
    String? reportId,
    String? senderName,
    String? senderUserId,
    String? receiverUserId,
    String? message,
    DateTime? createdAt,
    bool? isRead,
  }) {
    return LostPetMessage(
      id: id ?? this.id,
      reportId: reportId ?? this.reportId,
      senderName: senderName ?? this.senderName,
      senderUserId: senderUserId ?? this.senderUserId,
      receiverUserId: receiverUserId ?? this.receiverUserId,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
    );
  }
}
