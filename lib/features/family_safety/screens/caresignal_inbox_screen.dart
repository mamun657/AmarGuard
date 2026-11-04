import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../controllers/caresignal_controller.dart';
import '../services/caresignal_api.dart';
import '../theme/care_colors.dart';
import '../theme/care_theme.dart';
import '../widgets/care_formatters.dart';
import '../widgets/care_widgets.dart';
import '../../../shared/widgets/amarguard_loading.dart';
import 'caresignal_home_screen.dart';
import 'caresignal_response_screen.dart';
import 'caresignal_widgets.dart';

class CareSignalInboxScreen extends StatefulWidget {
  const CareSignalInboxScreen({super.key, required this.controller});

  final CareSignalController controller;

  @override
  State<CareSignalInboxScreen> createState() => _CareSignalInboxScreenState();
}

class _CareSignalInboxScreenState extends State<CareSignalInboxScreen> {
  List<CareSignalHelpRequest> _requests = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    final items = await widget.controller.loadInbox();
    if (!mounted) return;
    setState(() {
      if (widget.controller.inboxRequestsErrorCode == null) {
        _requests = items;
      }
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

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
                trailing: CareActionTileIcon(
                  icon: Icons.refresh_rounded,
                  tooltip: l10n.careSignalTryAgain,
                  onTap: () {
                    setState(() => _loading = true);
                    _load();
                  },
                ),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: CareColors.teal,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    Text(
                      l10n.careSignalInboxTitle,
                      style: CareTheme.text(
                        context,
                        Theme.of(context).textTheme.headlineSmall,
                        size: 23,
                        weight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_loading && _requests.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: AmarGuardLoading(
                          variant: AmarGuardLoadingVariant.section,
                          width: 72,
                          height: 72,
                          title: '',
                          message: l10n.loadingDefaultMessage,
                        ),
                      )
                    else if (widget.controller.inboxRequestsErrorCode != null)
                      CareErrorBanner(
                        message: l10n.errorGeneric,
                        onRetry: () {
                          setState(() => _loading = true);
                          _load();
                        },
                        retryLabel: l10n.careRetry,
                      )
                    else if (!_loading && _requests.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: CareTheme.cardDecoration(),
                        child: CareEmptyState(
                          icon: Icons.inbox_rounded,
                          title: l10n.careSignalInboxEmpty,
                          message: l10n.careSignalInboxEmptyBody,
                        ),
                      )
                    else
                      for (final request in _requests)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _InboxCard(
                            request: request,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => CareSignalResponseScreen(
                                  controller: widget.controller,
                                  request: request,
                                ),
                              ),
                            ),
                          ),
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
}

class _InboxCard extends StatelessWidget {
  const _InboxCard({required this.request, required this.onTap});

  final CareSignalHelpRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final acknowledged = request.isAcknowledged;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CareTheme.radiusControl),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: CareTheme.cardDecoration(
            color: acknowledged ? CareColors.white : CareColors.ivory,
            borderColor: acknowledged ? CareColors.navySoft : CareColors.gold,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: acknowledged
                          ? CareColors.tealSoft
                          : CareColors.goldSoft,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      acknowledged
                          ? Icons.check_rounded
                          : Icons.notification_important_rounded,
                      color: acknowledged ? CareColors.teal : CareColors.coral,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.careSignalRequestFrom(
                            request.senderDisplayName ??
                                l10n.careSignalFamilyMember,
                          ),
                          style: CareTheme.text(
                            context,
                            Theme.of(context).textTheme.titleMedium,
                            size: 14.5,
                            weight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          request.requestedAt == null
                              ? l10n.careSignalNotAvailable
                              : l10n.careSignalCreatedAt(
                                  formatDateTime(context, request.requestedAt!),
                                ),
                          style: CareTheme.text(
                            context,
                            Theme.of(context).textTheme.bodySmall,
                            color: CareColors.slate,
                            size: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  CareStatusPill(
                    label: acknowledged
                        ? l10n.careSignalStatusAcknowledged
                        : l10n.careSignalStatusNew,
                    color: acknowledged ? CareColors.teal : CareColors.gold,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                request.originalMessage,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: CareTheme.text(
                  context,
                  Theme.of(context).textTheme.bodyMedium,
                  size: 13.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: CareColors.seaMist,
                  borderRadius: BorderRadius.circular(CareTheme.radiusControl),
                ),
                child: Text(
                  request.generatedSummary,
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
      ),
    );
  }
}
