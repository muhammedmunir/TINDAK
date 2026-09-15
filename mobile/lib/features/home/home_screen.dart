import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/app/routes.dart';
import 'package:tindak/core/clock/clock_provider.dart';
import 'package:tindak/features/actions/widgets/entity_row.dart';
import 'package:tindak/features/auth/auth_providers.dart';
import 'package:tindak/features/intake/intake_controller.dart';
import 'package:tindak/features/memory/memory_providers.dart';
import 'package:tindak/features/memory/model/memory_record.dart';
import 'package:tindak/features/sync/sync_providers.dart';
import 'package:tindak/shared/saved_date_label.dart';

/// Home: the empty state until something is saved, then Memory.
///
/// Not a dashboard (PRD section 19, UX section 28). One list, one search field,
/// and the way in — Share from another app, or Tampal here.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Shown when the clipboard holds nothing TINDAK can use.
  static const String nothingToPasteMessage = 'Tiada teks untuk ditampal.';

  static const String searchHint = 'Cari memori';
  static const String noMatchesMessage = 'Tiada memori sepadan.';
  static const String unreadableMessage = 'Memori tidak dapat dibaca.';

  static const String settingsTooltip = 'Tetapan';

  /// PD-019: guest data can be lost on uninstall. Said plainly, in Memory,
  /// without blocking anything. Shown while any listed item exists only on
  /// this device; account items are not at that risk.
  static const String deviceOnlyNotice =
      'Disimpan pada peranti ini sahaja. Item mungkin hilang jika TINDAK '
      'dinyahpasang.';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(memoryQueryProvider);
    final memories = ref.watch(memoryListProvider);

    return memories.when(
      // Keeps the current list on screen while a new search runs, so the
      // search field is never torn down mid-typing.
      skipLoadingOnReload: true,
      loading: () => const _Scaffold(showPasteAction: false, body: SizedBox()),
      error: (_, _) => const _Scaffold(
        showPasteAction: true,
        body: _CentredMessage(unreadableMessage),
      ),
      data: (records) => records.isEmpty && query.isEmpty
          ? const _Scaffold(showPasteAction: false, body: _EmptyState())
          : _Scaffold(
              showPasteAction: true,
              body: _MemoryList(records: records),
            ),
    );
  }
}

/// The only path in TINDAK that reads the clipboard, and it runs only from the
/// Tampal control (PD-033, ADR-004).
Future<void> _paste(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final outcome = await ref.read(intakeControllerProvider.notifier).paste();
  if (outcome == PasteOutcome.accepted) return;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(content: Text(HomeScreen.nothingToPasteMessage)),
    );
}

class _Scaffold extends ConsumerWidget {
  const _Scaffold({required this.body, required this.showPasteAction});

  final Widget body;
  final bool showPasteAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TINDAK'),
        actions: <Widget>[
          if (showPasteAction)
            IconButton(
              onPressed: () => _paste(context, ref),
              icon: const Icon(Icons.content_paste_outlined),
              tooltip: 'Tampal',
            ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed(Routes.settings),
            icon: const Icon(Icons.settings_outlined),
            tooltip: HomeScreen.settingsTooltip,
          ),
        ],
      ),
      body: body,
    );
  }
}

class _EmptyState extends ConsumerWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              Icons.share_outlined,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Jumpa maklumat penting?',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Covers both explicit intake paths (PD-033) and makes no claim
            // about sharing from WhatsApp, which users cannot do.
            Text(
              'Share ke TINDAK, atau salin teks\ndan tampal di sini.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _paste(context, ref),
              icon: const Icon(Icons.content_paste_outlined),
              label: const Text('Tampal'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryList extends ConsumerStatefulWidget {
  const _MemoryList({required this.records});

  final List<MemoryRecord> records;

  @override
  ConsumerState<_MemoryList> createState() => _MemoryListState();
}

class _MemoryListState extends ConsumerState<_MemoryList> {
  late final TextEditingController _search = TextEditingController(
    text: ref.read(memoryQueryProvider),
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = ref.watch(clockProvider).today();
    final records = widget.records;
    final signedIn = ref.watch(
      currentAccountProvider.select((a) => a != null),
    );
    final anyDeviceOnly = records.any(
      (r) => r.storage == MemoryStorage.deviceOnly,
    );

    final list = records.isEmpty
        ? const _CentredMessage(HomeScreen.noMatchesMessage)
        : ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: records.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _MemoryTile(record: records[index], today: today),
          );

    // SafeArea at the bottom only: the device-only notice was drawn under the
    // gesture navigation bar on a real device.
    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: ref.read(memoryQueryProvider.notifier).update,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: HomeScreen.searchHint,
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Kosongkan',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          ref.read(memoryQueryProvider.notifier).update('');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            // Manual pull is a sync trigger, offered only when there is an
            // account to sync (docs/10_ARCHITECTURE.md section 8.1).
            child: signedIn
                ? RefreshIndicator(
                    onRefresh: () =>
                        ref.read(syncControllerProvider.notifier).requestSync(),
                    child: list,
                  )
                : list,
          ),
          if (anyDeviceOnly)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                HomeScreen.deviceOnlyNotice,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MemoryTile extends StatelessWidget {
  const _MemoryTile({required this.record, required this.today});

  final MemoryRecord record;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final entities = record.entities
        .take(2)
        .map(EntityRow.displayValue)
        .join(' • ');
    final saved = savedDateLabel(record.createdAt, today: today);

    return ListTile(
      key: ValueKey<String>('memory-${record.id}'),
      title: Text(
        record.content.trim(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        entities.isEmpty ? saved : '$entities\n$saved',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: entities.isNotEmpty,
      onTap: () => Navigator.of(
        context,
      ).pushNamed(Routes.memoryDetail, arguments: record.id),
    );
  }
}

class _CentredMessage extends StatelessWidget {
  const _CentredMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
