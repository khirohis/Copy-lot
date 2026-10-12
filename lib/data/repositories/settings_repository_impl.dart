import '../../domain/models/settings_state.dart';
import '../../domain/models/translation_direction.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/secure_storage_datasource.dart';

/// SettingsRepository の具象実装
class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this._datasource);

  final SecureStorageDatasource _datasource;

  static const _keyApiKey = 'google_cloud_api_key';
  static const _keyDirection = 'translation_direction';
  static const _keyAlwaysOnTop = 'always_on_top';

  @override
  Future<SettingsState> loadSettings() async {
    final apiKey = await _datasource.read(_keyApiKey) ?? '';
    final directionRaw = await _datasource.read(_keyDirection);
    final alwaysOnTopRaw = await _datasource.read(_keyAlwaysOnTop);

    final direction = directionRaw == 'jaToEn'
        ? TranslationDirection.jaToEn
        : TranslationDirection.enToJa;

    final isAlwaysOnTop = alwaysOnTopRaw == 'true';

    return SettingsState(
      apiKey: apiKey,
      direction: direction,
      isAlwaysOnTop: isAlwaysOnTop,
      isLoading: false,
    );
  }

  @override
  Future<void> saveApiKey(String apiKey) async {
    await _datasource.write(_keyApiKey, apiKey);
  }

  @override
  Future<void> saveDirection(TranslationDirection direction) async {
    await _datasource.write(_keyDirection, direction.name);
  }

  @override
  Future<void> saveAlwaysOnTop(bool isAlwaysOnTop) async {
    await _datasource.write(_keyAlwaysOnTop, isAlwaysOnTop.toString());
  }
}
