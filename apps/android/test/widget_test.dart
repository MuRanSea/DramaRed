import 'package:dramared/widgets/series_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openhongguo/openhongguo.dart';

void main() {
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
}
