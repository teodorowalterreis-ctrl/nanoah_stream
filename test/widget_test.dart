import 'package:flutter_test/flutter_test.dart';
import 'package:nanoah_stream/main.dart';

void main() {
  testWidgets('NanoahStreamApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const NanoahStreamApp());
    expect(find.byType(NanoahStreamApp), findsOneWidget);
  });
}