import 'package:url_launcher/url_launcher.dart';

/// Opens external feedback mail and privacy links via `url_launcher` (M8 §5).
abstract interface class ExternalLinkService {
  Future<bool> openFeedbackEmail(String email);

  Future<bool> openPrivacyPolicy(String url);
}

class UrlLauncherExternalLinkService implements ExternalLinkService {
  const UrlLauncherExternalLinkService();

  @override
  Future<bool> openFeedbackEmail(String email) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=KickVolt%20feedback',
    );
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> openPrivacyPolicy(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
