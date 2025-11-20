class News {
  final String agency;  // Mapped from 'source'
  final String title;
  final String summary;  // Mapped from 'content'
  final String imageBase64;
  final String url;  // Mapped from 'original_url'
  final DateTime publishedAt;

  News({
    required this.agency,
    required this.title,
    required this.summary,
    required this.imageBase64,
    required this.url,
    required this.publishedAt,
  });

  factory News.fromJson(Map<String, dynamic> json) {
    return News(
      // Map 'source' to 'agency' for backwards compatibility
      agency: json['source'] as String? ?? json['agency'] as String? ?? '',
      title: json['title'] as String? ?? '',
      // Map 'content' to 'summary' for backwards compatibility
      summary: json['content'] as String? ?? json['summary'] as String? ?? '',
      imageBase64: json['image_base64'] as String? ?? '',
      // Map 'original_url' to 'url' for backwards compatibility
      url: json['original_url'] as String? ?? json['url'] as String? ?? '',
      // Use current time if no published date available
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'source': agency,
      'title': title,
      'content': summary,
      'image_base64': imageBase64,
      'original_url': url,
      'published_at': publishedAt.toIso8601String(),
    };
  }

  /// Get a short preview of the summary (first 150 characters)
  String get summaryPreview {
    if (summary.length <= 150) return summary;
    return '${summary.substring(0, 150)}...';
  }

  /// Check if news article has an image
  bool get hasImage => imageBase64.isNotEmpty && imageBase64 != 'null';
}
