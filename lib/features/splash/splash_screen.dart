import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/brand_logo.dart';
import '../../l10n/generated/app_localizations.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const _total = Duration(milliseconds: 2500);

  late final AnimationController _controller;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _shine;
  late final Animation<double> _wordmarkFade;
  late final Animation<Offset> _wordmarkSlide;
  late final Animation<double> _taglineFade;
  late final Animation<Offset> _taglineSlide;
  late final Animation<double> _indicatorFade;
  late final Animation<double> _indicatorScale;
  late final Animation<double> _creditFade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _total);

    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.12, 0.42, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.85, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.12, 0.42, curve: Curves.easeOutCubic),
      ),
    );
    _shine = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.28, 0.55, curve: Curves.easeInOut),
    );

    _wordmarkFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.40, 0.62, curve: Curves.easeOut),
    );
    _wordmarkSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.40, 0.62, curve: Curves.easeOutCubic),
      ),
    );

    _taglineFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.54, 0.76, curve: Curves.easeOut),
    );
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.10),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.54, 0.76, curve: Curves.easeOutCubic),
      ),
    );

    _indicatorFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.70, 0.88, curve: Curves.easeOut),
    );
    _indicatorScale = Tween<double>(begin: 0.7, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.70, 0.88, curve: Curves.easeOutCubic),
      ),
    );
    _creditFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.78, 0.95, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFBF4), Color(0xFFFFF3D9)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final logoSize = (maxWidth * 0.32).clamp(96.0, 140.0);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          FadeTransition(
                            opacity: _logoFade,
                            child: ScaleTransition(
                              scale: _logoScale,
                              child: _ShineLogo(
                                shine: _shine,
                                child: BrandLogo(size: logoSize),
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          SlideTransition(
                            position: _wordmarkSlide,
                            child: FadeTransition(
                              opacity: _wordmarkFade,
                              child: const BrandWordmark(fontSize: 36),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SlideTransition(
                            position: _taglineSlide,
                            child: FadeTransition(
                              opacity: _taglineFade,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                child: Text(
                                  l10n.brandTagline,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 2.2,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 28, top: 12),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          FadeTransition(
                            opacity: _indicatorFade,
                            child: ScaleTransition(
                              scale: _indicatorScale,
                              child: Container(
                                width: 30,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          FadeTransition(
                            opacity: _creditFade,
                            child: Text(
                              l10n.splashCredit,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textTertiary,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ShineLogo extends StatelessWidget {
  const _ShineLogo({required this.shine, required this.child});

  final Animation<double> shine;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shine,
      builder: (context, _) {
        final t = shine.value;
        if (t <= 0) return child;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) {
            final pos = -1.2 + t * 2.4;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0x00FFFFFF),
                Color(0x55FFFFFF),
                Color(0x00FFFFFF),
              ],
              stops: [
                (pos - 0.18).clamp(0.0, 1.0),
                pos.clamp(0.0, 1.0),
                (pos + 0.18).clamp(0.0, 1.0),
              ],
            ).createShader(rect);
          },
          child: child,
        );
      },
    );
  }
}
