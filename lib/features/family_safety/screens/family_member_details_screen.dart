import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../controllers/family_safety_controller.dart';
import '../models/family_models.dart';
import '../theme/care_colors.dart';
import '../theme/care_theme.dart';
import '../widgets/care_components.dart';
import '../widgets/care_formatters.dart';
import '../widgets/care_widgets.dart';

class FamilyMemberDetailsScreen extends StatelessWidget {
  const FamilyMemberDetailsScreen({
    super.key,
    required this.controller,
    required this.grant,
    this.connection,
    this.onEdit,
    this.onRemove,
  });

  final FamilySafetyController controller;
  final AccessGrant grant;
  final FamilyConnection? connection;
  final Future<void> Function(BuildContext context)? onEdit;
  final Future<void> Function(BuildContext context)? onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final presence = connection?.presence ?? DevicePresenceStatus.empty();
    final location = connection?.location;
    final freshness = connection?.freshness ?? _freshness(presence, location);
    final accent = freshnessColor(freshness);
    final name = connection?.viewerDisplayName ?? _displayName();
    final lastUpload = presence.lastSuccessfulUpload ??
        location?.syncedAt ??
        location?.capturedAt;

    return Scaffold(
      backgroundColor: CareColors.ivory,
      appBar: AppBar(
        backgroundColor: CareColors.ivory,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.careMemberDetailsTitle,
          style: const TextStyle(
            color: CareColors.navy,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
              decoration: BoxDecoration(
                gradient: CareTheme.heroGradient,
                borderRadius: BorderRadius.circular(CareTheme.radiusCard),
              ),
              child: Row(
                children: [
                  CareAvatar(
                    name: name,
                    size: 58,
                    background: Colors.white.withValues(alpha: 0.24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          relationshipLabel(context, grant.relationship),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
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
                            freshnessLabelFor(context, freshness),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            if (lastUpload == null)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: CareTheme.cardDecoration(),
                child: CareEmptyState(
                  icon: Icons.location_off_rounded,
                  title: l10n.careNoLocationYet,
                  message: l10n.careNoLocationYetBody,
                ),
              )
            else
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: CareTheme.cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CareSectionHeader(
                      title: l10n.careCoordinates,
                      trailing: CareStatusPill(
                        label: freshnessLabelFor(context, freshness),
                        color: accent,
                        icon: freshnessIcon(freshness),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 14,
                      ),
                      decoration: BoxDecoration(
                        color: CareColors.seaMist,
                        borderRadius: BorderRadius.circular(
                          CareTheme.radiusControl,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            formatCoordinates(
                              location?.latitude ?? 0,
                              location?.longitude ?? 0,
                            ),
                            style: const TextStyle(
                              color: CareColors.navy,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    CareInfoTile(
                      icon: Icons.straighten_rounded,
                      label: l10n.careMapAccuracy,
                      value: location == null
                          ? '--'
                          : '${location.accuracy.round()} m',
                    ),
                    CareInfoTile(
                      icon: Icons.schedule_rounded,
                      label: l10n.careSyncTime,
                      value: formatDateTime(context, lastUpload),
                    ),
                    CareInfoTile(
                      icon: Icons.battery_charging_full_rounded,
                      label: l10n.careBattery,
                      value: presence.batteryLevel >= 0
                          ? '${presence.batteryLevel}%'
                          : '--',
                      valueColor: _batteryColor(presence.batteryLevel),
                    ),
                    CareInfoTile(
                      icon: Icons.power_rounded,
                      label: l10n.careLiveStatus,
                      value: presence.isCharging
                          ? l10n.careCharging
                          : l10n.careNotCharging,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 14),
            if (connection != null && (onEdit != null || onRemove != null))
              Row(
                children: [
                  if (onEdit != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onEdit == null
                            ? null
                            : () => onEdit!(context),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit name'),
                      ),
                    ),
                  if (onEdit != null && onRemove != null)
                    const SizedBox(width: 10),
                  if (onRemove != null)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onRemove == null
                            ? null
                            : () => onRemove!(context),
                        icon: const Icon(Icons.link_off_rounded),
                        label: const Text('Remove'),
                      ),
                    ),
                ],
              ),
            if (connection != null) const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: CareTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CareSectionHeader(title: l10n.careDeviceNickname),
                  const SizedBox(height: 8),
                  CareInfoTile(
                    icon: Icons.smartphone_rounded,
                    label: l10n.careDeviceNickname,
                    value:
                        connection?.deviceNickname ??
                        controller.deviceIdentity?.nickname ??
                        l10n.careMyDevice,
                  ),
                  CareInfoTile(
                    icon: Icons.person_outline_rounded,
                    label: l10n.careMemberSince(
                      formatDateTime(context, grant.grantedAt),
                    ),
                    value: relationshipLabel(context, grant.relationship),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayName() {
    final name = grant.viewerDisplayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = grant.viewerEmail?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Family member';
  }

  LocationFreshness _freshness(
    DevicePresenceStatus presence,
    SharedLocationRecord? location,
  ) {
    switch (presence.sharingState) {
      case SharingState.paused:
        return LocationFreshness.paused;
      case SharingState.permissionDisabled:
        return LocationFreshness.permissionDisabled;
      case SharingState.active:
        if (location == null) return LocationFreshness.unavailable;
        return LocationFreshnessEvaluator.evaluate(
          capturedAt: location.capturedAt,
          syncedAt: location.syncedAt,
          now: DateTime.now().toUtc(),
        );
      case SharingState.stopped:
      case SharingState.notConfigured:
        return LocationFreshness.notConnected;
    }
  }

  Color _batteryColor(int level) {
    if (level < 0) return CareColors.markerUnavailable;
    if (level <= 5) return CareColors.coral;
    if (level <= 20) return CareColors.gold;
    return CareColors.teal;
  }
}
