class CommunityTip {
  final String id;
  final String author;
  final String title;
  final String body;
  final String? imagePath;
  final String? imageUrl;

  CommunityTip({
    required this.id,
    required this.author,
    required this.title,
    required this.body,
    required this.imagePath,
    this.imageUrl,
  });

  factory CommunityTip.create({
    required String author,
    required String title,
    required String body,
    String? imagePath,
    String? imageUrl,
  }) {
    return CommunityTip(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      author: author,
      title: title,
      body: body,
      imagePath: imagePath,
      imageUrl: imageUrl,
    );
  }

  CommunityTip copyWith({
    String? id,
    String? author,
    String? title,
    String? body,
    String? imagePath,
    String? imageUrl,
  }) {
    return CommunityTip(
      id: id ?? this.id,
      author: author ?? this.author,
      title: title ?? this.title,
      body: body ?? this.body,
      imagePath: imagePath ?? this.imagePath,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author': author,
      'title': title,
      'body': body,
      'imagePath': imagePath,
      'imageUrl': imageUrl,
    };
  }

  factory CommunityTip.fromJson(Map<String, dynamic> json) {
    return CommunityTip(
      id: json['id'] as String,
      author: json['author'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      imagePath: json['imagePath'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}
