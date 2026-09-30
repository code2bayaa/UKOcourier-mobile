/// Where this build of the app points, and the numbers it has to agree with the server about.
///
/// The API base is a `--dart-define`, not a constant, because the same source has to run against three
/// very different things: an emulator (which reaches the host as 10.0.2.2), a real handset on the same
/// wi-fi (which needs the laptop's LAN address — `localhost` on a phone is the phone), and production.
///
///   flutter run --dart-define=UKO_API=http://192.168.1.20:8016
///   flutter build apk --release --dart-define=UKO_API=https://courier.uko-app.co.ke
library;

abstract final class Config {
  /// Origin only — no trailing slash and no `/api`; [ApiClient] adds that.
  static const apiBase = String.fromEnvironment(
    'UKO_API',
    // The Android emulator's alias for the machine running it. A physical phone needs the LAN address
    // passed in; `localhost` there would be the handset itself.
    defaultValue: 'http://10.0.2.2:8016',
  );

  /// The courier console, for the "change it on the web" hand-offs.
  static const courierWebUrl = String.fromEnvironment(
    'UKO_COURIER_WEB',
    defaultValue: 'http://10.0.2.2:3016',
  );

  /// The console's address as a driver should read it — empty when this build points at a developer's
  /// machine. Opening a dev URL on a dev build is right; *printing* one is not, and a build that never
  /// had `UKO_COURIER_WEB` passed would otherwise tell a driver to apply at 10.0.2.2.
  static String get courierWebLabel {
    final dev = RegExp(
        r'^https?://(10\.0\.2\.2|localhost|127\.|0\.0\.0\.0|192\.168\.|10\.|172\.(1[6-9]|2\d|3[01])\.)');
    if (dev.hasMatch(courierWebUrl)) return '';
    return courierWebUrl.replaceFirst(RegExp(r'^https?://'), '').replaceFirst(RegExp(r'/$'), '');
  }

  /// Where the session is kept. Distinct from the delivery app's key so both can be installed on one
  /// phone — which happens: a partner staff have cleared for both rides and drives.
  static const sessionKey = 'uko_courier_session';

  /// What the server's watchdog does while a load is on the van (courier `config.py`). Longer than the
  /// rider's 10/30 because a van on the Nairobi–Mombasa road loses signal for real stretches, and a
  /// driver who is simply out of coverage should not be treated as a driver who has vanished.
  static const trackWarnMinutes = 20;
  static const trackMissingMinutes = 60;

  /// UKO's cut of every leg (`COURIER_COMMISSION_PCT`). Only ever used to explain a figure the API has
  /// already calculated — `driver_earns` is what actually lands in his wallet.
  static const courierCommissionPct = 10;
}
