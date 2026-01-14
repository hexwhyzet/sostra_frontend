import 'dart:developer' as console;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:qr_reader/request.dart';
import 'package:qr_reader/services/password_storage.dart';

class AuthInterceptor extends Interceptor {
  final Future<String?> Function() getAccessToken;
  final Future<String?> Function() getRefreshToken;
  final Future<void> Function(String accessToken) saveAccessToken;
  final Future<void> Function(String accessToken) saveRefreshToken;
  final VoidCallback onUnauthorized;

  AuthInterceptor({
    required this.getAccessToken,
    required this.getRefreshToken,
    required this.saveAccessToken,
    required this.saveRefreshToken,
    required this.onUnauthorized,
  });

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    // Не добавляем токен, если interceptor отключен
    if (options.extra["disableInterceptor"] != true) {
      final token = await getAccessToken();
      if (token != null) {
        options.headers["Authorization"] = "Bearer $token";
      }
    }
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401 &&
        err.requestOptions.extra["disableInterceptor"] != true) {
      final refreshToken = await getRefreshToken();
      if (refreshToken != null) {
        try {
          final newAccessToken = await _refreshToken(refreshToken);
          if (newAccessToken != null) {
            saveAccessToken(newAccessToken);
            final options = err.requestOptions;
            options.extra["disableInterceptor"] = true; // Чтобы не поймать
            // рекурсивно проваленный запрос
            options.headers["Authorization"] = "Bearer $newAccessToken";
            final response = await Dio().fetch(options);
            return handler.resolve(response);
          } else {
            await _tryLoginWithSavedPassword(err, handler);
            return;
          }
        } catch (_) {
          // Если refresh токен протух, пробуем использовать сохраненный пароль
          await _tryLoginWithSavedPassword(err, handler);
          return;
        }
      } else {
        // Если нет refresh токена, пробуем использовать сохраненный пароль
        await _tryLoginWithSavedPassword(err, handler);
        return;
      }
    }
    super.onError(err, handler);
  }

  Future<void> _tryLoginWithSavedPassword(
      DioException err, ErrorInterceptorHandler handler) async {
    try {
      // Получаем сохраненные учетные данные
      final credentials = await PasswordStorageService.getSavedCredentials();
      if (credentials['username'] == null || credentials['password'] == null) {
        onUnauthorized();
        return;
      }

      // Пробуем войти с сохраненными данными
      final response = await sendRequest(
        'POST',
        'token/',
        body: {
          'username': credentials['username'],
          'password': credentials['password'],
        },
        disableInterceptor: true,
      );

      if (response != null && response.containsKey('access')) {
        // Сохраняем новые токены
        await saveAccessToken(response['access']);
        await saveRefreshToken(response['refresh']);

        // Повторяем оригинальный запрос с новым токеном
        final options = err.requestOptions;
        options.extra["disableInterceptor"] = true;
        options.headers["Authorization"] = "Bearer ${response['access']}";
        final retryResponse = await Dio().fetch(options);
        return handler.resolve(retryResponse);
      } else {
        onUnauthorized();
      }
    } catch (e) {
      print('Error trying to login with saved password: $e');
      onUnauthorized();
    }
  }

  Future<String?> _refreshToken(String refreshToken) async {
    try {
      final response = await sendRequest('POST', 'token/refresh/',
          body: {'refresh': refreshToken}, disableInterceptor: true);
      if (response != null && response.containsKey('access')) {
        return response['access'];
      }
    } catch (e) {
      print('Error refreshing token: $e');
    }
    return null;
  }
}
