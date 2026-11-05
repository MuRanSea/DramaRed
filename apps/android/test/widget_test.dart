import 'package:flutter_test/flutter_test.dart';
import 'package:dramared/main.dart';

void main() {
  testWidgets('app smoke', (tester) async {
    await tester.pumpWidget(const DramaRedApp());
    expect(find.textContaining('DramaRed'), findsWidgets);
  });
}
