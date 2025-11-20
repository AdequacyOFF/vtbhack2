import 'package:flutter/foundation.dart';
import '../models/news.dart';
import '../models/transaction.dart';
import '../services/news_service.dart';
import '../services/analytics_service.dart';

class NewsProvider extends ChangeNotifier {
  final NewsService _newsService = NewsService();

  List<News> _newsArticles = [];
  bool _isLoading = false;
  String? _error;

  List<News> get newsArticles => _newsArticles;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasNews => _newsArticles.isNotEmpty;

  /// Fetches personalized news based on user's transaction categories
  ///
  /// [transactions] - List of user transactions to analyze
  /// [n] - Number of news articles to fetch (default: 10)
  /// [maxCategories] - Maximum number of categories to use for news topics (default: 5)
  Future<void> fetchPersonalizedNews({
    required List<BankTransaction> transactions,
    int n = 10,
    int maxCategories = 5,
  }) async {
    if (transactions.isEmpty) {
      _error = 'No transactions available for analysis';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Analyze transaction categories
      final categoryStats = AnalyticsService.getTransactionFrequencyAnalysis(
        transactions,
      );

      if (categoryStats.isEmpty) {
        _error = 'No transaction categories found';
        _isLoading = false;
        notifyListeners();
        return;
      }

      print('[NewsProvider] Fetching news for ${categoryStats.length} categories');

      // Fetch news based on top categories
      _newsArticles = await _newsService.fetchNewsFromCategories(
        categoryStats: categoryStats,
        n: n,
        maxCategories: maxCategories,
      );

      print('[NewsProvider] Successfully loaded ${_newsArticles.length} news articles');

      _isLoading = false;
      _error = null;
    } catch (e) {
      print('[NewsProvider] Error fetching news: $e');
      _error = e.toString();
      _newsArticles = [];
      _isLoading = false;
    }

    notifyListeners();
  }

  /// Fetches news with custom categories
  ///
  /// [categories] - List of custom categories
  /// [n] - Number of news articles to fetch
  Future<void> fetchNewsByCategories({
    required List<String> categories,
    int n = 10,
  }) async {
    if (categories.isEmpty) {
      _error = 'Categories list cannot be empty';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _newsArticles = await _newsService.fetchNews(
        categories: categories,
        n: n,
      );

      _isLoading = false;
      _error = null;
    } catch (e) {
      print('[NewsProvider] Error fetching news: $e');
      _error = e.toString();
      _newsArticles = [];
      _isLoading = false;
    }

    notifyListeners();
  }

  /// Dislike a news article (hides it and adds to disliked list)
  Future<void> dislikeNews(News news) async {
    try {
      // Save to disliked titles
      await _newsService.dislikeNews(news.title);

      // Remove from current list
      _newsArticles.removeWhere((article) => article.title == news.title);

      print('[NewsProvider] News disliked: ${news.title}');
      notifyListeners();
    } catch (e) {
      print('[NewsProvider] Error disliking news: $e');
    }
  }

  /// Like a news article (saves to liked list)
  Future<void> likeNews(News news) async {
    try {
      await _newsService.likeNews(news.title);
      print('[NewsProvider] News liked: ${news.title}');
      notifyListeners();
    } catch (e) {
      print('[NewsProvider] Error liking news: $e');
    }
  }

  /// Check if a news article is liked
  Future<bool> isNewsLiked(String title) async {
    try {
      final likedTitles = await _newsService.getLikedTitles();
      return likedTitles.contains(title);
    } catch (e) {
      print('[NewsProvider] Error checking if news is liked: $e');
      return false;
    }
  }

  /// Remove like from a news article
  Future<void> removeLike(News news) async {
    try {
      await _newsService.removeLike(news.title);
      print('[NewsProvider] Like removed: ${news.title}');
      notifyListeners();
    } catch (e) {
      print('[NewsProvider] Error removing like: $e');
    }
  }

  /// Refreshes the current news
  Future<void> refresh({
    required List<BankTransaction> transactions,
    int n = 10,
    int maxCategories = 5,
  }) async {
    await fetchPersonalizedNews(
      transactions: transactions,
      n: n,
      maxCategories: maxCategories,
    );
  }

  /// Clears all news articles and errors
  void clear() {
    _newsArticles = [];
    _error = null;
    _isLoading = false;
    notifyListeners();
  }
}
