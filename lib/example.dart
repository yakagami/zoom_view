import 'package:flutter/material.dart';
import 'package:zoom_view/zoom_view.dart';

class ZoomListViewExample extends StatefulWidget {
  const ZoomListViewExample({super.key});

  @override
  State<ZoomListViewExample> createState() => _ZoomListViewExampleState();
}

class _ZoomListViewExampleState extends State<ZoomListViewExample> {
  ScrollController controller = ScrollController();
  @override
  Widget build(BuildContext context) {
    return ZoomListView(
      child: ListView.builder(
          physics: const BouncingScrollPhysics(),
          controller: controller,
          itemCount: 100,
          itemBuilder: (context, index) {
            return Center(
                child: Text("text $index")
            );
          }
      ),
    );
  }
}
