import 'package:dramared/pages/settings_page.dart';
import 'package:dramared/services/playback_settings_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('settings expose timer, background listen and auto-next', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.pumpAndSettle();

    expect(find.text('定时停播'), findsOneWidget);
    expect(find.text('后台继续听'), findsOneWidget);
    expect(find.text('自动连播下一集'), findsOneWidget);
    expect(find.text('关'), findsOneWidget);
    expect(find.text('15分'), findsOneWidget);
    expect(find.text('30分'), findsOneWidget);
    expect(find.text('60分'), findsOneWidget);
  });

  testWidgets('choosing 15 minutes persists stopAfterMinutes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('15分'));
    await tester.pumpAndSettle();

    final loaded = await PlaybackSettingsStore().load();
    expect(loaded.stopAfterMinutes, 15);
    expect(find.textContaining('进入播放后 15 分钟暂停'), findsOneWidget);
  });

  testWidgets('toggling background listen persists false', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, '后台继续听'));
    await tester.pumpAndSettle();

    final loaded = await PlaybackSettingsStore().load();
    expect(loaded.backgroundListen, isFalse);
    expect(loaded.autoNext, isTrue);
  });
}
