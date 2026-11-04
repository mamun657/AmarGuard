import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../models/family_models.dart';
import '../theme/care_colors.dart';
import '../theme/care_theme.dart';
import '../widgets/care_widgets.dart';

class CareHeroHeader extends StatelessWidget {
  const CareHeroHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onBack,
    this.statusLabel,
    this.statusColor,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final String? statusLabel;
  final Color? statusColor;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 480;
    return Container(
      padding: EdgeInsets.fromLTRB(18, 18, 18, isWide ? 22 : 18),
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
              _CircleAction(
                icon: Icons.arrow_back_rounded,
                onTap: onBack,
                background: Colors.white.withValues(alpha: 0.22),
              ),
              const Spacer(),
              if (statusLabel != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor ?? Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          statusLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
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

class _CircleAction extends StatelessWidget {
  const _CircleAction({
    required this.icon,
    required this.onTap,
    required this.background,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color background;

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
          ),
          child: Icon(icon, color: Colors.white, size: 21),
        ),
      ),
    );
  }
}

class CareActionTile extends StatelessWidget {
  const CareActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.iconColor = CareColors.teal,
    this.iconBackground = CareColors.seaMist,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color iconColor;
  final Color iconBackground;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CareTheme.radiusControl),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: CareColors.white,
            borderRadius: BorderRadius.circular(CareTheme.radiusControl),
            border: Border.all(color: CareColors.navySoft),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CareTheme.text(
                        context,
                        Theme.of(context).textTheme.titleMedium,
                        size: 14.5,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: CareTheme.text(
                        context,
                        Theme.of(context).textTheme.bodySmall,
                        color: CareColors.slate,
                        size: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 10),
                trailing!,
              ] else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: CareColors.markerUnavailable,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CareMemberCard extends StatelessWidget {
  const CareMemberCard({
    super.key,
    required this.name,
    required this.relationshipLabel,
    required this.freshness,
    required this.freshnessLabel,
    required this.batteryLevel,
    required this.isCharging,
    required this.lastSeenLabel,
    required this.onTap,
  });

  final String name;
  final String relationshipLabel;
  final LocationFreshness freshness;
  final String freshnessLabel;
  final int batteryLevel;
  final bool isCharging;
  final String lastSeenLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = freshnessColor(freshness);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CareTheme.radiusControl),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: CareColors.white,
            borderRadius: BorderRadius.circular(CareTheme.radiusControl),
            border: Border.all(color: CareColors.navySoft),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CareAvatar(name: name, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CareTheme.text(
                        context,
                        Theme.of(context).textTheme.titleMedium,
                        size: 15,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      relationshipLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CareTheme.text(
                        context,
                        Theme.of(context).textTheme.bodySmall,
                        color: CareColors.slate,
                        size: 12.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        CareStatusPill(
                          label: freshnessLabel,
                          color: accent,
                          icon: freshnessIcon(freshness),
                        ),
                        CareBatteryBadge(
                          level: batteryLevel,
                          isCharging: isCharging,
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${AppLocalizations.of(context)!.careLastSeen}: $lastSeenLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CareTheme.text(
                        context,
                        Theme.of(context).textTheme.bodySmall,
                        color: CareColors.markerUnavailable,
                        size: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: CareColors.markerUnavailable,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color freshnessColor(LocationFreshness freshness) {
  switch (freshness) {
    case LocationFreshness.fresh:
      return CareColors.teal;
    case LocationFreshness.stale:
      return CareColors.gold;
    case LocationFreshness.unavailable:
      return CareColors.markerUnavailable;
    case LocationFreshness.paused:
      return CareColors.gold;
    case LocationFreshness.notConnected:
      return CareColors.markerUnavailable;
    case LocationFreshness.notConfigured:
      return CareColors.markerUnavailable;
    case LocationFreshness.permissionDisabled:
      return CareColors.coral;
  }
}

IconData freshnessIcon(LocationFreshness freshness) {
  switch (freshness) {
    case LocationFreshness.fresh:
      return Icons.wifi_tethering_rounded;
    case LocationFreshness.stale:
      return Icons.history_rounded;
    case LocationFreshness.unavailable:
      return Icons.cloud_off_rounded;
    case LocationFreshness.paused:
      return Icons.pause_circle_filled_rounded;
    case LocationFreshness.notConnected:
      return Icons.link_off_rounded;
    case LocationFreshness.notConfigured:
      return Icons.settings_suggest_rounded;
    case LocationFreshness.permissionDisabled:
      return Icons.lock_person_rounded;
  }
}

String freshnessLabelFor(
  BuildContext context,
  LocationFreshness freshness,
) {
  final l10n = AppLocalizations.of(context)!;
  switch (freshness) {
    case LocationFreshness.fresh:
      return l10n.careMemberFreshnessFresh;
    case LocationFreshness.stale:
      return l10n.careMemberFreshnessStale;
    case LocationFreshness.unavailable:
      return l10n.careMemberFreshnessUnavailable;
    case LocationFreshness.paused:
      return l10n.careMemberFreshnessPaused;
    case LocationFreshness.notConnected:
      return l10n.careMemberFreshnessNotConnected;
    case LocationFreshness.notConfigured:
      return l10n.careMemberFreshnessNotConfigured;
    case LocationFreshness.permissionDisabled:
      return l10n.careMemberFreshnessPermissionDisabled;
  }
}
