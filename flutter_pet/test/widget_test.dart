import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pet/main.dart';

void main() {
  testWidgets('Poko Pet App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DesktopElectricPetApp());
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('波可'), findsWidgets);
  });
}
