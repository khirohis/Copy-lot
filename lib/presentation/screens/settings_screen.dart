import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/settings_state.dart';
import '../../domain/repositories/translation_repository.dart';
import '../providers/settings_provider.dart';
import '../providers/translation_provider.dart';

/// API キーの疎通確認ステータス
enum ApiKeyValidationStatus {
  /// 未確認
  none,

  /// 確認中
  checking,

  /// 接続確認 OK
  valid,

  /// 接続確認 NG
  invalid,
}

/// フルページ設定画面
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    super.key,
    this.isInitialSetup = false,
  });

  /// APIキー未設定による初回強制遷移フラグ
  final bool isInitialSetup;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late final TextEditingController _apiKeyController;
  bool _obscureApiKey = true;
  bool _isSaving = false;

  ApiKeyValidationStatus _validationStatus = ApiKeyValidationStatus.none;
  String? _validationMessage;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsNotifierProvider);
    _apiKeyController = TextEditingController(text: settings.apiKey);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  /// API キーの疎通確認
  Future<void> _testConnection() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      setState(() {
        _validationStatus = ApiKeyValidationStatus.invalid;
        _validationMessage = 'API キーを入力してください';
      });
      return;
    }

    setState(() {
      _validationStatus = ApiKeyValidationStatus.checking;
      _validationMessage = null;
    });

    try {
      final repository = ref.read(translationRepositoryProvider);
      await repository.validateApiKey(apiKey);

      if (!mounted) return;
      setState(() {
        _validationStatus = ApiKeyValidationStatus.valid;
        _validationMessage = '接続確認 OK: 有効な API キーです';
      });
    } on TranslationException catch (e) {
      if (!mounted) return;
      setState(() {
        _validationStatus = ApiKeyValidationStatus.invalid;
        _validationMessage = '接続確認 NG: ${e.message}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _validationStatus = ApiKeyValidationStatus.invalid;
        _validationMessage = '接続確認 NG: 予期せぬエラーが発生しました ($e)';
      });
    }
  }

  Future<void> _handleSave() async {
    final apiKey = _apiKeyController.text.trim();
    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('API キーを入力してください'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    await ref.read(settingsNotifierProvider.notifier).updateApiKey(apiKey);
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('設定を保存しました'),
          duration: Duration(seconds: 1),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  /// 接続確認結果のインジケーター表示ウィジェット
  Widget _buildValidationIndicator(ThemeData theme) {
    final Color bgColor;
    final Color borderColor;
    final Color textColor;
    final Widget icon;
    final String text;

    switch (_validationStatus) {
      case ApiKeyValidationStatus.none:
        return const SizedBox.shrink();
      case ApiKeyValidationStatus.checking:
        bgColor = theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5);
        borderColor = theme.colorScheme.outlineVariant;
        textColor = theme.colorScheme.onSurfaceVariant;
        icon = const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
        text = 'Google Cloud Translation API への接続を確認しています...';
        break;
      case ApiKeyValidationStatus.valid:
        bgColor = Colors.green.withValues(alpha: 0.08);
        borderColor = Colors.green.withValues(alpha: 0.4);
        textColor = Colors.green.shade800;
        icon = const Icon(Icons.check_circle, size: 16, color: Colors.green);
        text = _validationMessage ?? '接続確認 OK: 有効な API キーです';
        break;
      case ApiKeyValidationStatus.invalid:
        bgColor = theme.colorScheme.errorContainer.withValues(alpha: 0.3);
        borderColor = theme.colorScheme.error.withValues(alpha: 0.5);
        textColor = theme.colorScheme.onErrorContainer;
        icon = Icon(Icons.error_outline, size: 16, color: theme.colorScheme.error);
        text = _validationMessage ?? '接続確認 NG: API キーが無効です';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    ref.listen<SettingsState>(settingsNotifierProvider, (previous, next) {
      if ((previous == null || previous.isLoading) && !next.isLoading) {
        if (_apiKeyController.text.isEmpty && next.apiKey.isNotEmpty) {
          _apiKeyController.text = next.apiKey;
        }
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        automaticallyImplyLeading: !widget.isInitialSetup,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isInitialSetup) ...[
                Card(
                  color: theme.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: theme.colorScheme.onPrimaryContainer,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'ご利用を開始するには、Google Cloud Translation API キーの設定が必要です。',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                'Google Cloud Translation API',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Cloud Translation API v2 (Basic) で発行した API キーを入力してください。',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 12),
              // API キー入力フィールド ＋ 接続確認ボタン
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _apiKeyController,
                      obscureText: _obscureApiKey,
                      onChanged: (_) {
                        if (_validationStatus != ApiKeyValidationStatus.none) {
                          setState(() {
                            _validationStatus = ApiKeyValidationStatus.none;
                            _validationMessage = null;
                          });
                        }
                      },
                      decoration: InputDecoration(
                        labelText: 'API キー',
                        hintText: 'AIzaSy...',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.key),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureApiKey
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() => _obscureApiKey = !_obscureApiKey);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed:
                          _validationStatus == ApiKeyValidationStatus.checking
                              ? null
                              : _testConnection,
                      icon: _validationStatus == ApiKeyValidationStatus.checking
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.network_check),
                      label: const Text('接続確認'),
                    ),
                  ),
                ],
              ),
              if (_validationStatus != ApiKeyValidationStatus.none) ...[
                const SizedBox(height: 8),
                _buildValidationIndicator(theme),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'API キーは OS のセキュアストレージに安全に暗号化保存されます',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton.icon(
                  onPressed: _isSaving ? null : _handleSave,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: const Text('設定を保存'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
