import 'package:url_launcher/url_launcher.dart';
import '../utils/helpers.dart';

// One value per main screen. Templates map to /cards/ since that page covers them.
enum HelpContext { cards, sets, study, templates, importExport, account }

// Opens the help site at the page corresponding to the current screen context.
class HelpService {
  static const _base = 'https://flash-me-7a1a2.web.app';

  static const _paths = {
    HelpContext.cards: '/cards/',
    HelpContext.sets: '/sets/',
    HelpContext.study: '/study/',
    HelpContext.templates: '/cards/',
    HelpContext.importExport: '/import-export/',
    HelpContext.account: '/account/',
  };

  static Future<void> launch(HelpContext ctx) async {
    final uri = Uri.parse('$_base${_paths[ctx] ?? '/'}');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      AppLogger.error('HelpService: could not launch $uri');
    }
  }
}
