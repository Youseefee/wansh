import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';
import '../l10n/wenshy_labels.dart';
import '../models/json_parsers.dart';

/// In-app / push notification record matching `public.notifications`.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.titleAr,
    required this.titleEn,
    required this.bodyAr,
    required this.bodyEn,
    required this.type,
    this.data = const <String, dynamic>{},
    this.isRead = false,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String titleAr;
  final String titleEn;
  final String bodyAr;
  final String bodyEn;
  final String type;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  /// Returns [titleAr] for Arabic locales and [titleEn] otherwise, falling
  /// back to the alternate language if the preferred string is blank.
  String localizedTitle(String locale) {
    if (WenshyLabels.isArabic(locale)) {
      return titleAr.isNotEmpty ? titleAr : titleEn;
    }
    return titleEn.isNotEmpty ? titleEn : titleAr;
  }

  /// Returns [bodyAr] for Arabic locales and [bodyEn] otherwise, falling back
  /// to the alternate language if the preferred string is blank.
  String localizedBody(String locale) {
    if (WenshyLabels.isArabic(locale)) {
      return bodyAr.isNotEmpty ? bodyAr : bodyEn;
    }
    return bodyEn.isNotEmpty ? bodyEn : bodyAr;
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    final parsedData = rawData is Map
        ? Map<String, dynamic>.unmodifiable(Map<String, dynamic>.from(rawData))
        : const <String, dynamic>{};

    return AppNotification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      titleAr: (json['title_ar'] as String?) ?? '',
      titleEn: (json['title_en'] as String?) ?? '',
      bodyAr: (json['body_ar'] as String?) ?? '',
      bodyEn: (json['body_en'] as String?) ?? '',
      type: (json['type'] as String?) ?? 'general',
      data: parsedData,
      isRead: JsonParsers.asBool(json['is_read'], defaultValue: false),
      createdAt: JsonParsers.asDateTime(
        json['created_at'],
        field: 'created_at',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'user_id': userId,
      'title_ar': titleAr,
      'title_en': titleEn,
      'body_ar': bodyAr,
      'body_en': bodyEn,
      'type': type,
      'data': Map<String, dynamic>.from(data),
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? titleAr,
    String? titleEn,
    String? bodyAr,
    String? bodyEn,
    String? type,
    Map<String, dynamic>? data,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      titleAr: titleAr ?? this.titleAr,
      titleEn: titleEn ?? this.titleEn,
      bodyAr: bodyAr ?? this.bodyAr,
      bodyEn: bodyEn ?? this.bodyEn,
      type: type ?? this.type,
      data: data ?? this.data,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppNotification &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          userId == other.userId &&
          titleAr == other.titleAr &&
          titleEn == other.titleEn &&
          bodyAr == other.bodyAr &&
          bodyEn == other.bodyEn &&
          type == other.type &&
          mapEquals(data, other.data) &&
          isRead == other.isRead &&
          createdAt == other.createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        userId,
        titleAr,
        titleEn,
        bodyAr,
        bodyEn,
        type,
        Object.hashAllUnordered(
          data.entries.map((e) => Object.hash(e.key, e.value)),
        ),
        isRead,
        createdAt,
      );

  @override
  String toString() =>
      'AppNotification(id: $id, type: $type, isRead: $isRead)';
}

/// Service for registering push device tokens (`public.device_tokens`) and
/// reading/acknowledging user notifications (`public.notifications`).
class NotificationService {
  const NotificationService({this.client});

  /// Allowed device platform values matching `public.device_tokens` check
  /// constraint.
  static const Set<String> supportedPlatforms = <String>{
    'android',
    'ios',
    'web',
  };

  final SupabaseClient? client;

  SupabaseClient get _supabase => client ?? Supabase.instance.client;

  /// Registers or reactivates a push notification token for [userId].
  ///
  /// [platform] must be one of `'android'`, `'ios'`, or `'web'`.
  Future<void> upsertDeviceToken({
    required String userId,
    required String token,
    required String platform,
  }) async {
    final trimmedToken = token.trim();
    if (trimmedToken.isEmpty) {
      throw ArgumentError.value(token, 'token', 'Device token cannot be empty');
    }
    final normalizedPlatform = platform.trim().toLowerCase();
    if (!supportedPlatforms.contains(normalizedPlatform)) {
      throw ArgumentError.value(
        platform,
        'platform',
        'Platform must be one of ${supportedPlatforms.join(', ')}',
      );
    }

    await _supabase.from(WenshyTables.deviceTokens).upsert(
      <String, dynamic>{
        'user_id': userId,
        'token': trimmedToken,
        'platform': normalizedPlatform,
        'is_active': true,
      },
      onConflict: 'user_id,token',
    );
  }

  /// Marks a device push token as inactive (e.g., on sign-out).
  Future<void> deactivateDeviceToken(String token) async {
    final trimmedToken = token.trim();
    if (trimmedToken.isEmpty) return;

    await _supabase
        .from(WenshyTables.deviceTokens)
        .update(<String, dynamic>{'is_active': false})
        .eq('token', trimmedToken);
  }

  /// Fetches the most recent notifications for [userId], newest first.
  Future<List<AppNotification>> getNotifications(
    String userId, {
    int limit = 30,
  }) async {
    final rows = await _supabase
        .from(WenshyTables.notifications)
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit.clamp(1, 200));

    return (rows as List<dynamic>)
        .map(
          (row) => AppNotification.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  /// Marks a single notification [notificationId] as read.
  Future<void> markAsRead(String notificationId) async {
    await _supabase
        .from(WenshyTables.notifications)
        .update(<String, dynamic>{'is_read': true})
        .eq('id', notificationId);
  }

  /// Marks all unread notifications for [userId] as read.
  Future<void> markAllAsRead(String userId) async {
    await _supabase
        .from(WenshyTables.notifications)
        .update(<String, dynamic>{'is_read': true})
        .eq('user_id', userId)
        .eq('is_read', false);
  }
}
