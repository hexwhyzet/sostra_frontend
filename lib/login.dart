import 'dart:developer' as console;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:qr_reader/request.dart';
import 'package:qr_reader/settings.dart';
import 'package:qr_reader/services/password_storage.dart';

import 'alert.dart';
import 'appbar.dart';
import 'menu.dart';
import 'password_reset.dart';

class AuthChecker extends StatefulWidget {
  @override
  _AuthCheckerState createState() => _AuthCheckerState();
}

class _AuthCheckerState extends State<AuthChecker> {
  bool _isLoading = true;
  bool _isAuthenticated = false;
  late Future<bool> _authSetup;

  @override
  void initState() {
    super.initState();
    _checkAuthToken();

    _authSetup = asyncSetup(); // initState has to be sync
  }

  Future<bool> asyncSetup() async {
    await setupDioInterceptors(
      getToken: config.authToken.getSetting,
      getRefreshToken: config.refreshToken.getSetting,
      saveToken: config.authToken.setSetting,
      saveRefreshToken: config.refreshToken.setSetting,
      onUnauthorized: () {
        logout();
      },
    );
    await _checkAuthToken();
    return true;
  }

  void logout() async {
    // При выходе удаляем все сохраненные данные, включая пароль
    await PasswordStorageService.deletePassword();
    await config.authToken.clearSetting();
    await config.refreshToken.clearSetting();
    
    setState(() {
      _isAuthenticated = false;
    });
  }

  Future<void> _checkAuthToken() async {
    Map<String, dynamic>? response = await sendRequest('GET', 'whoami/');

    try {
      if (response != null &&
          response.containsKey('success') &&
          response['success']) {
        setState(() {
          _isAuthenticated = true;
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      print(e);
    }

    logout();
  }

  void _onLogin() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _authSetup,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_isAuthenticated) {
          return MenuScreen(logout);
        }
        return LoginScreen(onLoginSuccess: _onLogin);
      },
    );
  }
}

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  LoginScreen({required this.onLoginSuccess});

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      // Всегда загружаем сохраненные данные, если они есть
      final credentials = await PasswordStorageService.getSavedCredentials();
      if (credentials['username'] != null && credentials['password'] != null) {
        setState(() {
          _usernameController.text = credentials['username'] ?? '';
          _passwordController.text = credentials['password'] ?? '';
        });
      }
    } catch (e) {
      print('Error loading saved credentials: $e');
    }
  }

  Future<void> _performLogin(String username, String password) async {
    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic>? response = await sendRequest(
        'POST',
        'token/',
        body: {'username': username, 'password': password},
        disableInterceptor: true,
      );

      if (response != null && response.containsKey('access')) {
        await config.authToken.setSetting(response['access']);
        await config.refreshToken.setSetting(response['refresh']);

        // Всегда сохраняем пароль для автоматического обновления токена
        await PasswordStorageService.savePassword(username, password);

        widget.onLoginSuccess();
      } else {
        raiseErrorFlushbar(context, "Произошла ошибка запроса");
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        raiseErrorFlushbar(context, "Неверный логин или пароль");
      } else {
        raiseErrorFlushbar(context, "Ошибка подключения: ${e.message}");
      }
    } catch (e) {
      raiseErrorFlushbar(context, "Неизвестная ошибка: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _login(BuildContext context) async {
    final username = _usernameController.text;
    final password = _passwordController.text;

    if (username.isNotEmpty && password.isNotEmpty) {
      await _performLogin(username, password);
    } else {
      raiseErrorFlushbar(context, "Пароль и логин должны быть заполнены");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(context),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: 'Username'),
              enabled: !_isLoading,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
              enabled: !_isLoading,
            ),
            SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PasswordResetRequestScreen(),
                          ),
                        );
                      },
                child: Text('Забыли пароль?'),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : () => _login(context),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
              ),
              child: _isLoading
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text('Войти'),
            ),
          ],
        ),
      ),
    );
  }
}
