class AdoptionPet {
  final String id;
  final String name;
  final String type;
  final String age;
  final String location;
  final String description;
  final String contactPhone;
  final String? photoPath;
  final String? photoUrl;
  final bool adopted;
  final String? userId;

  AdoptionPet({
    required this.id,
    required this.name,
    required this.type,
    required this.age,
    required this.location,
    required this.description,
    required this.contactPhone,
    this.photoPath,
    this.photoUrl,
    this.adopted = false,
    this.userId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'age': age,
      'location': location,
      'description': description,
      'contactPhone': contactPhone,
      'photoPath': photoPath,
      'photoUrl': photoUrl,
      'adopted': adopted,
      'userId': userId,
    };
  }

  factory AdoptionPet.fromJson(Map<String, dynamic> json) {
    return AdoptionPet(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      age: json['age'],
      location: json['location'],
      description: json['description'],
      contactPhone: json['contactPhone'],
      photoPath: json['photoPath'],
      photoUrl: json['photoUrl'] as String?,
      adopted: json['adopted'] ?? false,
      userId: json['userId'] as String?,
    );
  }
}
