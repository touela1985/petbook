class LostPetSighting {
  final String id;
  final String location;
  final String notes;
  final DateTime createdAt;

  final double? latitude;
  final double? longitude;

  LostPetSighting({
    required this.id,
    required this.location,
    required this.notes,
    this.latitude,
    this.longitude,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'location': location,
      'notes': notes,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LostPetSighting.fromJson(Map<String, dynamic> json) {
    return LostPetSighting(
      id: json['id'],
      location: json['location'] ?? '',
      notes: json['notes'] ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
    );
  }
}

class LostPetReport {
  final String id;
  final String petName;
  final String type;
  final String lastSeenLocation;
  final DateTime lastSeenDate;
  final String notes;
  final String contactPhone;
  final bool isResolved;
  final String? photoPath;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;
  final List<LostPetSighting> sightings;

  LostPetReport({
    required this.id,
    required this.petName,
    required this.type,
    required this.lastSeenLocation,
    required this.lastSeenDate,
    required this.notes,
    required this.contactPhone,
    required this.isResolved,
    this.photoPath,
    this.latitude,
    this.longitude,
    DateTime? createdAt,
    List<LostPetSighting>? sightings,
  })  : createdAt = createdAt ?? DateTime.now(),
        sightings = sightings ?? [];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petName': petName,
      'type': type,
      'lastSeenLocation': lastSeenLocation,
      'lastSeenDate': lastSeenDate.toIso8601String(),
      'notes': notes,
      'contactPhone': contactPhone,
      'isResolved': isResolved,
      'photoPath': photoPath,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': createdAt.toIso8601String(),
      'sightings': sightings.map((s) => s.toJson()).toList(),
    };
  }

  factory LostPetReport.fromJson(Map<String, dynamic> json) {
    return LostPetReport(
      id: json['id'],
      petName: json['petName'],
      type: json['type'],
      lastSeenLocation: json['lastSeenLocation'],
      lastSeenDate: DateTime.parse(json['lastSeenDate']),
      notes: json['notes'],
      contactPhone: json['contactPhone'],
      isResolved: json['isResolved'] ?? false,
      photoPath: json['photoPath'],
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      sightings: (json['sightings'] as List<dynamic>?)
              ?.map((item) => LostPetSighting.fromJson(item))
              .toList() ??
          [],
    );
  }
}
