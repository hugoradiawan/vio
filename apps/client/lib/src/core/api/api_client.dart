import 'package:dio/dio.dart';
import 'package:vio_core/vio_core.dart';

/// Base API client for communicating with the Vio backend
class ApiClient {
  ApiClient({
    required String baseUrl,
    Duration? connectTimeout,
    Duration? receiveTimeout,
  }) : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl,
            connectTimeout: connectTimeout ?? const Duration(seconds: 10),
            receiveTimeout: receiveTimeout ?? const Duration(seconds: 30),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ) {
    _setupInterceptors();
  }

  final Dio _dio;

  Dio get dio => _dio;

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: _onRequest,
        onResponse: _onResponse,
        onError: _onError,
      ),
    );
  }

  void _onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    VioLogger.info('API Request: ${options.method} ${options.uri}');
    if (options.data != null) {
      VioLogger.info('Request Body: ${options.data}');
    }
    handler.next(options);
  }

  void _onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    VioLogger.info(
      'API Response: ${response.statusCode} ${response.requestOptions.uri}',
    );
    handler.next(response);
  }

  void _onError(DioException error, ErrorInterceptorHandler handler) {
    VioLogger.error('API Error: ${error.type} - ${error.message}', error);

    // Convert DioException to ApiException for cleaner error handling
    final apiException = ApiException.fromDioException(error);
    handler.reject(
      DioException(
        requestOptions: error.requestOptions,
        error: apiException,
        type: error.type,
        response: error.response,
      ),
    );
  }

  /// GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// POST request
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// PUT request
  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// PATCH request
  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }
}

/// Custom API exception for cleaner error handling
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.errorCode,
    this.data,
  });

  factory ApiException.fromDioException(DioException error) {
    String message;
    final int? statusCode = error.response?.statusCode;
    String? errorCode;
    final dynamic data = error.response?.data;

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        message = 'Connection timeout. Please check your internet connection.';
        errorCode = 'CONNECTION_TIMEOUT';
      case DioExceptionType.sendTimeout:
        message = 'Request timeout. Please try again.';
        errorCode = 'SEND_TIMEOUT';
      case DioExceptionType.receiveTimeout:
        message = 'Server response timeout. Please try again.';
        errorCode = 'RECEIVE_TIMEOUT';
      case DioExceptionType.badCertificate:
        message = 'Invalid SSL certificate.';
        errorCode = 'BAD_CERTIFICATE';
      case DioExceptionType.badResponse:
        message = _extractErrorMessage(error.response) ??
            'Server error (${error.response?.statusCode})';
        errorCode = 'BAD_RESPONSE';
      case DioExceptionType.cancel:
        message = 'Request was cancelled.';
        errorCode = 'CANCELLED';
      case DioExceptionType.connectionError:
        message = 'Connection error. Please check your internet connection.';
        errorCode = 'CONNECTION_ERROR';
      case DioExceptionType.unknown:
        message = error.message ?? 'An unknown error occurred.';
        errorCode = 'UNKNOWN';
    }

    return ApiException(
      message: message,
      statusCode: statusCode,
      errorCode: errorCode,
      data: data,
    );
  }

  final String message;
  final int? statusCode;
  final String? errorCode;
  final dynamic data;

  static String? _extractErrorMessage(Response<dynamic>? response) {
    if (response?.data == null) return null;

    final data = response!.data;
    if (data is Map) {
      // Try common error message fields
      return data['message'] as String? ??
          data['error'] as String? ??
          data['detail'] as String?;
    }
    if (data is String) return data;
    return null;
  }

  @override
  String toString() =>
      'ApiException: $message (code: $errorCode, status: $statusCode)';
}
