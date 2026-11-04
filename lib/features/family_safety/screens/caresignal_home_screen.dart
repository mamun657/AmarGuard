import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../controllers/caresignal_controller.dart';
import '../services/caresignal_api.dart';
import '../theme/care_colors.dart';
import '../theme/care_theme.dart';
import '../widgets/care_formatters.dart';
import '../widgets/care_widgets.dart';
import 'caresignal_inbox_screen.dart';
import 'caresignal_recording_screen.dart';
import 'caresignal_response_screen.dart';
import 'caresignal_summary_screen.dart';
import 'caresignal_widgets.dart';
import '../../../shared/widgets/amarguard_loading.dart';

class CareSignalHomeScreen extends StatefulWidget {
  const CareSignalHomeScreen({
    super.key,
    required this.controller,
    required this.onBack,
    this.initialRequestId,
    this.onIncomingRequestRead,
  });

  final CareSignalController controller;
  final VoidCallback onBack;
  final String? initialRequestId;
  final Future<void> Function(String requestId)? onIncomingRequestRead;

  @override
  State<CareSignalHomeScreen> createState() => _CareSignalHomeScreenState();
}

class _CareSignalHomeScreenState extends State<CareSignalHomeScreen> {
  bool _loadingSent = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _loadSent();
    final requestId = widget.initialRequestId;
    if (requestId != null && requestId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openIncomingRequest(requestId);
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openIncomingRequest(String requestId) async {
    final request = await widget.controller.loadRequest(requestId);
    if (!mounted ||
        request == null ||
        request.recipientUid != FirebaseAuth.instance.currentUser?.uid) {
      return;
    }
    await widget.onIncomingRequestRead?.call(requestId);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CareSignalResponseScreen(
          controller: widget.controller,
          request: request,
        ),
      ),
    );
  }

  Future<void> _loadSent() async {
    setState(() => _loadingSent = true);
    await widget.controller.loadSent();
    if (!mounted) return;
    setState(() => _loadingSent = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = widget.controller;

    return Scaffold(
      backgroundColor: CareColors.ivory,
      body: SafeArea(
        bottom: true,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
          children: [
            CareSignalBackBar(
              onBack: widget.onBack,
              trailing: CareActionTileIcon(
                icon: Icons.inbox_rounded,
                tooltip: l10n.careSignalInboxTitle,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        CareSignalInboxScreen(controller: widget.controller),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            CareSignalHero(
              title: l10n.careSignalTitle,
              subtitle: l10n.careSignalTagline,
              badge: 'Meta AI',
            ),
            const SizedBox(height: 20),
            CareSignalNeedHelpButton(onPressed: () => _startFlow(context)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: CareTheme.cardDecoration(),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    color: CareColors.teal,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.careSignalPrivacyNote,
                      style: CareTheme.text(
                        context,
                        Theme.of(context).textTheme.bodySmall,
                        color: CareColors.slate,
                        size: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            CareSectionHeader(title: l10n.careSignalSentRequests),
            const SizedBox(height: 10),
            if (_loadingSent && controller.sentRequests.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 22),
                decoration: CareTheme.cardDecoration(),
                child: Center(
                  child: AmarGuardLoading(
                    variant: AmarGuardLoadingVariant.section,
                    width: 76,
                    height: 76,
                    title: '',
                    message: l10n.loadingDefaultMessage,
                  ),
                ),
              )
            else if (controller.sentRequestsError != null)
              CareErrorBanner(
                message: controller.sentRequestsError!,
                onRetry: _loadSent,
                retryLabel: l10n.careRetry,
              ),
            if (controller.sentRequests.isNotEmpty ||
                (!_loadingSent && controller.sentRequestsError == null))
              _SentRequestsCard(controller: controller, onRefresh: _loadSent),
          ],
        ),
      ),
    );
  }

  Future<void> _startFlow(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await widget.controller.prepareConsent();
    } on CareSignalException catch (error) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: CareColors.coral,
          content: Text(error.message),
        ),
      );
      return;
    }
    if (!context.mounted) return;
    final started = await navigator.push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            CareSignalRecordingScreen(controller: widget.controller),
      ),
    );
    if (started != true) return;
    if (!context.mounted) return;
    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => CareSignalSummaryScreen(controller: widget.controller),
      ),
    );
  }
}

class CareActionTileIcon extends StatelessWidget {
  const CareActionTileIcon({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: CareColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: CareColors.navySoft),
          ),
          child: Icon(icon, color: CareColors.navy, size: 21),
        ),
      ),
    );
    if (tooltip == null) return child;
    return Tooltip(message: tooltip!, child: child);
  }
}

class _SentRequestsCard extends StatelessWidget {
  const _SentRequestsCard({required this.controller, required this.onRefresh});

  final CareSignalController controller;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final requests = controller.sentRequests;
    if (requests.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: CareTheme.cardDecoration(),
        child: CareEmptyState(
          icon: Icons.outgoing_mail,
          title: l10n.careSignalSentRequestsEmpty,
          message: l10n.careSignalSentRequestsEmptyBody,
        ),
      );
    }
    return RefreshIndicator(
      color: CareColors.teal,
      onRefresh: () async => onRefresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        shrinkWrap: true,
        children: [
          for (final request in requests)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SentRequestCard(
                request: request,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CareSignalResponseScreen(
                      controller: controller,
                      request: request,
                      isRecipient: false,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SentRequestCard extends StatelessWidget {
  const _SentRequestCard({required this.request, required this.onTap});

  final CareSignalHelpRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final acknowledged = request.isAcknowledged;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: CareTheme.cardDecoration(
        borderColor: acknowledged ? CareColors.teal : CareColors.gold,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(CareTheme.radiusControl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    acknowledged
                        ? Icons.check_circle_rounded
                        : Icons.schedule_rounded,
                    color: acknowledged ? CareColors.teal : CareColors.gold,
                    size: 20,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      request.requestedAt == null
                          ? l10n.careSignalNotAvailable
                          : l10n.careSignalCreatedAt(
                              formatDateTime(context, request.requestedAt!),
                            ),
                      style: CareTheme.text(
                        context,
                        Theme.of(context).textTheme.titleMedium,
                        size: 14,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ),
                  CareStatusPill(
                    label: acknowledged
                        ? l10n.careSignalStatusAcknowledged
                        : request.notificationStatus == 'submitted'
                        ? l10n.careSignalStatusNotificationSubmitted
                        : l10n.careSignalStatusSaved,
                    color: acknowledged ? CareColors.teal : CareColors.gold,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                request.generatedSummary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: CareTheme.text(
                  context,
                  Theme.of(context).textTheme.bodySmall,
                  color: CareColors.slate,
                  size: 12.5,
                  height: 1.4,
                ),
              ),
              if (!acknowledged) ...[
                const SizedBox(height: 7),
                Text(
                  request.notificationStatus == 'submitted'
                      ? l10n.careSignalNotificationSubmitted
                      : l10n.careSignalNotificationNotSubmitted,
                  style: CareTheme.text(
                    context,
                    Theme.of(context).textTheme.bodySmall,
                    color: CareColors.slate,
                    size: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
