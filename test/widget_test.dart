import 'package:flutter_test/flutter_test.dart';
import 'package:pli_runner/main.dart';

void main() {
  testWidgets('App starts', (tester) async {
    await tester.pumpWidget(const PliRunnerApp());
    expect(find.text('Aucun pli pour le moment'), findsOneWidget);
  });
}
