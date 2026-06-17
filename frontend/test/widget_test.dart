import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_app/main.dart';

void main() {
  testWidgets('Home screen loads', (WidgetTester tester) async {
    await tester.pumpWidget(const FitnessApp());
    await tester.pump();
    expect(find.text('Ma'), findsOneWidget);
    expect(find.text('Tevékenységgyűrűk'), findsOneWidget);
  });
}
