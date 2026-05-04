import 'package:busha_pay/src/shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders without throwing and exposes a loading semantics label', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChooserShimmer()));

    expect(find.byType(ChooserShimmer), findsOneWidget);
    expect(find.bySemanticsLabel('Loading payment options'), findsOneWidget);
  });

  testWidgets('disposes its animation controller cleanly', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ChooserShimmer()));
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    expect(find.byType(ChooserShimmer), findsNothing);
  });
}
