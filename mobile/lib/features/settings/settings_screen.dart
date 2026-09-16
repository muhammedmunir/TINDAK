import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/app/routes.dart';
import 'package:tindak/features/auth/auth_providers.dart';
import 'package:tindak/features/sync/sync_providers.dart';
import 'package:tindak/features/sync/widgets/sync_dialogs.dart';

/// Minimal Settings: Akaun and Cloud Sync, and nothing else (PD-043).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  static const String title = 'Tetapan';

  static const String accountSection = 'Akaun';
  static const String signInPrompt =
      'Log masuk untuk sync memori ke akaun anda.';
  static const String signIn = 'Log Masuk';
  static const String signOut = 'Log Keluar';
  static const String signedOutMessage = 'Anda telah log keluar.';

  static const String syncSection = 'Cloud Sync';
  static const String unavailable = 'Cloud Sync tidak tersedia dalam versi ini.';
  static const String guestSyncHint =
      'Log masuk untuk menggunakan Cloud Sync. Item anda kekal pada peranti '
      'ini.';
  static const String syncing = 'Sedang sync…';
  static const String upToDate = 'Semua perubahan telah disync.';
  static String pending(int count) => '$count perubahan menunggu sync.';
  static const String offline =
      'Tiada sambungan. Perubahan akan disync kemudian.';
  static const String failed = 'Sync tidak berjaya. Cuba lagi.';
  static const String syncNow = 'Sync Sekarang';
  static String guestItems(int count) =>
      '$count item pada peranti ini belum disync ke akaun.';
  static const String syncGuestItems = 'Sync ke Akaun';

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _signingOut = false;

  Future<void> _signIn() async {
    final signedIn = await Navigator.of(
      context,
    ).pushNamed<bool>(Routes.signIn);
    if (signedIn != true || !mounted) return;
    await offerGuestMigration(context, ref);
  }

  Future<void> _signOut() async {
    final messenger = ScaffoldMessenger.of(context);
    final signedOut = await signOutSafely(
      context,
      ref,
      onBusy: (busy) {
        if (mounted) setState(() => _signingOut = busy);
      },
    );
    if (signedOut) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text(SettingsScreen.signedOutMessage)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final available = ref.watch(authGatewayProvider).isAvailable;
    final account = ref.watch(currentAccountProvider);
    final phase = ref.watch(syncControllerProvider);
    final pendingCount = ref.watch(pendingChangeCountProvider).value ?? 0;
    final guestCount = ref.watch(guestItemCountProvider).value ?? 0;

    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Scaffold(
      appBar: AppBar(title: const Text(SettingsScreen.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: <Widget>[
            _Heading(SettingsScreen.accountSection, theme),
            if (!available)
              Text(SettingsScreen.unavailable, style: muted)
            else if (account == null) ...<Widget>[
              Text(SettingsScreen.signInPrompt, style: muted),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  onPressed: _signIn,
                  child: const Text(SettingsScreen.signIn),
                ),
              ),
            ] else ...<Widget>[
              Text(account.email ?? '', style: theme.textTheme.bodyLarge),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: _signingOut ? null : _signOut,
                  child: _signingOut
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(SettingsScreen.signOut),
                ),
              ),
            ],
            const SizedBox(height: 32),
            _Heading(SettingsScreen.syncSection, theme),
            if (!available)
              Text(SettingsScreen.unavailable, style: muted)
            else if (account == null)
              Text(SettingsScreen.guestSyncHint, style: muted)
            else ...<Widget>[
              Text(_status(phase, pendingCount), style: muted),
              if (pendingCount > 0 && phase != SyncPhase.syncing) ...<Widget>[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () => ref
                        .read(syncControllerProvider.notifier)
                        .requestSync(),
                    child: const Text(SettingsScreen.syncNow),
                  ),
                ),
              ],
              // A migration declined with Bukan Sekarang is resumed here.
              if (guestCount > 0) ...<Widget>[
                const SizedBox(height: 20),
                Text(SettingsScreen.guestItems(guestCount), style: muted),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: phase == SyncPhase.syncing
                        ? null
                        : () => offerGuestMigration(context, ref),
                    child: const Text(SettingsScreen.syncGuestItems),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  static String _status(SyncPhase phase, int pendingCount) => switch (phase) {
    SyncPhase.syncing => SettingsScreen.syncing,
    SyncPhase.offline => SettingsScreen.offline,
    SyncPhase.failed => SettingsScreen.failed,
    SyncPhase.idle || SyncPhase.upToDate =>
      pendingCount == 0
          ? SettingsScreen.upToDate
          : SettingsScreen.pending(pendingCount),
  };
}

class _Heading extends StatelessWidget {
  const _Heading(this.text, this.theme);

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
      ),
    ),
  );
}
