import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

class ZoomListView extends StatefulWidget {
  final ListView child;
  final double minScale;
  final double maxScale;
  const ZoomListView({
    super.key,
    required this.child,
    this.minScale = 1.0,
    this.maxScale = 4.0,
  });

  @override
  State<ZoomListView> createState() => _ZoomListViewState();
}

class _ZoomListViewState extends State<ZoomListView> {
  @override
  void initState() {
    if (widget.child.controller == null) {
      throw Exception(
        "List does not have a controller. Add a controller to your list",
      );
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ZoomView(
      controller: widget.child.controller!,
      scrollAxis: widget.child.scrollDirection,
      maxScale: widget.maxScale,
      minScale: widget.minScale,
      child: widget.child,
    );
  }
}

///Allows a ListView or other Scrollables that implement ScrollPosition and
///jumpTo(offset) in their controller to be zoomed and scrolled.
class ZoomView extends StatefulWidget {
  const ZoomView({
    super.key,
    required this.child,
    required this.controller,
    this.maxScale = 4.0,
    this.minScale = 1.0,
    this.onDoubleTapDown,
    this.scrollAxis = Axis.vertical,
  });

  ///This is set by the user but will generally be ZoomViewGestureHandler.onDoubleTap or null
  final void Function(ZoomViewDetails details)? onDoubleTapDown;
  final Widget child;
  final ScrollController controller;

  ///scrollAxis must be set to Axis.horizontal if the Scrollable is horizontal
  final Axis scrollAxis;
  final double maxScale;
  final double minScale;

  @override
  State<ZoomView> createState() => _ZoomViewState();
}

class _ZoomViewState extends State<ZoomView> with SingleTickerProviderStateMixin {
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
    animationController = AnimationController.unbounded(vsync: this);
    super.initState();
  }

  //The current scale of the ZoomView
  double scale = 1;
  double lastScale = 1;

  //Used for trackpad pointerEvents to determine if the user is panning or scaling
  late TrackPadState trackPadState;

  //Total distance the trackpad has moved vertically since the last scale start event
  double globalTrackpadDistanceVertical = 0.0;

  ///Total distance the trackpad has moved horizontally since the last scale start event
  double globalTrackpadDistanceHorizontal = 0.0;

  late PointerDeviceKind pointerDeviceKind;

  ///Used to by double tap to animate to a new scale.
  ///Does not animate the scroll positions
  late AnimationController animationController;

  late ScrollController verticalController;
  late ScrollController horizontalController;

  late _TouchHandler verticalTouchHandler;
  late _TouchHandler horizontalTouchHandler;

  final VelocityTracker tracker = VelocityTracker.withKind(
    PointerDeviceKind.touch,
  );

  ///The distance of the focal point from the bottom of the screen
  late double focalPointDistanceFromBottomFactor;

  ///The distance of the focal point from the right of the screen
  late double horizontalFocalPointDistanceFromBottomFactor;

  late TapDownDetails _tapDownDetails;

  void updateScale(double scale) {
    setState(() {
      this.scale = scale;
      lastScale = scale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        double height = constraints.maxHeight;
        double width = constraints.maxWidth;
        //The listener is only needed for trackpad events
        return Listener(
          onPointerDown: (PointerDownEvent event) {
            trackPadState = event.kind == PointerDeviceKind.trackpad
                ? TrackPadState.waiting
                : TrackPadState.none;
          },
          onPointerPanZoomStart: (PointerPanZoomStartEvent event) {
            trackPadState = event.kind == PointerDeviceKind.trackpad
                ? TrackPadState.waiting
                : TrackPadState.none;
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onScaleStart: (ScaleStartDetails details) {
              if (details.pointerCount == 1) {
                DragStartDetails dragDetails = DragStartDetails(
                  globalPosition: details.focalPoint,
                  kind: PointerDeviceKind.touch,
                );
                verticalTouchHandler.handleDragStart(dragDetails);
                horizontalTouchHandler.handleDragStart(dragDetails);
              } else {
                final distanceFromOffset = details.localFocalPoint.dy;
                final horizontalDistanceFromOffset = details.localFocalPoint.dx;
                focalPointDistanceFromBottomFactor =
                    (height - distanceFromOffset) / distanceFromOffset;
                horizontalFocalPointDistanceFromBottomFactor =
                    (width - horizontalDistanceFromOffset) / horizontalDistanceFromOffset;
              }
            },
            onScaleUpdate: (ScaleUpdateDetails details) {
              //If the trackpad has not moved enough to determine the
              //gesture type, then wait for it to move more
              if (trackPadState == TrackPadState.waiting) {
                //If the scale is not 1.0, then the user is scaling
                if (details.scale != 1.0) {
                  trackPadState = TrackPadState.scale;
                } else {
                  final double correctedDeltaVertical = details.focalPointDelta.dy * scale;
                  globalTrackpadDistanceVertical += correctedDeltaVertical;
                  final correctedDeltaHorizontal = details.focalPointDelta.dx * scale;
                  globalTrackpadDistanceHorizontal += correctedDeltaHorizontal;
                  if (globalTrackpadDistanceVertical.abs() > kPrecisePointerPanSlop ||
                      globalTrackpadDistanceHorizontal.abs() > kPrecisePointerPanSlop) {
                    trackPadState = TrackPadState.pan;
                    DragStartDetails dragDetails = DragStartDetails(
                      globalPosition: details.focalPoint,
                      kind: PointerDeviceKind.touch,
                    );
                    verticalTouchHandler.handleDragStart(dragDetails);
                    horizontalTouchHandler.handleDragStart(dragDetails);
                  }
                }
              } else if (details.pointerCount > 1 && trackPadState == TrackPadState.none ||
                  trackPadState == TrackPadState.scale) {
                double oldHeight = height * scale;
                double oldWidth = width * scale;
                final newScale = lastScale / details.scale;
                setState(() {
                  scale = _clampDouble(newScale, 1 / widget.maxScale, 1 / widget.minScale);
                });

                //vertical offset
                final double newHeight = height * scale;
                verticalController.jumpTo(
                  verticalController.position.pixels +
                      (oldHeight - newHeight) / (1 + focalPointDistanceFromBottomFactor),
                );

                //horizontal offset
                final double newWidth = width * scale;
                horizontalController.jumpTo(
                  horizontalController.offset +
                      (oldWidth - newWidth) / (1 + horizontalFocalPointDistanceFromBottomFactor),
                );
              } else if (trackPadState == TrackPadState.none ||
                  trackPadState == TrackPadState.pan) {
                final double correctedDelta = details.focalPointDelta.dy * scale;
                final Offset correctedOffset = details.focalPoint * scale;
                final time = details.sourceTimeStamp!;
                tracker.addPosition(time, correctedOffset);
                final DragUpdateDetails verticalDetails = DragUpdateDetails(
                  globalPosition: correctedOffset,
                  sourceTimeStamp: time,
                  primaryDelta: correctedDelta,
                  delta: Offset(0.0, correctedDelta),
                );
                final double horizontalCorrectedDelta = details.focalPointDelta.dx * scale;
                final DragUpdateDetails horizontalDetails = DragUpdateDetails(
                  globalPosition: correctedOffset,
                  sourceTimeStamp: time,
                  primaryDelta: horizontalCorrectedDelta,
                  delta: Offset(horizontalCorrectedDelta, 0.0),
                );
                verticalTouchHandler.handleDragUpdate(verticalDetails);
                horizontalTouchHandler.handleDragUpdate(horizontalDetails);
              }
            },
            onScaleEnd: (ScaleEndDetails details) {
              trackPadState = TrackPadState.none;
              globalTrackpadDistanceVertical = 0.0;
              globalTrackpadDistanceHorizontal = 0.0;
              lastScale = scale;
              Offset velocity = tracker.getVelocity().pixelsPerSecond;
              DragEndDetails endDetails = DragEndDetails(
                velocity: Velocity(pixelsPerSecond: Offset(0.0, velocity.dy)),
                primaryVelocity: velocity.dy,
              );
              DragEndDetails hEndDetails = DragEndDetails(
                velocity: Velocity(pixelsPerSecond: Offset(velocity.dx, 0.0)),
                primaryVelocity: velocity.dx,
              );
              verticalTouchHandler.handleDragEnd(endDetails);
              horizontalTouchHandler.handleDragEnd(hEndDetails);
            },
            onDoubleTapDown: widget.onDoubleTapDown == null
                ? null
                : (TapDownDetails details) {
                    _tapDownDetails = details;
                  },
            onDoubleTap: widget.onDoubleTapDown == null
                ? null
                : () {
                    ZoomViewDetails zoomViewDetails = ZoomViewDetails(
                      tapDownDetails: _tapDownDetails,
                      height: height,
                      width: width,
                      updateScale: updateScale,
                      verticalController: verticalController,
                      horizontalController: horizontalController,
                      animationController: animationController,
                      scale: scale,
                    );
                    setState(() {
                      widget.onDoubleTapDown!(zoomViewDetails);
                    });
                  },
            child: Column(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: ScrollConfiguration(
                      behavior: const ScrollBehavior().copyWith(
                        overscroll: false,
                        //Disable all inputs on the list as we will handle them
                        //ourselves using the gesture detector and scroll controllers
                        dragDevices: <PointerDeviceKind>{},
                      ),
                      child: SizedBox(
                        height: height * scale,
                        width: width * scale,
                        child: Center(
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            controller: widget.scrollAxis == Axis.vertical
                                ? horizontalController
                                : verticalController,
                            scrollDirection: widget.scrollAxis == Axis.vertical
                                ? Axis.horizontal
                                : Axis.vertical,
                            child: SizedBox(
                              width: widget.scrollAxis == Axis.vertical ? width : null,
                              height: widget.scrollAxis == Axis.vertical ? null : height,
                              child: widget.child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

///keeps record of the state of a trackpad. Should be set to none if
///the PointerDeviceKind is not a trackpad
enum TrackPadState { none, waiting, pan, scale }

final class ZoomViewDetails {
  final TapDownDetails tapDownDetails;
  final double height;
  final double width;
  final Function updateScale;
  final ScrollController verticalController;
  final ScrollController horizontalController;
  final AnimationController animationController;
  final double scale;
  ZoomViewDetails({
    required this.verticalController,
    required this.horizontalController,
    required this.tapDownDetails,
    required this.height,
    required this.width,
    required this.updateScale,
    required this.animationController,
    required this.scale,
  });

  double getVerticalOffset(double newScale) {
    final distanceFromOffset = tapDownDetails.localPosition.dy;
    final focalPointDistanceFromBottomFactor = (height - distanceFromOffset) / distanceFromOffset;
    final double oldHeight = height * scale;
    final double newHeight = height * newScale;
    final verticalOffset = verticalController.offset +
        (oldHeight - newHeight) / (1 + focalPointDistanceFromBottomFactor);
    return verticalOffset;
  }

  double getHorizontalOffset(double newScale) {
    final horizontalDistanceFromOffset = tapDownDetails.localPosition.dx;
    final horizontalFocalPointDistanceFromBottomFactor =
        (width - horizontalDistanceFromOffset) / horizontalDistanceFromOffset;
    final double oldWidth = width * scale;
    final double newWidth = width * newScale;
    final horizontalOffset = horizontalController.offset +
        (oldWidth - newWidth) / (1 + horizontalFocalPointDistanceFromBottomFactor);
    return horizontalOffset;
  }
}

final class ZoomViewGestureHandler {
  int index = 0;
  final List<double> zoomLevels;
  final Duration duration;
  late ZoomViewDetails zoomViewDetails;
  void Function()? _animationListener;
  ZoomViewGestureHandler({
    required this.zoomLevels,
    this.duration = const Duration(milliseconds: 100),
  });

  void onDoubleTap(ZoomViewDetails zoomViewDetails) {
    late double newScale;
    if (zoomViewDetails.scale > 1.0 && 1 == 1) {
      newScale = 1;
      index = 0;
    } else {
      newScale = 1 / zoomLevels[index];
      index++;
      if (index == zoomLevels.length) {
        index = 0;
      }
    }

    final verticalOffset = zoomViewDetails.getVerticalOffset(newScale);
    final horizontalOffset = zoomViewDetails.getHorizontalOffset(newScale);

    AnimationController animationController = zoomViewDetails.animationController;

    if (_animationListener != null) {
      animationController.removeListener(_animationListener!);
    }

    if (duration != const Duration(milliseconds: 0)) {
      animationController.value = zoomViewDetails.scale;

      _animationListener = () {
        zoomViewDetails.updateScale(animationController.value);
      };
      animationController.addListener(_animationListener!);

      animationController.animateTo(
        newScale,
        duration: duration,
        curve: Curves.linear,
      );

      _ZoomViewAnimateTo(
        scrollController: zoomViewDetails.verticalController,
        to: verticalOffset,
        duration: duration,
        curve: Curves.linear,
      );

      _ZoomViewAnimateTo(
        scrollController: zoomViewDetails.horizontalController,
        to: horizontalOffset,
        duration: duration,
        curve: Curves.linear,
      );
    } else {
      zoomViewDetails.updateScale(newScale);
      zoomViewDetails.horizontalController.jumpTo(horizontalOffset);
      zoomViewDetails.verticalController.jumpTo(verticalOffset);
    }
  }
}

class _ZoomViewAnimateTo {
  final ScrollController scrollController;
  final double to;
  final Duration duration;
  final Curve curve;
  late AnimationController controller;
  _ZoomViewAnimateTo({
    required this.scrollController,
    required this.to,
    required this.duration,
    required this.curve,
  }) {
    controller = AnimationController.unbounded(
      vsync: scrollController.position.context.vsync,
      value: scrollController.position.pixels,
    )
      ..addListener(() {
        tick();
      })
      ..animateTo(to, duration: duration, curve: curve);
  }
  void tick() {
    scrollController.jumpTo(controller.value);
  }
}

///Touch handlers coppied from Flutter ScrollableState
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

double _clampDouble(double x, double min, double max) {
  if (x < min) {
    return min;
  }
  if (x > max) {
    return max;
  }
  return x;
}
