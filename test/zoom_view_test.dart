import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zoom_view/zoom_view.dart';

Future<void> _doubleTap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pump(kDoubleTapMinTime);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Widget createZoomViewApp({
  required ScrollController scrollController,
  ZoomViewController? zoomViewController,
  void Function(ZoomViewDetails details)? onDoubleTap,
  void Function(double scale)? onScaleChanged,
  void Function(ZoomViewScaleEndDetails details)? onScaleEnd,
  double minScale = 0.5,
  double maxScale = 4.0,
  bool doubleTapDrag = false,
  Axis scrollAxis = Axis.vertical,
  Key? zoomViewKey,
}) {
  final listView = ListView.builder(
    controller: scrollController,
    scrollDirection: scrollAxis,
    itemCount: 20,
    itemBuilder: (context, index) {
      if (scrollAxis == Axis.vertical) {
        return SizedBox(height: 100, child: Center(child: Text('Item $index')));
      } else {
        return SizedBox(width: 150, child: Center(child: Text('Item $index')));
      }
    },
  );

  return MaterialApp(
    home: Scaffold(
      body: ZoomView(
        key: zoomViewKey,
        controller: scrollController,
        zoomViewController: zoomViewController,
        onDoubleTap: onDoubleTap,
        onScaleChanged: onScaleChanged,
        onScaleEnd: onScaleEnd,
        minScale: minScale,
        maxScale: maxScale,
        doubleTapDrag: doubleTapDrag,
        scrollAxis: scrollAxis,
        child: listView,
      ),
    ),
  );
}

void main() {
  group('ZoomViewController', () {
    testWidgets('Controller attaches and detaches correctly', (tester) async {
      final zoomViewController = ZoomViewController();
      final scrollController = ScrollController();
      expect(zoomViewController.isAttached, isFalse);

      await tester.pumpWidget(createZoomViewApp(
        scrollController: scrollController,
        zoomViewController: zoomViewController,
      ));
      expect(zoomViewController.isAttached, isTrue);

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(zoomViewController.isAttached, isFalse);
      scrollController.dispose();
    });

    testWidgets('setScale() should update the ZoomView scale', (tester) async {
      final zoomViewController = ZoomViewController();
      final scrollController = ScrollController();

      await tester.pumpWidget(createZoomViewApp(
        scrollController: scrollController,
        zoomViewController: zoomViewController,
      ));

      expect(zoomViewController.isAttached, isTrue);
      expect(zoomViewController.scale, 1.0);

      zoomViewController.setScale(2.5);
      await tester.pump();

      expect(zoomViewController.scale, moreOrLessEquals(2.5));
      scrollController.dispose();
    });

    testWidgets('setScale() with a focalPoint correctly adjusts the view', (tester) async {
      final zoomViewController = ZoomViewController();
      final scrollController = ScrollController();
      await tester.pumpWidget(createZoomViewApp(
        scrollController: scrollController,
        zoomViewController: zoomViewController,
      ));

      expect(scrollController.offset, 0.0);
      // Zoom into the top-left corner
      zoomViewController.setScale(3.0, focalPoint: Offset.zero);
      await tester.pump();

      expect(zoomViewController.scale, moreOrLessEquals(3.0));
      // Since we zoomed into the top-left, the scroll offset should remain 0
      expect(scrollController.offset, moreOrLessEquals(0.0));
      scrollController.dispose();
    });

    testWidgets('setScale() respects minScale and maxScale', (tester) async {
      final controller = ZoomViewController();
      final sc = ScrollController();
      await tester.pumpWidget(createZoomViewApp(
        scrollController: sc,
        zoomViewController: controller,
        minScale: 1.0,
        maxScale: 4.0,
      ));

      controller.setScale(0.5);
      await tester.pump();
      expect(controller.scale, moreOrLessEquals(1.0));

      controller.setScale(5.0);
      await tester.pump();
      expect(controller.scale, moreOrLessEquals(4.0));
      sc.dispose();
    });

    testWidgets('setScaleWithAnimation() animates the scale change', (tester) async {
      final controller = ZoomViewController();
      final scrollController = ScrollController();
      await tester.pumpWidget(createZoomViewApp(
        scrollController: scrollController,
        zoomViewController: controller,
      ));

      controller.setScaleWithAnimation(3.0, duration: const Duration(milliseconds: 300));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(controller.scale, greaterThan(1.0));
      expect(controller.scale, lessThan(3.0));

      await tester.pumpAndSettle();
      expect(controller.scale, moreOrLessEquals(3.0));
      scrollController.dispose();
    });
  });

  group('ZoomView Gestures', () {
    testWidgets('Pinch-to-zoom-in gesture increases the scale', (tester) async {
      final controller = ZoomViewController();
      final scrollController = ScrollController();
      await tester.pumpWidget(createZoomViewApp(
        scrollController: scrollController,
        zoomViewController: controller,
      ));

      final finder = find.byType(ZoomView);
      final center = tester.getCenter(finder);
      final gesture1 = await tester.startGesture(center - const Offset(50, 0));
      final gesture2 = await tester.startGesture(center + const Offset(50, 0));
      await tester.pump();

      // Move pointers further apart to zoom in
      await gesture1.moveBy(const Offset(-50, 0));
      await gesture2.moveBy(const Offset(50, 0));
      await tester.pump();

      expect(controller.scale, greaterThan(1.5));

      await gesture1.up();
      await gesture2.up();
      await tester.pumpAndSettle();
      scrollController.dispose();
    });

    testWidgets('Pinch-to-zoom-out gesture decreases the scale', (tester) async {
      final controller = ZoomViewController();
      final scrollController = ScrollController();
      await tester.pumpWidget(createZoomViewApp(
        scrollController: scrollController,
        zoomViewController: controller,
      ));

      await tester.pump();

      final finder = find.byType(ZoomView);
      final center = tester.getCenter(finder);
      final gesture1 = await tester.startGesture(center - const Offset(100, 0));
      final gesture2 = await tester.startGesture(center + const Offset(100, 0));
      await tester.pump();

      // Move pointers closer together to zoom out
      await gesture1.moveBy(const Offset(50, 0));
      await gesture2.moveBy(const Offset(-50, 0));
      await tester.pump();

      expect(controller.scale, lessThan(1.0));

      await gesture1.up();
      await gesture2.up();
      await tester.pumpAndSettle();
      scrollController.dispose();
    });

    testWidgets('Single-finger drag pans the content vertically', (tester) async {
      final scrollController = ScrollController();
      await tester.pumpWidget(createZoomViewApp(scrollController: scrollController));

      expect(scrollController.offset, 0.0);
      await tester.drag(find.byType(ZoomView), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(scrollController.offset, greaterThan(50.0));
      scrollController.dispose();
    });

    testWidgets('Single-finger drag pans the content horizontally', (tester) async {
      final scrollController = ScrollController();
      await tester.pumpWidget(createZoomViewApp(
        scrollController: scrollController,
        scrollAxis: Axis.horizontal,
      ));

      expect(scrollController.offset, 0.0);
      await tester.drag(find.byType(ZoomView), const Offset(-100, 0));
      await tester.pumpAndSettle();
      expect(scrollController.offset, greaterThan(50.0));
      scrollController.dispose();
    });

    testWidgets('Double tap gesture calls onDoubleTap callback', (tester) async {
      bool wasDoubleTapped = false;
      final scrollController = ScrollController();

      await tester.pumpWidget(createZoomViewApp(
        scrollController: scrollController,
        onDoubleTap: (details) {
          wasDoubleTapped = true;
        },
      ));

      await _doubleTap(tester, find.byType(ZoomView));
      expect(wasDoubleTapped, isTrue);
      scrollController.dispose();
    });

    testWidgets('Double tap and drag gesture changes scale', (tester) async {
      final controller = ZoomViewController();
      final scrollController = ScrollController();
      await tester.pumpWidget(createZoomViewApp(
        scrollController: scrollController,
        zoomViewController: controller,
        doubleTapDrag: true,
      ));

      final finder = find.byType(ZoomView);
      final center = tester.getCenter(finder);

      await tester.tap(finder);
      await tester.pump(kDoubleTapMinTime);

      final gesture = await tester.startGesture(center);
      await tester.pump(kDoubleTapMinTime);

      expect(controller.scale, 1.0);

      await gesture.moveBy(const Offset(0, 100));
      await tester.pump();
      expect(controller.scale, greaterThan(1.2));
      final scaleAfterZoomIn = controller.scale;

      await gesture.moveBy(const Offset(0, -150));
      await tester.pump();
      expect(controller.scale, lessThan(scaleAfterZoomIn));

      await gesture.up();
      await tester.pumpAndSettle();
      scrollController.dispose();
    });
  });

  group('ZoomView Callbacks', () {
    testWidgets('onScaleChanged callback fires during zoom', (tester) async {
      final scrollController = ScrollController();
      double lastScale = 0;
      int callCount = 0;

      await tester.pumpWidget(createZoomViewApp(
        scrollController: scrollController,
        onScaleChanged: (scale) {
          lastScale = scale;
          callCount++;
        },
      ));

      final finder = find.byType(ZoomView);
      final center = tester.getCenter(finder);
      final gesture1 = await tester.startGesture(center - const Offset(50, 0));
      final gesture2 = await tester.startGesture(center + const Offset(50, 0));
      await tester.pump();

      await gesture1.moveBy(const Offset(-50, 0));
      await gesture2.moveBy(const Offset(50, 0));
      await tester.pump();

      expect(callCount, greaterThan(0));
      expect(lastScale, greaterThan(1.0));

      await gesture1.up();
      await gesture2.up();
      scrollController.dispose();
    });

    testWidgets('onScaleEnd callback fires after zoom gesture', (tester) async {
      final scrollController = ScrollController();
      ZoomViewScaleEndDetails? endDetails;

      await tester.pumpWidget(createZoomViewApp(
        scrollController: scrollController,
        onScaleEnd: (details) {
          endDetails = details;
        },
      ));

      final finder = find.byType(ZoomView);
      final center = tester.getCenter(finder);
      final gesture1 = await tester.startGesture(center - const Offset(50, 0));
      final gesture2 = await tester.startGesture(center + const Offset(50, 0));
      await tester.pump();
      await gesture1.moveBy(const Offset(-50, 0));
      await gesture2.moveBy(const Offset(50, 0));
      await tester.pump();
      await gesture1.up();
      await gesture2.up();
      await tester.pumpAndSettle();

      expect(endDetails, isNotNull);
      expect(endDetails!.scale, greaterThan(1.0));

      scrollController.dispose();
    });
  });

  group('ZoomListView', () {
    testWidgets('builds correctly with a controlled ListView', (tester) async {
      final listController = ScrollController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomListView(
              child: ListView.builder(
                controller: listController,
                itemCount: 10,
                itemBuilder: (context, index) => ListTile(title: Text('Item $index')),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(ZoomView), findsOneWidget);
      expect(find.byType(ListView), findsOneWidget);
      listController.dispose();
    });

    testWidgets('throws exception if child ListView has no controller', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ZoomListView(
                child: ListView.builder(itemCount: 5, itemBuilder: (_, __) => const Text('hi'))),
          ),
        ),
      );

      final exception = tester.takeException();
      expect(exception, isA<Exception>());
      expect(
        exception.toString(),
        contains('List does not have a controller'),
      );
    });
  });

  group('ZoomViewGestureHandler', () {
    testWidgets('onDoubleTap cycles through zoomLevels', (tester) async {
      final zoomViewController = ZoomViewController();
      final gestureHandler = ZoomViewGestureHandler(zoomLevels: [2.0, 3.0]);
      final scrollController = ScrollController();

      await tester.pumpWidget(createZoomViewApp(
        scrollController: scrollController,
        zoomViewController: zoomViewController,
        onDoubleTap: gestureHandler.onDoubleTap,
        minScale: 0.1,
        maxScale: 10.0,
      ));

      await _doubleTap(tester, find.byType(ZoomView));
      expect(zoomViewController.scale, moreOrLessEquals(2.0));

      await _doubleTap(tester, find.byType(ZoomView));
      expect(zoomViewController.scale, moreOrLessEquals(3.0));

      await _doubleTap(tester, find.byType(ZoomView));
      expect(zoomViewController.scale, moreOrLessEquals(2.0));

      await _doubleTap(tester, find.byType(ZoomView));
      expect(zoomViewController.scale, moreOrLessEquals(3.0));

      scrollController.dispose();
    });
  });
}
