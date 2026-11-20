import 'package:url_launcher/url_launcher.dart';

/// Abstracts launching `tel:` phone calls so views can be unit/widget tested
/// without hitting platform channels.
abstract class PhoneDialer {
  Future<bool> callPhone(String phoneNumber);
}

/// Production [PhoneDialer] powered by `url_launcher`.
class UrlLauncherPhoneDialer implements PhoneDialer {
  const UrlLauncherPhoneDialer();

  @override
  Future<bool> callPhone(String phoneNumber) async {
    final sanitized = phoneNumber.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (sanitized.isEmpty) return false;

    final uri = Uri(scheme: 'tel', path: sanitized);
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
