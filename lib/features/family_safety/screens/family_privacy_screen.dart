import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../controllers/family_safety_controller.dart';
import '../models/family_models.dart';
import '../theme/care_colors.dart';
import '../theme/care_theme.dart';
import '../widgets/care_components.dart';
import '../widgets/care_formatters.dart';
import '../widgets/care_widgets.dart';
import 'family_permission_screen.dart';

class FamilyPrivacyScreen extends StatefulWidget {
  const FamilyPrivacyScreen({
    super.key,
    required this.controller,
  });

  final FamilySafetyController controller;

  @override
  State<FamilyPrivacyScreen> createState() => _FamilyPrivacyScreenState();
}

class _FamilyPrivacyScreenState extends State<FamilyPrivacyScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
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
    final activeGrants = controller.grants.where((grant) => grant.active).toList();
    final state = controller.sharingState;

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
          l10n.carePrivacyTitle,
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: CareColors.seaMist,
                borderRadius: BorderRadius.circular(CareTheme.radiusCard),
                border: Border.all(color: CareColors.tealSoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.visibility_rounded,
                        color: CareColors.teal,
                        size: 20,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          l10n.carePrivacyWhoCanView,
                          style: CareTheme.text(
                            context,
                            Theme.of(context).textTheme.titleMedium,
                            size: 15,
                            weight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.carePrivacyWhoCanViewBody,
                    style: CareTheme.text(
                      context,
                      Theme.of(context).textTheme.bodyMedium,
                      color: CareColors.slate,
                      size: 12.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (activeGrants.isEmpty)
                    Text(
                      l10n.careNoMembers,
                      style: CareTheme.text(
                        context,
                        Theme.of(context).textTheme.bodyMedium,
                        color: CareColors.slate,
                        size: 12.5,
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final grant in activeGrants)
                          CareStatusPill(
                            label: _displayName(grant),
                            color: CareColors.teal,
                            icon: Icons.person_rounded,
                          ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            CareSectionHeader(title: l10n.carePrivacyDeviceControls),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: CareTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CareInfoTile(
                    icon: Icons.phone_android_rounded,
                    label: l10n.careDeviceNickname,
                    value: controller.deviceIdentity?.nickname ?? l10n.careMyDevice,
                  ),
                  CareInfoTile(
                    icon: Icons.share_location_rounded,
                    label: l10n.careLiveStatus,
                    value: _sharingLabel(l10n, state),
                    valueColor: _sharingColor(state),
                  ),
                  CareInfoTile(
                    icon: Icons.people_alt_rounded,
                    label: l10n.carePrivacyActiveSessions,
                    value: activeGrants.length == 1
                        ? l10n.careSharingTo(activeGrants.length)
                        : l10n.careSharingToPlural(activeGrants.length),
                  ),
                  const SizedBox(height: 14),
                  if (state == SharingState.active)
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: controller.pauseSharing,
                              style: CareTheme.secondaryButtonStyle(
                                minimumSize: const Size.fromHeight(48),
                              ),
                              icon: const Icon(
                                Icons.pause_rounded,
                                size: 18,
                              ),
                              label: Text(
                                l10n.carePauseSharing,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: () => _stopSharing(context),
                              style: CareTheme.dangerButtonStyle(),
                              icon: const Icon(Icons.stop_rounded, size: 18),
                              label: Text(
                                l10n.careStopSharing,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  else if (state == SharingState.paused)
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: controller.resumeSharing,
                        style: CareTheme.primaryButtonStyle(
                          minimumSize: const Size.fromHeight(48),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 19),
                        label: Text(l10n.careResumeSharing),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            CareSectionHeader(title: l10n.careConnectedMembers),
            const SizedBox(height: 12),
            if (activeGrants.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: CareTheme.cardDecoration(),
                child: CareEmptyState(
                  icon: Icons.person_off_rounded,
                  title: l10n.careNoMembers,
                  message: l10n.careNoMembersBody,
                ),
              )
            else
              for (final grant in activeGrants) ...[
                _RevokeRow(
                  name: _displayName(grant),
                  relationship: relationshipLabel(context, grant.relationship),
                  grantedAt: grant.grantedAt,
                  onRevoke: () => _revoke(context, grant),
                ),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 14),
            CareActionTile(
              icon: Icons.settings_rounded,
              title: l10n.carePrivacyPermissionSettings,
              subtitle: l10n.carePermissionBackgroundBody,
              iconColor: CareColors.gold,
              iconBackground: CareColors.goldSoft,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FamilyPermissionScreen(controller: widget.controller),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: CareColors.white,
                borderRadius: BorderRadius.circular(CareTheme.radiusCard),
                border: Border.all(color: CareColors.navySoft),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.privacy_tip_rounded,
                        color: CareColors.teal,
                        size: 20,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          l10n.carePrivacyInformation,
                          style: CareTheme.text(
                            context,
                            Theme.of(context).textTheme.titleMedium,
                            size: 15,
                            weight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    l10n.carePrivacyInformationBody,
                    style: CareTheme.text(
                      context,
                      Theme.of(context).textTheme.bodyMedium,
                      color: CareColors.slate,
                      size: 12.5,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayName(AccessGrant grant) {
    final name = grant.viewerDisplayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final email = grant.viewerEmail?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Family member';
  }

  String _sharingLabel(AppLocalizations l10n, SharingState state) {
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

  Color _sharingColor(SharingState state) {
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

  Future<void> _revoke(BuildContext context, AccessGrant grant) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CareColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Text(
          l10n.careRevokeConfirmTitle,
          style: const TextStyle(
            color: CareColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          l10n.careRevokeConfirmBody,
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
            child: Text(l10n.careRevokeAccess),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.controller.revokeViewer(grant.viewerUid);
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: CareColors.teal,
        content: Text(l10n.careRevokeDone),
      ),
    );
  }

  Future<void> _stopSharing(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CareColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
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
    await widget.controller.stopSharing();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: CareColors.navy,
        content: Text(l10n.careSharingStoppedMessage),
      ),
    );
  }
}

class _RevokeRow extends StatelessWidget {
  const _RevokeRow({
    required this.name,
    required this.relationship,
    required this.grantedAt,
    required this.onRevoke,
  });

  final String name;
  final String relationship;
  final DateTime grantedAt;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: CareTheme.cardDecoration(),
      child: Row(
        children: [
          CareAvatar(name: name, size: 44),
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
                    size: 14.5,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  relationship,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CareTheme.text(
                    context,
                    Theme.of(context).textTheme.bodySmall,
                    color: CareColors.slate,
                    size: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  relativeTimeLabel(context, grantedAt),
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
          const SizedBox(width: 8),
          SizedBox(
            height: 40,
            child: TextButton.icon(
              onPressed: onRevoke,
              style: TextButton.styleFrom(
                foregroundColor: CareColors.coral,
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              icon: const Icon(Icons.person_remove_rounded, size: 17),
              label: Text(
                l10n.careRevokeAccess,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
