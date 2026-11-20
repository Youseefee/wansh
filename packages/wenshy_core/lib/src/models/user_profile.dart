import 'package:flutter/foundation.dart';

import 'enums.dart';
import 'json_parsers.dart';

/// User profile matching `public.profiles` (Migration 002).
@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    this.role = AppRole.customer,
    this.fullName = '',
    this.phone,
    this.email,
    this.avatarUrl,
    this.isActive = true,
    this.fcmToken,
    this.locale = 'ar',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final AppRole role;
  final String fullName;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final bool isActive;
  final String? fcmToken;
  final String locale;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isArabic => locale.toLowerCase().startsWith('ar');

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      role: AppRole.tryFromJson(json['role']) ?? AppRole.customer,
      fullName: (json['full_name'] as String?) ?? '',
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isActive: JsonParsers.asBool(json['is_active'], defaultValue: true),
      fcmToken: json['fcm_token'] as String?,
      locale: (json['locale'] as String?) ?? 'ar',
      createdAt: JsonParsers.asDateTime(
        json['created_at'],
        field: 'created_at',
      ),
      updatedAt: JsonParsers.asDateTime(
        json['updated_at'],
        field: 'updated_at',
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'role': role.toJson(),
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'avatar_url': avatarUrl,
      'is_active': isActive,
      'fcm_token': fcmToken,
      'locale': locale,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    AppRole? role,
    String? fullName,
    String? phone,
    String? email,
    String? avatarUrl,
    bool? isActive,
    String? fcmToken,
    String? locale,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      role: role ?? this.role,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActive: isActive ?? this.isActive,
      fcmToken: fcmToken ?? this.fcmToken,
      locale: locale ?? this.locale,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          role == other.role &&
          fullName == other.fullName &&
          phone == other.phone &&
          email == other.email &&
          avatarUrl == other.avatarUrl &&
          isActive == other.isActive &&
          fcmToken == other.fcmToken &&
          locale == other.locale &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        role,
        fullName,
        phone,
        email,
        avatarUrl,
        isActive,
        fcmToken,
        locale,
        createdAt,
        updatedAt,
      );
}
