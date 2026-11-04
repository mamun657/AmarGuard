import 'package:flutter/material.dart';

import '../models/family_models.dart';
import '../theme/care_colors.dart';
import '../theme/care_theme.dart';

class CareStatusPill extends StatelessWidget {
  const CareStatusPill({
    super.key,
    required this.label,
    required this.color,
    this.background,
    this.icon,
  });

  final String label;
  final Color color;
  final Color? background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background ?? color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CareSectionHeader extends StatelessWidget {
  const CareSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: CareTheme.text(
                  context,
                  Theme.of(context).textTheme.titleMedium,
                  size: 16,
                  weight: FontWeight.w800,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: CareTheme.text(
                    context,
                    Theme.of(context).textTheme.bodySmall,
                    color: CareColors.slate,
                    size: 12.5,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

class CareBatteryBadge extends StatelessWidget {
  const CareBatteryBadge({
    super.key,
    required this.level,
    required this.isCharging,
    this.compact = false,
  });

  final int level;
  final bool isCharging;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final health = _healthFor(level);
    final color = _colorFor(health);
    final icon = _iconFor(health, isCharging);
    final text = level >= 0 && level <= 100 ? '$level%' : '--';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: compact ? 13 : 15, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: compact ? 11.5 : 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

BatteryHealth _healthFor(int level) {
  if (level < 0 || level > 100) return BatteryHealth.unknown;
  if (level <= 5) return BatteryHealth.critical;
  if (level <= 20) return BatteryHealth.low;
  return BatteryHealth.healthy;
}

Color _colorFor(BatteryHealth health) {
  switch (health) {
    case BatteryHealth.healthy:
      return CareColors.teal;
    case BatteryHealth.low:
      return CareColors.gold;
    case BatteryHealth.critical:
      return CareColors.coral;
    case BatteryHealth.unknown:
      return CareColors.markerUnavailable;
  }
}

IconData _iconFor(BatteryHealth health, bool isCharging) {
  if (isCharging) return Icons.battery_charging_full_rounded;
  switch (health) {
    case BatteryHealth.healthy:
      return Icons.battery_full_rounded;
    case BatteryHealth.low:
      return Icons.battery_2_bar_rounded;
    case BatteryHealth.critical:
      return Icons.battery_alert_rounded;
    case BatteryHealth.unknown:
      return Icons.battery_unknown_rounded;
  }
}

class CareAvatar extends StatelessWidget {
  const CareAvatar({
    super.key,
    required this.name,
    this.size = 48,
    this.background,
    this.foreground = CareColors.white,
  });

  final String name;
  final double size;
  final Color? background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? CareColors.teal,
        shape: BoxShape.circle,
        border: Border.all(color: CareColors.white, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(name),
        style: TextStyle(
          color: foreground,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _initials(String value) {
    final parts = value.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return '${parts.first.substring(0, 1)}${parts[1].substring(0, 1)}'
        .toUpperCase();
  }
}

class CareEmptyState extends StatelessWidget {
  const CareEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: CareColors.seaMist,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: CareColors.teal),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: CareTheme.text(
                context,
                Theme.of(context).textTheme.titleLarge,
                size: 17,
                weight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: CareTheme.text(
                context,
                Theme.of(context).textTheme.bodyMedium,
                color: CareColors.slate,
                size: 13.5,
                height: 1.5,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class CareInfoTile extends StatelessWidget {
  const CareInfoTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: CareColors.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: CareTheme.text(
                context,
                Theme.of(context).textTheme.bodyMedium,
                color: CareColors.slate,
                size: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: CareTheme.text(
                context,
                Theme.of(context).textTheme.bodyMedium,
                color: valueColor ?? CareColors.navy,
                size: 13,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CareErrorBanner extends StatelessWidget {
  const CareErrorBanner({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel,
  });

  final String message;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: CareColors.coralSoft,
        borderRadius: BorderRadius.circular(CareTheme.radiusControl),
        border: Border.all(color: CareColors.coral.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: CareColors.coral,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: CareTheme.text(
                context,
                Theme.of(context).textTheme.bodyMedium,
                color: CareColors.navy,
                size: 13,
                height: 1.4,
              ),
            ),
          ),
          if (onRetry != null && retryLabel != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                foregroundColor: CareColors.coral,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                minimumSize: const Size(0, 36),
              ),
              child: Text(
                retryLabel!,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
