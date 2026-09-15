import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/features/auth/auth_providers.dart';
import 'package:tindak/features/auth/data/auth_gateway.dart';

/// Email, then a six-digit code (ADR-020). Pops `true` once signed in.
///
/// Nothing about Memory happens here. Guest items are offered for migration
/// only after this screen closes, and only with explicit confirmation
/// (PD-044).
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  static const String title = 'Log Masuk';
  static const String emailIntro =
      'Masukkan emel anda. Kami akan menghantar kod 6 digit.';
  static const String emailLabel = 'Emel';
  static const String sendCode = 'Hantar Kod';
  static String codeIntro(String email) =>
      'Masukkan kod 6 digit yang dihantar ke $email.';
  static const String codeLabel = 'Kod';
  static const String verify = 'Sahkan';
  static const String resend = 'Hantar Semula Kod';
  static const String changeEmail = 'Tukar Emel';
  static const String codeResent = 'Kod baharu telah dihantar.';

  static const String invalidEmailMessage = 'Emel tidak sah.';
  static const String invalidCodeMessage =
      'Kod tidak sah atau telah tamat tempoh. Minta kod baharu.';
  static const String rateLimitedMessage =
      'Terlalu banyak cubaan. Tunggu sebentar dan cuba lagi.';
  static const String offlineMessage = 'Tiada sambungan internet. Cuba lagi.';
  static const String failedMessage = 'Tidak dapat log masuk. Cuba lagi.';

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _codePattern = RegExp(r'^\d{6}$');

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _code = TextEditingController();

  bool _awaitingCode = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _sendCode({bool resend = false}) async {
    final email = _email.text.trim();
    if (!SignInScreen._emailPattern.hasMatch(email)) {
      setState(() => _error = SignInScreen.invalidEmailMessage);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final outcome = await ref.read(authGatewayProvider).sendCode(email);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (outcome == AuthOutcome.success) {
        _awaitingCode = true;
        _code.clear();
      } else {
        _error = _messageFor(outcome);
      }
    });
    if (outcome == AuthOutcome.success && resend) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(SignInScreen.codeResent)));
    }
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (!SignInScreen._codePattern.hasMatch(code)) {
      setState(() => _error = SignInScreen.invalidCodeMessage);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final outcome = await ref
        .read(authGatewayProvider)
        .verifyCode(_email.text.trim(), code);
    if (!mounted) return;
    if (outcome == AuthOutcome.success) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _busy = false;
      _error = _messageFor(outcome);
    });
  }

  static String _messageFor(AuthOutcome outcome) => switch (outcome) {
    AuthOutcome.invalidEmail => SignInScreen.invalidEmailMessage,
    AuthOutcome.invalidCode => SignInScreen.invalidCodeMessage,
    AuthOutcome.rateLimited => SignInScreen.rateLimitedMessage,
    AuthOutcome.offline => SignInScreen.offlineMessage,
    AuthOutcome.failed || AuthOutcome.success => SignInScreen.failedMessage,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text(SignInScreen.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: <Widget>[
            if (!_awaitingCode) ...<Widget>[
              Text(SignInScreen.emailIntro, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 20),
              TextField(
                key: const ValueKey<String>('sign-in-email'),
                controller: _email,
                enabled: !_busy,
                autofocus: true,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const <String>[AutofillHints.email],
                autocorrect: false,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendCode(),
                decoration: const InputDecoration(
                  labelText: SignInScreen.emailLabel,
                  border: OutlineInputBorder(),
                ),
              ),
            ] else ...<Widget>[
              Text(
                SignInScreen.codeIntro(_email.text.trim()),
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              TextField(
                key: const ValueKey<String>('sign-in-code'),
                controller: _code,
                enabled: !_busy,
                autofocus: true,
                keyboardType: TextInputType.number,
                autofillHints: const <String>[AutofillHints.oneTimeCode],
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _verify(),
                decoration: const InputDecoration(
                  labelText: SignInScreen.codeLabel,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy
                  ? null
                  : (_awaitingCode ? _verify : () => _sendCode()),
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      _awaitingCode
                          ? SignInScreen.verify
                          : SignInScreen.sendCode,
                    ),
            ),
            if (_awaitingCode) ...<Widget>[
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () => _sendCode(resend: true),
                child: const Text(SignInScreen.resend),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _awaitingCode = false;
                        _error = null;
                      }),
                child: const Text(SignInScreen.changeEmail),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
