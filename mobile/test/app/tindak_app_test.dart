import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tindak/app/tindak_app.dart';
import 'package:tindak/features/home/home_screen.dart';

void main() {
  group('TindakApp', () {
    testWidgets('boots to the home screen', (tester) async {
      await tester.pumpWidget(const ProviderScope(child: TindakApp()));

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('shows the approved empty-state copy', (tester) async {
      // docs/03_UX_FLOWS.md section 4.
      await tester.pumpWidget(const ProviderScope(child: TindakApp()));

      expect(find.text('Jumpa maklumat penting?'), findsOneWidget);
      expect(
        find.text(
          'Tekan Share dalam WhatsApp, browser\natau app lain dan pilih TINDAK.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('starts with no account prompt and no permission wall',
        (tester) async {
      // PD-001 guest-first, UX section 3: no forced registration and no
      // permission wall before first value.
      await tester.pumpWidget(const ProviderScope(child: TindakApp()));

      expect(find.textContaining('Sign in'), findsNothing);
      expect(find.textContaining('Log masuk'), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('renders in dark theme without error', (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(const ProviderScope(child: TindakApp()));
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
