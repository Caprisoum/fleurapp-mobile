import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class CheckoutDeviceTokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class SecureCheckoutDeviceTokenStore implements CheckoutDeviceTokenStore {
  const SecureCheckoutDeviceTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _key = 'fleurapp_checkout_device_token';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}

class EphemeralCheckoutDeviceTokenStore implements CheckoutDeviceTokenStore {
  EphemeralCheckoutDeviceTokenStore([this._token]);

  String? _token;

  @override
  Future<void> delete() async => _token = null;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> write(String token) async => _token = token;
}
