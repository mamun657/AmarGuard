import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../controllers/caresignal_controller.dart';
import '../services/caresignal_api.dart';
import '../theme/care_colors.dart';
import '../theme/care_theme.dart';
import '../widgets/care_formatters.dart';
import '../widgets/care_widgets.dart';
import 'caresignal_widgets.dart';

class CareSignalResponseScreen extends StatefulWidget {
  const CareSignalResponseScreen({
    super.key,
    required this.controller,
    required this.request,
    this.isRecipient = true,
  });

  final CareSignalController controller;
  final CareSignalHelpRequest request;
  final bool isRecipient;

  @override
  State<CareSignalResponseScreen> createState() =>
      _CareSignalResponseScreenState();
}

class _CareSignalResponseScreenState extends State<CareSignalResponseScreen> {
  late CareSignalHelpRequest _request;
  bool _acknowledging = false;

  @override
  void initState() {
    super.initState();
    _request = widget.request;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final location = _request.location;
    final battery = _request.batteryLevel;
    final isRecipient = widget.isRecipient;

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
                  label: _request.isAcknowledged
                      ? l10n.careSignalStatusAcknowledged
                      : isRecipient
                      ? l10n.careSignalStatusNew
                      : _request.notificationStatus == 'submitted'
                      ? l10n.careSignalStatusNotificationSubmitted
                      : l10n.careSignalStatusSaved,
                  color: _request.isAcknowledged
                      ? CareColors.teal
                      : CareColors.gold,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                children: [
                  Text(
                    l10n.careSignalResponseTitle,
                    style: CareTheme.text(
                      context,
                      Theme.of(context).textTheme.headlineSmall,
                      size: 23,
                      weight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  CareSignalInfoCard(
                    icon: Icons.record_voice_over_rounded,
                    label: l10n.careSignalOriginalStatement,
                    value: _request.originalMessage,
                  ),
                  const SizedBox(height: 10),
                  CareSignalInfoCard(
                    icon: Icons.flag_outlined,
                    label: l10n.careSignalRequestTypeLabel,
                    value: requestTypeLabel(context, _request.requestType),
                    iconColor: CareColors.gold,
                    iconBackground: CareColors.goldSoft,
                  ),
                  const SizedBox(height: 10),
                  CareSignalInfoCard(
                    icon: Icons.auto_awesome_rounded,
                    label: l10n.careSignalAiInterpretation,
                    value: _request.generatedSummary,
                    iconColor: CareColors.gold,
                    iconBackground: CareColors.goldSoft,
                  ),
                  const SizedBox(height: 10),
                  CareSignalInfoCard(
                    icon: Icons.location_on_rounded,
                    label: l10n.careSignalLastKnownLocation,
                    value: location == null
                        ? l10n.careSignalLocationUnavailable
                        : _locationText(context, location),
                    valueColor: location == null ? CareColors.slate : null,
                  ),
                  const SizedBox(height: 10),
                  CareSignalInfoCard(
                    icon: Icons.battery_charging_full_rounded,
                    label: l10n.careSignalBatteryInfo,
                    value: battery == null
                        ? l10n.careSignalBatteryUnavailable
                        : '$battery%',
                    iconColor: CareColors.gold,
                    iconBackground: CareColors.goldSoft,
                  ),
                  const SizedBox(height: 10),
                  CareSignalInfoCard(
                    icon: Icons.schedule_rounded,
                    label: l10n.careSignalResponseTitle,
                    value: _request.requestedAt == null
                        ? l10n.careSignalNotAvailable
                        : l10n.careSignalCreatedAt(
                            formatDateTime(context, _request.requestedAt!),
                          ),
                    iconColor: CareColors.slate,
                    iconBackground: CareColors.slateSoft,
                  ),
                  if (widget.controller.errorMessage != null) ...[
                    const SizedBox(height: 14),
                    CareErrorBanner(message: widget.controller.errorMessage!),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isRecipient)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: CareColors.seaMist,
                          borderRadius: BorderRadius.circular(
                            CareTheme.radiusControl,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.outgoing_mail,
                              color: CareColors.teal,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _request.isAcknowledged
                                    ? l10n.careSignalAcknowledgedBody
                                    : l10n.careSignalSentByYou,
                                style: CareTheme.text(
                                  context,
                                  Theme.of(context).textTheme.bodySmall,
                                  color: CareColors.tealDeep,
                                  size: 12.5,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (!_request.isAcknowledged)
                      SizedBox(
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: _acknowledging
                              ? null
                              : () => _acknowledge(context),
                          style: CareTheme.primaryButtonStyle(),
                          icon: _acknowledging
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 20),
                          label: Text(l10n.careSignalAcknowledge),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: CareColors.seaMist,
                          borderRadius: BorderRadius.circular(
                            CareTheme.radiusControl,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.check_circle_rounded,
                              color: CareColors.teal,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                l10n.careSignalAcknowledgedBody,
                                style: CareTheme.text(
                                  context,
                                  Theme.of(context).textTheme.bodySmall,
                                  color: CareColors.tealDeep,
                                  size: 12.5,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (isRecipient) ...[
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton.icon(
                                onPressed: () => _call(context),
                                style: CareTheme.secondaryButtonStyle(),
                                icon: const Icon(Icons.call_rounded, size: 19),
                                label: Text(
                                  l10n.careSignalCallMember,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: location == null
                                  ? null
                                  : () => _openMap(context, location),
                              style: CareTheme.secondaryButtonStyle(),
                              icon: const Icon(Icons.map_rounded, size: 19),
                              label: Text(
                                l10n.careSignalViewLocation,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _locationText(BuildContext context, Map<String, dynamic> location) {
    final latitude = location['latitude'];
    final longitude = location['longitude'];
    if (latitude is! num || longitude is! num) {
      return AppLocalizations.of(context)!.careSignalLocationUnavailable;
    }
    final buffer = StringBuffer(
      formatCoordinates(latitude.toDouble(), longitude.toDouble()),
    );
    final accuracy = location['accuracy'];
    if (accuracy is num) {
      buffer.write('\n${formatAccuracy(accuracy.toDouble())}');
    }
    final capturedAt = location['captured_at'];
    if (capturedAt is String) {
      final parsed = DateTime.tryParse(capturedAt);
      if (parsed != null) {
        buffer.write('\n${formatDateTime(context, parsed)}');
      }
    }
    return buffer.toString();
  }

  Future<void> _acknowledge(BuildContext context) async {
    setState(() => _acknowledging = true);
    final ok = await widget.controller.acknowledge(_request.requestId);
    if (!mounted) return;
    setState(() => _acknowledging = false);
    if (!ok) return;
    setState(() => _request = widget.controller.sentRequest ?? _request);
  }

  Future<void> _call(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final phone = _request.senderPhoneNumber;
    if (phone == null || phone.isEmpty) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: CareColors.navy,
          content: Text(AppLocalizations.of(context)!.careSignalNoPhoneNumber),
        ),
      );
      return;
    }
    final uri = Uri.parse('tel:$phone');
    if (!await launchUrl(uri) && context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: CareColors.navy,
          content: Text(AppLocalizations.of(context)!.careSignalCallMember),
        ),
      );
    }
  }

  Future<void> _openMap(
    BuildContext context,
    Map<String, dynamic> location,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final latitude = location['latitude'];
    final longitude = location['longitude'];
    if (latitude is! num || longitude is! num) return;
    final uri = Uri.parse(
      'geo:${latitude.toDouble()},${longitude.toDouble()}?q=${latitude.toDouble()},${longitude.toDouble()}',
    );
    if (!await launchUrl(uri) && context.mounted) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: CareColors.navy,
          content: Text(AppLocalizations.of(context)!.careSignalNotAvailable),
        ),
      );
    }
  }
}
