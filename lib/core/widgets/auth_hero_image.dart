import 'package:flutter/material.dart';

class AuthHeroImage extends StatelessWidget {
  const AuthHeroImage({
    super.key,
    this.maxWidthFactor = 0.86,
    this.heightFactor = 0.28,
    this.minHeight = 140,
    this.maxHeight = 260,
  });

  final double maxWidthFactor;
  final double heightFactor;
  final double minHeight;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final media = MediaQuery.of(context);
        final maxWidth = c.maxWidth.isFinite
            ? c.maxWidth
            : media.size.width;
        final targetWidth = maxWidth * maxWidthFactor;
        final desiredHeight = media.size.height * heightFactor;
        final clampedHeight = desiredHeight.clamp(minHeight, maxHeight);
        final aspect = 1.5;
        final widthByHeight = clampedHeight * aspect;
        final width = widthByHeight > targetWidth
            ? targetWidth
            : widthByHeight;
        final height = width / aspect;
        return SizedBox(
          width: targetWidth,
          height: clampedHeight,
          child: Center(
            child: SizedBox(
              width: width,
              height: height,
              child: Image.asset(
                'assets/images/img1.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
              ),
            ),
          ),
        );
      },
    );
  }
}
