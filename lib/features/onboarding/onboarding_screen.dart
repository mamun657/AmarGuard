import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/primary_button.dart';
import '../../l10n/generated/app_localizations.dart';
import 'onboarding_data.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  late final List<OnboardingPage> _pages;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;
    _pages = OnboardingPages.all(l10n);
  }

  void _next() {
    if (_index < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    } else {
      widget.onComplete();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;
    final media = MediaQuery.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              _ProgressDots(
                count: _pages.length,
                activeIndex: _index,
              ),
              SizedBox(height: media.size.height * 0.02),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final page = _pages[i];
                    return LayoutBuilder(
                      builder: (context, c) {
                        final maxVisualWidth = (c.maxWidth - 16).clamp(180.0, 360.0);
                        final targetVisualHeight = (c.maxHeight * 0.34)
                            .clamp(220.0, 270.0);
                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: c.maxHeight,
                            ),
                            child: Column(
                              children: [
                                SizedBox(height: c.maxHeight * 0.03),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: maxVisualWidth,
                                        maxHeight: targetVisualHeight,
                                      ),
                                      child: page.visual,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 22),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    page.title,
                                    textAlign: TextAlign.center,
                                    maxLines: 3,
                                    softWrap: true,
                                    style: const TextStyle(
                                      fontSize: 25,
                                      height: 1.2,
                                      letterSpacing: -0.3,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                  ),
                                  child: Text(
                                    page.subtitle,
                                    textAlign: TextAlign.center,
                                    softWrap: true,
                                    style: const TextStyle(
                                      fontSize: 14.5,
                                      height: 1.55,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              PrimaryButton(
                label: isLast ? l10n.onboardingGetStarted : l10n.onboardingNext,
                icon: isLast ? null : Icons.arrow_forward_rounded,
                onPressed: _next,
              ),
              const SizedBox(height: 10),
              if (!isLast)
                TextButton(
                  onPressed: widget.onComplete,
                  child: Text(
                    l10n.onboardingSkip,
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                const SizedBox(height: 44),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 240),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 28 : 10,
          height: 6,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.border,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
