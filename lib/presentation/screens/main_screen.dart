import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/text_type.dart';
import '../providers/clipboard_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/translation_provider.dart';
import '../providers/window_tray_provider.dart';
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
  late final AppLifecycleListener _lifecycleListener;
  StreamSubscription<bool>? _visibilitySubscription;

  @override
  void initState() {
    super.initState();

    // システムトレイ格納/復帰の連動購読
    _visibilitySubscription = ref
        .read(windowTrayDatasourceProvider)
        .onVisibilityChanged
        .listen((isVisible) {
      ref
          .read(clipboardNotifierProvider.notifier)
          .setWindowVisibility(isVisible);
    });

    _lifecycleListener = AppLifecycleListener(
      onDetach: () =>
          ref.read(clipboardNotifierProvider.notifier).stopListening(),
    );
  }

  @override
  void dispose() {
    _visibilitySubscription?.cancel();
    _lifecycleListener.dispose();
    super.dispose();
  }

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
    final clipboard = ref.watch(clipboardNotifierProvider);
    final translation = ref.watch(translationNotifierProvider);
    final theme = Theme.of(context);

    // クリップボードテキスト変更検知 → 自動翻訳実行
    ref.listen(clipboardNotifierProvider, (prev, next) {
      if (next.hasText && prev?.currentText != next.currentText) {
        ref.read(translationNotifierProvider.notifier).translate(next.currentText);
      }
    });

    // 翻訳方向切り替え検知 → 現在のテキストを再翻訳
    ref.listen(settingsNotifierProvider.select((s) => s.direction), (prev, next) {
      final currentText = ref.read(clipboardNotifierProvider).currentText;
      if (currentText.trim().isNotEmpty && prev != next) {
        ref.read(translationNotifierProvider.notifier).translate(currentText);
      }
    });

    // 最前面固定切り替え検知 → OS ウィンドウに反映
    ref.listen(settingsNotifierProvider.select((s) => s.isAlwaysOnTop),
        (prev, next) {
      if (prev != next) {
        ref.read(windowTrayDatasourceProvider).setAlwaysOnTop(next);
      }
    });

    // 5,000文字切り詰め時の非破壊的通知
    ref.listen(clipboardNotifierProvider, (prev, next) {
      if (next.isTruncated && prev?.currentText != next.currentText) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('5,000文字を超過したため、先頭5,000文字に切り詰められました。'),
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });

    // 翻訳エラー発生時の非破壊的通知
    ref.listen(translationNotifierProvider.select((s) => s.errorMessage),
        (prev, next) {
      if (next != null && next.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(translationNotifierProvider.notifier).clearError();
      }
    });

    // 初回APIキー未設定時のチェック
    _checkApiKey(settings.hasApiKey, settings.isLoading);

    final translationResult = translation.result;
    final isWord = translationResult?.textType == TextType.word;
    final translationCardTitle = isWord ? '訳語 (Word)' : '翻訳 (Translation)';

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
                    // 自動監視スイッチ行
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            clipboard.isAutoMonitoringEnabled
                                ? Icons.sync
                                : Icons.sync_disabled,
                            size: 18,
                            color: clipboard.isAutoMonitoringEnabled
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface
                                    .withValues(alpha: 0.5),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'クリップボード自動監視',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Tooltip(
                            message: settings.hasApiKey
                                ? (clipboard.isAutoMonitoringEnabled
                                    ? '自動監視を停止'
                                    : '自動監視を開始')
                                : 'API キーが設定されていないため有効化できません',
                            child: Switch(
                              value: clipboard.isAutoMonitoringEnabled,
                              onChanged: settings.hasApiKey
                                  ? (val) {
                                      ref
                                          .read(
                                            clipboardNotifierProvider.notifier,
                                          )
                                          .toggleAutoMonitoring(val);
                                    }
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

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

                    // 原文カード (クリップボード取得テキストをバインド & 手動ペーストボタン連携)
                    TextCard(
                      title: '原文 (Source)',
                      content: clipboard.currentText,
                      placeholder: 'クリップボードにコピーしたテキストが取り込まれます...',
                      onPaste: () {
                        ref
                            .read(clipboardNotifierProvider.notifier)
                            .pasteAndTranslate();
                      },
                    ),
                    const SizedBox(height: 12),

                    // 翻訳結果カード
                    TextCard(
                      title: translationCardTitle,
                      content: translationResult?.translatedText ?? '',
                      placeholder: translationResult?.isSkipped == true
                          ? '（${translationResult?.skipReason}）'
                          : '翻訳結果がここに表示されます...',
                      isLoading: translation.isLoading,
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
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: clipboard.isListening ? Colors.green : Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    clipboard.isListening
                        ? 'クリップボード自動監視中'
                        : (!clipboard.isAutoMonitoringEnabled
                            ? '自動監視 OFF (手動ペースト待機)'
                            : 'トレイ待機中 (監視停止)'),
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
