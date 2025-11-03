Widget that allows both zooming and scrolling a `ListView`, or other `Scrollable`s such as scrollable_positioned_list.

## Features

Double tap to zoom, min and max scale, scroll a list of images, maintain standard ScrollPhysics and fling velocity, double tap and drag to zoom, listen to onScaleChanged and onScaleEnd callbacks, set zoom programatiaclly with ZoomViewController.

## Demo

<img src = "https://raw.githubusercontent.com/yakagami/zoom_view/main/zoomView.gif" width  = 300>

## Usage

### Using ListView

```dart
import 'package:flutter/material.dart';
import 'package:zoom_view/zoom_view.dart';

void main() {
  runApp(const MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ScrollController controller = ScrollController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //wrap with Expanded if in a Column or similar
      body: ZoomListView(
        child: ListView.builder(
            controller: controller,
            itemCount: 10000,
            itemBuilder: (context, index) {
              return Center(
                  child: Text("text $index")
              );
            }
        ),
      ),
    );
  }
}

```

Note that the `controller` argument most be set for your `ListView`.

### Using some other scrolling list

```dart

class ZoomViewExample extends StatefulWidget {
  const ZoomViewExample({super.key});

  @override
  State<ZoomViewExample> createState() => _ZoomViewExampleState();
}

class _ZoomViewExampleState extends State<ZoomViewExample> {
  ScrollController controller = ScrollController();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZoomView(
        controller: controller,
        child: ListView.builder(
            controller: controller,
            itemCount: 10000,
            itemBuilder: (context, index) {
              return Center(
                  child: Text("text $index")
              );
            }
        ),
      ),
    );
  }
}

```

Note that here the controller is given both to the ZoomView and the List.

### Double-tap to zoom

```dart

class ZoomViewExample extends StatefulWidget {
  const ZoomViewExample({super.key});

  @override
  State<ZoomViewExample> createState() => _ZoomViewExampleState();
}

class _ZoomViewExampleState extends State<ZoomViewExample> {
  ScrollController controller = ScrollController();
  final ZoomViewController _zoomViewController = ZoomViewController();
  late final ZoomViewGestureHandler handler;

  @override
  void initState() {
    super.initState();
    handler = ZoomViewGestureHandler(
        zoomLevels: [2, 1], controller: _zoomViewController);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZoomView(
        zoomViewController: _zoomViewController,
        controller: controller,
        onDoubleTap: (TapDownDetails details) {
          handler.onDoubleTap(details);
        },
        child: ListView.builder(
            controller: controller,
            itemCount: 10000,
            itemBuilder: (context, index) {
              return Center(child: Text("text $index"));
            }),
      ),
    );
  }
}


```

### Double-tap-drag:


```dart

class ZoomViewExample extends StatefulWidget {
  const ZoomViewExample({super.key});

  @override
  State<ZoomViewExample> createState() => _ZoomViewExampleState();
}

class _ZoomViewExampleState extends State<ZoomViewExample> {
  ScrollController controller = ScrollController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZoomView(
        controller: controller,
        doubleTapDrag: true,
        child: ListView.builder(
            controller: controller,
            itemCount: 10000,
            itemBuilder: (context, index) {
              return Center(
                  child: Text("text $index")
              );
            }
        ),
      ),
    );
  }
}

```

### ZoomViewController, ScaleChanged and ScaleEnd callbacks:

```dart

import 'package:flutter/material.dart';
import 'package:zoom_view/zoom_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZoomView Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const MyZoomablePage(),
    );
  }
}

class MyZoomablePage extends StatefulWidget {
  const MyZoomablePage({super.key});

  @override
  State<MyZoomablePage> createState() => _MyZoomablePageState();
}

class _MyZoomablePageState extends State<MyZoomablePage> {
  late final ZoomViewGestureHandler _zoomViewGestureHandler;
  late final ZoomViewController _zoomViewController;
  late final ScrollController _scrollController;

  bool _autoResetOnScaleEnd = false;

  @override
  void initState() {
    super.initState();
    _zoomViewController = ZoomViewController();
    _scrollController = ScrollController();
    _zoomViewGestureHandler = ZoomViewGestureHandler(
        zoomLevels: [2.0, 1.0], controller: _zoomViewController);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(
              Icons.replay,
              color: _autoResetOnScaleEnd
                  ? Theme.of(context).primaryColor
                  : Colors.grey,
            ),
            onPressed: () {
              setState(() {
                _autoResetOnScaleEnd = !_autoResetOnScaleEnd;
              });
            },
          ),
          IconButton(
              icon: const Icon(Icons.zoom_out),
              tooltip: 'Zoom Out',
              onPressed: () {
                final cs = _zoomViewController.scale;
                _zoomViewController.setScaleWithAnimation(cs - 0.6);
              }),
          IconButton(
              icon: const Icon(Icons.zoom_in),
              tooltip: 'Zoom In',
              onPressed: () {
                final cs = _zoomViewController.scale;
                _zoomViewController.setScaleWithAnimation(cs + 1.75);
              }),
        ],
      ),
      body: ZoomView(
        zoomViewController: _zoomViewController,
        minScale: 0.5,
        controller: _scrollController,
        onDoubleTap: (details) {
          print(details.localPosition);
          _zoomViewGestureHandler.onDoubleTap(details);
        },
        onScaleChanged: (scale) {
          print(scale);
        },
        onScaleEnd: (details) {
          print("scale end");
          print(details.pointerCount);
          if (_autoResetOnScaleEnd &&
              _zoomViewController.dragMode == DragMode.pinchScale) {
            _zoomViewController.setScale(1.0);
          }
        },
        doubleTapDrag: true,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: 50,
          itemBuilder: (context, index) {
            return Card(
              child: ListTile(
                leading: CircleAvatar(child: Text('${index + 1}')),
                title: Text('List Item ${index + 1}'),
                subtitle: const Text('This is a zoomable list item'),
              ),
            );
          },
        ),
      ),
    );
  }
}

```

### Using [ScrollablePositionedList](https://pub.dev/packages/scrollable_positioned_list)

You will need to use [this fork](https://github.com/yakagami/scrollable_positioned_list) of `scrollable_positioned_list` which exposes the list's `ScrollPosition` in `ScrollOffsetController`:

```yml

  scrollable_positioned_list:
    git: https://github.com/yakagami/scrollable_positioned_list

```

Alternatively, you can add expose the `ScrollPosition` in `ScrollOffsetController` yourself, found in scrollable_positioned_list/lib/src/scrollable_positioned_list.dart

```dart

  ScrollPosition get position => _scrollableListState!.primary.scrollController.position;

```

Then add this class to your project:

```dart

class ScrollOffsetToScrollController extends ScrollController{
  ScrollOffsetToScrollController({required this.scrollOffsetController});
  final ScrollOffsetController scrollOffsetController;

  @override
  ScrollPosition get position => scrollOffsetController.position;

  @override
  void jumpTo(double value){
    scrollOffsetController.jumpTo(value);
  }

  @override
  Future<void> animateTo(double offset, {required Curve curve, required Duration duration}){
    return scrollOffsetController.animateScroll(offset: offset, duration: duration);
  }
}

```

Usage:

```dart

final ScrollOffsetController scrollOffsetController = ScrollOffsetController();

ZoomView(
  controller: ScrollOffsetToScrollController(
    scrollOffsetController: scrollOffsetController,
  ),
  child: ScrollablePositionedList.builder(
    scrollOffsetController : scrollOffsetController,
    itemBuilder: (context, index) => Text('Item $index'),
  ),
),

```

