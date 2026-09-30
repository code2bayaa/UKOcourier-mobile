/// Driver sign-in: company e-mail and password, then the six-digit code e-mailed to that address.
///
/// The screen mirrors the web console's `/login` deliberately, including the part that is easy to
/// mistake for a formality. **Accepting location tracking is a condition of signing in**, not a setting
/// to find later: UKO shares a van's position with both shelves and with whoever is waiting for the
/// load, and raises an alarm if it goes quiet on the road. The web asks for the browser's permission
/// when the code is submitted; here the OS permission is requested at the same moment, which is the
/// right one — asking at launch, before he knows why, is how permissions get denied forever.
library;

import 'package:flutter/material.dart';
import 'package:uko_core/uko_core.dart';

import '../config.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  CodeRequest? _sent;
  String _code = '';
  bool _consent = false;
  bool _showPassword = false;
  String _error = '';
  DateTime? _codeSentAt;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canRequest =>
      _email.text.trim().isNotEmpty && _password.text.isNotEmpty && _consent;

  Duration get _resendIn {
    final sent = _codeSentAt;
    final wait = _sent?.resendIn ?? 60;
    if (sent == null) return Duration.zero;
    final left = sent.add(Duration(seconds: wait)).difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> _requestCode() async {
    setState(() => _error = '');
    try {
      final sent = await widget.auth.requestCode(
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      setState(() {
        _sent = sent;
        _codeSentAt = DateTime.now();
        _code = '';
      });
    } on ApiException catch (e) {
      // The API's sentences are written for the driver — "Set your password first", "Wrong email or
      // password", and the 429 that says how long to wait. Shown as they are.
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _signIn() async {
    setState(() => _error = '');
    try {
      // Ask for location now, with the reason on screen above — not at launch, when it means nothing.
      await LocationConsent.request();
      await widget.auth.signIn(
        email: _email.text,
        password: _password.text,
        code: _code,
      );
      // The gate above this screen swaps it out once the session lands; nothing to do here.
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _sendPasswordLink() async {
    setState(() => _error = '');
    try {
      final to = await widget.auth.sendPasswordLink(_email.text);
      if (!mounted) return;
      showUkoMessage(context,
          'If $to has a UKO courier account, a link to set your password is on its way. It lasts an hour.');
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onCodeStep = _sent != null;
    return Scaffold(
      backgroundColor: UkoColors.surface,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
          children: [
            const _Brand(),
            const SizedBox(height: 26),
            UkoPanel(
              title: onCodeStep ? 'Enter your code' : 'Sign in',
              subtitle: onCodeStep
                  ? 'We sent a 6-digit code to ${_sent!.sentTo}. It lasts 10 minutes.'
                  : 'Use the company e-mail UKO gave you when your application was approved.',
              child: onCodeStep ? _codeStep() : _passwordStep(),
            ),
            if (_error.isNotEmpty) ...[
              const SizedBox(height: 14),
              UkoNotice(_error, tone: UkoTone.danger),
            ],
            const SizedBox(height: 18),
            Text(
              Config.courierWebLabel.isEmpty
                  ? 'Not a UKO driver yet? Apply on the UKO courier site — no account needed to apply.'
                  : 'Not a UKO driver yet? Apply at ${Config.courierWebLabel} '
                      '— no account needed to apply.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: UkoColors.muted, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Company e-mail',
              hintText: 'name.surname@uko.co.ke',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: !_showPassword,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, size: 20),
                onPressed: () => setState(() => _showPassword = !_showPassword),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          _consentTile(),
          const SizedBox(height: 16),
          AsyncButton(
            label: 'Send me a code',
            icon: Icons.mail_outline,
            onPressed: _canRequest ? _requestCode : null,
            enabled: _canRequest,
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _email.text.trim().isEmpty ? null : _sendPasswordLink,
            child: const Text(
              'First time here, or forgotten your password? E-mail me a link',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      );

  Widget _codeStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_sent!.simulated) ...[
            UkoNotice(
              'This server has no mail set up, so it handed the code straight back: ${_sent!.code}',
              tone: UkoTone.warning,
              title: 'Test server',
            ),
            const SizedBox(height: 14),
          ],
          Center(
            child: CodeInput(
              length: 6,
              autofocus: true,
              onChanged: (v) => setState(() => _code = v),
              onCompleted: (_) => _signIn(),
            ),
          ),
          const SizedBox(height: 18),
          AsyncButton(
            label: 'Sign in',
            onPressed: _code.length == 6 ? _signIn : null,
            enabled: _code.length == 6,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => setState(() {
                    _sent = null;
                    _code = '';
                    _error = '';
                  }),
                  child: const Text('Change e-mail', style: TextStyle(fontSize: 12.5)),
                ),
              ),
              Expanded(
                child: TextButton(
                  onPressed: _resendIn == Duration.zero ? _requestCode : null,
                  child: Text(
                    _resendIn == Duration.zero
                        ? 'Send another'
                        : 'Send another in ${countdown(_resendIn)}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      );

  Widget _consentTile() => InkWell(
        onTap: () => setState(() => _consent = !_consent),
        borderRadius: BorderRadius.circular(UkoRadius.md),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _consent ? UkoColors.primary050 : UkoColors.surface,
            borderRadius: BorderRadius.circular(UkoRadius.md),
            border: Border.all(
              color: _consent ? UkoColors.primary300 : UkoColors.border,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _consent,
                onChanged: (v) => setState(() => _consent = v ?? false),
                visualDensity: VisualDensity.compact,
              ),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: 10, left: 2),
                  child: Text(
                    'I accept location tracking while I have a load.\n'
                    'UKO shares where the van is with both shelves and with whoever is waiting for the '
                    'load, from the moment you accept until the far shelf signs for it — never before, '
                    'never after — and raises an alarm if your phone goes quiet on the road.',
                    style: TextStyle(fontSize: 12, color: UkoColors.ink, height: 1.45),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Container(
            height: 54,
            width: 54,
            decoration: BoxDecoration(
              color: UkoColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.local_shipping, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 12),
          const Text(
            'UKO courier',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: UkoColors.ink),
          ),
          const SizedBox(height: 4),
          const Text(
            'County to county, shelf to shelf',
            style: TextStyle(fontSize: 12.5, color: UkoColors.ink2),
          ),
        ],
      );
}
