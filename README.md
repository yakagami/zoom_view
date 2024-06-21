Widget that allows both zooming and scrolling a `ListView`, `ScrollablePositionedList` or other `Scrollable`s

![](https://raw.githubusercontent.com/yakagami/zoom_view/main/zoomView.gif)

## Features

Scroll a ListView while it is zoomed in with fling velocity

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


### Using [ScrollablePositionedList](https://pub.dev/packages/scrollable_positioned_list)

add this class:

```dart

class ScrollOffsetToScrollController extends ScrollController{
  ScrollOffsetToScrollController({required this.scrollOffsetController});
  final ScrollOffsetController scrollOffsetController;

  @override
  ScrollPosition get position => scrollOffsetController.position;

  @override
  double get offset => 0.0;

  @override
  void jumpTo(double value){
    scrollOffsetController.jumpTo(value);
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
