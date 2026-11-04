import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'A',
          style: TextStyle(
            fontSize: size * 0.55,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -1,
          ),
        ),
      ),
    );
  }
}

class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.fontSize = 32});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        children: const [
          TextSpan(
            text: 'Amar',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          TextSpan(
            text: 'Guard',
            style: TextStyle(color: AppColors.primaryDark),
          ),
        ],
      ),
    );
  }
}