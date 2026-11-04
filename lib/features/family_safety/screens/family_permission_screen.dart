import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../controllers/family_safety_controller.dart';
import '../theme/care_colors.dart';
import '../theme/care_theme.dart';

class FamilyPermissionScreen extends StatefulWidget {
  const FamilyPermissionScreen({
    super.key,
    required this.controller,
  });

  final FamilySafetyController controller;

  @override
  State<FamilyPermissionScreen> createState() =>
      _FamilyPermissionScreenState();
}

class _FamilyPermissionScreenState extends State<FamilyPermissionScreen> {
  bool _serviceEnabled = false;
  bool _foregroundGranted = false;
  bool _backgroundGranted = false;
  bool _approximate = false;
  bool _isLoading = true;
  bool _isRequesting = false;

  @override
  void initState() {
    super.initState();
    _refreshStates();
  }

  Future<void> _refreshStates() async {
    final controller = widget.controller;
    final serviceEnabled = await controller.isLocationServiceEnabled();
    final permission = await controller.currentPermission();
    final accuracy = await _readAccuracyStatus();
    if (!mounted) return;
    setState(() {
      _serviceEnabled = serviceEnabled;
      _foregroundGranted = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      _backgroundGranted = permission == LocationPermission.always;
      _approximate = accuracy == LocationAccuracyStatus.reduced;
      _isLoading = false;
    });
  }

  Future<LocationAccuracyStatus> _readAccuracyStatus() async {
    try {
      return await Geolocator.getLocationAccuracy();
    } catch (_) {
      return LocationAccuracyStatus.unknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
          l10n.carePermissionTitle,
          style: const TextStyle(
            color: CareColors.navy,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: CareColors.teal),
              )
            : ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
                children: [
                  Text(
                    l10n.carePermissionSubtitle,
                    style: CareTheme.text(
                      context,
                      Theme.of(context).textTheme.bodyMedium,
                      color: CareColors.slate,
                      size: 13.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _PermissionCard(
                    icon: Icons.gps_fixed_rounded,
                    title: l10n.carePermissionServiceOn,
                    subtitle: _serviceEnabled
                        ? l10n.carePermissionServiceOn
                        : l10n.carePermissionServiceOff,
                    granted: _serviceEnabled,
                    actionLabel: _serviceEnabled ? null : l10n.careOpenSettings,
                    onAction: _serviceEnabled ? null : _openLocationSettings,
                  ),
                  const SizedBox(height: 12),
                  _PermissionCard(
                    icon: Icons.my_location_rounded,
                    title: l10n.carePermissionForeground,
                    subtitle: _foregroundGranted
                        ? l10n.carePermissionGranted
                        : l10n.carePermissionDenied,
                    granted: _foregroundGranted,
                    actionLabel: _foregroundGranted ? null : l10n.carePermissionGrant,
                    onAction:
                        _foregroundGranted ? null : _requestForegroundPermission,
                  ),
                  const SizedBox(height: 12),
                  _PermissionCard(
                    icon: Icons.location_searching_rounded,
                    title: l10n.carePermissionPrecision,
                    subtitle: _approximate
                        ? l10n.carePermissionPrecisionApproximate
                        : l10n.carePermissionPrecisionPrecise,
                    granted: _foregroundGranted,
                  ),
                  const SizedBox(height: 12),
                  _PermissionCard(
                    icon: Icons.av_timer_rounded,
                    title: l10n.carePermissionBackground,
                    subtitle: _backgroundGranted
                        ? l10n.carePermissionBackgroundGranted
                        : l10n.carePermissionBackgroundDenied,
                    granted: _backgroundGranted,
                    detail: l10n.carePermissionBackgroundBody,
                    actionLabel:
                        _backgroundGranted ? null : l10n.careOpenSettings,
                    onAction: _backgroundGranted ? null : _openAppSettings,
                  ),
                  const SizedBox(height: 12),
                  _PermissionCard(
                    icon: Icons.notifications_active_rounded,
                    title: l10n.carePermissionNotification,
                    subtitle: l10n.carePermissionNotificationBody,
                    granted: true,
                    isInformational: true,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isRequesting ? null : _continue,
                      style: CareTheme.primaryButtonStyle(),
                      icon: _isRequesting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_forward_rounded, size: 20),
                      label: Text(l10n.carePermissionContinue),
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
                      child: Text(l10n.carePermissionCancel),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _requestForegroundPermission() async {
    setState(() => _isRequesting = true);
    await widget.controller.requestForegroundPermission();
    await _refreshStates();
    if (!mounted) return;
    setState(() => _isRequesting = false);
  }

  Future<void> _openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> _openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  Future<void> _continue() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (!_foregroundGranted) {
      final granted = await widget.controller.requestForegroundPermission();
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
    }
    if (!navigator.canPop()) return;
    navigator.pop();
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    this.detail,
    this.actionLabel,
    this.onAction,
    this.isInformational = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isInformational;

  @override
  Widget build(BuildContext context) {
    final accent = isInformational
        ? CareColors.navy
        : granted
            ? CareColors.teal
            : CareColors.gold;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: CareTheme.cardDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
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
                    size: 14.5,
                    weight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: CareTheme.text(
                    context,
                    Theme.of(context).textTheme.bodySmall,
                    color: granted ? CareColors.teal : CareColors.slate,
                    size: 12.5,
                    height: 1.4,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    detail!,
                    style: CareTheme.text(
                      context,
                      Theme.of(context).textTheme.bodySmall,
                      color: CareColors.slate,
                      size: 12,
                      height: 1.45,
                    ),
                  ),
                ],
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: onAction,
                      style: CareTheme.secondaryButtonStyle(
                        foreground: CareColors.teal,
                        borderColor: CareColors.tealSoft,
                      ),
                      icon: const Icon(Icons.settings_rounded, size: 17),
                      label: Text(
                        actionLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!isInformational) ...[
            const SizedBox(width: 8),
            Icon(
              granted
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: granted ? CareColors.teal : CareColors.markerUnavailable,
              size: 21,
            ),
          ],
        ],
      ),
    );
  }
}
