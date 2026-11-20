import 'package:flutter/foundation.dart';

/// Shared JSON conversion helpers for PostgreSQL / PostgREST payloads.
abstract final class JsonParsers {
  /// Parses a required `num` or numeric `String` into a `double`.
  static double asDouble(Object? value, {String field = 'value'}) {
    final parsed = asNullableDouble(value);
    if (parsed == null) {
      throw FormatException('Expected numeric value for "$field", got $value');
    }
    return parsed;
  }

  /// Parses an optional `num` or numeric `String` into a `double?`.
  static double? asNullableDouble(Object? value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  /// Parses a required `num` or integer `String` into an `int`.
  static int asInt(Object? value, {String field = 'value'}) {
    final parsed = asNullableInt(value);
    if (parsed == null) {
      throw FormatException('Expected integer value for "$field", got $value');
    }
    return parsed;
  }

  /// Parses an optional `num` or integer `String` into an `int?`.
  static int? asNullableInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      return int.tryParse(trimmed) ?? double.tryParse(trimmed)?.toInt();
    }
    return null;
  }

  /// Parses a required boolean (or boolean string) with an optional fallback.
  static bool asBool(Object? value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true') return true;
      if (normalized == 'false') return false;
    }
    if (value is num) return value != 0;
    return defaultValue;
  }

  /// Parses a required ISO-8601 `String` or `DateTime`.
  static DateTime asDateTime(Object? value, {String field = 'timestamp'}) {
    final parsed = asNullableDateTime(value);
    if (parsed == null) {
      throw FormatException('Expected timestamp for "$field", got $value');
    }
    return parsed;
  }

  /// Parses an optional ISO-8601 `String` or `DateTime`.
  static DateTime? asNullableDateTime(Object? value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  /// Formats a `DateTime` into PostgreSQL `date` (`YYYY-MM-DD`).
  static String? toSqlDate(DateTime? date) {
    if (date == null) return null;
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Parses a PostgreSQL `text[]` JSON array into an unmodifiable `List<String>`.
  static List<String> asStringList(Object? value) {
    if (value == null) return const <String>[];
    if (value is Iterable) {
      return List<String>.unmodifiable(
        value.where((e) => e != null).map((e) => e.toString()),
      );
    }
    return const <String>[];
  }

  /// Checks list equality safely for immutable value objects.
  static bool stringListEquals(List<String> a, List<String> b) =>
      listEquals(a, b);
}
