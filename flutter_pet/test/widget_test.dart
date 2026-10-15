import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_pet/main.dart';

void main() {
  testWidgets('Poko Pet App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DesktopElectricPetApp());
    expect(find.textContaining('波可'), findsWidgets);
  });
}
