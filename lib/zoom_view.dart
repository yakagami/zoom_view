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
    return ZoomView(
      controller: widget.child.controller!,
      scrollAxis: widget.child.scrollDirection,
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
    this.onDoubleTapDown,
    this.scrollAxis = Axis.vertical,
  });

  ///This is set by the user but will generally be ZoomViewGestureHandler.onDoubleTap
  final void Function(ZoomViewDetails details)? onDoubleTapDown;
  final Widget child;
  final ScrollController controller;
  final Axis scrollAxis;

  @override
  State<ZoomView> createState() => _ZoomViewState();
}

class _ZoomViewState extends State<ZoomView>
    with SingleTickerProviderStateMixin {
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
    animationController = AnimationController(vsync: this);
    super.initState();
  }

  double scale = 1;
  double globalDistanceVertical = 0.0;
  double globalDistanceHorizontal = 0.0;

  late TrackPadState trackPadState;

  late PointerDeviceKind pointerDeviceKind;
  late AnimationController animationController;
  late ScrollController verticalController;
  late ScrollController horizontalController;
  late _TouchHandler verticalTouchHandler;
  late _TouchHandler horizontalTouchHandler;
  final VelocityTracker tracker =
      VelocityTracker.withKind(PointerDeviceKind.touch);

  late double distanceFromOffset;
  late double horizontalDistanceFromOffset;
  late double focalPointDistanceFromBottomFactor;
  late double horizontalFocalPointDistanceFromBottomFactor;

  late TapDownDetails _tapDownDetails;

  double lastScale = 1;

  void updateScale(double scale) {
    setState(() {
      this.scale = scale;
      this.lastScale = lastScale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
            double height = constraints.maxHeight;
            double width = constraints.maxWidth;
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
                  if (trackPadState == TrackPadState.waiting) {
                    if (details.scale != 1.0) {
                      trackPadState = TrackPadState.scale;
                    } else {
                      final double correctedDeltaVertical =
                          details.focalPointDelta.dy * scale;
                      globalDistanceVertical += correctedDeltaVertical;
                      final correctedDeltaHorizontal =
                          details.focalPointDelta.dx * scale;
                      globalDistanceHorizontal += correctedDeltaHorizontal;
                      if (globalDistanceVertical.abs() >
                              kPrecisePointerPanSlop ||
                          globalDistanceHorizontal.abs() >
                              kPrecisePointerPanSlop) {
                        trackPadState = TrackPadState.pan;
                        DragStartDetails dragDetails = DragStartDetails(
                            globalPosition: details.focalPoint,
                            kind: PointerDeviceKind.touch);
                        DragStartDetails hDragDetails = DragStartDetails(
                            globalPosition: details.focalPoint,
                            kind: PointerDeviceKind.touch);
                        verticalTouchHandler.handleDragStart(dragDetails);
                        horizontalTouchHandler.handleDragStart(hDragDetails);
                      }
                    }
                  } else if (details.pointerCount > 1 &&
                          trackPadState == TrackPadState.none ||
                      trackPadState == TrackPadState.scale) {
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
                    } else {
                      setState(() {
                        scale = 1.0;
                      });
                    }
                    //vertical offset
                    final double newHeight = height * scale;
                    verticalController.jumpTo(
                        verticalController.position.pixels +
                            (oldHeight - newHeight) /
                                (1 + focalPointDistanceFromBottomFactor));
                    //horizontal offset
                    final double newWidth = width * scale;
                    horizontalController.jumpTo(horizontalController.offset +
                        (oldWidth - newWidth) /
                            (1 + horizontalFocalPointDistanceFromBottomFactor));
                  } else if (trackPadState == TrackPadState.none ||
                      trackPadState == TrackPadState.pan) {
                    final double correctedDelta =
                        details.focalPointDelta.dy * scale;
                    final Offset correctedOffset = details.focalPoint * scale;
                    final time = details.sourceTimeStamp!;
                    tracker.addPosition(time, correctedOffset);
                    final DragUpdateDetails verticalDetails = DragUpdateDetails(
                        globalPosition: correctedOffset,
                        sourceTimeStamp: time,
                        primaryDelta: correctedDelta,
                        delta: Offset(0.0, correctedDelta));
                    final double horizontalCorrectedDelta =
                        details.focalPointDelta.dx * scale;
                    final DragUpdateDetails horizontalDetails =
                        DragUpdateDetails(
                            globalPosition: correctedOffset,
                            sourceTimeStamp: time,
                            primaryDelta: horizontalCorrectedDelta,
                            delta: Offset(horizontalCorrectedDelta, 0.0));
                    verticalTouchHandler.handleDragUpdate(verticalDetails);
                    horizontalTouchHandler.handleDragUpdate(horizontalDetails);
                  }
                },
                onScaleEnd: (ScaleEndDetails details) {
                  trackPadState = TrackPadState.none;
                  globalDistanceVertical = 0.0;
                  globalDistanceHorizontal = 0.0;
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
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: ScrollConfiguration(
                    behavior: const ScrollBehavior().copyWith(
                        overscroll: false, dragDevices: <PointerDeviceKind>{}),
                    child: SizedBox(
                      height: height * scale,
                      width: width * scale,
                      child: ListView(
                        padding: EdgeInsets.zero,
                        physics: const ClampingScrollPhysics(),
                        controller: widget.scrollAxis == Axis.vertical
                            ? horizontalController
                            : verticalController,
                        scrollDirection: widget.scrollAxis == Axis.vertical
                            ? Axis.horizontal
                            : Axis.vertical,
                        children: [
                          SizedBox(
                            width: widget.scrollAxis == Axis.vertical
                                ? width
                                : null,
                            height: widget.scrollAxis == Axis.vertical
                                ? null
                                : height,
                            child: widget.child,
                          ),
                        ],
                      ),
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
}

final class ZoomViewGestureHandler {
  int index = 0;
  final List<int> zoomLevels;
  final Duration duration;
  late ZoomViewDetails zoomViewDetails;
  void Function()? _animationListener;
  ZoomViewGestureHandler(
      {required this.zoomLevels,
      this.duration = const Duration(milliseconds: 100)});

  void onDoubleTap(ZoomViewDetails zoomViewDetails) {
    double newScale = 1 / zoomLevels[index];
    index++;
    if (index == zoomLevels.length) {
      index = 0;
    }

    final distanceFromOffset = zoomViewDetails.tapDownDetails.localPosition.dy;
    final horizontalDistanceFromOffset =
        zoomViewDetails.tapDownDetails.localPosition.dx;
    final focalPointDistanceFromBottomFactor =
        (zoomViewDetails.height - distanceFromOffset) / distanceFromOffset;
    final horizontalFocalPointDistanceFromBottomFactor =
        (zoomViewDetails.width - horizontalDistanceFromOffset) /
            horizontalDistanceFromOffset;
    final double oldHeight = zoomViewDetails.height * zoomViewDetails.scale;
    final double oldWidth = zoomViewDetails.width * zoomViewDetails.scale;
    final double newHeight = zoomViewDetails.height * newScale;
    final double newWidth = zoomViewDetails.width * newScale;
    final verticalOffset = zoomViewDetails.verticalController.offset +
        (oldHeight - newHeight) / (1 + focalPointDistanceFromBottomFactor);
    final horizontalOffset = zoomViewDetails.horizontalController.offset +
        (oldWidth - newWidth) /
            (1 + horizontalFocalPointDistanceFromBottomFactor);

    AnimationController animationController =
        zoomViewDetails.animationController;

    if (_animationListener != null) {
      animationController.removeListener(_animationListener!);
    }

    if (duration != const Duration(milliseconds: 0)) {
      animationController.value = zoomViewDetails.scale;

      _animationListener = () {
        zoomViewDetails.updateScale(animationController.value);
      };
      animationController.addListener(_animationListener!);

      animationController.animateTo(newScale,
          duration: duration, curve: Curves.linear);

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
