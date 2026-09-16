import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/features/auth/auth_providers.dart';
import 'package:tindak/features/memory/memory_providers.dart';
import 'package:tindak/features/security/analyzer/url_safety_analyzer.dart';
import 'package:tindak/features/security/data/online_check_disclosure.dart';
import 'package:tindak/features/security/data/reputation_provider.dart';
import 'package:tindak/features/security/security_checker.dart';

/// The on-device checks. Pure Dart, no state, no I/O.
final Provider<UrlSafetyAnalyzer> urlSafetyAnalyzerProvider =
    Provider<UrlSafetyAnalyzer>((ref) => const UrlSafetyAnalyzer());

/// The online half. Null in a build with no cloud configuration, and
/// `main.dart` overrides it with the Edge Function client otherwise — so a
/// build that cannot reach TINDAK's function cannot reach Google either.
final Provider<ReputationProvider?> reputationProviderProvider =
    Provider<ReputationProvider?>((ref) => null);

final Provider<OnlineCheckDisclosure> onlineCheckDisclosureProvider =
    Provider<OnlineCheckDisclosure>(
      (ref) => OnlineCheckDisclosure(ref.watch(databaseProvider)),
    );

/// Runs a check because the user pressed Semak Keselamatan (PD-012).
final Provider<SecurityChecker> securityCheckerProvider =
    Provider<SecurityChecker>(
      (ref) => SecurityChecker(
        analyzer: ref.watch(urlSafetyAnalyzerProvider),
        isSignedIn: () => ref.read(currentAccountProvider) != null,
        hasAcceptedDisclosure: ref.watch(onlineCheckDisclosureProvider).accepted,
        provider: ref.watch(reputationProviderProvider),
      ),
    );
