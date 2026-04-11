class FoundPetMessage {
  final String id;
  final String reportId;
  final String text;
  final String senderName;
  final DateTime timestamp;
  final String? senderUserId;
  final String? receiverUserId;
  final String? reportOwnerUserId;
  final bool isRead;

  const FoundPetMessage({
    required this.id,
    required this.reportId,
    required this.text,
    required this.senderName,
    required this.timestamp,
    this.senderUserId,
    this.receiverUserId,
    this.reportOwnerUserId,
    this.isRead = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reportId': reportId,
      'text': text,
      'senderName': senderName,
      'timestamp': timestamp.toIso8601String(),
      'senderUserId': senderUserId,
      'receiverUserId': receiverUserId,
      'reportOwnerUserId': reportOwnerUserId,
      'isRead': isRead,
    };
  }

  factory FoundPetMessage.fromMap(Map<String, dynamic> map) {
    return FoundPetMessage(
      id: map['id'] as String,
      reportId: map['reportId'] as String,
      text: (map['text'] ?? map['message']) as String? ?? '',
      senderName: map['senderName'] as String? ?? '',
      timestamp: DateTime.parse(
        (map['timestamp'] ?? map['createdAt']) as String,
      ),
      senderUserId: map['senderUserId'] as String?,
      receiverUserId: map['receiverUserId'] as String?,
      reportOwnerUserId: map['reportOwnerUserId'] as String?,
      isRead: map['isRead'] as bool? ?? false,
    );
  }

  FoundPetMessage copyWith({
    String? id,
    String? reportId,
    String? text,
    String? senderName,
    DateTime? timestamp,
    String? senderUserId,
    String? receiverUserId,
    String? reportOwnerUserId,
    bool? isRead,
  }) {
    return FoundPetMessage(
      id: id ?? this.id,
      reportId: reportId ?? this.reportId,
      text: text ?? this.text,
      senderName: senderName ?? this.senderName,
      timestamp: timestamp ?? this.timestamp,
      senderUserId: senderUserId ?? this.senderUserId,
      receiverUserId: receiverUserId ?? this.receiverUserId,
      reportOwnerUserId: reportOwnerUserId ?? this.reportOwnerUserId,
      isRead: isRead ?? this.isRead,
    );
  }
}
