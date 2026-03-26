class CommunityTip {
  final String id;
  final String author;
  final String title;
  final String body;
  final String? imagePath;

  CommunityTip({
    required this.id,
    required this.author,
    required this.title,
    required this.body,
    required this.imagePath,
  });

  factory CommunityTip.create({
    required String author,
    required String title,
    required String body,
    String? imagePath,
  }) {
    return CommunityTip(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      author: author,
      title: title,
      body: body,
      imagePath: imagePath,
    );
  }

  CommunityTip copyWith({
    String? id,
    String? author,
    String? title,
    String? body,
    String? imagePath,
  }) {
    return CommunityTip(
      id: id ?? this.id,
      author: author ?? this.author,
      title: title ?? this.title,
      body: body ?? this.body,
      imagePath: imagePath ?? this.imagePath,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author': author,
      'title': title,
      'body': body,
      'imagePath': imagePath,
    };
  }

  factory CommunityTip.fromJson(Map<String, dynamic> json) {
    return CommunityTip(
      id: json['id'] as String,
      author: json['author'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      imagePath: json['imagePath'] as String?,
    );
  }
}
