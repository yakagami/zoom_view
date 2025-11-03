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
  void Function(TapDownDetails details)? onDoubleTap,
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

    testWidgets('dragMode is correctly updated during gestures', (tester) async {
      final controller = ZoomViewController();
      final scrollController = ScrollController();
      await tester.pumpWidget(createZoomViewApp(
        scrollController: scrollController,
        zoomViewController: controller,
        doubleTapDrag: true,
      ));

      final finder = find.byType(ZoomView);
      final center = tester.getCenter(finder);

      // Test Pan
      final panGesture = await tester.startGesture(center);
      await panGesture.moveBy(const Offset(0, -(kPanSlop + 1)));
      await tester.pump();
      expect(controller.dragMode, DragMode.pan);

      await panGesture.up();
      await tester.pumpAndSettle();
      expect(controller.dragMode, DragMode.none);

      // Test Pinch Scale
      final gesture1 = await tester.startGesture(center - const Offset(50, 0));
      final gesture2 = await tester.startGesture(center + const Offset(50, 0));
      await tester.pump();
      await gesture1.moveBy(const Offset(-20, 0));
      await gesture2.moveBy(const Offset(20, 0));
      await tester.pump();
      expect(controller.dragMode, DragMode.pinchScale);
      await gesture1.up();
      await gesture2.up();
      await tester.pumpAndSettle();
      expect(controller.dragMode, DragMode.none);

      // Test Double Tap Drag
      await tester.tap(finder);
      await tester.pump(kDoubleTapMinTime);
      final doubleTapDragGesture = await tester.startGesture(center);
      await tester.pump(kDoubleTapMinTime);
      await doubleTapDragGesture.moveBy(const Offset(0, 50));
      await tester.pump();
      expect(controller.dragMode, DragMode.doubleTapDrag);
      await doubleTapDragGesture.up();
      await tester.pumpAndSettle();
      expect(controller.dragMode, DragMode.none);

      scrollController.dispose();
    });

    testWidgets('Pan gesture transitions to pinch-to-zoom when a second finger is added',
        (tester) async {
      final controller = ZoomViewController();
      final scrollController = ScrollController();
      await tester.pumpWidget(createZoomViewApp(
        scrollController: scrollController,
        zoomViewController: controller,
      ));

      final finder = find.byType(ZoomView);
      final center = tester.getCenter(finder);

      // Start with a single-finger pan
      final gesture1 = await tester.startGesture(center);
      await tester.pump();
      await gesture1.moveBy(const Offset(0, -50));
      await tester.pump(const Duration(milliseconds: 20)); // Settle pan

      // Verify it's panning
      expect(controller.dragMode, DragMode.pan);
      expect(scrollController.offset, greaterThan(0));
      expect(controller.scale, 1.0);
      final initialOffset = scrollController.offset;

      // Add a second finger
      final gesture2 = await tester.startGesture(center + const Offset(100, 0));
      await tester.pump();

      // Move both fingers to scale. A move event is needed to trigger onScaleUpdate
      // and update the dragMode.
      await gesture1.moveBy(const Offset(-20, 0));
      await gesture2.moveBy(const Offset(20, 0));
      await tester.pump();

      // Verify it's now scaling
      expect(controller.dragMode, DragMode.pinchScale);
      expect(controller.scale, greaterThan(1.0));

      // FIX: The scroll offset is EXPECTED to change to keep the zoom anchored
      // to the focal point. The original test's expectation was incorrect.
      // We now simply check that the offset has increased, as expected when
      // zooming into the center of a scrolled view.
      expect(scrollController.offset, greaterThan(initialOffset));

      await gesture1.up();
      await gesture2.up();
      await tester.pumpAndSettle();
      scrollController.dispose();
    });

    testWidgets('Pinch-to-zoom transitions to pan when one finger is lifted', (tester) async {
      final controller = ZoomViewController();
      final scrollController = ScrollController();
      await tester.pumpWidget(createZoomViewApp(
        scrollController: scrollController,
        zoomViewController: controller,
      ));

      final finder = find.byType(ZoomView);
      final center = tester.getCenter(finder);
      final initialScale = controller.scale;
      final initialOffset = scrollController.offset;

      // Start with a two-finger pinch
      final gesture1 = await tester.startGesture(center - const Offset(50, 0));
      final gesture2 = await tester.startGesture(center + const Offset(50, 0));
      await tester.pump();

      await gesture1.moveBy(const Offset(-50, 0));
      await gesture2.moveBy(const Offset(50, 0));
      await tester.pump();

      // Verify it's scaling
      expect(controller.dragMode, DragMode.pinchScale);
      expect(controller.scale, greaterThan(initialScale));
      final scaleAfterZoom = controller.scale;

      // Lift one finger
      await gesture1.up();
      await tester.pump();

      // onScaleEnd is called, so dragMode should be none.
      expect(controller.dragMode, DragMode.none);

      // Move the remaining finger to pan, which starts a new gesture.
      await gesture2.moveBy(const Offset(0, -50));
      await tester.pump(const Duration(milliseconds: 20));

      // Verify it's now panning
      expect(controller.dragMode, DragMode.pan);
      expect(controller.scale, moreOrLessEquals(scaleAfterZoom)); // Scale should not change
      expect(
          scrollController.offset, isNot(moreOrLessEquals(initialOffset))); // Offset should change

      await gesture2.up();
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
      final gestureHandler =
          ZoomViewGestureHandler(zoomLevels: [2.0, 3.0], controller: zoomViewController);
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

  group('Complex Gestures', () {
    testWidgets('Trackpad pinch gesture zooms the view', (tester) async {
      final controller = ZoomViewController();
      final scrollController = ScrollController();
      await tester.pumpWidget(createZoomViewApp(
        scrollController: scrollController,
        zoomViewController: controller,
      ));

      final trackpad = TestPointer(1, PointerDeviceKind.trackpad);
      final center = tester.getCenter(find.byType(ZoomView));

      // Start the gesture
      await tester.sendEventToBinding(trackpad.panZoomStart(center));
      await tester.pump();

      // Zoom in
      await tester.sendEventToBinding(trackpad.panZoomUpdate(center, scale: 2.0));
      await tester.pump();
      expect(controller.scale, greaterThan(1.5));
      expect(controller.dragMode, DragMode.pinchScale);

      // Zoom out
      await tester.sendEventToBinding(trackpad.panZoomUpdate(center, scale: 0.5));
      await tester.pump();
      expect(controller.scale, lessThan(1.0));

      // End the gesture
      await tester.sendEventToBinding(trackpad.panZoomEnd());
      await tester.pumpAndSettle();
      expect(controller.dragMode, DragMode.none);
      scrollController.dispose();
    });

    testWidgets('Trackpad scroll gesture pans the view', (tester) async {
      final controller = ZoomViewController();
      final scrollController = ScrollController();
      await tester.pumpWidget(createZoomViewApp(
        scrollController: scrollController,
        zoomViewController: controller,
      ));
      expect(scrollController.offset, 0.0);

      final trackpad = TestPointer(1, PointerDeviceKind.trackpad);
      final center = tester.getCenter(find.byType(ZoomView));

      // Start
      await tester.sendEventToBinding(trackpad.panZoomStart(center));
      await tester.pump();

      // Pan down (scrolls content up)
      await tester.sendEventToBinding(trackpad.panZoomUpdate(center, pan: const Offset(0, -50)));
      await tester.pump();
      expect(controller.dragMode, DragMode.pan);
      expect(scrollController.offset, greaterThan(0));

      // End
      await tester.sendEventToBinding(trackpad.panZoomEnd());
      await tester.pumpAndSettle();
      expect(controller.dragMode, DragMode.none);
      scrollController.dispose();
    });

    testWidgets('Three-finger pinch gesture scales and transitions correctly', (tester) async {
      final controller = ZoomViewController();
      final scrollController = ScrollController();
      await tester.pumpWidget(createZoomViewApp(
        scrollController: scrollController,
        zoomViewController: controller,
      ));

      final finder = find.byType(ZoomView);
      final center = tester.getCenter(finder);

      // Start with two fingers
      final g1 = await tester.startGesture(center - const Offset(50, 0));
      final g2 = await tester.startGesture(center + const Offset(50, 0));
      await g1.moveBy(const Offset(-20, 0));
      await g2.moveBy(const Offset(20, 0));
      await tester.pump();
      expect(controller.dragMode, DragMode.pinchScale);
      final scaleAfter2Fingers = controller.scale;
      expect(scaleAfter2Fingers, greaterThan(1.0));

      // Add a third finger
      final g3 = await tester.startGesture(center + const Offset(0, 50));
      await tester.pump();

      // Move all three fingers apart
      await g1.moveBy(const Offset(-20, 0));
      await g2.moveBy(const Offset(20, 0));
      await g3.moveBy(const Offset(0, 20));
      await tester.pump();
      expect(controller.dragMode, DragMode.pinchScale);
      final scaleAfter3Fingers = controller.scale;
      expect(scaleAfter3Fingers, greaterThan(scaleAfter2Fingers));

      // Lift one finger (g1)
      await g1.up();
      await tester.pump();

      // Move remaining two fingers (g2, g3)
      await g2.moveBy(const Offset(-20, 0)); // Move left
      await g3.moveBy(const Offset(0, -20));
      await tester.pump();
      // A new scale gesture starts
      expect(controller.dragMode, DragMode.pinchScale);
      expect(controller.scale, lessThan(scaleAfter3Fingers));
      final scaleAfterLifting1 = controller.scale;

      // Lift another finger (g2)
      await g2.up();
      await tester.pump();

      // Move final finger (g3)
      await g3.moveBy(const Offset(0, -50));
      await tester.pump();
      // A new pan gesture starts
      expect(controller.dragMode, DragMode.pan);
      expect(controller.scale, moreOrLessEquals(scaleAfterLifting1));
      expect(scrollController.offset, isNonZero);

      // Lift final finger
      await g3.up();
      await tester.pumpAndSettle();
      expect(controller.dragMode, DragMode.none);
      scrollController.dispose();
    });

    testWidgets('Gesture is cancelled by PointerCancelEvent', (tester) async {
      final controller = ZoomViewController();
      final scrollController = ScrollController();
      await tester.pumpWidget(createZoomViewApp(
        scrollController: scrollController,
        zoomViewController: controller,
      ));
      final center = tester.getCenter(find.byType(ZoomView));
      final g1 = await tester.startGesture(center - const Offset(50, 0));
      final g2 = await tester.startGesture(center + const Offset(50, 0));
      await g1.moveBy(const Offset(-20, 0));
      await tester.pump();

      expect(controller.dragMode, DragMode.pinchScale);
      final scaleBeforeCancel = controller.scale;

      // Cancel the gesture
      await g1.cancel();
      await tester.pumpAndSettle();

      // Drag mode should reset, scale should be preserved
      expect(controller.dragMode, DragMode.none);
      expect(controller.scale, moreOrLessEquals(scaleBeforeCancel));

      // The second pointer is still down, but the gesture recognizer has reset.
      // Moving it should start a new pan gesture.
      final offsetBeforePan = scrollController.offset;
      await g2.moveBy(const Offset(0, -50));
      await tester.pump();

      expect(controller.dragMode, DragMode.pan);
      expect(scrollController.offset, isNot(moreOrLessEquals(offsetBeforePan)));

      await g2.up();
      await tester.pumpAndSettle();
      scrollController.dispose();
    });

    testWidgets('Scale is clamped during vigorous pinch gesture', (tester) async {
      final controller = ZoomViewController();
      final scrollController = ScrollController();
      await tester.pumpWidget(createZoomViewApp(
        scrollController: scrollController,
        zoomViewController: controller,
        minScale: 0.5,
        maxScale: 2.0,
      ));

      final center = tester.getCenter(find.byType(ZoomView));

      // Test maxScale clamping
      final g1 = await tester.startGesture(center - const Offset(50, 0));
      final g2 = await tester.startGesture(center + const Offset(50, 0));
      await g1.moveBy(const Offset(-500, 0)); // Very large zoom-in
      await g2.moveBy(const Offset(500, 0));
      await tester.pump();

      expect(controller.scale, moreOrLessEquals(2.0));

      await g1.up();
      await g2.up();
      await tester.pumpAndSettle();
      expect(controller.scale, moreOrLessEquals(2.0));

      // Test minScale clamping
      final g3 = await tester.startGesture(center - const Offset(200, 0));
      final g4 = await tester.startGesture(center + const Offset(200, 0));
      await g3.moveBy(const Offset(190, 0)); // Very large zoom-out
      await g4.moveBy(const Offset(-190, 0));
      await tester.pump();

      expect(controller.scale, moreOrLessEquals(0.5));

      await g3.up();
      await g4.up();
      await tester.pumpAndSettle();
      expect(controller.scale, moreOrLessEquals(0.5));

      scrollController.dispose();
    });
  });
}
