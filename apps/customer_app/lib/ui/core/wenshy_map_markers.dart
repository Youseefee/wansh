import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:wenshy_core/wenshy_core.dart';

/// Shared map marker widgets used by Home Map and Live Trip Tracker.
abstract final class WenshyMapMarkers {
  /// Breakdown pickup pin marker.
  static Widget pickupPin({String? label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (label != null)
          Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 6,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: WenshyColors.deepSlate,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Container(
          padding: const EdgeInsetsDirectional.all(6),
          decoration: BoxDecoration(
            color: WenshyColors.amber,
            shape: BoxShape.circle,
            border: Border.all(color: WenshyColors.deepSlate, width: 2.5),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.car_crash_rounded,
            size: 18,
            color: WenshyColors.deepSlate,
          ),
        ),
      ],
    );
  }

  /// Destination dropoff pin marker.
  static Widget dropoffPin({String? label}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (label != null)
          Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 6,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: WenshyColors.emerald,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        Container(
          padding: const EdgeInsetsDirectional.all(6),
          decoration: BoxDecoration(
            color: WenshyColors.emerald,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Colors.black26,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.flag_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  /// Nearby online tow-truck marker on the Home Map.
  static Widget nearbyWinchMarker({
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.all(6),
        decoration: BoxDecoration(
          color: isSelected ? WenshyColors.amber : WenshyColors.deepSlate,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? WenshyColors.deepSlate : WenshyColors.amber,
            width: 2,
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black26,
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          Icons.local_shipping_rounded,
          size: 18,
          color: isSelected ? WenshyColors.deepSlate : WenshyColors.amber,
        ),
      ),
    );
  }

  /// Animated live tow-truck marker during an active rescue trip.
  static Widget liveTowTruckMarker({double? headingDegrees}) {
    final angleRad =
        headingDegrees != null ? (headingDegrees * math.pi / 180.0) : 0.0;
    return Transform.rotate(
      angle: angleRad,
      child: Container(
        padding: const EdgeInsetsDirectional.all(8),
        decoration: BoxDecoration(
          color: WenshyColors.deepSlate,
          shape: BoxShape.circle,
          border: Border.all(color: WenshyColors.amber, width: 3),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Colors.black38,
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: const Icon(
          Icons.local_shipping_rounded,
          size: 22,
          color: WenshyColors.amber,
        ),
      ),
    );
  }
}
