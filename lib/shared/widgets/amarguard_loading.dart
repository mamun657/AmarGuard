import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/generated/app_localizations.dart';

enum AmarGuardLoadingVariant { fullScreen, section, compact }

class AmarGuardLoading extends StatelessWidget {
  static const double _artworkScale = 2.2;

  const AmarGuardLoading({
    super.key,
    this.title,
    this.message,
    this.variant = AmarGuardLoadingVariant.fullScreen,
    this.width,
    this.height,
    this.background = false,
    this.transparent = false,
    this.alignment = Alignment.center,
    this.padding = EdgeInsets.zero,
  });

  final String? title;
  final String? message;
  final AmarGuardLoadingVariant variant;
  final double? width;
  final double? height;
  final bool background;
  final bool transparent;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry padding;

  double _animationWidth(BuildContext context) {
    if (width != null) return width!;
    return switch (variant) {
      AmarGuardLoadingVariant.fullScreen => 160.0,
      AmarGuardLoadingVariant.section => 72.0,
      AmarGuardLoadingVariant.compact => 36.0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isReducedMotion = MediaQuery.of(context).disableAnimations;
    final effectiveTitle = title ?? '';
    final effectiveMessage =
        message ?? (l10n?.loadingDefaultMessage ?? 'Loading...');
    final animationSize = _animationWidth(context);
    final displayWidth = width ?? animationSize;
    final displayHeight = height ?? animationSize;

    final content = Semantics(
      label: effectiveTitle.isEmpty ? effectiveMessage : effectiveTitle,
      value: effectiveTitle.isEmpty ? null : effectiveMessage,
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: displayWidth,
            height: displayHeight,
            child: ClipRect(
              child: Transform.scale(
                scale: _artworkScale,
                child: Lottie.asset(
                  'assets/images/loading.json',
                  key: const ValueKey<String>('amarguard-loading-animation'),
                  width: displayWidth,
                  height: displayHeight,
                  fit: BoxFit.contain,
                  repeat: true,
                  animate: !isReducedMotion,
                  errorBuilder: (context, error, stackTrace) {
                    return SizedBox(
                      width: displayWidth,
                      height: displayHeight,
                      child: const Icon(
                        Icons.hourglass_top_rounded,
                        size: 32,
                        color: AppColors.primary,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          if (effectiveTitle.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              effectiveTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
          if (effectiveMessage.isNotEmpty) ...[
            SizedBox(height: effectiveTitle.isEmpty ? 12 : 8),
            Text(
              effectiveMessage,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );

    final decoration = (background && !transparent)
        ? const BoxDecoration(color: AppColors.background)
        : null;

    return Container(
      padding: padding,
      decoration: decoration,
      child: Align(alignment: alignment, child: content),
    );
  }
}
