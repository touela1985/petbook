class CommunityPlace {
  final String id;
  final String title;
  final String description;
  final String? imagePath;
  final String? imageUrl;
  final String? userId;

  CommunityPlace({
    required this.id,
    required this.title,
    required this.description,
    required this.imagePath,
    this.imageUrl,
    this.userId,
  });

  factory CommunityPlace.create({
    required String title,
    required String description,
    String? imagePath,
    String? imageUrl,
    String? userId,
  }) {
    return CommunityPlace(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      imagePath: imagePath,
      imageUrl: imageUrl,
      userId: userId,
    );
  }

  CommunityPlace copyWith({
    String? id,
    String? title,
    String? description,
    String? imagePath,
    String? imageUrl,
    String? userId,
  }) {
    return CommunityPlace(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
      userId: userId ?? this.userId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'imagePath': imagePath,
      'imageUrl': imageUrl,
      'userId': userId,
    };
  }

  factory CommunityPlace.fromJson(Map<String, dynamic> json) {
    return CommunityPlace(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      imagePath: json['imagePath'] as String?,
      imageUrl: json['imageUrl'] as String?,
      userId: json['userId'] as String?,
    );
  }
}
