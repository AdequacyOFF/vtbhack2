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
  /// [topN] - Number of news articles to fetch (default: 10)
  /// [maxCategories] - Maximum number of categories to use for news topics (default: 5)
  Future<void> fetchPersonalizedNews({
    required List<BankTransaction> transactions,
    int topN = 10,
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
        topN: topN,
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

  /// Fetches news with custom topics
  ///
  /// [topics] - List of custom topics
  /// [topN] - Number of news articles to fetch
  Future<void> fetchNewsByTopics({
    required List<String> topics,
    int topN = 10,
  }) async {
    if (topics.isEmpty) {
      _error = 'Topics list cannot be empty';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _newsArticles = await _newsService.fetchNews(
        topics: topics,
        topN: topN,
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

  /// Refreshes the current news
  Future<void> refresh({
    required List<BankTransaction> transactions,
    int topN = 10,
    int maxCategories = 5,
  }) async {
    await fetchPersonalizedNews(
      transactions: transactions,
      topN: topN,
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
