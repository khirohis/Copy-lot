import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/settings_provider.dart';
import '../widgets/text_card.dart';
import '../widgets/translation_direction_switch.dart';
import 'settings_screen.dart';

/// メイン翻訳画面
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  bool _hasCheckedInitialApiKey = false;

  // モック用のテキスト状態（今後のネイティブクリップボード連携で動的更新に置き換え）
  final String _sourceText = '';
  final String _translatedText = '';
  final bool _isTranslating = false;

  void _checkApiKey(bool hasApiKey, bool isLoading) {
    if (isLoading || _hasCheckedInitialApiKey) return;
    _hasCheckedInitialApiKey = true;

    if (!hasApiKey) {
      // フレーム描画後に設定画面を自動プッシュ
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const SettingsScreen(isInitialSetup: true),
          ),
        );
      });
    }
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsNotifierProvider);
    final theme = Theme.of(context);

    // 初回APIキー未設定時のチェック
    _checkApiKey(settings.hasApiKey, settings.isLoading);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Copy-lot',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          // 最前面固定（Always on Top）トグルボタン
          IconButton(
            icon: Icon(
              settings.isAlwaysOnTop
                  ? Icons.push_pin
                  : Icons.push_pin_outlined,
              size: 20,
              color: settings.isAlwaysOnTop
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            tooltip: settings.isAlwaysOnTop ? '最前面固定を解除' : '常に最前面に固定',
            onPressed: () {
              ref.read(settingsNotifierProvider.notifier).toggleAlwaysOnTop();
            },
          ),
          // 設定画面遷移ボタン
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: '設定',
            onPressed: _openSettings,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 翻訳方向スイッチ
                    TranslationDirectionSwitch(
                      selected: settings.direction,
                      onChanged: (newDir) {
                        ref
                            .read(settingsNotifierProvider.notifier)
                            .setDirection(newDir);
                      },
                    ),
                    const SizedBox(height: 12),

                    // 原文カード
                    TextCard(
                      title: '原文 (Source)',
                      content: _sourceText,
                      placeholder: 'クリップボードにコピーしたテキストが自動で取り込まれます...',
                    ),
                    const SizedBox(height: 12),

                    // 翻訳結果カード
                    TextCard(
                      title: '翻訳 (Translation)',
                      content: _translatedText,
                      placeholder: '翻訳結果がここに表示されます...',
                      isLoading: _isTranslating,
                    ),
                  ],
                ),
              ),
            ),

            // ステータスバー（最下部）
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'クリップボード監視待機中',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    settings.direction.shortLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
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
