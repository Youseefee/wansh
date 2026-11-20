import 'package:supabase_flutter/supabase_flutter.dart';

/// Converts Supabase and runtime exceptions into concise, user-friendly
/// messages without exposing raw stack traces.
abstract final class ErrorFormatter {
  static String format(Object error, {String locale = 'ar'}) {
    final isAr = locale.toLowerCase().startsWith('ar');
    if (error is AuthException) {
      return error.message;
    }
    if (error is PostgrestException) {
      if (error.message.isNotEmpty) return error.message;
    }
    if (error is StorageException) {
      if (error.message.isNotEmpty) return error.message;
    }
    if (error is FormatException) {
      return error.message;
    }
    if (error is StateError) {
      return error.message;
    }
    final raw = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
    if (raw.isNotEmpty && raw != 'Instance of \'Object\'') {
      return raw;
    }
    return isAr
        ? 'حدث خطأ غير متوقع، يرجى المحاولة لاحقاً.'
        : 'Unexpected error, please try again.';
  }
}
