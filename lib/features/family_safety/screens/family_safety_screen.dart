import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../controllers/family_safety_controller.dart';
import '../models/family_models.dart';
import '../theme/care_colors.dart';
import '../theme/care_theme.dart';
import '../widgets/care_components.dart';
import '../widgets/care_formatters.dart';
import '../widgets/care_widgets.dart';
import '../../../shared/widgets/amarguard_loading.dart';
import 'family_invitation_screen.dart';
import 'family_map_screen.dart';
import 'family_members_screen.dart';
import 'family_privacy_screen.dart';

class FamilySafetyScreen extends StatefulWidget {
  const FamilySafetyScreen({
    super.key,
    required this.controller,
    required this.isGuest,
  });

  final FamilySafetyController controller;
  final bool isGuest;

  @override
  State<FamilySafetyScreen> createState() => _FamilySafetyScreenState();
}

class _FamilySafetyScreenState extends State<FamilySafetyScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.controller.initialize(isGuest: widget.isGuest);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = widget.controller;

    if (widget.isGuest) {
      return _GuestBlockedScaffold(onBack: () => Navigator.of(context).pop());
    }

    return Scaffold(
      backgroundColor: CareColors.ivory,
      body: SafeArea(
        bottom: false,
        child: controller.loadState == CareLoadState.loading
            ? Center(
                child: AmarGuardLoading(
                  variant: AmarGuardLoadingVariant.fullScreen,
                  width: 160,
                  height: 160,
                  title: '',
                  message: l10n.careLoading,
                ),
              )
            : RefreshIndicator(
                color: CareColors.teal,
                onRefresh: controller.refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
                  children: [
                    CareHeroHeader(
                      title: l10n.careTitle,
                      subtitle: l10n.careTagline,
                      onBack: () => Navigator.of(context).pop(),
                      statusLabel: _sharingLabel(
                        l10n,
                        controller.sharingState,
                        controller.isSyncStale,
                      ),
                      statusColor: _sharingColor(controller.sharingState),
                    ),
                    const SizedBox(height: 20),
                    _MyDeviceCard(controller: controller),
                    if (controller.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: CareColors.coral.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: CareColors.coral.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: CareColors.coral,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                controller.errorMessage!,
                                style: const TextStyle(
                                  color: CareColors.navy,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: controller.refresh,
                              child: Text(l10n.careRetry),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    CareSectionHeader(
                      title: l10n.careConnectedMembers,
                      subtitle: l10n.careFamilyMembersSubtitle,
                      trailing: _MemberCountBadge(
                        count: {
                          ...controller.authorizedConnections.map(
                            (item) => item.memberKey,
                          ),
                          ...controller.grants
                              .where((grant) => grant.active)
                              .map(
                                (grant) =>
                                    '${grant.ownerUid}__${grant.deviceId}',
                              ),
                        }.length,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ConnectedMembersSection(controller: controller),
                    const SizedBox(height: 20),
                    CareActionTile(
                      icon: Icons.person_add_alt_1_rounded,
                      title: l10n.careAddMember,
                      subtitle: l10n.careAddFamilyMemberSubtitle,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              FamilyInvitationScreen(controller: controller),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CareActionTile(
                      icon: Icons.map_rounded,
                      title: l10n.careViewMap,
                      subtitle: l10n.careFamilyMembersSubtitle,
                      iconColor: CareColors.tealDeep,
                      iconBackground: CareColors.tealSoft,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              FamilyMapScreen(controller: controller),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CareActionTile(
                      icon: Icons.privacy_tip_rounded,
                      title: l10n.carePrivacySettings,
                      subtitle: l10n.carePrivacyWhoCanViewBody,
                      iconColor: CareColors.gold,
                      iconBackground: CareColors.goldSoft,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              FamilyPrivacyScreen(controller: controller),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  String _sharingLabel(
    AppLocalizations l10n,
    SharingState state,
    bool isSyncStale,
  ) {
    switch (state) {
      case SharingState.active:
        return isSyncStale ? l10n.careSharingStale : l10n.careSharingActive;
      case SharingState.paused:
        return l10n.careSharingPaused;
      case SharingState.stopped:
        return l10n.careSharingStopped;
      case SharingState.permissionDisabled:
        return l10n.carePermissionDisabled;
      case SharingState.notConfigured:
        return l10n.careSharingNotConfigured;
    }
  }

  Color _sharingColor(SharingState state) {
    switch (state) {
      case SharingState.active:
        return Colors.white;
      case SharingState.paused:
        return CareColors.gold;
      case SharingState.stopped:
        return Colors.white70;
      case SharingState.permissionDisabled:
        return CareColors.coral;
      case SharingState.notConfigured:
        return Colors.white70;
    }
  }
}

class _MemberCountBadge extends StatelessWidget {
  const _MemberCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: CareColors.seaMist,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: CareColors.teal,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MyDeviceCard extends StatelessWidget {
  const _MyDeviceCard({required this.controller});

  final FamilySafetyController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final identity = controller.deviceIdentity;
    final state = controller.sharingState;
    final isActive = state == SharingState.active;
    final isPaused = state == SharingState.paused;
    final canStart =
        state == SharingState.stopped ||
        state == SharingState.notConfigured ||
        state == SharingState.permissionDisabled;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: CareTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: CareColors.seaMist,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.smartphone_rounded,
                  color: CareColors.teal,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.careMyDevice,
                      style: CareTheme.text(
                        context,
                        Theme.of(context).textTheme.bodySmall,
                        color: CareColors.slate,
                        size: 12,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      identity?.nickname ?? l10n.careMyDevice,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CareTheme.text(
                        context,
                        Theme.of(context).textTheme.titleLarge,
                        size: 16.5,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              CareStatusPill(
                label: _statusText(l10n, state),
                color: _statusColor(state),
                icon: isActive
                    ? Icons.wifi_tethering_rounded
                    : isPaused
                    ? Icons.pause_circle_filled_rounded
                    : Icons.stop_circle_outlined,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: CareColors.ivory,
              borderRadius: BorderRadius.circular(CareTheme.radiusControl),
              border: Border.all(color: CareColors.navySoft),
            ),
            child: Column(
              children: [
                CareInfoTile(
                  icon: Icons.badge_outlined,
                  label: l10n.careDeviceIdentifier,
                  value: identity?.shortLabel ?? '--',
                ),
                CareInfoTile(
                  icon: Icons.location_on_outlined,
                  label: l10n.careCurrentLocationPermission,
                  value: _permissionLabel(l10n, state),
                  valueColor: state == SharingState.permissionDisabled
                      ? CareColors.coral
                      : CareColors.navy,
                ),
                CareInfoTile(
                  icon: Icons.sync_rounded,
                  label: l10n.careLastSync,
                  value: _lastSyncLabel(context, l10n),
                ),
                CareInfoTile(
                  icon: Icons.battery_charging_full_rounded,
                  label: l10n.careLiveBattery,
                  value: controller.battery.hasKnownLevel
                      ? '${controller.battery.level}%'
                      : '--',
                ),
                CareInfoTile(
                  icon: Icons.sync_rounded,
                  label: l10n.careLastSyncedBattery,
                  value: controller.presence.batteryLevel >= 0
                      ? '${controller.presence.batteryLevel}%'
                      : '--',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SharingControls(
            controller: controller,
            canStart: canStart,
            isActive: isActive,
            isPaused: isPaused,
          ),
        ],
      ),
    );
  }

  String _statusText(AppLocalizations l10n, SharingState state) {
    switch (state) {
      case SharingState.active:
        return l10n.careSharingActive;
      case SharingState.paused:
        return l10n.careSharingPaused;
      case SharingState.stopped:
        return l10n.careSharingStopped;
      case SharingState.permissionDisabled:
        return l10n.carePermissionDisabled;
      case SharingState.notConfigured:
        return l10n.careSharingNotConfigured;
    }
  }

  Color _statusColor(SharingState state) {
    switch (state) {
      case SharingState.active:
        return CareColors.teal;
      case SharingState.paused:
        return CareColors.gold;
      case SharingState.stopped:
        return CareColors.markerUnavailable;
      case SharingState.permissionDisabled:
        return CareColors.coral;
      case SharingState.notConfigured:
        return CareColors.markerUnavailable;
    }
  }

  String _permissionLabel(AppLocalizations l10n, SharingState state) {
    if (state == SharingState.permissionDisabled) {
      return l10n.carePermissionDisabled;
    }
    return l10n.carePermissionForeground;
  }

  String _lastSyncLabel(BuildContext context, AppLocalizations l10n) {
    final lastUpload = controller.presence.lastSuccessfulUpload ??
        controller.currentLocation?.syncedAt ??
        controller.currentLocation?.capturedAt;
    if (lastUpload == null) return l10n.careNever;
    return relativeTimeLabel(context, lastUpload);
  }
}

class _SharingControls extends StatelessWidget {
  const _SharingControls({
    required this.controller,
    required this.canStart,
    required this.isActive,
    required this.isPaused,
  });

  final FamilySafetyController controller;
  final bool canStart;
  final bool isActive;
  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canStart)
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _startSharing(context),
              style: CareTheme.primaryButtonStyle(),
              icon: const Icon(Icons.play_arrow_rounded, size: 21),
              label: Text(l10n.careStartSharing),
            ),
          ),
        if (isActive || isPaused) ...[
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () => isActive
                        ? controller.pauseSharing()
                        : controller.resumeSharing(),
                    style: CareTheme.secondaryButtonStyle(),
                    icon: Icon(
                      isActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 19,
                    ),
                    label: Text(
                      isActive ? l10n.carePauseSharing : l10n.careResumeSharing,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => _stopSharing(context),
                    style: CareTheme.dangerButtonStyle(),
                    icon: const Icon(Icons.stop_rounded, size: 19),
                    label: Text(
                      l10n.careStopSharing,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _startSharing(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context)!;
    try {
      final granted = await controller.requestForegroundPermission();
      if (!granted) {
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: CareColors.coral,
            content: Text(l10n.carePermissionDenied),
          ),
        );
        return;
      }
      final started = await controller.startSharing();
      if (!started) {
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: CareColors.coral,
            content: Text(l10n.careSharingStartFailed),
          ),
        );
        return;
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: CareColors.coral,
          content: Text(l10n.careSharingStartFailed),
        ),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: CareColors.teal,
        content: Text(l10n.careSharingStarted),
      ),
    );
    if (navigator.canPop()) return;
  }

  Future<void> _stopSharing(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CareColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          l10n.careStopConfirmTitle,
          style: const TextStyle(
            color: CareColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          l10n.careStopConfirmBody,
          style: const TextStyle(color: CareColors.slate, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: CareColors.slate),
            child: Text(l10n.careCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: CareColors.coral,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Text(l10n.careStopSharing),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await controller.stopSharing();
    if (!messenger.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: CareColors.navy,
        content: Text(l10n.careSharingStoppedMessage),
      ),
    );
  }
}

class _ConnectedMembersSection extends StatelessWidget {
  const _ConnectedMembersSection({required this.controller});

  final FamilySafetyController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cards = controller.authorizedConnections;

    if (cards.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: CareTheme.cardDecoration(),
        child: CareEmptyState(
          icon: Icons.family_restroom_rounded,
          title: l10n.careNoMembers,
          message: l10n.careNoMembersBody,
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < cards.length; index++) ...[
          CareMemberCard(
            name: cards[index].viewerDisplayName,
            relationshipLabel: relationshipLabel(
              context,
              cards[index].grant.relationship,
            ),
            freshness: cards[index].freshness,
            freshnessLabel: freshnessLabelFor(context, cards[index].freshness),
            batteryLevel: cards[index].presence?.batteryLevel ?? -1,
            isCharging: cards[index].presence?.isCharging ?? false,
            lastSeenLabel: relativeTimeLabel(
              context,
              cards[index].presence?.lastSuccessfulUpload ??
                  cards[index].location?.syncedAt ??
                  cards[index].location?.capturedAt ??
                  cards[index].grant.grantedAt,
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FamilyMembersScreen(controller: controller),
              ),
            ),
          ),
          if (index != cards.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _GuestBlockedScaffold extends StatelessWidget {
  const _GuestBlockedScaffold({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: CareColors.ivory,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onBack,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: CareColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: CareColors.navySoft),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: CareColors.navy,
                        size: 21,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: CareEmptyState(
                  icon: Icons.person_off_rounded,
                  title: l10n.careGuestBlockedTitle,
                  message: l10n.careGuestBlockedBody,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
