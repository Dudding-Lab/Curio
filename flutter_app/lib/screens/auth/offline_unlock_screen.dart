import 'package:curio/features/offline/offline_access_controller.dart';
import 'package:curio/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Offline device unlock is intentionally distinct from Supabase login.
/// No unencrypted cached collection data is exposed in this foundation.
class OfflineUnlockScreen extends StatefulWidget {
  const OfflineUnlockScreen({super.key, this.controller});

  final OfflineAccessController? controller;

  @override
  State<OfflineUnlockScreen> createState() => _OfflineUnlockScreenState();
}

class _OfflineUnlockScreenState extends State<OfflineUnlockScreen> {
  bool _busy = false;
  bool _unlocked = false;
  String? _error;

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = Supabase.instance.client.auth.currentSession;
      final decision = await (widget.controller ??
              OfflineAccessController(
                knownDevices: SecureKnownDeviceStore(),
                deviceUnlock: PlatformDeviceUnlock(),
              ))
          .unlockOffline(
        restoredSessionUserId: session?.user.id,
        sessionExpired: session?.isExpired ?? false,
      );
      if (!mounted) return;
      setState(() {
        _unlocked = decision != null;
        _error = decision == null
            ? AppLocalizations.of(context)!.offlineUnlockUnavailable
            : null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _unlocked = false;
        _error = AppLocalizations.of(context)!.offlineUnlockUnavailable;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.offlineModeTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(24),
            shrinkWrap: true,
            children: [
              const Icon(Icons.wifi_off, size: 52),
              const SizedBox(height: 16),
              Text(
                l10n.offlineModeExplanation,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (!_unlocked)
                FilledButton.icon(
                  key: const ValueKey('unlock-offline'),
                  onPressed: _busy ? null : _unlock,
                  icon: const Icon(Icons.lock_open_outlined),
                  label: Text(l10n.offlineUnlockAction),
                ),
              if (_busy)
                const Center(child: CircularProgressIndicator()),
              if (_error != null)
                Text(
                  _error!,
                  key: const ValueKey('offline-unlock-error'),
                  textAlign: TextAlign.center,
                ),
              if (_unlocked) ...[
                const Icon(Icons.check_circle_outline, size: 42),
                const SizedBox(height: 12),
                Text(
                  l10n.offlineUnlockedNotice,
                  key: const ValueKey('offline-unlocked'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(l10n.offlineStoragePending,
                    textAlign: TextAlign.center),
              ],
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text(l10n.offlineSignInOnline),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
