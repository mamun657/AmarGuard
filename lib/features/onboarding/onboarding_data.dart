import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';

class OnboardingPage {
  const OnboardingPage({
    required this.title,
    required this.subtitle,
    required this.visual,
  });

  final String title;
  final String subtitle;
  final Widget visual;
}

class OnboardingPages {
  OnboardingPages._();

  static List<OnboardingPage> all(AppLocalizations l10n) => [
        OnboardingPage(
          title: l10n.onboardingTitle1,
          subtitle: l10n.onboardingSubtitle1,
          visual: const _OnboardingAsset('assets/images/onb1.png'),
        ),
        OnboardingPage(
          title: l10n.onboardingTitle2,
          subtitle: l10n.onboardingSubtitle2,
          visual: const _OnboardingAsset('assets/images/img2.png'),
        ),
        OnboardingPage(
          title: l10n.onboardingTitle3,
          subtitle: l10n.onboardingSubtitle3,
          visual: const _OnboardingAsset('assets/images/onb3.png'),
        ),
      ];
}

class _OnboardingAsset extends StatelessWidget {
  const _OnboardingAsset(this.asset);

  final String asset;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      isAntiAlias: true,
    );
  }
}