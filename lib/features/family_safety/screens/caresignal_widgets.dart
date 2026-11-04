import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../theme/care_colors.dart';
import '../theme/care_theme.dart';

class CareSignalBackBar extends StatelessWidget {
  const CareSignalBackBar({super.key, required this.onBack, this.trailing});

  final VoidCallback onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _RoundIcon(
          icon: Icons.arrow_back_rounded,
          onTap: onBack,
          background: CareColors.white,
          foreground: CareColors.navy,
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.onTap,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: CareColors.navySoft),
          ),
          child: Icon(icon, color: foreground, size: 21),
        ),
      ),
    );
  }
}

class CareSignalHero extends StatelessWidget {
  const CareSignalHero({
    super.key,
    required this.title,
    required this.subtitle,
    this.badge,
  });

  final String title;
  final String subtitle;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        gradient: CareTheme.heroGradient,
        borderRadius: BorderRadius.circular(CareTheme.radiusCard),
        boxShadow: [
          BoxShadow(
            color: CareColors.teal.withValues(alpha: 0.22),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.graphic_eq_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class CareSignalNeedHelpButton extends StatelessWidget {
  const CareSignalNeedHelpButton({
    super.key,
    required this.onPressed,
    this.enabled = true,
  });

  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      height: 72,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: CareColors.coral,
          foregroundColor: Colors.white,
          disabledBackgroundColor: CareColors.coral.withValues(alpha: 0.4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mic_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.careSignalNeedHelp,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class CareSignalStepList extends StatelessWidget {
  const CareSignalStepList({super.key, required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < steps.length; index++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    value: index == 0 ? null : 1,
                    color: CareColors.teal,
                    backgroundColor: CareColors.tealSoft,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    steps[index],
                    style: CareTheme.text(
                      context,
                      Theme.of(context).textTheme.bodyMedium,
                      size: 13.5,
                      weight: FontWeight.w600,
                      color: index == 0 ? CareColors.navy : CareColors.slate,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class CareSignalInfoCard extends StatelessWidget {
  const CareSignalInfoCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.iconColor = CareColors.teal,
    this.iconBackground = CareColors.seaMist,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: CareColors.ivory,
        borderRadius: BorderRadius.circular(CareTheme.radiusControl),
        border: Border.all(color: CareColors.navySoft),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 19),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: CareTheme.text(
                    context,
                    Theme.of(context).textTheme.bodySmall,
                    color: CareColors.slate,
                    size: 12,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: CareTheme.text(
                    context,
                    Theme.of(context).textTheme.bodyMedium,
                    color: valueColor ?? CareColors.navy,
                    size: 13,
                    weight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CareSignalActionList extends StatelessWidget {
  const CareSignalActionList({super.key, required this.actions});

  final List<String> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final action in actions)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: CareColors.mint,
                  size: 18,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    action,
                    style: CareTheme.text(
                      context,
                      Theme.of(context).textTheme.bodyMedium,
                      size: 13.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
