import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../errors/api_exception.dart';
import '../storage/token_storage.dart';

/// Thin Dio wrapper with bearer auth, single-flight refresh, and error mapping.
class ApiClient {
  ApiClient(this._storage)
      : _dio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            receiveTimeout: const Duration(seconds: 60),
            headers: {'Accept': 'application/json'},
          ),
        ),
        _refreshDio = Dio(
          BaseOptions(
            baseUrl: AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
          ),
        ) {
    _dio.interceptors.add(
      QueuedInterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.readAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          final path = error.requestOptions.path;
          final alreadyRetried = error.requestOptions.extra['retried'] == true;
          final isAuthCall = path.contains('/auth/');

          if (status == 401 && !alreadyRetried && !isAuthCall) {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              final options = error.requestOptions;
              options.extra['retried'] = true;
              final token = await _storage.readAccessToken();
              options.headers['Authorization'] = 'Bearer $token';
              try {
                final retried = await _dio.fetch<dynamic>(options);
                handler.resolve(retried);
                return;
              } catch (_) {
                // Fall through to the original error.
              }
            }
            onUnauthorized?.call();
          }
          handler.next(error);
        },
      ),
    );
  }

  final TokenStorage _storage;
  final Dio _dio;
  final Dio _refreshDio;

  /// Wired by the provider below to clear app auth state on session expiry.
  void Function()? onUnauthorized;

  Future<bool> _tryRefresh() async {
    final refreshToken = await _storage.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final response = await _refreshDio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = response.data;
      if (data == null) return false;
      await _storage.saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
      return true;
    } catch (_) {
      await _storage.clear();
      return false;
    }
  }

  Never _mapError(Object error) {
    if (error is ApiException) throw error;
    if (error is DioException) {
      final response = error.response;
      final data = response?.data;
      var message = 'Could not reach the server. Check your connection.';
      if (data is Map) {
        final nested = data['error'];
        if (nested is Map && nested['message'] is String) {
          message = nested['message'] as String;
        } else if (data['detail'] is String) {
          message = data['detail'] as String;
        }
      }
      if (response?.statusCode == 401) message = 'Session expired. Please sign in again.';
      throw ApiException(message, statusCode: response?.statusCode);
    }
    throw ApiException(error.toString());
  }

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(path, queryParameters: query);
      return response.data ?? <String, dynamic>{};
    } catch (error) {
      _mapError(error);
    }
  }

  Future<Map<String, dynamic>> postJson(String path, {Object? data}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: data);
      return response.data ?? <String, dynamic>{};
    } catch (error) {
      _mapError(error);
    }
  }

  Future<Map<String, dynamic>> patchJson(String path, {Object? data}) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(path, data: data);
      return response.data ?? <String, dynamic>{};
    } catch (error) {
      _mapError(error);
    }
  }

  Future<void> delete(String path) async {
    try {
      await _dio.delete<dynamic>(path);
    } catch (error) {
      _mapError(error);
    }
  }

  Future<Map<String, dynamic>> uploadPdf(
    String path, {
    required List<int> bytes,
    required String filename,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: filename),
      });
      final response = await _dio.post<Map<String, dynamic>>(path, data: form);
      return response.data ?? <String, dynamic>{};
    } catch (error) {
      _mapError(error);
    }
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(tokenStorageProvider));
});
