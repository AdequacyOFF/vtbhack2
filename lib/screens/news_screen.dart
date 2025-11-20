import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/news_provider.dart';
import '../providers/account_provider.dart';
import '../models/news.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({Key? key}) : super(key: key);

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  @override
  void initState() {
    super.initState();
    // Load news on screen init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadNews();
    });
  }

  Future<void> _loadNews() async {
    final newsProvider = context.read<NewsProvider>();
    final accountProvider = context.read<AccountProvider>();

    // Get all transactions from all accounts
    final allTransactions = accountProvider.allTransactions;

    if (allTransactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No transactions found. Please sync your accounts first.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await newsProvider.fetchPersonalizedNews(
      transactions: allTransactions,
      n: 10,
      maxCategories: 5,
    );
  }

  Future<void> _openUrl(String url) async {
    try {
      // Clean and validate URL
      String cleanUrl = url.trim();

      // Ensure URL has a scheme
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        cleanUrl = 'https://$cleanUrl';
      }

      final uri = Uri.parse(cleanUrl);

      // Try to launch the URL
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось открыть ссылку: $cleanUrl')),
        );
      }
    } catch (e) {
      print('[NewsScreen] Error opening URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка при открытии ссылки: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalized News'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadNews,
          ),
        ],
      ),
      body: Consumer<NewsProvider>(
        builder: (context, newsProvider, child) {
          if (newsProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (newsProvider.error != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading news',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      newsProvider.error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadNews,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (!newsProvider.hasNews) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.article_outlined,
                      size: 64,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No news available',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'We couldn\'t find any news based on your transactions.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _loadNews,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadNews,
            child: ListView.builder(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 110, // Space for floating bottom bar
              ),
              itemCount: newsProvider.newsArticles.length,
              itemBuilder: (context, index) {
                final news = newsProvider.newsArticles[index];
                return _NewsCard(
                  news: news,
                  onTap: () => _openUrl(news.url),
                  onLike: () async {
                    await newsProvider.likeNews(news);
                  },
                  onDislike: () async {
                    await newsProvider.dislikeNews(news);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Скрыто: ${news.title}'),
                        duration: const Duration(seconds: 2),
                        action: SnackBarAction(
                          label: 'Обновить',
                          onPressed: _loadNews,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NewsCard extends StatefulWidget {
  final News news;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onDislike;

  const _NewsCard({
    required this.news,
    required this.onTap,
    required this.onLike,
    required this.onDislike,
  });

  @override
  State<_NewsCard> createState() => _NewsCardState();
}

class _NewsCardState extends State<_NewsCard> {
  bool _isLiked = false;
  bool _isCheckingLike = true;

  @override
  void initState() {
    super.initState();
    _checkIfLiked();
  }

  Future<void> _checkIfLiked() async {
    final newsProvider = context.read<NewsProvider>();
    final isLiked = await newsProvider.isNewsLiked(widget.news.title);
    if (mounted) {
      setState(() {
        _isLiked = isLiked;
        _isCheckingLike = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    setState(() {
      _isLiked = !_isLiked;
    });

    if (_isLiked) {
      widget.onLike();
    } else {
      final newsProvider = context.read<NewsProvider>();
      await newsProvider.removeLike(widget.news);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (widget.news.hasImage)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                child: _Base64Image(
                  base64String: widget.news.imageBase64,
                  height: 200,
                ),
              ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Agency
                  Text(
                    widget.news.agency.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).primaryColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Title
                  Text(
                    widget.news.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Summary
                  Text(
                    widget.news.summary,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),

                  // Like/Dislike and Read more buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Like and Dislike buttons
                      Row(
                        children: [
                          // Like button
                          IconButton(
                            onPressed: _isCheckingLike ? null : _toggleLike,
                            icon: Icon(
                              _isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                              color: _isLiked ? Colors.blue : Colors.grey,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: _isLiked ? 'Убрать из избранного' : 'Добавить в избранное',
                          ),
                          const SizedBox(width: 16),
                          // Dislike button
                          IconButton(
                            onPressed: () async {
                              // Show confirmation dialog
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Скрыть новость?'),
                                  content: Text('Эта новость будет скрыта и не будет показываться снова.\n\n"${widget.news.title}"'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Отмена'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Скрыть'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                widget.onDislike();
                              }
                            },
                            icon: const Icon(
                              Icons.thumb_down_outlined,
                              color: Colors.grey,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Не показывать такие новости',
                          ),
                        ],
                      ),
                      // Read more button
                      TextButton.icon(
                        onPressed: widget.onTap,
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Читать'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Base64Image extends StatelessWidget {
  final String base64String;
  final double height;

  const _Base64Image({
    required this.base64String,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    try {
      // Remove data URI prefix if present
      String cleanBase64 = base64String;
      if (base64String.contains(',')) {
        cleanBase64 = base64String.split(',').last;
      }

      final bytes = base64Decode(cleanBase64);
      return Image.memory(
        bytes,
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _PlaceholderImage(height: height);
        },
      );
    } catch (e) {
      print('[NewsCard] Error decoding base64 image: $e');
      return _PlaceholderImage(height: height);
    }
  }
}

class _PlaceholderImage extends StatelessWidget {
  final double height;

  const _PlaceholderImage({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      color: Colors.grey[300],
      child: const Icon(
        Icons.image_not_supported,
        size: 64,
        color: Colors.grey,
      ),
    );
  }
}
