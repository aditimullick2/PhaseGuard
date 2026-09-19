import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:phaseguard/state/session_controller.dart';
import 'package:phaseguard/widgets/pg_gauge.dart';
import 'package:phaseguard/widgets/pg_custom_icons.dart';
import 'package:phaseguard/widgets/pg_animations.dart';
import 'package:phaseguard/screens_new/app_navigation.dart';

void main() {
  testWidgets('PgRadialGauge renders score and risk badge correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PgRadialGauge(
            value: 0.84,
            title: 'PDI SCORE',
            subtitle: 'CRITICAL RISK',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('PDI SCORE'), findsOneWidget);
    expect(find.text('84'), findsOneWidget);
    expect(find.text('%'), findsOneWidget);
    expect(find.text('CRITICAL RISK'), findsOneWidget);
  });

  testWidgets('PgAcousticMeter renders synthetic voice score', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PgAcousticMeter(
            value: 0.78,
            label: 'SYNTHETIC VOICE',
            isSynthetic: true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('SYNTHETIC VOICE'), findsOneWidget);
    expect(find.text('78'), findsOneWidget);
    expect(find.text('CLONE DETECTED'), findsOneWidget);
  });

  testWidgets('PgCustomIcon and PgActionCard render without errors', (WidgetTester tester) async {
    bool tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PgActionCard(
            label: 'Live Verify',
            description: 'Real-time call check',
            iconType: PgIconType.scanner,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Live Verify'), findsOneWidget);
    expect(find.text('Real-time call check'), findsOneWidget);

    await tester.tap(find.text('Live Verify'));
    expect(tapped, isTrue);
  });

  testWidgets('PulsingRing and LiveWaveform render properly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              PulsingRing(
                child: Icon(Icons.shield),
              ),
              LiveWaveform(
                height: 40,
                barCount: 20,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.shield), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 200));
  });

  testWidgets('MainDashboard renders protection card, quick actions, and defense telemetry', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChangeNotifierProvider(
            create: (_) => SessionController(),
            child: const MainDashboard(),
          ),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('PhaseGuard'), findsOneWidget);
    expect(find.text('PROTECTION STATUS'), findsOneWidget);
    expect(find.text('Shield Engaged'), findsOneWidget);
    expect(find.text('STANDBY'), findsOneWidget);
    expect(find.text('Live Verify'), findsOneWidget);
    expect(find.text('Voice Analysis'), findsOneWidget);
    expect(find.text('Scambaiter'), findsOneWidget);
    expect(find.text('Call History'), findsOneWidget);
    expect(find.text('DEFENSE TELEMETRY'), findsOneWidget);
  });
}
