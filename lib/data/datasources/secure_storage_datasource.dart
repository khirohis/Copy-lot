import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// 暗号化ストレージへのデータソース
class SecureStorageDatasource {
  SecureStorageDatasource({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              wOptions: WindowsOptions(),
            );

  final FlutterSecureStorage _storage;

  Future<String?> read(String key) async {
    return _storage.read(key: key);
  }

  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }
}
