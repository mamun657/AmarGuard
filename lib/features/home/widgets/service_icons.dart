import 'package:flutter/material.dart';

class _ServiceIcon extends StatelessWidget {
  const _ServiceIcon({required this.asset, this.size = 56});
  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
    );
  }
}

class AnalyzeCallIcon extends StatelessWidget {
  const AnalyzeCallIcon({super.key, this.size = 56, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return _ServiceIcon(
      asset: 'assets/icons/analyze_call.png',
      size: size,
    );
  }
}

class CheckMessageIcon extends StatelessWidget {
  const CheckMessageIcon({super.key, this.size = 56, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return _ServiceIcon(
      asset: 'assets/icons/check_message.png',
      size: size,
    );
  }
}

class CheckLinkIcon extends StatelessWidget {
  const CheckLinkIcon({super.key, this.size = 56, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return _ServiceIcon(
      asset: 'assets/icons/check_link.png',
      size: size,
    );
  }
}

class ScanScreenshotIcon extends StatelessWidget {
  const ScanScreenshotIcon({super.key, this.size = 56, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return _ServiceIcon(
      asset: 'assets/icons/scan_screenshot.png',
      size: size,
    );
  }
}

class AnalyzeAudioIcon extends StatelessWidget {
  const AnalyzeAudioIcon({super.key, this.size = 56, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return _ServiceIcon(
      asset: 'assets/icons/analyze_audio.png',
      size: size,
    );
  }
}

class FamilySafetyIcon extends StatelessWidget {
  const FamilySafetyIcon({super.key, this.size = 56, this.color});
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return _ServiceIcon(
      asset: 'assets/icons/family_safety.png',
      size: size,
    );
  }
}
