class News {
  final String agency;
  final String title;
  final String summary;
  final String imageBase64;
  final String url;
  final DateTime publishedAt;
  final DateTime crawledAt;

  News({
    required this.agency,
    required this.title,
    required this.summary,
    required this.imageBase64,
    required this.url,
    required this.publishedAt,
    required this.crawledAt,
  });

  factory News.fromJson(Map<String, dynamic> json) {
    return News(
      agency: json['agency'] as String? ?? '',
      title: json['title'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      imageBase64: json['image_base64'] as String? ?? '',
      url: json['url'] as String? ?? '',
      publishedAt: json['published_at'] != null
          ? DateTime.parse(json['published_at'] as String)
          : DateTime.now(),
      crawledAt: json['crawled_at'] != null
          ? DateTime.parse(json['crawled_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'agency': agency,
      'title': title,
      'summary': summary,
      'image_base64': imageBase64,
      'url': url,
      'published_at': publishedAt.toIso8601String(),
      'crawled_at': crawledAt.toIso8601String(),
    };
  }

  /// Get a short preview of the summary (first 150 characters)
  String get summaryPreview {
    if (summary.length <= 150) return summary;
    return '${summary.substring(0, 150)}...';
  }

  /// Check if news article has an image
  bool get hasImage => imageBase64.isNotEmpty;
}
