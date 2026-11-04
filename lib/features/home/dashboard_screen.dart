import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/generated/app_localizations.dart';
import 'widgets/service_icons.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.displayName,
    this.onMenuPressed,
    required this.onNotificationsPressed,
    this.showNotificationBadge = false,
    required this.onFamilySafetyPressed,
    required this.onCareSignalPressed,
    required this.onSilentSpeakPressed,
  });

  final String displayName;
  final VoidCallback? onMenuPressed;
  final VoidCallback onNotificationsPressed;
  final bool showNotificationBadge;
  final VoidCallback onFamilySafetyPressed;
  final VoidCallback onCareSignalPressed;
  final VoidCallback onSilentSpeakPressed;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final l10n = AppLocalizations.of(context)!;
    String greeting;
    final hour = DateTime.now().hour;
    if (hour < 12) {
      greeting = l10n.greetingMorning;
    } else if (hour < 17) {
      greeting = l10n.greetingAfternoon;
    } else {
      greeting = l10n.greetingEvening;
    }

    final horizontalPadding = media.size.width > 480 ? 24.0 : 20.0;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.only(
          left: horizontalPadding,
          right: horizontalPadding,
          bottom: 32,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            _DashboardHeader(
              onNotifications: onNotificationsPressed,
              showNotificationBadge: showNotificationBadge,
              tagline: l10n.brandTagline,
            ),
            const SizedBox(height: 20),
            _GreetingBlock(
              greeting: greeting,
              name: displayName.trim().isEmpty ? 'there' : displayName.trim(),
              safetyActive: l10n.safetyActive,
            ),
            const SizedBox(height: 20),
            _ProtectionCard(
              title: l10n.protectedTitle,
              body: l10n.protectedBody,
            ),
            const SizedBox(height: 24),
            _SectionTitle(title: l10n.quickActions),
            const SizedBox(height: 16),
            _QuickActionsGrid(
              onFamilySafetyPressed: onFamilySafetyPressed,
              onCareSignalPressed: onCareSignalPressed,
              onSilentSpeakPressed: onSilentSpeakPressed,
            ),
            const SizedBox(height: 20),
            StayAlertBanner(
              title: l10n.stayAlertTitle,
              body: l10n.stayAlertBody,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.onNotifications,
    required this.showNotificationBadge,
    required this.tagline,
  });

  final VoidCallback onNotifications;
  final bool showNotificationBadge;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(width: 44),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  children: [
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
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  tagline,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
        _IconCircle(
          icon: Icons.notifications_none_rounded,
          onTap: onNotifications,
          background: Colors.white,
          border: AppColors.border,
          foreground: AppColors.textPrimary,
          badge: showNotificationBadge,
        ),
      ],
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({
    required this.icon,
    required this.onTap,
    required this.background,
    required this.foreground,
    this.border,
    this.badge = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color background;
  final Color foreground;
  final Color? border;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(16),
                  border: border != null
                      ? Border.all(color: border!, width: 1)
                      : null,
                ),
                child: Icon(icon, color: foreground, size: 22),
              ),
              if (badge)
                Positioned(
                  right: 10,
                  top: 10,
                  child: Container(
                    key: const ValueKey<String>('home-notification-badge'),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GreetingBlock extends StatelessWidget {
  const _GreetingBlock({
    required this.greeting,
    required this.name,
    required this.safetyActive,
  });

  final String greeting;
  final String name;
  final String safetyActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border),
          ),
          child: const Center(
            child: Icon(
              Icons.person_rounded,
              size: 28,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontSize: isBangla ? 22 : 24,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                safetyActive,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: isBangla ? 12 : 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProtectionCard extends StatelessWidget {
  const _ProtectionCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.protectionBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.protectionAccent.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: AppColors.protectionAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.4,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.onFamilySafetyPressed,
    required this.onCareSignalPressed,
    required this.onSilentSpeakPressed,
  });

  final VoidCallback onFamilySafetyPressed;
  final VoidCallback onCareSignalPressed;
  final VoidCallback onSilentSpeakPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _FeatureCard(
                title: l10n.familySafetyTitle,
                subtitle: l10n.familySafetySubtitle,
                icon: FamilySafetyIcon(size: 52),
                background: const Color(0xFFE6F5F0),
                iconBackground: const Color(0xFFCDEBE1),
                accent: const Color(0xFF0D756D),
                onTap: onFamilySafetyPressed,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _FeatureCard(
                title: l10n.careSignalTitle,
                subtitle: l10n.careSignalSubtitle,
                icon: const Center(child: CareSignalIcon(size: 38)),
                background: const Color(0xFFFFF0EA),
                iconBackground: const Color(0xFFFFD8CF),
                accent: const Color(0xFFE66759),
                onTap: onCareSignalPressed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _SilentSpeakFeatureCard(onTap: onSilentSpeakPressed),
      ],
    );
  }
}

class _SilentSpeakFeatureCard extends StatelessWidget {
  const _SilentSpeakFeatureCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: const Color(0xFFF2ECFF),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 96),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD8C5FF)),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFFE2D4FF),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(child: const SilentSpeakIcon(size: 52)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.silentSpeakTitle,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.silentSpeakSubtitle,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: Color(0xFF673AB7)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.background,
    required this.iconBackground,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Widget icon;
  final Color background;
  final Color iconBackground;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 206,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(child: icon),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Center(
                  child: Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.openFeature,
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 14, color: accent),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StayAlertBanner extends StatelessWidget {
  const StayAlertBanner({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {},
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            color: AppColors.alertBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.alertAccent.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.lightbulb_outline_rounded,
                  color: AppColors.alertAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      maxLines: isBangla ? 3 : 2,
                      softWrap: true,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: isBangla ? 11.5 : 12,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecentActivityList extends StatelessWidget {
  const RecentActivityList({
    super.key,
    required this.callTitle,
    required this.screenshotTitle,
    required this.linkTitle,
    required this.highLabel,
    required this.mediumLabel,
    required this.lowLabel,
  });

  final String callTitle;
  final String screenshotTitle;
  final String linkTitle;
  final String highLabel;
  final String mediumLabel;
  final String lowLabel;

  @override
  Widget build(BuildContext context) {
    final items = [
      _ActivityItem(
        title: callTitle,
        subtitle: '+880 1XXX-XXXX',
        time: '10:42 AM',
        risk: highLabel,
        iconBuilder: AnalyzeCallIcon.new,
      ),
      _ActivityItem(
        title: screenshotTitle,
        subtitle: 'IMG_20250706_1032.jpg',
        time: 'Yesterday',
        risk: mediumLabel,
        iconBuilder: ScanScreenshotIcon.new,
      ),
      _ActivityItem(
        title: linkTitle,
        subtitle: 'bit.ly/special-offer',
        time: 'Jul 5, 2025',
        risk: highLabel,
        iconBuilder: CheckLinkIcon.new,
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            _ActivityRow(item: items[i]),
            if (i != items.length - 1)
              const Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: AppColors.border,
              ),
          ],
        ],
      ),
    );
  }
}

class _ActivityItem {
  const _ActivityItem({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.risk,
    required this.iconBuilder,
  });

  final String title;
  final String subtitle;
  final String time;
  final String risk;
  final Widget Function({double size, Color? color}) iconBuilder;
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.item});

  final _ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final riskColor = _resolveRiskColor(item.risk, l10n);

    final iconBg = _resolveRiskBg(item.risk, l10n);
    final iconColor = _resolveRiskFg(item.risk, l10n);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: item.iconBuilder(size: 24, color: iconColor)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.risk,
                style: TextStyle(
                  color: riskColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.time,
                style: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}

Color _resolveRiskColor(String risk, AppLocalizations l10n) {
  if (risk == l10n.riskHigh) return AppColors.danger;
  if (risk == l10n.riskMedium) return AppColors.warning;
  return AppColors.success;
}

Color _resolveRiskBg(String risk, AppLocalizations l10n) {
  if (risk == l10n.riskHigh) return AppColors.callBg;
  if (risk == l10n.riskMedium) return AppColors.messageBg;
  return AppColors.audioBg;
}

Color _resolveRiskFg(String risk, AppLocalizations l10n) {
  if (risk == l10n.riskHigh) return AppColors.callFg;
  if (risk == l10n.riskMedium) return AppColors.warning;
  return AppColors.audioFg;
}
