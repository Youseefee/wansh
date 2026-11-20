import 'package:flutter/material.dart';
import 'package:wenshy_core/wenshy_core.dart';

import '../../../core/driver_strings.dart';

/// Incoming rescue offer card / bottom-sheet content displaying live countdown
/// timer (`expires_at`), distance, pickup/dropoff locations, vehicle info, and
/// Accept / Reject CTAs.
class IncomingOfferCard extends StatelessWidget {
  const IncomingOfferCard({
    super.key,
    required this.offer,
    required this.remaining,
    required this.locale,
    required this.isBusy,
    required this.onAccept,
    required this.onReject,
  });

  final DispatchOffer offer;
  final Duration remaining;
  final String locale;
  final bool isBusy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final req = offer.rescueRequest;
    final seconds = remaining.inSeconds.clamp(0, 999);
    final totalSeconds = offer.expiresAt
        .difference(offer.createdAt)
        .inSeconds
        .clamp(15, 180);
    final progress = (seconds / totalSeconds).clamp(0.0, 1.0);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: WenshyColors.amber, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  padding: const EdgeInsetsDirectional.all(10),
                  decoration: BoxDecoration(
                    color: WenshyColors.amberSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: WenshyColors.amberDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        DriverStrings.incomingOfferTitle(locale),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (req != null)
                        Text(
                          req.requestCode,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: seconds <= 10
                        ? WenshyColors.red.withValues(alpha: 0.14)
                        : WenshyColors.deepSlate,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${seconds}s',
                    style: TextStyle(
                      color: seconds <= 10
                          ? WenshyColors.red
                          : WenshyColors.amber,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: theme.colorScheme.surfaceContainerHigh,
                color: seconds <= 10 ? WenshyColors.red : WenshyColors.amber,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _InfoChip(
                  icon: Icons.near_me_outlined,
                  label: WenshyLabels.formatDistanceMeters(
                    offer.distanceMeters,
                    locale: locale,
                  ),
                ),
                if (offer.etaMinutes != null)
                  _InfoChip(
                    icon: Icons.schedule,
                    label: WenshyLabels.formatEtaMinutes(
                      offer.etaMinutes!,
                      locale: locale,
                    ),
                  ),
                if (req != null)
                  _InfoChip(
                    icon: Icons.payments_outlined,
                    label: WenshyLabels.formatPrice(
                      req.estimatedPrice,
                      currency: req.currency,
                      locale: locale,
                    ),
                  ),
              ],
            ),
            if (req != null) ...<Widget>[
              const SizedBox(height: 14),
              _AddressRow(
                icon: Icons.my_location_rounded,
                color: WenshyColors.red,
                label: DriverStrings.pickupPoint(locale),
                value: req.pickupAddress,
              ),
              const SizedBox(height: 8),
              _AddressRow(
                icon: Icons.flag_rounded,
                color: WenshyColors.emerald,
                label: DriverStrings.dropoffPoint(locale),
                value: req.dropoffAddress,
              ),
              if (req.vehicleSummary != null ||
                  req.breakdownReason != null) ...<Widget>[
                const SizedBox(height: 10),
                Text(
                  [
                    ?req.vehicleSummary,
                    if (req.breakdownReason?.trim().isNotEmpty == true)
                      req.breakdownReason!,
                  ].join(' • '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy ? null : onReject,
                    icon: const Icon(Icons.close_rounded),
                    label: Text(DriverStrings.rejectOffer(locale)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: WenshyColors.red,
                      side: const BorderSide(color: WenshyColors.red),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: WenshyPrimaryButton(
                    label: DriverStrings.acceptOffer(locale),
                    icon: Icons.check_circle_outline,
                    backgroundColor: WenshyColors.emerald,
                    foregroundColor: Colors.white,
                    isLoading: isBusy,
                    onPressed: onAccept,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

class _AddressRow extends StatelessWidget {
  const _AddressRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
