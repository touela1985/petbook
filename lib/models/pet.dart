class Pet {
  String id;
  String name;
  String type;
  String? age;
  String? gender;
  String? photoPath;
  String? photoBase64;

  Pet({
    required this.id,
    required this.name,
    required this.type,
    this.age,
    this.gender,
    this.photoPath,
    this.photoBase64,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'age': age,
      'gender': gender,
      'photoPath': photoPath,
      'photoBase64': photoBase64,
    };
  }

  factory Pet.fromJson(Map<String, dynamic> json) {
    final dynamic rawAge = json['age'];

    return Pet(
      id: json['id'],
      name: json['name'],
      type: json['type'],
      age: rawAge == null ? null : rawAge.toString(),
      gender: json['gender'],
      photoPath: json['photoPath'],
      photoBase64: json['photoBase64'],
    );
  }
}
