import 'package:cosmic_guide/models/zodiac.dart';
import 'package:cosmic_guide/widgets/energy_forecast_chart.dart';
import 'package:cosmic_guide/widgets/score_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The score ring and the energy forecast are the product's headline outputs
/// and both are bare `CustomPaint`, so without a textual equivalent a screen
/// reader announces nothing at all for them.
void main() {
  testWidgets('the score ring announces its value', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ScoreRing(
            value: 0.54,
            label: '54%',
            caption: 'Mixed',
            color: Colors.orange,
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Mixed: 54%'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the energy forecast describes today and the best day', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final points = [
      ForecastPoint(date: DateTime(2026, 10, 7), score: 54, band: 'Mixed'),
      ForecastPoint(date: DateTime(2026, 10, 8), score: 68, band: 'Steady'),
      ForecastPoint(date: DateTime(2026, 10, 9), score: 81, band: 'Favorable'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EnergyForecastChart(points: points, bestDay: points.last),
        ),
      ),
    );

    expect(
      find.bySemanticsLabel(
        'Energy forecast over 3 days. Today 54, mixed. Best day 9/10 at 81.',
      ),
      findsOneWidget,
    );
    handle.dispose();
  });

  test('band colours follow the score thresholds', () {
    expect(forecastScoreColor(90), forecastScoreColor(85));
    expect(forecastScoreColor(84), isNot(forecastScoreColor(85)));
    expect(forecastScoreColor(40), forecastScoreColor(51));
  });
}
