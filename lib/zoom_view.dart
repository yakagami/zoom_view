import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class ZoomListView extends StatefulWidget {
  final ListView child;
  const ZoomListView({super.key, required this.child});

  @override
  State<ZoomListView> createState() => _ZoomListViewState();
}

class _ZoomListViewState extends State<ZoomListView> {
  @override
  void initState() {
    if (widget.child.controller == null) {
      throw Exception(
          "List does not have a controller. Add a controller to your list");
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ZoomView(controller: widget.child.controller!, child: widget.child);
  }
}

///Allows a ListView or other Scrollables that implement ScrollPosition and
///jumpTo(offset) in their controller to be zoomed and scrolled.
class ZoomView extends StatefulWidget {
  const ZoomView({super.key, required this.child, required this.controller});
  final Widget child;
  final ScrollController controller;

  @override
  State<ZoomView> createState() => _ZoomViewState();
}

class _ZoomViewState extends State<ZoomView> {
  @override
  void initState() {
    controller = widget.controller;
    verticalTouchHandler = _TouchHandler(controller: controller);
    horizontalTouchHandler = _TouchHandler(controller: horizontalController);
    super.initState();
  }

  double scale = 1;
  late ScrollController controller;
  //note: terms like vertical and horizontal TouchHandler should be replaced
  //with mainAxisTouchHandler and crossAxisTouchHandler to add support for 
  //arbritary Axis ListViews
  late _TouchHandler verticalTouchHandler;
  late _TouchHandler horizontalTouchHandler;
  ScrollController horizontalController = ScrollController();
  final VelocityTracker tracker =
      VelocityTracker.withKind(PointerDeviceKind.touch);

  late double distanceFromOffset;
  late double horizontalDistanceFromOffset;
  late double focalPointDistanceFromBottomFactor;
  late double horizontalFocalPointDistanceFromBottomFactor;

  double lastScale = 1;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
            double height = constraints.maxHeight;
            double width = constraints.maxWidth;
            return GestureDetector(
              onScaleStart: (ScaleStartDetails details) {
                if (details.pointerCount == 1) {
                  DragStartDetails dragDetails = DragStartDetails(
                      globalPosition: details.focalPoint,
                      kind: PointerDeviceKind.touch);
                  DragStartDetails hDragDetails = DragStartDetails(
                      globalPosition: details.focalPoint,
                      kind: PointerDeviceKind.touch);
                  verticalTouchHandler.handleDragStart(dragDetails);
                  horizontalTouchHandler.handleDragStart(hDragDetails);
                } else {
                  distanceFromOffset = details.localFocalPoint.dy;
                  horizontalDistanceFromOffset = details.localFocalPoint.dx;
                  focalPointDistanceFromBottomFactor =
                      (height - distanceFromOffset) / distanceFromOffset;
                  horizontalFocalPointDistanceFromBottomFactor =
                      (width - horizontalDistanceFromOffset) /
                          horizontalDistanceFromOffset;
                }
              },
              onScaleUpdate: (ScaleUpdateDetails details) {
                if (details.pointerCount > 1) {
                  double oldHeight = height * scale;
                  double oldWidth = width * scale;
                  //this prevents the viewer from zooming out more than 1x
                  //(ie. you can only zoom in and back to 1x, you cannot zoom out
                  //TODO: allow developers to control zoom out feature.
                  //currently if you zoom out the List will be stuck to the
                  //left hand side of the screen. not the middle as it should.
                  if (lastScale / details.scale <= 1.0) {
                    setState(() {
                      scale = lastScale / details.scale;
                    });
                  }
                  //vertical offset
                  final double newHeight = height * scale;
                  controller.jumpTo(controller.offset +
                      (oldHeight - newHeight) /
                          (1 + focalPointDistanceFromBottomFactor));

                  //horizontal offset
                  final double newWidth = width * scale;
                  horizontalController.jumpTo(horizontalController.offset +
                      (oldWidth - newWidth) /
                          (1 + horizontalFocalPointDistanceFromBottomFactor));
                } else {
                  final Duration currentTime = Duration(
                      milliseconds: DateTime.now().millisecondsSinceEpoch);
                  final double correctedDelta =
                      details.focalPointDelta.dy * scale;
                  final Offset correctedOffset = details.focalPoint * scale;
                  tracker.addPosition(currentTime, correctedOffset);
                  final DragUpdateDetails verticalDetails = DragUpdateDetails(
                      globalPosition: correctedOffset,
                      sourceTimeStamp: currentTime,
                      primaryDelta: correctedDelta,
                      delta: Offset(0.0, correctedDelta));
                  final double horizontalCorrectedDelta =
                      details.focalPointDelta.dx * scale;
                  final DragUpdateDetails horizontalDetails = DragUpdateDetails(
                      globalPosition: correctedOffset,
                      sourceTimeStamp: currentTime,
                      primaryDelta: horizontalCorrectedDelta,
                      delta: Offset(horizontalCorrectedDelta, 0.0));
                  verticalTouchHandler.handleDragUpdate(verticalDetails);
                  horizontalTouchHandler.handleDragUpdate(horizontalDetails);
                }
              },
              onScaleEnd: (ScaleEndDetails details) {
                lastScale = scale;
                Offset velocity = tracker.getVelocity().pixelsPerSecond;
                DragEndDetails endDetails = DragEndDetails(
                  velocity: Velocity(
                    pixelsPerSecond: Offset(0.0, velocity.dy),
                  ),
                  primaryVelocity: velocity.dy,
                );
                DragEndDetails hEndDetails = DragEndDetails(
                  velocity: Velocity(
                    pixelsPerSecond: Offset(velocity.dx, 0.0),
                  ),
                  primaryVelocity: velocity.dx,
                );
                verticalTouchHandler.handleDragEnd(endDetails);
                horizontalTouchHandler.handleDragEnd(hEndDetails);
              },
              child: FittedBox(
                fit: BoxFit.fill,
                child: ScrollConfiguration(
                  behavior: const ScrollBehavior().copyWith(
                      overscroll: false, dragDevices: <PointerDeviceKind>{}),
                  child: SizedBox(
                    height: height * scale,
                    width: width * scale,
                    child: ListView(
                      physics: const ClampingScrollPhysics(),
                      controller: horizontalController,
                      scrollDirection: Axis.horizontal,
                      children: [
                        SizedBox(width: width, child: widget.child),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

final class _TouchHandler {
  final ScrollController controller;
  _TouchHandler({required this.controller});
  final GlobalKey<RawGestureDetectorState> _gestureDetectorKey =
      GlobalKey<RawGestureDetectorState>();
  Drag? _drag;

  ScrollHoldController? _hold;

  void handleDragDown(DragDownDetails details) {
    assert(_drag == null);
    assert(_hold == null);
    _hold = controller.position.hold(disposeHold);
  }

  void handleDragStart(DragStartDetails details) {
    assert(_drag == null);
    _drag = controller.position.drag(details, disposeDrag);
    assert(_drag != null);
    assert(_hold == null);
  }

  void handleDragUpdate(DragUpdateDetails details) {
    // _drag might be null if the drag activity ended and called _disposeDrag.
    assert(_hold == null || _drag == null);
    _drag?.update(details);
  }

  void handleDragEnd(DragEndDetails details) {
    // _drag might be null if the drag activity ended and called _disposeDrag.
    assert(_hold == null || _drag == null);
    _drag?.end(details);
    assert(_drag == null);
  }

  void handleDragCancel() {
    if (_gestureDetectorKey.currentContext == null) {
      return;
    }
    // _hold might be null if the drag started.
    // _drag might be null if the drag activity ended and called _disposeDrag.
    assert(_hold == null || _drag == null);
    _hold?.cancel();
    _drag?.cancel();
    assert(_hold == null);
    assert(_drag == null);
  }

  void disposeHold() {
    _hold = null;
  }

  void disposeDrag() {
    _drag = null;
  }
}
