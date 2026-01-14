import 'package:shared_preferences/shared_preferences.dart';

class PasswordStorageService {
  static const String _usernameKey = 'saved_username';
  static const String _passwordKey = 'saved_password';

  /// Сохраняет пароль в хранилище
  static Future<void> savePassword(String username, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_usernameKey, username);
      await prefs.setString(_passwordKey, password);
    } catch (e) {
      print('Error saving password: $e');
      rethrow;
    }
  }

  /// Получает сохраненный пароль
  static Future<Map<String, String?>> getSavedCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final username = prefs.getString(_usernameKey);
      final password = prefs.getString(_passwordKey);
      return {
        'username': username,
        'password': password,
      };
    } catch (e) {
      print('Error getting saved password: $e');
      return {'username': null, 'password': null};
    }
  }

  /// Удаляет сохраненный пароль
  static Future<void> deletePassword() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_usernameKey);
      await prefs.remove(_passwordKey);
    } catch (e) {
      print('Error deleting password: $e');
    }
  }

  /// Проверяет, есть ли сохраненные учетные данные
  static Future<bool> hasSavedCredentials() async {
    final credentials = await getSavedCredentials();
    return credentials['username'] != null && credentials['password'] != null;
  }
}
