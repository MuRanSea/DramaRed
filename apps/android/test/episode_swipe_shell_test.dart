import 'package:dramared/widgets/episode_swipe_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('vertical pager swipe reports the next page index', (tester) async {
    final pages = <int>[];
    final controller = PageController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 800,
          child: EpisodeSwipeShell(
            episodeCount: 3,
            controller: controller,
            onPageChanged: pages.add,
            onSwipeNext: () {},
            onSwipePrev: () {},
            onTap: () {},
            overlayBuilder: (context) => const ColoredBox(
              color: Colors.black,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(EpisodeSwipeShell.pagerKey), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(0, -600), 2000);
    await tester.pumpAndSettle();
    expect(pages, [1]);
    expect(controller.page, closeTo(1, 0.01));
  });

  testWidgets('vertical pager swipe down reports the previous page', (tester) async {
    final pages = <int>[];
    final controller = PageController(initialPage: 1);
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 800,
          child: EpisodeSwipeShell(
            episodeCount: 3,
            controller: controller,
            onPageChanged: pages.add,
            onSwipeNext: () {},
            onSwipePrev: () {},
            onTap: () {},
            overlayBuilder: (context) => const ColoredBox(
              color: Colors.black,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    await tester.fling(find.byType(PageView), const Offset(0, 600), 2000);
    await tester.pumpAndSettle();
    expect(pages, [0]);
  });

  testWidgets('single-episode shell maps fling velocity to next/prev', (tester) async {
    var next = 0;
    var prev = 0;
    final controller = PageController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 400,
          height: 800,
          child: EpisodeSwipeShell(
            episodeCount: 1,
            controller: controller,
            onPageChanged: (_) {},
            onSwipeNext: () => next++,
            onSwipePrev: () => prev++,
            onTap: () {},
            overlayBuilder: (context) => const ColoredBox(
              color: Colors.black,
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(EpisodeSwipeShell.singleKey), findsOneWidget);
    await tester.fling(
      find.byKey(EpisodeSwipeShell.singleKey),
      const Offset(0, -500),
      2000,
    );
    await tester.pumpAndSettle();
    expect(next, 1);
    expect(prev, 0);

    await tester.fling(
      find.byKey(EpisodeSwipeShell.singleKey),
      const Offset(0, 500),
      2000,
    );
    await tester.pumpAndSettle();
    expect(next, 1);
    expect(prev, 1);
  });
}
