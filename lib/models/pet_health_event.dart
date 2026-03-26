class PetHealthEvent {
  final String id;
  final String petId;
  final String type;
  final String title;
  final String notes;
  final DateTime date;
  final String? value;
  final DateTime? reminderDate;

  PetHealthEvent({
    required this.id,
    required this.petId,
    required this.type,
    required this.title,
    required this.notes,
    required this.date,
    this.value,
    this.reminderDate,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'type': type,
      'title': title,
      'notes': notes,
      'date': date.toIso8601String(),
      'value': value,
      'reminderDate': reminderDate?.toIso8601String(),
    };
  }

  factory PetHealthEvent.fromJson(Map<String, dynamic> json) {
    return PetHealthEvent(
      id: json['id'],
      petId: json['petId'],
      type: json['type'],
      title: json['title'],
      notes: json['notes'],
      date: DateTime.parse(json['date']),
      value: json['value'],
      reminderDate: json['reminderDate'] != null
          ? DateTime.parse(json['reminderDate'])
          : null,
    );
  }
}
