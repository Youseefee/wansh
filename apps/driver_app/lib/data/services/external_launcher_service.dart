import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Supported external turn-by-turn navigation providers.
enum ExternalNavProvider {
  googleMaps,
  waze,
}

/// Abstract launcher for phone calls (`tel:`) and turn-by-turn external maps
/// (Google Maps / Waze) so ViewModels and widgets stay deterministic in tests.
abstract class DriverExternalLauncher {
  Future<bool> callPhone(String phone);

  Future<bool> navigateTo({
    required double lat,
    required double lng,
    ExternalNavProvider provider = ExternalNavProvider.googleMaps,
  });
}

/// Production [DriverExternalLauncher] backed by `url_launcher`.
class UrlLauncherDriverExternalLauncher implements DriverExternalLauncher {
  const UrlLauncherDriverExternalLauncher();

  /// Builds the ordered candidate URIs for launching turn-by-turn navigation.
  static List<Uri> buildNavigationUris({
    required double lat,
    required double lng,
    required ExternalNavProvider provider,
    required TargetPlatform platform,
  }) {
    final coords = '$lat,$lng';
    if (provider == ExternalNavProvider.waze) {
      return <Uri>[
        Uri.parse('waze://?ll=$coords&navigate=yes'),
        Uri.parse('https://waze.com/ul?ll=$coords&navigate=yes'),
      ];
    }

    final webFallback = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$coords',
    );
    if (platform == TargetPlatform.android) {
      return <Uri>[
        Uri.parse('google.navigation:q=$coords'),
        webFallback,
      ];
    }
    if (platform == TargetPlatform.iOS) {
      return <Uri>[
        Uri.parse('comgooglemaps://?daddr=$coords&directionsmode=driving'),
        webFallback,
      ];
    }
    return <Uri>[webFallback];
  }

  /// Builds a normalized `tel:` URI from a raw customer phone string.
  static Uri? buildPhoneUri(String rawPhone) {
    final cleaned = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '').trim();
    if (cleaned.isEmpty) return null;
    return Uri(scheme: 'tel', path: cleaned);
  }

  @override
  Future<bool> callPhone(String phone) async {
    final uri = buildPhoneUri(phone);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> navigateTo({
    required double lat,
    required double lng,
    ExternalNavProvider provider = ExternalNavProvider.googleMaps,
  }) async {
    final candidates = buildNavigationUris(
      lat: lat,
      lng: lng,
      provider: provider,
      platform: defaultTargetPlatform,
    );

    for (final uri in candidates) {
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (launched) return true;
      } catch (_) {
        // Try next fallback URI.
      }
    }
    return false;
  }
}
