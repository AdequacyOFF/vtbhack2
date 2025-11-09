import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/news.dart';

class NewsService {
  static const String _baseUrl = 'http://81.200.148.163:51000';
  static const Duration _timeout = Duration(seconds: 30);

  /// Fetches personalized news articles based on transaction categories
  ///
  /// [topics] - List of transaction categories (e.g., ["investments", "transport", "food"])
  /// [topN] - Number of news articles to retrieve
  ///
  /// Returns a list of News objects
  /// Throws an exception if the request fails
  Future<List<News>> fetchNews({
    required List<String> topics,
    required int topN,
  }) async {
    if (topics.isEmpty) {
      throw ArgumentError('Topics list cannot be empty');
    }

    if (topN <= 0) {
      throw ArgumentError('topN must be greater than 0');
    }

    try {
      final uri = Uri.parse('$_baseUrl/news');

      final requestBody = {
        'topics': topics,
        'top_n': topN,
      };

      print('[NewsService] Fetching news with topics: $topics, top_n: $topN');

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(_timeout);

      print('[NewsService] Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> jsonData = jsonDecode(response.body);

        final newsList = jsonData.map((json) {
          try {
            return News.fromJson(json as Map<String, dynamic>);
          } catch (e) {
            print('[NewsService] Error parsing news item: $e');
            return null;
          }
        }).whereType<News>().toList();

        print('[NewsService] Successfully fetched ${newsList.length} news articles');
        return newsList;
      } else {
        final errorMessage = 'Failed to fetch news: ${response.statusCode} ${response.reasonPhrase}';
        print('[NewsService] $errorMessage');
        throw Exception(errorMessage);
      }
    } on http.ClientException catch (e) {
      print('[NewsService] Network error: $e');
      throw Exception('Network error: Unable to connect to news service');
    } catch (e) {
      print('[NewsService] Unexpected error: $e');
      rethrow;
    }
  }

  /// Fetches news based on transaction analysis
  ///
  /// [categoryStats] - List of category statistics from AnalyticsService
  /// [topN] - Number of news articles to retrieve
  /// [maxCategories] - Maximum number of categories to send (default: 5)
  Future<List<News>> fetchNewsFromCategories({
    required List<Map<String, dynamic>> categoryStats,
    required int topN,
    int maxCategories = 5,
  }) async {
    if (categoryStats.isEmpty) {
      throw ArgumentError('Category statistics cannot be empty');
    }

    // Extract top categories by frequency
    final topics = categoryStats
        .take(maxCategories)
        .map((stat) => stat['category'] as String)
        .toList();

    return fetchNews(topics: topics, topN: topN);
  }
}
