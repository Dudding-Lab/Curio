import 'package:flutter/material.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:curio/core/language_menu.dart';
import 'package:curio/features/offline/offline_access_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.enterCredentials)),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final AuthResponse response;
      if (_isSignUp) {
        response = await Supabase.instance.client.auth.signUp(
          email: email,
          password: password,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.signUpSuccess)),
          );
          setState(() => _isSignUp = false);
        }
      } else {
        response = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
      }
      final session = response.session;
      // Only an authenticated online session may enroll the device.
      // Secure storage errors must not undo a successful server sign-in.
      if (session != null && !session.isExpired) {
        try {
          await OfflineAccessController(
            knownDevices: SecureKnownDeviceStore(),
            deviceUnlock: PlatformDeviceUnlock(),
          ).recordOnlineLogin(session.user.id);
        } catch (_) {
          // Offline unlock remains unavailable until a later online login.
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text('${l10n.appTitle} – ${_isSignUp ? l10n.signUp : l10n.signIn}'),
        actions: const [KovunelaLanguageMenu()],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: l10n.email),
              keyboardType: TextInputType.emailAddress,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: l10n.password),
              obscureText: true,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isSignUp ? l10n.signUp : l10n.signIn),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isLoading
                  ? null
                  : () => setState(() => _isSignUp = !_isSignUp),
              child: Text(
                _isSignUp
                    ? l10n.alreadyRegistered
                    : l10n.needAccount,
              ),
            ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
