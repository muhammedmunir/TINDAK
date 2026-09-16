import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/core/clock/clock_provider.dart';
import 'package:tindak/features/auth/auth_providers.dart';
import 'package:tindak/features/memory/memory_providers.dart';
import 'package:tindak/features/sync/data/cloud_memory_api.dart';
import 'package:tindak/features/sync/data/sync_store.dart';
import 'package:tindak/features/sync/sync_engine.dart';

/// The cloud. Null in a build without cloud configuration; `main.dart`
/// overrides it with Supabase otherwise.
final Provider<CloudMemoryApi?> cloudMemoryApiProvider =
    Provider<CloudMemoryApi?>((ref) => null);

final Provider<SyncStore> syncStoreProvider = Provider<SyncStore>(
  (ref) => SyncStore(ref.watch(databaseProvider)),
);

final Provider<SyncEngine?> syncEngineProvider = Provider<SyncEngine?>((ref) {
  final api = ref.watch(cloudMemoryApiProvider);
  if (api == null) return null;
  return SyncEngine(
    store: ref.watch(syncStoreProvider),
    api: api,
    clock: ref.watch(clockProvider),
  );
});

/// Guest items on this device, for the migration prompt and Settings.
final StreamProvider<int> guestItemCountProvider = StreamProvider<int>(
  (ref) => ref.watch(syncStoreProvider).watchGuestCount(),
);

/// The signed-in account's changes not yet in the cloud. Zero for a guest.
final StreamProvider<int> pendingChangeCountProvider = StreamProvider<int>((
  ref,
) {
  final id = ref.watch(currentAccountProvider.select((a) => a?.id));
  if (id == null) return Stream<int>.value(0);
  return ref.watch(syncStoreProvider).watchPendingCount(id);
});

/// What Settings says about sync.
enum SyncPhase { idle, syncing, upToDate, offline, failed }

final NotifierProvider<SyncController, SyncPhase> syncControllerProvider =
    NotifierProvider<SyncController, SyncPhase>(SyncController.new);

/// Starts sync at the moments the architecture names, and nowhere else:
/// after sign-in, after Save or Delete while signed in, on resume, and when the
/// user asks (docs/10_ARCHITECTURE.md section 8.1).
class SyncController extends Notifier<SyncPhase> {
  @override
  SyncPhase build() {
    // Sign-in, including a session restored at launch.
    ref.listen<String?>(
      currentAccountProvider.select((a) => a?.id),
      (previous, next) {
        // Deferred: this can fire while the provider is still building.
        if (next != null && next != previous) {
          Future<void>.microtask(requestSync);
        }
        if (next == null && previous != null) state = SyncPhase.idle;
      },
      fireImmediately: true,
    );
    return SyncPhase.idle;
  }

  /// Syncs the signed-in account. Does nothing for a guest or in a build
  /// without cloud configuration. Never throws.
  Future<SyncResult?> requestSync() async {
    final account = ref.read(currentAccountProvider);
    final engine = ref.read(syncEngineProvider);
    if (account == null || engine == null) return null;

    state = SyncPhase.syncing;
    final result = await engine.sync(account.id);
    if (!ref.mounted) return result;
    if (ref.read(currentAccountProvider)?.id != account.id) return result;
    state = switch (result) {
      SyncResult.upToDate => SyncPhase.upToDate,
      SyncResult.offline => SyncPhase.offline,
      SyncResult.sessionEnded || SyncResult.failed => SyncPhase.failed,
    };
    return result;
  }

  /// Explicit guest migration: the Sync button on the prompt or in Settings,
  /// and only that (PD-044, PD-045).
  Future<void> migrateGuestItems() async {
    final account = ref.read(currentAccountProvider);
    if (account == null) return;
    await ref.read(syncStoreProvider).migrateGuestRows(account.id);
    await requestSync();
  }

  /// Fail-safe sign-out (PD-041, ADR-031). Returns false, with the user still
  /// signed in and nothing deleted, when changes could not reach the cloud.
  Future<bool> signOut() async {
    final account = ref.read(currentAccountProvider);
    if (account == null) return true;
    final store = ref.read(syncStoreProvider);
    final gateway = ref.read(authGatewayProvider);

    if (!await store.purgeAccountIfSafe(account.id)) {
      await requestSync();
      if (!await store.purgeAccountIfSafe(account.id)) return false;
    }
    // Local rows are gone before the session ends: if ending it failed, there
    // is nothing left to leak (ADR-031).
    await gateway.endSession();
    return true;
  }
}
