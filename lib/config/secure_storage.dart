import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _keyAccessToken = 'access_token';

  static Future<void> setAccessToken(String token) async {
    try {
      await _storage.write(key: _keyAccessToken, value: token);
    } catch (e) {
      print('SecureStorage write error: $e');
    }
  }

  static Future<String> getAccessToken() async {
    try {
      return await _storage.read(key: _keyAccessToken) ?? '';
    } catch (e) {
      print('SecureStorage read error: $e');
      return '';
    }
  }

  static Future<void> deleteAccessToken() async {
    try {
      await _storage.delete(key: _keyAccessToken);
    } catch (e) {
      print('SecureStorage delete error: $e');
    }
  }
}
