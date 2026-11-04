import 'package:flutter/material.dart';

import 'care_colors.dart';

class CareTheme {
  CareTheme._();

  static const double radiusCard = 22;
  static const double radiusControl = 16;
  static const double radiusSheet = 26;
  static const double gap = 8;
  static const double pagePadding = 20;

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [CareColors.teal, CareColors.mint],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [CareColors.teal, CareColors.tealDeep],
  );

  static BoxDecoration cardDecoration({
    Color color = CareColors.white,
    Color borderColor = CareColors.navySoft,
    double radius = radiusCard,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor),
      boxShadow: [
        BoxShadow(
          color: CareColors.navy.withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  static TextStyle? text(
    BuildContext context,
    TextStyle? base, {
    Color color = CareColors.navy,
    double? size,
    FontWeight? weight,
    double? height,
  }) {
    final resolved =
        base ?? Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
    return resolved.copyWith(
      color: color,
      fontSize: size,
      fontWeight: weight,
      height: height,
    );
  }

  static ButtonStyle primaryButtonStyle({
    Color background = CareColors.teal,
    Color foreground = CareColors.white,
    Size minimumSize = const Size.fromHeight(54),
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      elevation: 0,
      minimumSize: minimumSize,
      textStyle: const TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w800,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
    );
  }

  static ButtonStyle dangerButtonStyle({
    Color background = CareColors.coral,
    Color foreground = CareColors.white,
  }) {
    return ElevatedButton.styleFrom(
      backgroundColor: background,
      foregroundColor: foreground,
      elevation: 0,
      minimumSize: const Size.fromHeight(54),
      textStyle: const TextStyle(
        fontSize: 15.5,
        fontWeight: FontWeight.w800,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
    );
  }

  static ButtonStyle secondaryButtonStyle({
    Color foreground = CareColors.teal,
    Color borderColor = CareColors.tealSoft,
    Size minimumSize = const Size.fromHeight(52),
  }) {
    return OutlinedButton.styleFrom(
      foregroundColor: foreground,
      side: BorderSide(color: borderColor, width: 1.4),
      minimumSize: minimumSize,
      textStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
      ),
    );
  }
}
