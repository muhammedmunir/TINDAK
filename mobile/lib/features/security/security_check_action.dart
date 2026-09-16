import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tindak/features/security/security_providers.dart';
import 'package:tindak/features/security/security_result_screen.dart';
import 'package:tindak/features/understanding/model/detected_entity.dart';

/// Runs a security check because the user pressed Semak Keselamatan, and shows
/// what it found (PD-012).
///
/// **Only from that button.** Not on detection, not on save, not on open, and
/// never in the background (M8 scope lock).
Future<void> runSecurityCheck(
  BuildContext context,
  WidgetRef ref,
  DetectedEntity url,
) async {
  final assessment = ref.read(securityCheckerProvider).check(url);
  if (!context.mounted) return;

  await Navigator.of(context).push(
    SecurityResultScreen.route(entity: url, assessment: assessment),
  );
}
