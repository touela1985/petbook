class FoundPetReport {
  final String id;
  final String type;
  final String locationFound;
  final DateTime foundDate;
  final String notes;
  final String contactPhone;
  final bool isResolved;
  final String? photoPath;
  final String? photoUrl;
  final double? latitude;
  final double? longitude;

  FoundPetReport({
    required this.id,
    required this.type,
    required this.locationFound,
    required this.foundDate,
    required this.notes,
    required this.contactPhone,
    required this.isResolved,
    this.photoPath,
    this.photoUrl,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'locationFound': locationFound,
      'foundDate': foundDate.toIso8601String(),
      'notes': notes,
      'contactPhone': contactPhone,
      'isResolved': isResolved,
      'photoPath': photoPath,
      'photoUrl': photoUrl,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory FoundPetReport.fromJson(Map<String, dynamic> json) {
    return FoundPetReport(
      id: json['id'],
      type: json['type'],
      locationFound: json['locationFound'],
      foundDate: DateTime.parse(json['foundDate']),
      notes: json['notes'],
      contactPhone: json['contactPhone'],
      isResolved: json['isResolved'] ?? false,
      photoPath: json['photoPath'],
      photoUrl: json['photoUrl'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
    );
  }
}
