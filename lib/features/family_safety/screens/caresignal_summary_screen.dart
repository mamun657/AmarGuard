import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../controllers/caresignal_controller.dart';
import '../services/caresignal_api.dart';
import '../theme/care_colors.dart';
import '../theme/care_theme.dart';
import '../widgets/care_formatters.dart';
import '../widgets/care_widgets.dart';
import 'caresignal_widgets.dart';

class CareSignalSummaryScreen extends StatefulWidget {
  const CareSignalSummaryScreen({super.key, required this.controller});

  final CareSignalController controller;

  @override
  State<CareSignalSummaryScreen> createState() =>
      _CareSignalSummaryScreenState();
}

class _CareSignalSummaryScreenState extends State<CareSignalSummaryScreen> {
  CareSignalRecipient? _selectedRecipient;

  @override
  void initState() {
    super.initState();
    _selectedRecipient = _suggestedRecipient(widget.controller.summary);
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) {
      _selectedRecipient ??= _suggestedRecipient(widget.controller.summary);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = widget.controller;
    final summary = controller.summary;

    if (summary == null) {
      return Scaffold(
        backgroundColor: CareColors.ivory,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: CareColors.teal),
                  const SizedBox(height: 16),
                  Text(l10n.careSignalLoadingData),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: CareColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: CareSignalBackBar(
                onBack: () => Navigator.of(context).pop(),
                trailing: CareStatusPill(
                  label: l10n.careSignalAwaitingConfirmation,
                  color: CareColors.gold,
                  icon: Icons.hourglass_top_rounded,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Text(
                    l10n.careSignalSummaryTitle,
                    style: CareTheme.text(
                      context,
                      Theme.of(context).textTheme.headlineSmall,
                      size: 23,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.careSignalSummaryBody,
                    style: CareTheme.text(
                      context,
                      Theme.of(context).textTheme.bodyMedium,
                      color: CareColors.slate,
                      size: 13.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  CareSignalInfoCard(
                    icon: Icons.record_voice_over_rounded,
                    label: l10n.careSignalOriginalStatement,
                    value: summary.originalTranscript.isEmpty
                        ? l10n.careSignalNotAvailable
                        : summary.originalTranscript,
                  ),
                  const SizedBox(height: 10),
                  CareSignalInfoCard(
                    icon: Icons.auto_awesome_rounded,
                    label: l10n.careSignalAiInterpretation,
                    value: summary.assistanceSummary,
                    iconColor: CareColors.gold,
                    iconBackground: CareColors.goldSoft,
                  ),
                  const SizedBox(height: 10),
                  _LocationCard(summary: summary),
                  const SizedBox(height: 10),
                  _BatteryCard(summary: summary),
                  if (summary.suggestedSafeActions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    CareSectionHeader(title: l10n.careSignalSuggestedActions),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: CareTheme.cardDecoration(),
                      child: CareSignalActionList(
                        actions: summary.suggestedSafeActions,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  CareSectionHeader(title: l10n.careSignalRecipients),
                  const SizedBox(height: 10),
                  _RecipientPicker(
                    summary: summary,
                    selectedUid: _selectedRecipient?.uid,
                    onSelect: (recipient) {
                      setState(() => _selectedRecipient = recipient);
                    },
                  ),
                  if (controller.errorMessage != null) ...[
                    const SizedBox(height: 14),
                    CareErrorBanner(message: controller.errorMessage!),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              decoration: const BoxDecoration(
                color: CareColors.white,
                border: Border(top: BorderSide(color: CareColors.navySoft)),
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: controller.stage == CareSignalStage.sending
                        ? null
                        : () => _confirm(context),
                    style: CareTheme.primaryButtonStyle(),
                    icon: controller.stage == CareSignalStage.sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 20),
                    label: Text(
                      controller.stage == CareSignalStage.sending
                          ? l10n.careSignalSending
                          : l10n.careSignalSendNow,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final summary = widget.controller.summary;
    if (summary == null) return;
    final recipients = summary.approvedRecipients;
    if (recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: CareColors.coral,
          content: Text(l10n.careSignalNoRecipients),
        ),
      );
      return;
    }
    final selected = _selectedRecipient;
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: CareColors.coral,
          content: Text(l10n.careSignalNoRecipients),
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CareColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          l10n.careSignalConfirmSendTitle,
          style: const TextStyle(
            color: CareColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.careSignalConfirmSendBody,
              style: const TextStyle(color: CareColors.slate, height: 1.45),
            ),
            const SizedBox(height: 12),
            Text(
              '${selected.displayName} · ${selected.relationship}',
              style: const TextStyle(
                color: CareColors.navy,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'UID: ${_shortUid(selected.uid)}',
              style: const TextStyle(color: CareColors.slate, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: CareColors.slate),
            child: Text(l10n.careSignalCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: CareColors.teal,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Text(l10n.careSignalSendNow),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!context.mounted) return;
    final sent = await widget.controller.sendHelpRequest(
      recipientUid: selected.uid,
    );
    if (!sent || !context.mounted) return;
    final request = widget.controller.sentRequest;
    final notificationMessage = request?.isAcknowledged == true
        ? l10n.careSignalReceiverAcknowledged
        : request?.notificationStatus == 'submitted'
        ? l10n.careSignalNotificationSubmitted
        : l10n.careSignalNotificationNotSubmitted;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CareColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(
          l10n.careSignalSentTitle,
          style: const TextStyle(
            color: CareColors.teal,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.careSignalSavedFor(selected.displayName),
              style: const TextStyle(color: CareColors.slate, height: 1.45),
            ),
            const SizedBox(height: 10),
            Text(
              notificationMessage,
              style: const TextStyle(color: CareColors.slate, height: 1.45),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: CareColors.teal,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Text(l10n.careSignalConfirm),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  CareSignalRecipient? _suggestedRecipient(CareSignalSummary? summary) {
    final uid = summary?.suggestedRecipientUid;
    if (uid == null || summary?.recipientMatchStatus != 'matched') return null;
    for (final recipient in summary!.approvedRecipients) {
      if (recipient.uid == uid) return recipient;
    }
    return null;
  }

  String _shortUid(String uid) {
    if (uid.length <= 12) return uid;
    return '${uid.substring(0, 6)}…${uid.substring(uid.length - 4)}';
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.summary});

  final CareSignalSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final location = summary.lastAuthorizedLocation;
    if (location == null) {
      return CareSignalInfoCard(
        icon: Icons.location_off_rounded,
        label: l10n.careSignalLastKnownLocation,
        value: _freshnessText(l10n, summary.locationFreshnessStatus),
        valueColor: CareColors.slate,
        iconColor: CareColors.slate,
        iconBackground: CareColors.slateSoft,
      );
    }
    final latitude = location['latitude'];
    final longitude = location['longitude'];
    final coordinates = latitude is num && longitude is num
        ? formatCoordinates(latitude.toDouble(), longitude.toDouble())
        : l10n.careSignalNotAvailable;
    final accuracy = summary.locationAccuracy;
    final timestamp = summary.locationTimestamp;
    final buffer = StringBuffer(coordinates);
    if (accuracy != null) {
      buffer.write('\n${formatAccuracy(accuracy)}');
    }
    if (timestamp != null) {
      final parsed = DateTime.tryParse(timestamp);
      if (parsed != null) {
        buffer.write('\n${formatDateTime(context, parsed)}');
      }
    }
    return CareSignalInfoCard(
      icon: Icons.location_on_rounded,
      label: l10n.careSignalLastKnownLocation,
      value: buffer.toString(),
    );
  }

  String _freshnessText(AppLocalizations l10n, String status) {
    switch (status) {
      case 'fresh':
        return l10n.careSignalLocationFresh;
      case 'stale':
        return l10n.careSignalLocationStale;
      case 'paused':
        return l10n.careSignalLocationPaused;
      case 'sharing_disabled':
        return l10n.careSignalLocationSharingDisabled;
      case 'not_configured':
        return l10n.careSignalLocationSharingDisabled;
      case 'permission_disabled':
        return l10n.careSignalLocationSharingDisabled;
      default:
        return l10n.careSignalLocationUnavailable;
    }
  }
}

class _BatteryCard extends StatelessWidget {
  const _BatteryCard({required this.summary});

  final CareSignalSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final level = summary.batteryLevel;
    return CareSignalInfoCard(
      icon: Icons.battery_charging_full_rounded,
      label: l10n.careSignalBatteryInfo,
      value: level == null ? l10n.careSignalBatteryUnavailable : '$level%',
      iconColor: CareColors.gold,
      iconBackground: CareColors.goldSoft,
    );
  }
}

class _RecipientPicker extends StatelessWidget {
  const _RecipientPicker({
    required this.summary,
    required this.selectedUid,
    required this.onSelect,
  });

  final CareSignalSummary summary;
  final String? selectedUid;
  final ValueChanged<CareSignalRecipient> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (summary.approvedRecipients.isEmpty) {
      return Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        decoration: CareTheme.cardDecoration(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.lock_outline_rounded,
              color: CareColors.gold,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${l10n.careSignalNoRecipients}\n\n'
                '${l10n.careSignalNoRecipientsBody}',
                style: CareTheme.text(
                  context,
                  Theme.of(context).textTheme.bodyMedium,
                  color: CareColors.slate,
                  size: 13,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: CareTheme.cardDecoration(),
      child: Column(
        children: [
          for (final recipient in summary.approvedRecipients)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onSelect(recipient),
                borderRadius: BorderRadius.circular(CareTheme.radiusControl),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: selectedUid == recipient.uid
                        ? CareColors.seaMist
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      CareTheme.radiusControl,
                    ),
                  ),
                  child: Row(
                    children: [
                      CareAvatar(
                        name: recipient.displayName,
                        size: 42,
                        background: CareColors.teal,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              recipient.displayName.isEmpty
                                  ? l10n.careSignalNotAvailable
                                  : recipient.displayName,
                              style: const TextStyle(
                                color: CareColors.navy,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${recipient.relationship} · '
                              '${l10n.careSignalApprovedRecipient}',
                              style: const TextStyle(
                                color: CareColors.slate,
                                fontSize: 12,
                              ),
                            ),
                            if (summary.suggestedRecipientUid ==
                                    recipient.uid &&
                                summary.recipientMatchStatus == 'matched')
                              Text(
                                l10n.careSignalSuggestedMatch,
                                style: const TextStyle(
                                  color: CareColors.teal,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        selectedUid == recipient.uid
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        color: selectedUid == recipient.uid
                            ? CareColors.teal
                            : CareColors.markerUnavailable,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
