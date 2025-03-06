Widget that allows both zooming and scrolling a `ListView`, or other `Scrollable`s such as scrollable_positioned_list.

## Features

Double tap to zoom, min and max scale, scroll a list of images, maintain standard ScrollPhysics and fling velocity.

## Demo

![](https://raw.githubusercontent.com/yakagami/zoom_view/main/zoomView.gif)

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
  ZoomViewGestureHandler handler = ZoomViewGestureHandler(zoomLevels: [2,1]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ZoomView(
        controller: controller,
        onDoubleTapDown: (ZoomViewDetails zoomViewDetails){
           handler.onDoubleTap(zoomViewDetails);
        },
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
