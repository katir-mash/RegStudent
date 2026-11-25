import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:regstudent_mobile/main.dart';
import 'package:regstudent_mobile/registry.dart';
import '../test/scenarios.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android emulator: real Flask API, SQLite and five screens',
      (t) async {
    bool converted = false;
    await flows(t, () => RegistryApi(Uri.parse(apiOrigin)),
        const String.fromEnvironment('LAB_PASSWORD'), (name) async {
      if (!converted) {
        await binding.convertFlutterSurfaceToImage();
        converted = true;
      }
      await t.pumpAndSettle();
      await binding.takeScreenshot(name);
    });
    final down = RegistryApi(Uri.parse('http://127.0.0.1:18799'));
    await t.pumpWidget(const SizedBox());
    await t.pumpAndSettle();
    await t.pumpWidget(RegistryApp(api: down));
    await t.pumpAndSettle();
    await enter(t, 'login', 'registrar');
    await enter(t, 'password', 'not-a-real-password');
    await tap(t, 'enter');
    await until(t, find.text('Серверге қосылу мүмкін болмады'));
  });
}
