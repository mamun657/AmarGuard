import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/generated/app_localizations.dart';
import 'models/service_definition.dart';
import 'widgets/maintenance_sheet.dart';
import 'widgets/service_icons.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.displayName,
    required this.onMenuPressed,
    required this.onNotificationsPressed,
  });

  final String displayName;
  final VoidCallback onMenuPressed;
  final VoidCallback onNotificationsPressed;

  String _firstName(String name) {
    final cleaned = name.trim();
    if (cleaned.isEmpty) return '';
    final parts = cleaned.split(RegExp(r'\s+'));
    return parts.first;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';

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
    final descriptionStyle = isBangla
        ? Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.3,
            )
        : Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12.5,
              color: AppColors.textSecondary,
              height: 1.3,
            );
    final titleStyle = isBangla
        ? Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.2,
            )
        : Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.1,
              height: 1.2,
            );

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
              onMenu: onMenuPressed,
              onNotifications: onNotificationsPressed,
              tagline: l10n.brandTagline,
            ),
            const SizedBox(height: 20),
            _GreetingBlock(
              greeting: greeting,
              name: _firstName(displayName),
              safetyActive: l10n.safetyActive,
            ),
            const SizedBox(height: 20),
            _ProtectionCard(
              title: l10n.protectedTitle,
              body: l10n.protectedBody,
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              title: l10n.quickActions,
              seeAll: l10n.seeAll,
            ),
            const SizedBox(height: 16),
            _QuickActionsGrid(
              titleStyle: titleStyle,
              descriptionStyle: descriptionStyle,
            ),
            const SizedBox(height: 24),
            _StayAlertBanner(
              title: l10n.stayAlertTitle,
              body: l10n.stayAlertBody,
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              title: l10n.recentActivity,
              seeAll: l10n.seeAll,
            ),
            const SizedBox(height: 14),
            _RecentActivityList(
              callTitle: l10n.activityCallTitle,
              screenshotTitle: l10n.activityScreenshotTitle,
              linkTitle: l10n.activityLinkTitle,
              highLabel: l10n.riskHigh,
              mediumLabel: l10n.riskMedium,
              lowLabel: l10n.riskLow,
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
    required this.onMenu,
    required this.onNotifications,
    required this.tagline,
  });

  final VoidCallback onMenu;
  final VoidCallback onNotifications;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconCircle(
          icon: Icons.menu_rounded,
          onTap: onMenu,
          background: Colors.white,
          border: AppColors.border,
          foreground: AppColors.textPrimary,
        ),
        const Spacer(),
        Column(
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
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                tagline,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ],
        ),
        const Spacer(),
        _IconCircle(
          icon: Icons.notifications_none_rounded,
          onTap: onNotifications,
          background: Colors.white,
          border: AppColors.border,
          foreground: AppColors.textPrimary,
          badge: true,
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
            child: Text(
              '🧑',
              style: TextStyle(fontSize: 30),
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
              Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontSize: isBangla ? 22 : 24,
                        height: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    '👋',
                    style: TextStyle(fontSize: 22),
                  ),
                ],
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
  const _SectionTitle({required this.title, required this.seeAll});

  final String title;
  final String seeAll;

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
        const SizedBox(width: 8),
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  seeAll,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.primaryDark,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.titleStyle,
    required this.descriptionStyle,
  });

  final TextStyle? titleStyle;
  final TextStyle? descriptionStyle;

  @override
  Widget build(BuildContext context) {
    final services = ServiceDefinition.all(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const gap = 8.0;
        final cell = (width - gap * 2) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: 14,
          children: services
              .map((s) => SizedBox(
                    width: cell,
                    child: _ServiceTile(
                      service: s,
                      titleStyle: titleStyle,
                      descriptionStyle: descriptionStyle,
                      onTap: () => MaintenanceSheet.show(context, service: s),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.service,
    required this.onTap,
    required this.titleStyle,
    required this.descriptionStyle,
  });

  final ServiceDefinition service;
  final VoidCallback onTap;
  final TextStyle? titleStyle;
  final TextStyle? descriptionStyle;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            children: [
              SizedBox(
                width: 58,
                height: 58,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: service.background,
                        shape: BoxShape.circle,
                      ),
                    ),
                    service.icon(size: 44),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                service.title(l10n),
                textAlign: TextAlign.center,
                maxLines: 2,
                softWrap: true,
                overflow: TextOverflow.visible,
                style: titleStyle,
              ),
              const SizedBox(height: 3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  service.description(l10n),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  style: descriptionStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StayAlertBanner extends StatelessWidget {
  const _StayAlertBanner({required this.title, required this.body});

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

class _RecentActivityList extends StatelessWidget {
  const _RecentActivityList({
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
            child: Center(
              child: item.iconBuilder(size: 24, color: iconColor),
            ),
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
