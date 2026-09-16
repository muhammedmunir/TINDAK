import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/core/clock/clock_provider.dart';
import 'package:tindak/core/result/result.dart';
import 'package:tindak/features/actions/executor/action_runner.dart';
import 'package:tindak/features/actions/widgets/entity_row.dart';
import 'package:tindak/features/memory/memory_providers.dart';
import 'package:tindak/features/memory/model/memory_record.dart';
import 'package:tindak/features/sync/sync_providers.dart';
import 'package:tindak/shared/saved_date_label.dart';

/// One saved item (UX section 16).
///
/// The original text, what TINDAK understood with the same actions a fresh
/// share offers, when it was saved, where it lives, and permanent deletion.
/// Reminder arrives at M7 and is not shown.
class MemoryDetailScreen extends ConsumerWidget {
  const MemoryDetailScreen({required this.id, super.key});

  final String id;

  static const String goneMessage = 'Item ini tidak lagi wujud.';

  /// PD-020: status in human terms, never database terms.
  static const String onDeviceStatus = 'Pada peranti ini';
  static const String pendingSyncStatus = 'Menunggu sync ke akaun';
  static const String syncedStatus = 'Disimpan dalam akaun';

  static String statusFor(MemoryStorage storage) => switch (storage) {
    MemoryStorage.deviceOnly => onDeviceStatus,
    MemoryStorage.pendingSync => pendingSyncStatus,
    MemoryStorage.synced => syncedStatus,
  };

  static const String deleteLabel = 'Padam';
  static const String confirmTitle = 'Padam item ini?';
  static const String confirmBody = 'Tindakan ini tidak boleh dibatalkan.';
  static const String cancelLabel = 'Batal';
  static const String deletedMessage = 'Item dipadam.';
  static const String deleteFailedMessage =
      'Item tidak dapat dipadam. Cuba lagi.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(memoryDetailProvider(id));

    return Scaffold(
      appBar: AppBar(title: const Text('TINDAK')),
      body: detail.when(
        loading: () => const SizedBox(),
        error: (_, _) => const _Message(goneMessage),
        data: (result) => switch (result) {
          Ok<MemoryRecord>(:final value) => _Detail(record: value),
          Err<MemoryRecord>() => const _Message(goneMessage),
        },
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.record});

  final MemoryRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final resolver = ref.watch(actionResolverProvider);
    final today = ref.watch(clockProvider).today();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SelectableText(record.content, style: theme.textTheme.bodyLarge),
            if (record.entities.isNotEmpty) ...<Widget>[
              const SizedBox(height: 28),
              _Label('Dikesan', theme),
              const SizedBox(height: 8),
              for (final entity in record.entities)
                EntityRow(
                  entity: entity,
                  actions: resolver.resolve(entity),
                  onAction: (action) =>
                      runActionWithFeedback(context, ref, action),
                ),
            ],
            const SizedBox(height: 28),
            _Label('Disimpan', theme),
            const SizedBox(height: 4),
            Text(
              savedDateLabel(record.createdAt, today: today),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 2),
            Text(
              MemoryDetailScreen.statusFor(record.storage),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () => _confirmAndDelete(context, ref),
              icon: const Icon(Icons.delete_outline),
              label: const Text(MemoryDetailScreen.deleteLabel),
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// UX section 17: confirm, then delete for good. No Trash, no Restore.
  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text(MemoryDetailScreen.confirmTitle),
        content: const Text(MemoryDetailScreen.confirmBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(MemoryDetailScreen.cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(MemoryDetailScreen.deleteLabel),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await ref.read(memoryRepositoryProvider).delete(record.id);

    messenger.hideCurrentSnackBar();
    if (result.isOk) {
      // An account item's deletion reaches the cloud through sync (PD-021).
      unawaited(ref.read(syncControllerProvider.notifier).requestSync());
      messenger.showSnackBar(
        const SnackBar(content: Text(MemoryDetailScreen.deletedMessage)),
      );
      if (navigator.canPop()) navigator.pop();
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text(MemoryDetailScreen.deleteFailedMessage)),
      );
    }
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, this.theme);

  final String text;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: theme.textTheme.labelLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    ),
  );
}

class _Message extends StatelessWidget {
  const _Message(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}
