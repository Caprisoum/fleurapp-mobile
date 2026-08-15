import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class AdminTokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class SecureAdminTokenStore implements AdminTokenStore {
  const SecureAdminTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(migrateWithBackup: true),
            );

  static const _key = 'fleurapp_admin_jwt';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}
