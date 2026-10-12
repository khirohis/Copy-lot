import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/datasources/translation_api_datasource.dart';
import '../../data/repositories/translation_repository_impl.dart';
import '../../domain/models/translation_result.dart';
import '../../domain/repositories/translation_repository.dart';
import 'network_provider.dart';
import 'settings_provider.dart';

/// TranslationApiDatasource の Provider
final translationDatasourceProvider = Provider<TranslationApiDatasource>((ref) {
  final dio = ref.watch(dioProvider);
  return TranslationApiDatasource(dio);
});

/// TranslationRepository の Provider
final translationRepositoryProvider = Provider<TranslationRepository>((ref) {
  final datasource = ref.watch(translationDatasourceProvider);
  return TranslationRepositoryImpl(datasource);
});

/// 翻訳状態モデル
class TranslationState {
  const TranslationState({
    this.isLoading = false,
    this.result,
    this.errorMessage,
  });

  /// 翻訳中フラグ
  final bool isLoading;

  /// 最新の翻訳結果
  final TranslationResult? result;

  /// エラーメッセージ（存在する場合）
  final String? errorMessage;

  TranslationState copyWith({
    bool? isLoading,
    TranslationResult? result,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TranslationState(
      isLoading: isLoading ?? this.isLoading,
      result: result ?? this.result,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

/// 翻訳処理を管理する Notifier
class TranslationNotifier extends Notifier<TranslationState> {
  @override
  TranslationState build() {
    return const TranslationState();
  }

  /// 指定テキストを現在の設定に基づき翻訳実行
  Future<void> translate(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final settings = ref.read(settingsNotifierProvider);
    if (!settings.hasApiKey) {
      state = state.copyWith(
        errorMessage: 'API キーが設定されていません。設定画面から API キーを入力してください。',
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
    );

    final repository = ref.read(translationRepositoryProvider);

    try {
      final result = await repository.translate(
        text: trimmed,
        direction: settings.direction,
        apiKey: settings.apiKey,
      );

      state = state.copyWith(
        isLoading: false,
        result: result,
      );
    } on TranslationException catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '予期せぬエラーが発生しました: $e',
      );
    }
  }

  /// エラーメッセージをクリア
  void clearError() {
    state = state.copyWith(clearError: true);
  }
}

/// TranslationNotifier の Provider
final translationNotifierProvider =
    NotifierProvider<TranslationNotifier, TranslationState>(
  TranslationNotifier.new,
);
