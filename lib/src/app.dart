/// The app itself: one API client, one auth controller, one tracker, and a gate that decides whether
/// the driver is looking at sign-in or at the board.
///
/// These three live here rather than in a service locator because there is exactly one of each for the
/// life of the process, and passing them down explicitly makes it obvious which screens can call the
/// API and which can move the tracker — which, for something that turns a phone's GPS on, is worth
/// being obvious.
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import 'api.dart';
import 'config.dart';
import 'screens/shell.dart';
import 'screens/sign_in.dart';

class UkoCourierApp extends StatefulWidget {
  const UkoCourierApp({super.key});

  @override
  State<UkoCourierApp> createState() => _UkoCourierAppState();
}

class _UkoCourierAppState extends State<UkoCourierApp> {
  late final AuthController _auth;
  late final ApiClient _client;
  late final CourierApi _api;
  late final LocationTracker _tracker;

  @override
  void initState() {
    super.initState();
    final store = SessionStore(key: Config.sessionKey);
    // The client reads the token from the controller on every call rather than being handed one, so a
    // sign-out or a refresh takes effect on the next request with nothing to rewire.
    _client = ApiClient(
      baseUrl: Config.apiBase,
      readToken: () async => _auth.session?.token,
      onSessionExpired: _onSessionExpired,
    );
    _auth = AuthController(api: _client, store: store);
    _api = CourierApi(_client);
    _tracker = LocationTracker(api: _client, riderFacingName: 'UKO courier');
    _auth.restore();
  }

  /// A 401 from anywhere. The two-hour session has ended, so stop the GPS — there is nothing to report
  /// to any more — and drop the token, which sends the gate back to sign-in.
  void _onSessionExpired() {
    _tracker.stop();
    _auth.forget();
  }

  @override
  void dispose() {
    _tracker.dispose();
    _client.close();
    _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'UKO courier',
        theme: ukoTheme(),
        debugShowCheckedModeBanner: false,
        home: AnimatedBuilder(
          animation: _auth,
          builder: (context, _) {
            if (_auth.restoring) return const _Splash();
            if (!_auth.signedIn) return SignInScreen(auth: _auth);
            return DriverShell(auth: _auth, api: _api, tracker: _tracker);
          },
        ),
      );
}

/// Held for the moment it takes to read the keystore — so a driver who is already signed in never sees
/// the sign-in screen flash past.
class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: UkoColors.primary,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.local_shipping, color: Colors.white, size: 44),
              SizedBox(height: 18),
              SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white70),
              ),
            ],
          ),
        ),
      );
}
