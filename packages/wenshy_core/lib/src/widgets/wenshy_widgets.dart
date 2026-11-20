import 'package:flutter/material.dart';

import '../l10n/wenshy_labels.dart';
import '../models/enums.dart';
import '../theme/wenshy_theme.dart';

/// Semantic status pill badge with RTL-friendly directional padding and
/// convenience factories for Wenshy domain enums.
class WenshyStatusBadge extends StatelessWidget {
  const WenshyStatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.backgroundColor,
    this.compact = false,
  });

  /// Creates a status badge styled for a [TripStatus].
  factory WenshyStatusBadge.trip(
    TripStatus status, {
    Key? key,
    String locale = 'ar',
    bool short = true,
    bool compact = false,
  }) {
    final color = switch (status) {
      TripStatus.searching => WenshyColors.amberDark,
      TripStatus.driverAssigned => WenshyColors.info,
      TripStatus.enRouteToPickup ||
      TripStatus.arrivedAtPickup ||
      TripStatus.vehicleLoaded ||
      TripStatus.enRouteToDropoff =>
        WenshyColors.amberDark,
      TripStatus.delivered => WenshyColors.emerald,
      TripStatus.cancelled || TripStatus.expired => WenshyColors.red,
    };
    final icon = switch (status) {
      TripStatus.searching => Icons.radar,
      TripStatus.driverAssigned => Icons.verified_user_outlined,
      TripStatus.enRouteToPickup ||
      TripStatus.enRouteToDropoff =>
        Icons.local_shipping_outlined,
      TripStatus.arrivedAtPickup => Icons.location_on_outlined,
      TripStatus.vehicleLoaded => Icons.car_repair_outlined,
      TripStatus.delivered => Icons.check_circle_outline,
      TripStatus.cancelled => Icons.cancel_outlined,
      TripStatus.expired => Icons.timer_off_outlined,
    };
    return WenshyStatusBadge(
      key: key,
      label: short
          ? WenshyLabels.tripStatusShort(status, locale: locale)
          : WenshyLabels.tripStatus(status, locale: locale),
      color: color,
      icon: icon,
      compact: compact,
    );
  }

  /// Creates a status badge styled for a [DriverApprovalStatus].
  factory WenshyStatusBadge.driverApproval(
    DriverApprovalStatus status, {
    Key? key,
    String locale = 'ar',
    bool compact = false,
  }) {
    final color = switch (status) {
      DriverApprovalStatus.pending => WenshyColors.amberDark,
      DriverApprovalStatus.underReview => WenshyColors.info,
      DriverApprovalStatus.approved => WenshyColors.emerald,
      DriverApprovalStatus.rejected ||
      DriverApprovalStatus.suspended =>
        WenshyColors.red,
    };
    final icon = switch (status) {
      DriverApprovalStatus.pending => Icons.hourglass_empty,
      DriverApprovalStatus.underReview => Icons.manage_search,
      DriverApprovalStatus.approved => Icons.verified,
      DriverApprovalStatus.rejected => Icons.error_outline,
      DriverApprovalStatus.suspended => Icons.block,
    };
    return WenshyStatusBadge(
      key: key,
      label: WenshyLabels.driverApprovalStatus(status, locale: locale),
      color: color,
      icon: icon,
      compact: compact,
    );
  }

  /// Creates a status badge styled for a [DocumentReviewStatus].
  factory WenshyStatusBadge.documentReview(
    DocumentReviewStatus status, {
    Key? key,
    String locale = 'ar',
    bool compact = false,
  }) {
    final color = switch (status) {
      DocumentReviewStatus.pending => WenshyColors.amberDark,
      DocumentReviewStatus.approved => WenshyColors.emerald,
      DocumentReviewStatus.rejected => WenshyColors.red,
    };
    return WenshyStatusBadge(
      key: key,
      label: WenshyLabels.documentReviewStatus(status, locale: locale),
      color: color,
      compact: compact,
    );
  }

  /// Creates a status badge styled for a [ComplaintStatus].
  factory WenshyStatusBadge.complaint(
    ComplaintStatus status, {
    Key? key,
    String locale = 'ar',
    bool compact = false,
  }) {
    final color = switch (status) {
      ComplaintStatus.open => WenshyColors.amberDark,
      ComplaintStatus.inProgress => WenshyColors.info,
      ComplaintStatus.resolved => WenshyColors.emerald,
      ComplaintStatus.dismissed => WenshyColors.slateMuted,
    };
    return WenshyStatusBadge(
      key: key,
      label: WenshyLabels.complaintStatus(status, locale: locale),
      color: color,
      compact: compact,
    );
  }

  /// Creates a status badge styled for an [OfferStatus].
  factory WenshyStatusBadge.offer(
    OfferStatus status, {
    Key? key,
    String locale = 'ar',
    bool compact = false,
  }) {
    final color = switch (status) {
      OfferStatus.pending => WenshyColors.amberDark,
      OfferStatus.accepted => WenshyColors.emerald,
      OfferStatus.rejected ||
      OfferStatus.expired ||
      OfferStatus.cancelled =>
        WenshyColors.red,
    };
    return WenshyStatusBadge(
      key: key,
      label: WenshyLabels.offerStatus(status, locale: locale),
      color: color,
      compact: compact,
    );
  }

  final String label;
  final Color color;
  final IconData? icon;
  final Color? backgroundColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? color.withValues(alpha: 0.14);
    final padding = compact
        ? const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 3)
        : const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 6);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: compact ? 13 : 15, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: compact ? 11.5 : 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// High-contrast, thumb-friendly primary call-to-action button for roadside
/// rescue flows.
class WenshyPrimaryButton extends StatelessWidget {
  const WenshyPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.primary;
    final fg = foregroundColor ?? theme.colorScheme.onPrimary;
    final effectiveOnPressed = isLoading ? null : onPressed;

    final child = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );

    final button = FilledButton(
      onPressed: effectiveOnPressed,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        minimumSize: const Size(0, 52),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: child,
    );

    if (!expanded) return button;
    return SizedBox(width: double.infinity, child: button);
  }
}

/// Centered loading indicator with an optional localized status message.
class WenshyLoadingView extends StatelessWidget {
  const WenshyLoadingView({
    super.key,
    this.message,
  });

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            CircularProgressIndicator(
              color: theme.colorScheme.primary,
            ),
            if (message != null && message!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Clean error state display with an optional retry button.
class WenshyErrorView extends StatelessWidget {
  const WenshyErrorView({
    super.key,
    required this.message,
    this.title,
    this.onRetry,
    this.retryLabel,
    this.icon = Icons.error_outline_rounded,
  });

  final String message;
  final String? title;
  final VoidCallback? onRetry;
  final String? retryLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final effectiveRetryLabel =
        retryLabel ?? (isRtl ? 'إعادة المحاولة' : 'Retry');

    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              padding: const EdgeInsetsDirectional.all(14),
              decoration: BoxDecoration(
                color: WenshyColors.red.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: WenshyColors.red,
              ),
            ),
            if (title != null && title!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                title!,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(effectiveRetryLabel),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface,
                  side: BorderSide(color: theme.colorScheme.outline),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
