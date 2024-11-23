import 'package:flutter/material.dart';

class ScannerOverlay extends StatelessWidget {
  const ScannerOverlay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.green, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.5 - 150,
          left: MediaQuery.of(context).size.width * 0.5 - 150,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 300),
            duration: const Duration(seconds: 2),
            curve: Curves.easeInOut,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: Container(
                  width: 300,
                  height: 2,
                  color: Colors.green,
                ),
              );
            },
            onEnd: () {
              (context as Element).markNeedsBuild();
            },
          ),
        ),
      ],
    );
  }
}
