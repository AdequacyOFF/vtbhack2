import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/news.dart';

class NewsService {
  static const String _baseUrl = 'http://5.129.212.83:51000';
  static const Duration _timeout = Duration(seconds: 30);
  static const String _dislikedTitlesKey = 'disliked_news_titles';
  static const String _likedTitlesKey = 'liked_news_titles';

  /// Get disliked news titles from storage
  Future<List<String>> getDislikedTitles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dislikedTitles = prefs.getStringList(_dislikedTitlesKey) ?? [];
      return dislikedTitles;
    } catch (e) {
      print('[NewsService] Error getting disliked titles: $e');
      return [];
    }
  }

  /// Save disliked news title
  Future<void> dislikeNews(String title) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dislikedTitles = await getDislikedTitles();

      if (!dislikedTitles.contains(title)) {
        dislikedTitles.add(title);
        await prefs.setStringList(_dislikedTitlesKey, dislikedTitles);
        print('[NewsService] Disliked title saved: $title');
      }
    } catch (e) {
      print('[NewsService] Error saving disliked title: $e');
    }
  }

  /// Get liked news titles from storage
  Future<List<String>> getLikedTitles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final likedTitles = prefs.getStringList(_likedTitlesKey) ?? [];
      return likedTitles;
    } catch (e) {
      print('[NewsService] Error getting liked titles: $e');
      return [];
    }
  }

  /// Save liked news title
  Future<void> likeNews(String title) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final likedTitles = await getLikedTitles();

      if (!likedTitles.contains(title)) {
        likedTitles.add(title);
        await prefs.setStringList(_likedTitlesKey, likedTitles);
        print('[NewsService] Liked title saved: $title');
      }
    } catch (e) {
      print('[NewsService] Error saving liked title: $e');
    }
  }

  /// Remove from liked titles
  Future<void> removeLike(String title) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final likedTitles = await getLikedTitles();

      if (likedTitles.contains(title)) {
        likedTitles.remove(title);
        await prefs.setStringList(_likedTitlesKey, likedTitles);
        print('[NewsService] Like removed: $title');
      }
    } catch (e) {
      print('[NewsService] Error removing like: $e');
    }
  }

  /// Fetches personalized news articles based on transaction categories
  ///
  /// [categories] - List of transaction categories (e.g., ["рестораны", "транспорт"])
  /// [n] - Number of news articles to retrieve
  ///
  /// Returns a list of News objects
  /// Throws an exception if the request fails
  Future<List<News>> fetchNews({
    required List<String> categories,
    required int n,
  }) async {
    if (categories.isEmpty) {
      throw ArgumentError('Categories list cannot be empty');
    }

    if (n <= 0) {
      throw ArgumentError('n must be greater than 0');
    }

    try {
      final uri = Uri.parse('$_baseUrl/news');

      // Get disliked titles to exclude from results
      final dislikedTitles = await getDislikedTitles();

      final requestBody = {
        'n': n,
        'top_spend_categories': categories,
        'disliked_titles': dislikedTitles,
      };

      print('[NewsService] Fetching news with categories: $categories, n: $n, disliked: ${dislikedTitles.length}');

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'accept': 'application/json',
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
  /// [n] - Number of news articles to retrieve
  /// [maxCategories] - Maximum number of categories to send (default: 5)
  Future<List<News>> fetchNewsFromCategories({
    required List<Map<String, dynamic>> categoryStats,
    required int n,
    int maxCategories = 5,
  }) async {
    if (categoryStats.isEmpty) {
      throw ArgumentError('Category statistics cannot be empty');
    }

    // Extract top categories by frequency
    final categories = categoryStats
        .take(maxCategories)
        .map((stat) => stat['category'] as String)
        .toList();

    return fetchNews(categories: categories, n: n);
  }
}
