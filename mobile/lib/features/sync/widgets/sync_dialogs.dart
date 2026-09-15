import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/features/sync/sync_providers.dart';

/// Copy approved as PD-044 and PD-041. Changed only by Product Direction.
final class SyncCopy {
  const SyncCopy._();

  static const String migrateTitle = 'Sync memori ke akaun?';
  static String migrateBody(int count) =>
      'Anda mempunyai $count item yang disimpan pada peranti ini. Sync ke akaun '
      'supaya item ini boleh tersedia apabila anda menggunakan TINDAK dengan '
      'akaun anda.';
  static const String notNow = 'Bukan Sekarang';
  static const String sync = 'Sync';

  static const String signOutBlockedTitle = 'Belum dapat log keluar';
  static const String signOutBlockedBody =
      'Ada perubahan yang belum disimpan ke cloud. Sambungkan internet dan cuba '
      'lagi supaya data anda tidak hilang.';
  static const String retry = 'Cuba Lagi';
  static const String cancel = 'Batal';
}

/// Offers to move this device's guest items into the signed-in account
/// (PD-044). Shows nothing when there are none.
///
/// **Bukan Sekarang** closes the dialog and does nothing else — no ownership
/// change, no upload, nothing scheduled. Only **Sync** migrates.
Future<void> offerGuestMigration(BuildContext context, WidgetRef ref) async {
  final count = await ref.read(syncStoreProvider).guestCount();
  if (count == 0 || !context.mounted) return;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(SyncCopy.migrateTitle),
      content: Text(SyncCopy.migrateBody(count)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(SyncCopy.notNow),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(SyncCopy.sync),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  await ref.read(syncControllerProvider.notifier).migrateGuestItems();
}

/// Fail-safe sign-out (PD-041). Keeps offering Cuba Lagi while changes cannot
/// reach the cloud. There is no way to sign out anyway.
///
/// Returns true once signed out.
Future<bool> signOutSafely(
  BuildContext context,
  WidgetRef ref, {
  required void Function(bool busy) onBusy,
}) async {
  final controller = ref.read(syncControllerProvider.notifier);
  while (true) {
    onBusy(true);
    final signedOut = await controller.signOut();
    onBusy(false);
    if (signedOut) return true;
    if (!context.mounted) return false;

    final retry = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(SyncCopy.signOutBlockedTitle),
        content: const Text(SyncCopy.signOutBlockedBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(SyncCopy.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(SyncCopy.retry),
          ),
        ],
      ),
    );
    if (retry != true) return false;
  }
}
