import 'package:copy_lot/data/datasources/secure_storage_datasource.dart';
import 'package:copy_lot/data/repositories/settings_repository_impl.dart';
import 'package:copy_lot/domain/models/translation_direction.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeSecureStorageDatasource extends SecureStorageDatasource {
  FakeSecureStorageDatasource() : super();

  final Map<String, String> _storage = {};

  @override
  Future<String?> read(String key) async => _storage[key];

  @override
  Future<void> write(String key, String value) async {
    _storage[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _storage.remove(key);
  }
}

void main() {
  group('SettingsRepositoryImpl', () {
    late FakeSecureStorageDatasource datasource;
    late SettingsRepositoryImpl repository;

    setUp(() {
      datasource = FakeSecureStorageDatasource();
      repository = SettingsRepositoryImpl(datasource);
    });

    test('loadSettings returns default values when storage is empty', () async {
      final settings = await repository.loadSettings();

      expect(settings.apiKey, isEmpty);
      expect(settings.direction, TranslationDirection.enToJa);
      expect(settings.isAlwaysOnTop, isFalse);
      expect(settings.isLoading, isFalse);
    });

    test('loadSettings returns stored settings correctly', () async {
      await datasource.write('google_cloud_api_key', 'test_key_123');
      await datasource.write('translation_direction', 'jaToEn');
      await datasource.write('always_on_top', 'true');

      final settings = await repository.loadSettings();

      expect(settings.apiKey, 'test_key_123');
      expect(settings.direction, TranslationDirection.jaToEn);
      expect(settings.isAlwaysOnTop, isTrue);
      expect(settings.isLoading, isFalse);
    });

    test('saveApiKey writes to storage', () async {
      await repository.saveApiKey('new_api_key');
      final stored = await datasource.read('google_cloud_api_key');
      expect(stored, 'new_api_key');
    });

    test('saveDirection writes enum name to storage', () async {
      await repository.saveDirection(TranslationDirection.jaToEn);
      final stored = await datasource.read('translation_direction');
      expect(stored, 'jaToEn');
    });

    test('saveAlwaysOnTop writes boolean string to storage', () async {
      await repository.saveAlwaysOnTop(true);
      expect(await datasource.read('always_on_top'), 'true');

      await repository.saveAlwaysOnTop(false);
      expect(await datasource.read('always_on_top'), 'false');
    });
  });
}
