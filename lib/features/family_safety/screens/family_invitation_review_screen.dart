import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../controllers/family_safety_controller.dart';
import '../models/family_models.dart';
import '../services/family_error_messages.dart';
import '../theme/care_colors.dart';
import '../theme/care_theme.dart';
import '../widgets/care_formatters.dart';
import '../widgets/care_widgets.dart';

class FamilyInvitationReviewScreen extends StatefulWidget {
  const FamilyInvitationReviewScreen({
    super.key,
    required this.controller,
    required this.invitation,
  });

  final FamilySafetyController controller;
  final FamilyInvitation invitation;

  @override
  State<FamilyInvitationReviewScreen> createState() =>
      _FamilyInvitationReviewScreenState();
}

class _FamilyInvitationReviewScreenState
    extends State<FamilyInvitationReviewScreen> {
  RelationshipType _relationship = RelationshipType.other;
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final invitation = widget.invitation;

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
          l10n.careJoinFamilyTitle,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.diversity_3_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.careJoinFamilyTitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.careJoinFamilySubtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: CareTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CareSectionHeader(
                    title: l10n.careConnectionRequestTitle,
                    subtitle: l10n.careInvitationOwner(
                      invitation.ownerDisplayName,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _InfoRow(
                    icon: Icons.person_outline_rounded,
                    label: l10n.careRequestedBy,
                    value: invitation.ownerDisplayName,
                  ),
                  _InfoRow(
                    icon: Icons.devices_other_rounded,
                    label: l10n.careDeviceNickname,
                    value: invitation.deviceNickname ?? l10n.careMyDevice,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.careIntendedConnection,
                    style: CareTheme.text(
                      context,
                      Theme.of(context).textTheme.bodySmall,
                      color: CareColors.slate,
                      size: 12.5,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final type in RelationshipType.values)
                        _RelationshipChip(
                          label: relationshipLabel(context, type),
                          selected: _relationship == type,
                          onTap: () => setState(() => _relationship = type),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: CareTheme.cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CareSectionHeader(title: l10n.careRequestedCapabilities),
                  const SizedBox(height: 12),
                  _CapabilityRow(
                    icon: Icons.my_location_rounded,
                    label: l10n.careCapabilityLocation,
                  ),
                  _CapabilityRow(
                    icon: Icons.battery_charging_full_rounded,
                    label: l10n.careCapabilityBattery,
                  ),
                  _CapabilityRow(
                    icon: Icons.schedule_rounded,
                    label: l10n.careCapabilityLastSeen,
                  ),
                  _CapabilityRow(
                    icon: Icons.smartphone_rounded,
                    label: l10n.careCapabilityDevice,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: CareColors.goldSoft,
                borderRadius: BorderRadius.circular(CareTheme.radiusCard),
                border: Border.all(
                  color: CareColors.gold.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.privacy_tip_rounded,
                        color: CareColors.gold,
                        size: 19,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.carePrivacyDisclosure,
                          style: CareTheme.text(
                            context,
                            Theme.of(context).textTheme.titleMedium,
                            size: 14,
                            weight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 9),
                  Text(
                    l10n.careJoinPrivacyDisclosureBody,
                    style: CareTheme.text(
                      context,
                      Theme.of(context).textTheme.bodyMedium,
                      color: CareColors.navy,
                      size: 12.5,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _acceptInvitation,
                style: CareTheme.primaryButtonStyle(),
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 20),
                label: Text(l10n.careAcceptInvitation),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: CareTheme.secondaryButtonStyle(
                  foreground: CareColors.slate,
                  borderColor: CareColors.navySoft,
                ),
                child: Text(l10n.careDeclineInvitation),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptInvitation() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context)!;
    setState(() => _isSubmitting = true);
    try {
      final alreadyPending = await widget.controller.submitRequest(
        invitation: widget.invitation,
        relationship: _relationship,
      );
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: CareColors.teal,
          content: Text(
            alreadyPending
                ? l10n.careRequestAlreadyPending
                : l10n.careInvitationAccepted,
          ),
        ),
      );
      if (navigator.canPop()) navigator.pop();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: CareColors.coral,
          content: Text(familySafetyErrorMessage(l10n, error)),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _RelationshipChip extends StatelessWidget {
  const _RelationshipChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? CareColors.teal : CareColors.ivory,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? CareColors.teal : CareColors.navySoft,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : CareColors.slate,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 17, color: CareColors.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: CareTheme.text(
                context,
                Theme.of(context).textTheme.bodyMedium,
                color: CareColors.navy,
                size: 13,
                weight: FontWeight.w600,
              ),
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            size: 17,
            color: CareColors.teal,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
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
                color: CareColors.navy,
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
