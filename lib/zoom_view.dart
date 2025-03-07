import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';

///Wrapper for [ZoomView] that handles the controller automatically
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

class _ZoomViewState extends State<ZoomView> with TickerProviderStateMixin {
  @override
  void initState() {
    if (widget.scrollAxis == Axis.vertical) {
      _verticalController = widget.controller;
      _horizontalController = ScrollController();
    } else {
      _verticalController = ScrollController();
      _horizontalController = widget.controller;
    }
    _verticalTouchHandler = _TouchHandler(controller: _verticalController);
    _horizontalTouchHandler = _TouchHandler(controller: _horizontalController);
    _animationController = AnimationController.unbounded(vsync: this)
      ..addListener(() {
        _updateScale(_animationController.value);
      });

    //The controllers do not attach until after the first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _verticalAnimationController =
          AnimationController.unbounded(vsync: _verticalController.position.context.vsync)
            ..addListener(() {
              _verticalController.jumpTo(_verticalAnimationController.value);
            });

      _horizontalAnimationController =
          AnimationController.unbounded(vsync: _horizontalController.position.context.vsync)
            ..addListener(() {
              _horizontalController.jumpTo(_horizontalAnimationController.value);
            });
    });

    super.initState();
  }

  ///The current scale of the ZoomView
  double _scale = 1;

  ///The scale of the ZoomView before the last scale update event
  double _lastScale = 1;

  ///Used for trackpad pointerEvents to determine if the user is panning or scaling
  late TrackPadState _trackPadState;

  ///Total distance the trackpad has moved vertically since the last scale start event
  double _globalTrackpadDistanceVertical = 0.0;

  ///Total distance the trackpad has moved horizontally since the last scale start event
  double _globalTrackpadDistanceHorizontal = 0.0;

  ///Used to by double tap to animate to a new scale
  late final AnimationController _animationController;

  ///Used by double tap to animate the vertical scroll position
  late final AnimationController _verticalAnimationController;

  ///Used by double tap to animate the horizontal scroll position
  late final AnimationController _horizontalAnimationController;

  late final ScrollController _verticalController;
  late final ScrollController _horizontalController;

  late final _TouchHandler _verticalTouchHandler;
  late final _TouchHandler _horizontalTouchHandler;

  final VelocityTracker _tracker = VelocityTracker.withKind(
    PointerDeviceKind.touch,
  );

  late TapDownDetails _tapDownDetails;

  ///The focal point of pointers at the start of a scale event
  late Offset _localFocalPoint;

  void _updateScale(double scale) {
    setState(() {
      this._scale = scale;
      _lastScale = scale;
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
          behavior: HitTestBehavior.translucent,
          onPointerDown: (PointerDownEvent event) {
            _trackPadState = event.kind == PointerDeviceKind.trackpad
                ? TrackPadState.waiting
                : TrackPadState.none;
          },
          onPointerPanZoomStart: (PointerPanZoomStartEvent event) {
            _trackPadState = event.kind == PointerDeviceKind.trackpad
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
                _verticalTouchHandler.handleDragStart(dragDetails);
                _horizontalTouchHandler.handleDragStart(dragDetails);
              } else {
                _localFocalPoint = details.localFocalPoint;
              }
            },
            onScaleUpdate: (ScaleUpdateDetails details) {
              //If the trackpad has not moved enough to determine the
              //gesture type, then wait for it to move more
              if (_trackPadState == TrackPadState.waiting) {
                if (details.scale != 1.0) {
                  _trackPadState = TrackPadState.scale;
                } else {
                  final double correctedDeltaVertical = details.focalPointDelta.dy * _scale;
                  _globalTrackpadDistanceVertical += correctedDeltaVertical;
                  final correctedDeltaHorizontal = details.focalPointDelta.dx * _scale;
                  _globalTrackpadDistanceHorizontal += correctedDeltaHorizontal;
                  if (_globalTrackpadDistanceVertical.abs() > kPrecisePointerPanSlop ||
                      _globalTrackpadDistanceHorizontal.abs() > kPrecisePointerPanSlop) {
                    _trackPadState = TrackPadState.pan;
                    DragStartDetails dragDetails = DragStartDetails(
                      globalPosition: details.focalPoint,
                      kind: PointerDeviceKind.touch,
                    );
                    _verticalTouchHandler.handleDragStart(dragDetails);
                    _horizontalTouchHandler.handleDragStart(dragDetails);
                  }
                }
              } else if (details.pointerCount > 1 && _trackPadState == TrackPadState.none ||
                  _trackPadState == TrackPadState.scale) {
                final newScale = _clampDouble(
                    _lastScale / details.scale, 1 / widget.maxScale, 1 / widget.minScale);
                final verticalOffset =
                    _verticalController.position.pixels + (_scale - newScale) * _localFocalPoint.dy;
                final horizontalOffset = _horizontalController.position.pixels +
                    (_scale - newScale) * _localFocalPoint.dx;
                //This is the main logic to actually perform the scaling
                setState(() {
                  _scale = newScale;
                });
                _verticalController.jumpTo(verticalOffset);
                _horizontalController.jumpTo(horizontalOffset);
              } else {
                final double correctedDelta = details.focalPointDelta.dy * _scale;
                final Offset correctedOffset = details.focalPoint * _scale;
                final time = details.sourceTimeStamp!;
                _tracker.addPosition(time, correctedOffset);
                final DragUpdateDetails verticalDetails = DragUpdateDetails(
                  globalPosition: correctedOffset,
                  sourceTimeStamp: time,
                  primaryDelta: correctedDelta,
                  delta: Offset(0.0, correctedDelta),
                );
                final double horizontalCorrectedDelta = details.focalPointDelta.dx * _scale;
                final DragUpdateDetails horizontalDetails = DragUpdateDetails(
                  globalPosition: correctedOffset,
                  sourceTimeStamp: time,
                  primaryDelta: horizontalCorrectedDelta,
                  delta: Offset(horizontalCorrectedDelta, 0.0),
                );
                _verticalTouchHandler.handleDragUpdate(verticalDetails);
                _horizontalTouchHandler.handleDragUpdate(horizontalDetails);
              }
            },
            onScaleEnd: (ScaleEndDetails details) {
              _trackPadState = TrackPadState.none;
              _globalTrackpadDistanceVertical = 0.0;
              _globalTrackpadDistanceHorizontal = 0.0;
              _lastScale = _scale;
              Offset velocity = _tracker.getVelocity().pixelsPerSecond;
              DragEndDetails endDetails = DragEndDetails(
                velocity: Velocity(pixelsPerSecond: Offset(0.0, velocity.dy)),
                primaryVelocity: velocity.dy,
              );
              DragEndDetails hEndDetails = DragEndDetails(
                velocity: Velocity(pixelsPerSecond: Offset(velocity.dx, 0.0)),
                primaryVelocity: velocity.dx,
              );
              _verticalTouchHandler.handleDragEnd(endDetails);
              _horizontalTouchHandler.handleDragEnd(hEndDetails);
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
                      height: height,
                      width: width,
                      scale: _scale,
                      updateScale: _updateScale,
                      tapDownDetails: _tapDownDetails,
                      verticalController: _verticalController,
                      horizontalController: _horizontalController,
                      animationController: _animationController,
                      verticalAnimationController: _verticalAnimationController,
                      horizontalAnimationController: _horizontalAnimationController,
                    );
                    setState(() {
                      widget.onDoubleTapDown!(zoomViewDetails);
                    });
                  },
            child: Column(
              children: [
                Expanded(
                  //When scale decreases, the SizedBox will shrink and the FittedBox
                  //will scale the child to fit the maximum constraints of the ZoomView
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox(
                      height: height * _scale,
                      width: width * _scale,
                      child: Center(
                        child: ScrollConfiguration(
                          behavior: const ScrollBehavior().copyWith(
                            overscroll: false,
                            //Disable all inputs on the list as we will handle them
                            //ourselves using the gesture detector and scroll controllers
                            dragDevices: <PointerDeviceKind>{},
                            scrollbars: false,
                          ),
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            controller: widget.scrollAxis == Axis.vertical
                                ? _horizontalController
                                : _verticalController,
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

///Details needed to perform a double tap zoom
final class ZoomViewDetails {
  final TapDownDetails tapDownDetails;
  final double height;
  final double width;
  final Function updateScale;
  final ScrollController verticalController;
  final ScrollController horizontalController;
  final AnimationController animationController;
  final AnimationController verticalAnimationController;
  final AnimationController horizontalAnimationController;
  final double scale;
  ZoomViewDetails({
    required this.verticalController,
    required this.horizontalController,
    required this.tapDownDetails,
    required this.height,
    required this.width,
    required this.updateScale,
    required this.animationController,
    required this.verticalAnimationController,
    required this.horizontalAnimationController,
    required this.scale,
  });

  ///Calculates the new vertical offset for the scroll controller
  double getVerticalOffset(double newScale) {
    return verticalController.position.pixels +
        (scale - newScale) * tapDownDetails.localPosition.dy;
  }

  ///Calculates the new horizontal offset for the scroll controller
  double getHorizontalOffset(double newScale) {
    return horizontalController.position.pixels +
        (scale - newScale) * tapDownDetails.localPosition.dx;
  }
}

///Handles the logic for a double tap zoom via the [ZoomView.onDoubleTapDown] callback
final class ZoomViewGestureHandler {
  int _index = 0;
  final List<double> zoomLevels;
  final Duration duration;
  ZoomViewGestureHandler({
    required this.zoomLevels,
    this.duration = const Duration(milliseconds: 100),
  });

  void onDoubleTap(ZoomViewDetails zoomViewDetails) {
    late double newScale;
    if (zoomViewDetails.scale > 1.0 && 1 == 1) {
      newScale = 1;
      _index = 0;
    } else {
      newScale = 1 / zoomLevels[_index];
      _index++;
      if (_index == zoomLevels.length) {
        _index = 0;
      }
    }

    final verticalOffset = zoomViewDetails.getVerticalOffset(newScale);
    final horizontalOffset = zoomViewDetails.getHorizontalOffset(newScale);

    if (duration != const Duration(milliseconds: 0)) {
      zoomViewDetails.animationController
        ..value = zoomViewDetails.scale
        ..animateTo(
          newScale,
          duration: duration,
          curve: Curves.linear,
        );

      zoomViewDetails.verticalAnimationController
        ..value = zoomViewDetails.verticalController.position.pixels
        ..animateTo(
          verticalOffset,
          duration: duration,
          curve: Curves.linear,
        );

      zoomViewDetails.horizontalAnimationController
        ..value = zoomViewDetails.horizontalController.position.pixels
        ..animateTo(
          horizontalOffset,
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
