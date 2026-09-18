import 'package:dio/dio.dart';

/// Every ScanServe API error response is shaped like
/// { "success": false, "message": "..." }. This pulls that message out
/// of a DioException, falling back to something generic for network
/// failures that never got a response at all.
String apiErrorMessage(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['message'] is String) {
      return data['message'] as String;
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'Could not reach the server. Check your connection and try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}
