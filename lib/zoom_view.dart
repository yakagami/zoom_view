import 'dart:nativewrappers/_internal/vm/lib/internal_patch.dart';

import 'package:flutter/foundation.dart';
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
      throw Exception("List does not have a controller. Add a controller to your list");
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
  const ZoomView({
    super.key,
    required this.child,
    required this.controller,
    this.scrollAxis = Axis.vertical,
    this.doubleTapScaleCircle = const [],
  });

  final Widget child;
  final ScrollController controller;
  final Axis scrollAxis;
  final List<double> doubleTapScaleCircle;

  @override
  State<ZoomView> createState() => _ZoomViewState();
}

class _ZoomViewState extends State<ZoomView> with TickerProviderStateMixin {
  @override
  void initState() {
    if (widget.scrollAxis == Axis.vertical) {
      verticalController = widget.controller;
      horizontalController = ScrollController();
    } else {
      verticalController = ScrollController();
      horizontalController = widget.controller;
    }
    verticalTouchHandler = _TouchHandler(controller: verticalController);
    horizontalTouchHandler = _TouchHandler(controller: horizontalController);
    doubleTapScaleCircle = widget.doubleTapScaleCircle;
    super.initState();
  }

  double scale = 1;
  late ScrollController verticalController;
  late ScrollController horizontalController;

  late _TouchHandler verticalTouchHandler;
  late _TouchHandler horizontalTouchHandler;
  final VelocityTracker tracker = VelocityTracker.withKind(PointerDeviceKind.touch);

  late double distanceFromOffset;
  late double horizontalDistanceFromOffset;
  late double focalPointDistanceFromBottomFactor;
  late double horizontalFocalPointDistanceFromBottomFactor;

  late List<double> doubleTapScaleCircle;
  bool inDoubleTapScaleCircle = false;
  int scaleCircleIndex = 0;

  double lastScale = 1;

  @override
  void didUpdateWidget(covariant ZoomView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!listEquals(doubleTapScaleCircle, widget.doubleTapScaleCircle)) {
      setState(() {
        doubleTapScaleCircle = widget.doubleTapScaleCircle;
        inDoubleTapScaleCircle = false;
        scaleCircleIndex = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child = Expanded(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          double height = constraints.maxHeight;
          double width = constraints.maxWidth;
          return GestureDetector(
            onScaleStart: (ScaleStartDetails details) {
              inDoubleTapScaleCircle = false;

              if (details.pointerCount == 1) {
                DragStartDetails dragDetails = DragStartDetails(globalPosition: details.focalPoint, kind: PointerDeviceKind.touch);
                DragStartDetails hDragDetails = DragStartDetails(globalPosition: details.focalPoint, kind: PointerDeviceKind.touch);
                verticalTouchHandler.handleDragStart(dragDetails);
                horizontalTouchHandler.handleDragStart(hDragDetails);
              } else {
                distanceFromOffset = details.localFocalPoint.dy;
                horizontalDistanceFromOffset = details.localFocalPoint.dx;
                focalPointDistanceFromBottomFactor = (height - distanceFromOffset) / distanceFromOffset;
                horizontalFocalPointDistanceFromBottomFactor = (width - horizontalDistanceFromOffset) / horizontalDistanceFromOffset;
              }
            },
            onScaleUpdate: (ScaleUpdateDetails details) {
              if (details.pointerCount > 1) {
                double oldHeight = height * scale;
                double oldWidth = width * scale;
                if (lastScale / details.scale <= 1.0) {
                  setState(() {
                    scale = lastScale / details.scale;
                  });
                }
                //vertical offset
                final double newHeight = height * scale;
                verticalController.jumpTo(verticalController.offset + (oldHeight - newHeight) / (1 + focalPointDistanceFromBottomFactor));

                //horizontal offset
                final double newWidth = width * scale;
                horizontalController.jumpTo(horizontalController.offset + (oldWidth - newWidth) / (1 + horizontalFocalPointDistanceFromBottomFactor));
              } else {
                final Duration currentTime = Duration(milliseconds: DateTime.now().millisecondsSinceEpoch);
                final double correctedDelta = details.focalPointDelta.dy * scale;
                final Offset correctedOffset = details.focalPoint * scale;
                tracker.addPosition(currentTime, correctedOffset);
                final DragUpdateDetails verticalDetails =
                    DragUpdateDetails(globalPosition: correctedOffset, sourceTimeStamp: currentTime, primaryDelta: correctedDelta, delta: Offset(0.0, correctedDelta));
                final double horizontalCorrectedDelta = details.focalPointDelta.dx * scale;
                final DragUpdateDetails horizontalDetails = DragUpdateDetails(
                    globalPosition: correctedOffset, sourceTimeStamp: currentTime, primaryDelta: horizontalCorrectedDelta, delta: Offset(horizontalCorrectedDelta, 0.0));
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
            onDoubleTapDown: doubleTapScaleCircle.isEmpty
                ? null
                : (TapDownDetails details) {
                    distanceFromOffset = details.localPosition.dy;
                    horizontalDistanceFromOffset = details.localPosition.dx;
                    focalPointDistanceFromBottomFactor = (height - distanceFromOffset) / distanceFromOffset;
                    horizontalFocalPointDistanceFromBottomFactor = (width - horizontalDistanceFromOffset) / horizontalDistanceFromOffset;
                  },
            onDoubleTap: doubleTapScaleCircle.isEmpty
                ? null
                : () {
                    if (!inDoubleTapScaleCircle && scale == 1) {
                      inDoubleTapScaleCircle = true;
                      scaleCircleIndex = 0;
                    }

                    if (!inDoubleTapScaleCircle) {
                      setState(() {
                        lastScale = scale;
                        scale = 1;
                        inDoubleTapScaleCircle = true;
                        scaleCircleIndex = 0;
                      });
                      return;
                    }

                    double oldHeight = height * scale;
                    double oldWidth = width * scale;

                    setState(() {
                      scaleCircleIndex = (scaleCircleIndex + 1) % doubleTapScaleCircle.length;
                      lastScale = scale = 1 / doubleTapScaleCircle[scaleCircleIndex];
                    });

                    final double newHeight = height * scale;
                    verticalController.jumpTo(verticalController.offset + (oldHeight - newHeight) / (1 + focalPointDistanceFromBottomFactor));

                    final double newWidth = width * scale;
                    horizontalController.jumpTo(horizontalController.offset + (oldWidth - newWidth) / (1 + horizontalFocalPointDistanceFromBottomFactor));
                  },
            child: FittedBox(
              fit: BoxFit.fill,
              child: ScrollConfiguration(
                behavior: const ScrollBehavior().copyWith(overscroll: false, dragDevices: <PointerDeviceKind>{}),
                child: SizedBox(
                  height: height * scale,
                  width: width * scale,
                  child: ListView(
                    physics: const ClampingScrollPhysics(),
                    controller: widget.scrollAxis == Axis.vertical ? horizontalController : verticalController,
                    scrollDirection: widget.scrollAxis == Axis.vertical ? Axis.horizontal : Axis.vertical,
                    children: [
                      SizedBox(
                        width: widget.scrollAxis == Axis.vertical ? width : null,
                        height: widget.scrollAxis == Axis.vertical ? null : height,
                        child: widget.child,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );

    return widget.scrollAxis == Axis.vertical ? Column(children: [child]) : Row(children: [child]);
  }
}

final class _TouchHandler {
  final ScrollController controller;

  _TouchHandler({required this.controller});

  final GlobalKey<RawGestureDetectorState> _gestureDetectorKey = GlobalKey<RawGestureDetectorState>();
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
