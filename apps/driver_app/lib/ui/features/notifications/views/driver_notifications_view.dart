import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../core/driver_strings.dart';
import '../../../core/locale_controller.dart';
import '../view_models/notifications_view_model.dart';

/// In-app Notifications Inbox (`/notifications`) displaying dispatch offers,
/// trip updates, and driver approval updates with Realtime refresh.
class DriverNotificationsView extends StatefulWidget {
  const DriverNotificationsView({
    super.key,
    required this.controller,
    required this.localeController,
  });

  final DriverNotificationsController controller;
  final LocaleController localeController;

  @override
  State<DriverNotificationsView> createState() =>
      _DriverNotificationsViewState();
}

class _DriverNotificationsViewState extends State<DriverNotificationsView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.controller.loadNotifications());
    });
  }

  Future<void> _onTapNotification(AppNotification item) async {
    await widget.controller.markAsRead(item.id);
    if (!mounted) return;

    final requestId = item.data['request_id'] as String?;
    if (requestId != null &&
        requestId.isNotEmpty &&
        item.type.startsWith('trip_')) {
      context.push('/trip/$requestId');
    } else if (item.type == 'dispatch_offer_new') {
      context.go('/home');
    }
  }

  IconData _iconForType(String type) {
    if (type == 'dispatch_offer_new') return Icons.notifications_active_rounded;
    if (type.startsWith('driver_approved')) return Icons.verified_rounded;
    if (type.startsWith('driver_rejected') ||
        type.startsWith('driver_suspended')) {
      return Icons.gpp_bad_outlined;
    }
    if (type.startsWith('trip_cancelled')) return Icons.cancel_outlined;
    if (type.startsWith('trip_')) return Icons.local_shipping_rounded;
    return Icons.notifications_outlined;
  }

  Color _colorForType(String type) {
    if (type == 'dispatch_offer_new') return WenshyColors.amberDark;
    if (type.startsWith('driver_approved')) return WenshyColors.emerald;
    if (type.startsWith('driver_rejected') ||
        type.startsWith('driver_suspended') ||
        type.startsWith('trip_cancelled')) {
      return WenshyColors.red;
    }
    return WenshyColors.deepSlate;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable>[
        widget.controller,
        widget.localeController,
      ]),
      builder: (context, _) {
        final locale = widget.localeController.localeCode;
        final theme = Theme.of(context);
        final ctrl = widget.controller;

        return Scaffold(
          appBar: AppBar(
            title: Text(DriverStrings.notificationsTitle(locale)),
            actions: <Widget>[
              if (ctrl.hasUnread)
                TextButton.icon(
                  onPressed: ctrl.isMarkingAll ? null : ctrl.markAllAsRead,
                  icon: const Icon(Icons.done_all_rounded, size: 18),
                  label: Text(DriverStrings.markAllRead(locale)),
                ),
            ],
          ),
          body: ctrl.isLoading && ctrl.notifications.isEmpty
              ? const WenshyLoadingView()
              : ctrl.errorMessage != null && ctrl.notifications.isEmpty
                  ? WenshyErrorView(
                      message: ctrl.errorMessage!,
                      onRetry: ctrl.loadNotifications,
                    )
                  : ctrl.notifications.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsetsDirectional.all(32),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Icon(
                                  Icons.notifications_none_rounded,
                                  size: 56,
                                  color: WenshyColors.slateMuted,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  DriverStrings.noNotificationsYet(locale),
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: WenshyColors.slateMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: ctrl.loadNotifications,
                          child: ListView.separated(
                            padding: const EdgeInsetsDirectional.all(16),
                            itemCount: ctrl.notifications.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = ctrl.notifications[index];
                              final accent = _colorForType(item.type);
                              return Card(
                                color: item.isRead
                                    ? null
                                    : WenshyColors.amberSoft
                                        .withValues(alpha: 0.45),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  side: BorderSide(
                                    color: item.isRead
                                        ? Colors.transparent
                                        : WenshyColors.amber
                                            .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding:
                                      const EdgeInsetsDirectional.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        accent.withValues(alpha: 0.14),
                                    child: Icon(
                                      _iconForType(item.type),
                                      color: accent,
                                    ),
                                  ),
                                  title: Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Text(
                                          item.localizedTitle(locale),
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                            fontWeight: item.isRead
                                                ? FontWeight.w600
                                                : FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      if (!item.isRead)
                                        Container(
                                          width: 9,
                                          height: 9,
                                          decoration: const BoxDecoration(
                                            color: WenshyColors.amberDark,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      const SizedBox(height: 4),
                                      Text(item.localizedBody(locale)),
                                      const SizedBox(height: 6),
                                      Text(
                                        WenshyLabels.formatRelativeTime(
                                          item.createdAt,
                                          locale: locale,
                                        ),
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                  onTap: () => _onTapNotification(item),
                                ),
                              );
                            },
                          ),
                        ),
        );
      },
    );
  }
}
