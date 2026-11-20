import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../core/app_dependencies.dart';
import '../../../core/app_strings.dart';

/// In-app Notifications inbox screen backed by `public.notifications` +
/// Supabase Realtime.
class NotificationsView extends StatefulWidget {
  const NotificationsView({super.key});

  @override
  State<NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<NotificationsView> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final deps = AppDependenciesScope.of(context);
    final uid = deps.authViewModel.currentUserId;
    if (uid != null) {
      deps.notificationsViewModel.initialize(
        uid,
        locale: deps.localeController.languageCode,
      );
    }
  }

  IconData _iconForType(String type) {
    if (type.contains('delivered')) return Icons.check_circle_rounded;
    if (type.contains('cancelled') || type.contains('expired')) {
      return Icons.cancel_rounded;
    }
    if (type.contains('driver') || type.contains('en_route')) {
      return Icons.local_shipping_rounded;
    }
    if (type.contains('arrived') || type.contains('loaded')) {
      return Icons.car_crash_rounded;
    }
    return Icons.notifications_rounded;
  }

  Color _colorForType(String type) {
    if (type.contains('delivered')) return WenshyColors.emerald;
    if (type.contains('cancelled') || type.contains('expired')) {
      return WenshyColors.red;
    }
    if (type.contains('trip_')) return WenshyColors.amberDark;
    return WenshyColors.info;
  }

  Future<void> _onNotificationTap(
    AppNotification notification,
    String localeCode,
  ) async {
    final deps = AppDependenciesScope.of(context);
    if (!notification.isRead) {
      await deps.notificationsViewModel.markAsRead(
        notification.id,
        locale: localeCode,
      );
    }
    if (!mounted) return;
    final requestId = notification.data['request_id'];
    if (requestId is String && requestId.trim().isNotEmpty) {
      context.push('/trip/${requestId.trim()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final deps = AppDependenciesScope.of(context);
    final vm = deps.notificationsViewModel;
    final strings = AppStrings.of(context);
    final theme = Theme.of(context);
    final localeCode = deps.localeController.languageCode;
    final uid = deps.authViewModel.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.notificationsTitle),
        actions: <Widget>[
          ListenableBuilder(
            listenable: vm,
            builder: (context, _) {
              if (vm.unreadCount == 0) return const SizedBox.shrink();
              return TextButton.icon(
                key: const Key('mark_all_read_btn'),
                onPressed: vm.isMarkingAll || uid == null
                    ? null
                    : () => vm.markAllAsRead(
                          userId: uid,
                          locale: localeCode,
                        ),
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: Text(strings.markAllReadBtn),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: vm,
        builder: (context, _) {
          if (vm.isLoading && vm.notifications.isEmpty) {
            return WenshyLoadingView(message: strings.loading);
          }

          if (vm.errorMessage != null && vm.notifications.isEmpty) {
            return WenshyErrorView(
              message: vm.errorMessage!,
              onRetry: uid == null
                  ? null
                  : () => vm.refresh(userId: uid, locale: localeCode),
            );
          }

          if (vm.notifications.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                if (uid != null) {
                  await vm.refresh(userId: uid, locale: localeCode);
                }
              },
              child: ListView(
                children: <Widget>[
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.65,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            const Icon(
                              Icons.notifications_none_rounded,
                              size: 56,
                              color: WenshyColors.slateMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              strings.noNotificationsEmpty,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              if (uid != null) {
                await vm.refresh(userId: uid, locale: localeCode);
              }
            },
            child: ListView.separated(
              padding: const EdgeInsetsDirectional.all(16),
              itemCount: vm.notifications.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = vm.notifications[index];
                final accent = _colorForType(item.type);
                final isUnread = !item.isRead;

                return Card(
                  key: Key('notification_item_${item.id}'),
                  color: isUnread
                      ? WenshyColors.amberSoft.withValues(alpha: 0.45)
                      : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isUnread
                          ? WenshyColors.amber.withValues(alpha: 0.7)
                          : theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _onNotificationTap(item, localeCode),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          CircleAvatar(
                            backgroundColor: accent.withValues(alpha: 0.14),
                            child: Icon(
                              _iconForType(item.type),
                              color: accent,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Row(
                                  children: <Widget>[
                                    Expanded(
                                      child: Text(
                                        item.localizedTitle(localeCode),
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                          fontWeight: isUnread
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (isUnread) ...<Widget>[
                                      const SizedBox(width: 6),
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: WenshyColors.amberDark,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item.localizedBody(localeCode),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  WenshyLabels.formatRelativeTime(
                                    item.createdAt,
                                    locale: localeCode,
                                  ),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: WenshyColors.slateMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
