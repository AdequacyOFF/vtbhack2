import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../config/app_theme.dart';

/// Modern iOS 26 style PDF viewer screen for viewing statements in-app
class PdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String title;

  const PdfViewerScreen({
    super.key,
    required this.filePath,
    this.title = 'Выписка',
  });

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfViewerController _pdfViewerController = PdfViewerController();
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            if (_totalPages > 0)
              Text(
                'Страница $_currentPage из $_totalPages',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                ),
              ),
          ],
        ),
        actions: [
          // Share button
          IconButton(
            icon: const Icon(Icons.share_rounded),
            onPressed: _shareDocument,
            tooltip: 'Поделиться',
          ),
          // Save button (opens in external viewer)
          IconButton(
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: _openExternal,
            tooltip: 'Открыть во внешнем приложении',
          ),
        ],
      ),
      body: Column(
        children: [
          // PDF Viewer
          Expanded(
            child: Container(
              color: AppTheme.backgroundLight,
              child: SfPdfViewer.file(
                File(widget.filePath),
                controller: _pdfViewerController,
                pageLayoutMode: PdfPageLayoutMode.single,
                onPageChanged: (PdfPageChangedDetails details) {
                  setState(() {
                    _currentPage = details.newPageNumber;
                  });
                },
                onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                  setState(() {
                    _totalPages = details.document.pages.count;
                  });
                },
              ),
            ),
          ),

          // Modern iOS 26 style bottom control bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.darkBlue.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Previous page button
                  _buildControlButton(
                    icon: Icons.chevron_left_rounded,
                    onPressed: _currentPage > 1
                        ? () {
                            _pdfViewerController.previousPage();
                          }
                        : null,
                    label: 'Назад',
                  ),

                  // Page indicator
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.iceBlue,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_currentPage / $_totalPages',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkBlue,
                      ),
                    ),
                  ),

                  // Next page button
                  _buildControlButton(
                    icon: Icons.chevron_right_rounded,
                    onPressed: _currentPage < _totalPages
                        ? () {
                            _pdfViewerController.nextPage();
                          }
                        : null,
                    label: 'Вперёд',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String label,
  }) {
    final isEnabled = onPressed != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isEnabled
                ? AppTheme.primaryBlue.withValues(alpha: 0.1)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isEnabled ? AppTheme.primaryBlue : Colors.grey,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isEnabled ? AppTheme.primaryBlue : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _shareDocument() async {
    try {
      await Share.shareXFiles(
        [XFile(widget.filePath)],
        subject: widget.title,
        text: 'Выписка из Multi-Bank App',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при отправке: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Future<void> _openExternal() async {
    // This will use the printing package to open in external viewer
    try {
      // You can use url_launcher or the printing package's share functionality
      await Share.shareXFiles(
        [XFile(widget.filePath)],
        subject: widget.title,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при открытии: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }
}
