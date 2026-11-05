import 'package:dramared/main.dart';
import 'package:dramared/pages/home_page.dart';
import 'package:dramared/pages/search_page.dart';
import 'package:dramared/widgets/series_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:openhongguo/openhongguo.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('SeriesTile shows title and navigates shell', (tester) async {
    const series = SeriesSummary(
      id: 's1',
      title: '测试短剧',
      description: '简介',
      episodeCount: 12,
      category: '都市',
      author: '作者',
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SeriesTile(series: series),
        ),
      ),
    );
    expect(find.text('测试短剧'), findsOneWidget);
    expect(find.textContaining('12 集'), findsOneWidget);
  });

  testWidgets('bottom nav is 首页 / 剧场 / 我的 without 商城', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RootShell()));
    await tester.pump();
    expect(find.text('首页'), findsWidgets);
    expect(find.text('剧场'), findsWidgets);
    expect(find.text('我的'), findsWidgets);
    expect(find.text('商城'), findsNothing);
  });

  testWidgets('home top bar only shows 推荐 and search', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pump();
    expect(find.text('推荐'), findsOneWidget);
    expect(find.byTooltip('搜索'), findsOneWidget);
    expect(find.text('关注'), findsNothing);
    expect(find.text('漫剧'), findsNothing);
    expect(find.text('真人剧'), findsNothing);
  });

  testWidgets('search page is reachable from home top bar', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomePage()));
    await tester.pump();
    await tester.tap(find.byTooltip('搜索'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(SearchPage), findsOneWidget);
  });
}
