import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_reader/alert.dart';
import 'package:qr_reader/appbar.dart';
import 'package:qr_reader/request.dart';

class PasswordResetRequestScreen extends StatefulWidget {
  @override
  _PasswordResetRequestScreenState createState() =>
      _PasswordResetRequestScreenState();
}

class _PasswordResetRequestScreenState
    extends State<PasswordResetRequestScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final phone = _phoneController.text.trim();

    if (phone.isEmpty) {
      raiseErrorFlushbar(context, "Введите номер телефона");
      return;
    }

    // Базовая валидация формата телефона
    if (!phone.startsWith('+')) {
      raiseErrorFlushbar(context, "Номер телефона должен начинаться с +");
      return;
    }

    if (phone.length < 10) {
      raiseErrorFlushbar(context, "Номер телефона слишком короткий");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await sendRequest(
        'POST',
        'auth/password_reset/request/',
        body: {'phone': phone},
        disableInterceptor: true,
      );

      if (response != null && response.containsKey('token')) {
        // Переходим на экран подтверждения
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PasswordResetConfirmScreen(
              token: response['token'],
              phone: phone,
            ),
          ),
        );
      } else if (response != null && response.containsKey('message')) {
        // Показываем сообщение (даже если пользователь не найден, для безопасности)
        // Если токен есть, переходим на экран подтверждения
        if (response.containsKey('token') && response['token'] != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PasswordResetConfirmScreen(
                token: response['token'],
                phone: phone,
              ),
            ),
          );
          // Показываем сообщение после навигации
          Future.delayed(Duration(milliseconds: 300), () {
            if (mounted) {
              raiseSuccessFlushbar(context, response['message']);
            }
          });
        } else {
          // Если токена нет, остаемся на этом экране и показываем сообщение
          raiseSuccessFlushbar(context, response['message']);
        }
      } else {
        raiseErrorFlushbar(context, "Произошла ошибка запроса");
      }
    } on DioException catch (e) {
      // Не обрабатываем 401 для запросов восстановления пароля
      if (e.response?.statusCode == 401) {
        raiseErrorFlushbar(context, "Ошибка авторизации. Попробуйте позже.");
      } else if (e.response?.statusCode == 400) {
        final errorData = e.response?.data;
        if (errorData is Map && errorData.containsKey('phone')) {
          raiseErrorFlushbar(context, errorData['phone'][0] ?? "Неверный формат номера телефона");
        } else {
          raiseErrorFlushbar(context, "Ошибка валидации данных");
        }
      } else if (e.response?.statusCode == 500) {
        final errorData = e.response?.data;
        if (errorData is Map && errorData.containsKey('error')) {
          raiseErrorFlushbar(context, errorData['error']);
        } else {
          raiseErrorFlushbar(context, "Ошибка сервера. Попробуйте позже.");
        }
      } else {
        raiseErrorFlushbar(context, "Ошибка подключения: ${e.message}");
      }
    } catch (e) {
      raiseErrorFlushbar(context, "Неизвестная ошибка: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
            Text(
              'Восстановление пароля',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Введите номер телефона для получения кода подтверждения',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 32),
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Номер телефона',
                hintText: '+7XXXXXXXXXX',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[+\d]')),
              ],
            ),
            SizedBox(height: 24),
            if (_isLoading)
              CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _requestCode,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text('Отправить код'),
              ),
            SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Назад к входу'),
            ),
          ],
        ),
      ),
    );
  }
}

class PasswordResetConfirmScreen extends StatefulWidget {
  final String token;
  final String phone;

  PasswordResetConfirmScreen({
    required this.token,
    required this.phone,
  });

  @override
  _PasswordResetConfirmScreenState createState() =>
      _PasswordResetConfirmScreenState();
}

class _PasswordResetConfirmScreenState
    extends State<PasswordResetConfirmScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _confirmReset() async {
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (code.isEmpty) {
      raiseErrorFlushbar(context, "Введите код подтверждения");
      return;
    }

    if (code.length != 6) {
      raiseErrorFlushbar(context, "Код должен содержать 6 цифр");
      return;
    }

    if (password.isEmpty) {
      raiseErrorFlushbar(context, "Введите новый пароль");
      return;
    }

    if (password.length < 8) {
      raiseErrorFlushbar(context, "Пароль должен содержать минимум 8 символов");
      return;
    }

    if (password != confirmPassword) {
      raiseErrorFlushbar(context, "Пароли не совпадают");
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final responseData = await sendRequest(
        'POST',
        'auth/password_reset/confirm/',
        body: {
          'token': widget.token,
          'code': code,
          'new_password': password,
        },
        disableInterceptor: true,
      );

      if (responseData != null && responseData.containsKey('message')) {
        // Сохраняем сообщение перед навигацией
        final successMessage = responseData['message'];
        // Возвращаемся на экран входа
        if (mounted) {
          // Используем popUntil для возврата на первый экран
          Navigator.of(context).popUntil((route) => route.isFirst);
          // Показываем сообщение после навигации с достаточной задержкой
          Future.delayed(Duration(milliseconds: 800), () {
            // Используем rootNavigator для показа сообщения
            final rootContext = Navigator.of(context, rootNavigator: true).context;
            try {
              raiseSuccessFlushbar(rootContext, successMessage);
            } catch (e) {
              // Игнорируем ошибки показа сообщения, если контекст недоступен
              print('Could not show success message: $e');
            }
          });
        }
      } else {
        if (mounted) {
          raiseErrorFlushbar(context, "Произошла ошибка запроса");
        }
      }
    } on DioException catch (e) {
      if (!mounted) return;
      
      // Откладываем показ ошибки, чтобы избежать конфликтов с навигацией
      Future.delayed(Duration(milliseconds: 100), () {
        if (!mounted) return;
        
        if (e.response?.statusCode == 400) {
          final errorData = e.response?.data;
          if (errorData is Map) {
            if (errorData.containsKey('error')) {
              raiseErrorFlushbar(context, errorData['error']);
            } else if (errorData.containsKey('code')) {
              raiseErrorFlushbar(context, errorData['code'][0] ?? "Неверный код");
            } else if (errorData.containsKey('new_password')) {
              final passwordErrors = errorData['new_password'];
              if (passwordErrors is List && passwordErrors.isNotEmpty) {
                raiseErrorFlushbar(context, passwordErrors[0]);
              } else {
                raiseErrorFlushbar(context, "Ошибка валидации пароля");
              }
            } else {
              raiseErrorFlushbar(context, "Ошибка валидации данных");
            }
          } else {
            raiseErrorFlushbar(context, "Ошибка валидации данных");
          }
        } else if (e.response?.statusCode == 401) {
          raiseErrorFlushbar(context, "Ошибка авторизации. Попробуйте позже.");
        } else {
          raiseErrorFlushbar(context, "Ошибка подключения: ${e.message ?? 'Неизвестная ошибка'}");
        }
      });
    } catch (e) {
      if (!mounted) return;
      Future.delayed(Duration(milliseconds: 100), () {
        if (mounted) {
          raiseErrorFlushbar(context, "Неизвестная ошибка: $e");
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
            Text(
              'Подтверждение',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Код отправлен на номер ${widget.phone}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 32),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: 'Код подтверждения',
                hintText: '000000',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                letterSpacing: 8,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Новый пароль',
                prefixIcon: Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
                border: OutlineInputBorder(),
              ),
              obscureText: _obscurePassword,
            ),
            SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Подтвердите пароль',
                prefixIcon: Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
                border: OutlineInputBorder(),
              ),
              obscureText: _obscureConfirmPassword,
            ),
            SizedBox(height: 24),
            if (_isLoading)
              CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _confirmReset,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 50),
                ),
                child: Text('Изменить пароль'),
              ),
            SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Назад'),
            ),
          ],
        ),
      ),
    );
  }
}
