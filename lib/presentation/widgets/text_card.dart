import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 原文・翻訳結果を表示するカード型コンポーネント
class TextCard extends StatelessWidget {
  const TextCard({
    super.key,
    required this.title,
    required this.content,
    this.placeholder = '',
    this.isLoading = false,
  });

  final String title;
  final String content;
  final String placeholder;
  final bool isLoading;

  void _copyToClipboard(BuildContext context) {
    if (content.isEmpty) return;
    Clipboard.setData(ClipboardData(text: content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$titleをクリップボードにコピーしました'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasContent = content.trim().isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ヘッダー部（タイトル & コピーボタン）
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy, size: 16),
                  tooltip: '$titleをコピー',
                  visualDensity: VisualDensity.compact,
                  onPressed: hasContent ? () => _copyToClipboard(context) : null,
                ),
              ],
            ),
            const SizedBox(height: 6),
            // コンテンツ部
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 80, maxHeight: 160),
                child: SingleChildScrollView(
                  child: SelectableText(
                    hasContent ? content : placeholder,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: hasContent
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
