import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/features/auth/data/auth_gateway.dart';

/// Sign-in. Without cloud configuration this is [UnavailableAuthGateway], and
/// TINDAK runs as a guest-only app. `main.dart` overrides it with Supabase when
/// the build carries a project URL and key.
final Provider<AuthGateway> authGatewayProvider = Provider<AuthGateway>(
  (ref) => const UnavailableAuthGateway(),
);

/// The signed-in account, or null for a guest. Synchronous, so the first frame
/// already knows who is signed in.
final NotifierProvider<CurrentAccount, Account?> currentAccountProvider =
    NotifierProvider<CurrentAccount, Account?>(CurrentAccount.new);

class CurrentAccount extends Notifier<Account?> {
  @override
  Account? build() {
    final gateway = ref.watch(authGatewayProvider);
    final subscription = gateway.accountChanges.listen((account) {
      if (account != state) state = account;
    });
    ref.onDispose(subscription.cancel);
    return gateway.currentAccount;
  }
}
