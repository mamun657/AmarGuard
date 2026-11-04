import 'package:flutter/material.dart';

import '../models/family_models.dart';
import '../services/caresignal_api.dart';
import '../theme/care_colors.dart';
import '../theme/care_theme.dart';
import '../widgets/care_formatters.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../shared/widgets/amarguard_loading.dart';

typedef SafetyInboxCareLoader = Future<List<CareSignalHelpRequest>> Function();
typedef SafetyInboxFamilyLoader = Future<List<ConnectionRequest>> Function();
typedef SafetyInboxCareOpener = Future<void> Function(
  CareSignalHelpRequest request,
);
typedef SafetyInboxFamilyOpener = Future<void> Function(
  ConnectionRequest request,
);
typedef SafetyInboxReadMarker = Future<void> Function(String requestId);

class SafetyInboxScreen extends StatefulWidget {
  const SafetyInboxScreen({
    super.key,
    required this.currentUserUid,
    required this.loadCareRequests,
    required this.loadFamilyRequests,
    required this.openCareRequest,
    required this.openFamilyRequest,
    required this.markCareRequestRead,
    required this.readCareRequestIds,
  });

  final String currentUserUid;
  final SafetyInboxCareLoader loadCareRequests;
  final SafetyInboxFamilyLoader loadFamilyRequests;
  final SafetyInboxCareOpener openCareRequest;
  final SafetyInboxFamilyOpener openFamilyRequest;
  final SafetyInboxReadMarker markCareRequestRead;
  final Set<String> readCareRequestIds;

  @override
  State<SafetyInboxScreen> createState() => _SafetyInboxScreenState();
}

class _SafetyInboxScreenState extends State<SafetyInboxScreen> {
  List<CareSignalHelpRequest> _careRequests = const [];
  List<ConnectionRequest> _familyRequests = const [];
  final Set<String> _readCareRequestIds = <String>{};
  bool _loading = true;
  String? _careError;
  String? _familyError;

  @override
  void initState() {
    super.initState();
    _readCareRequestIds.addAll(widget.readCareRequestIds);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _careError = null;
      _familyError = null;
    });

    try {
      final requests = await widget.loadCareRequests();
      _careRequests =
          requests
              .where((request) => request.recipientUid == widget.currentUserUid)
              .toList()
            ..sort(_compareCareRequests);
    } catch (error) {
      debugPrint('Safety inbox CareSignal load error=${error.runtimeType}');
      _careError = 'care';
      _careRequests = const [];
    }

    try {
      final requests = await widget.loadFamilyRequests();
      _familyRequests =
          requests
              .where(
                (request) =>
                    request.ownerUid == widget.currentUserUid &&
                    request.isPending,
              )
              .toList()
            ..sort(
              (left, right) =>
                  (right.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0))
                      .compareTo(
                        left.requestedAt ??
                            DateTime.fromMillisecondsSinceEpoch(0),
                      ),
            );
    } catch (error) {
      debugPrint(
        'Safety inbox family requests load error=${error.runtimeType}',
      );
      _familyError = 'family';
      _familyRequests = const [];
    }

    if (mounted) setState(() => _loading = false);
  }

  int _compareCareRequests(
    CareSignalHelpRequest left,
    CareSignalHelpRequest right,
  ) {
    final leftTime = left.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final rightTime =
        right.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return rightTime.compareTo(leftTime);
  }

  Future<void> _openCareRequest(CareSignalHelpRequest request) async {
    final wasRead = _readCareRequestIds.contains(request.requestId);
    setState(() => _readCareRequestIds.add(request.requestId));
    try {
      await widget.markCareRequestRead(request.requestId);
      await widget.openCareRequest(request);
      if (mounted) await _load();
    } catch (error) {
      if (!mounted) return;
      if (!wasRead) {
        setState(() => _readCareRequestIds.remove(request.requestId));
      }
      debugPrint('Safety inbox CareSignal open error=${error.runtimeType}');
      _showError();
    }
  }

  Future<void> _openFamilyRequest(ConnectionRequest request) async {
    try {
      await widget.openFamilyRequest(request);
      if (mounted) await _load();
    } catch (error) {
      if (!mounted) return;
      debugPrint('Safety inbox family request open error=${error.runtimeType}');
      _showError();
    }
  }

  void _showError() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: CareColors.coral,
        content: Text(AppLocalizations.of(context)!.errorGeneric),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final itemsExist = _careRequests.isNotEmpty || _familyRequests.isNotEmpty;

    return Scaffold(
      backgroundColor: CareColors.ivory,
      appBar: AppBar(
        backgroundColor: CareColors.ivory,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded, color: CareColors.navy),
        ),
        title: Text(
          l10n.safetyInboxTitle,
          style: const TextStyle(
            color: CareColors.navy,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: l10n.careSignalTryAgain,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, color: CareColors.teal),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: CareColors.teal,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              Text(
                l10n.safetyInboxSubtitle,
                style: CareTheme.text(
                  context,
                  Theme.of(context).textTheme.bodyMedium,
                  color: CareColors.slate,
                  size: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              if (_loading && !itemsExist)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: AmarGuardLoading(
                    variant: AmarGuardLoadingVariant.section,
                    width: 76,
                    height: 76,
                    title: '',
                    message: l10n.loadingDefaultMessage,
                  ),
                )
              else ...[
                if (_careError != null)
                  _InboxErrorCard(
                    message: l10n.safetyInboxCareSignalError,
                    onRetry: _load,
                  ),
                if (_familyError != null)
                  _InboxErrorCard(
                    message: l10n.safetyInboxFamilyError,
                    onRetry: _load,
                  ),
                if (!itemsExist && _careError == null && _familyError == null)
                  _InboxEmptyCard(
                    title: l10n.safetyInboxEmptyTitle,
                    message: l10n.safetyInboxEmptyBody,
                  )
                else ...[
                  for (final request in _careRequests)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _CareSignalInboxCard(
                        request: request,
                        isRead: _readCareRequestIds.contains(request.requestId),
                        onTap: () => _openCareRequest(request),
                      ),
                    ),
                  for (final request in _familyRequests)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _FamilyRequestInboxCard(
                        request: request,
                        onTap: () => _openFamilyRequest(request),
                      ),
                    ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CareSignalInboxCard extends StatelessWidget {
  const _CareSignalInboxCard({
    required this.request,
    required this.isRead,
    required this.onTap,
  });

  final CareSignalHelpRequest request;
  final bool isRead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final acknowledged = request.isAcknowledged;
    final sentAt = request.requestedAt;
    final statusColor = acknowledged ? CareColors.teal : CareColors.coral;

    return _InboxCard(
      icon: acknowledged
          ? Icons.check_circle_rounded
          : Icons.crisis_alert_rounded,
      iconColor: acknowledged ? CareColors.teal : CareColors.coral,
      iconBackground: acknowledged ? CareColors.tealSoft : CareColors.coralSoft,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InboxHeading(
            title: l10n.safetyInboxCareSignal,
            status: acknowledged
                ? l10n.safetyInboxAcknowledged
                : isRead
                ? l10n.safetyInboxRead
                : l10n.safetyInboxUnread,
            statusColor: statusColor,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.careSignalRequestFrom(
              request.senderDisplayName ?? l10n.careSignalFamilyMember,
            ),
            style: CareTheme.text(
              context,
              Theme.of(context).textTheme.bodyMedium,
              color: CareColors.navy,
              size: 13,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            requestTypeLabel(context, request.requestType),
            style: const TextStyle(
              color: CareColors.slate,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _InboxMetadata(
            source: l10n.safetyInboxSourceCareSignal,
            timestamp: sentAt == null
                ? l10n.careSignalNotAvailable
                : relativeTimeLabel(context, sentAt),
            requestStatus: acknowledged
                ? l10n.safetyInboxAcknowledged
                : l10n.safetyInboxAwaitingResponse,
            statusColor: statusColor,
          ),
        ],
      ),
    );
  }
}

class _FamilyRequestInboxCard extends StatelessWidget {
  const _FamilyRequestInboxCard({required this.request, required this.onTap});

  final ConnectionRequest request;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _InboxCard(
      icon: Icons.person_add_alt_1_rounded,
      iconColor: CareColors.gold,
      iconBackground: CareColors.goldSoft,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _InboxHeading(
            title: l10n.safetyInboxFamilyAccess,
            status: l10n.safetyInboxPendingApproval,
            statusColor: CareColors.gold,
          ),
          const SizedBox(height: 4),
          Text(
            request.viewerDisplayName,
            style: CareTheme.text(
              context,
              Theme.of(context).textTheme.bodyMedium,
              color: CareColors.navy,
              size: 13,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          _InboxMetadata(
            source: l10n.safetyInboxSourceFamilySafety,
            timestamp: request.requestedAt == null
                ? l10n.careSignalNotAvailable
                : relativeTimeLabel(context, request.requestedAt!),
            requestStatus: l10n.safetyInboxPendingApproval,
            statusColor: CareColors.gold,
          ),
        ],
      ),
    );
  }
}

class _InboxCard extends StatelessWidget {
  const _InboxCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.onTap,
    required this.child,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: CareColors.white,
      borderRadius: BorderRadius.circular(CareTheme.radiusControl),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CareTheme.radiusControl),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: CareTheme.cardDecoration(
            color: CareColors.white,
            borderColor: CareColors.navySoft,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(child: child),
              const SizedBox(width: 4),
              const Icon(
                Icons.chevron_right_rounded,
                color: CareColors.slate,
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InboxHeading extends StatelessWidget {
  const _InboxHeading({
    required this.title,
    required this.status,
    required this.statusColor,
  });

  final String title;
  final String status;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: CareTheme.text(
              context,
              Theme.of(context).textTheme.titleMedium,
              color: CareColors.navy,
              size: 14.5,
              weight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            status,
            style: TextStyle(
              color: statusColor == CareColors.gold
                  ? CareColors.navy
                  : statusColor,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _InboxMetadata extends StatelessWidget {
  const _InboxMetadata({
    required this.source,
    required this.timestamp,
    required this.requestStatus,
    required this.statusColor,
  });

  final String source;
  final String timestamp;
  final String requestStatus;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        Text(
          source,
          style: const TextStyle(
            color: CareColors.slate,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          timestamp,
          style: const TextStyle(color: CareColors.slate, fontSize: 11),
        ),
        Text(
          '${l10n.safetyInboxStatusLabel}: $requestStatus',
          style: TextStyle(
            color: statusColor == CareColors.gold
                ? CareColors.navy
                : statusColor,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _InboxEmptyCard extends StatelessWidget {
  const _InboxEmptyCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 18),
      decoration: CareTheme.cardDecoration(),
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, color: CareColors.teal, size: 34),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: CareTheme.text(
              context,
              Theme.of(context).textTheme.titleMedium,
              size: 15,
              weight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            textAlign: TextAlign.center,
            style: CareTheme.text(
              context,
              Theme.of(context).textTheme.bodySmall,
              color: CareColors.slate,
              size: 12.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxErrorCard extends StatelessWidget {
  const _InboxErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: CareTheme.cardDecoration(
          color: CareColors.coralSoft,
          borderColor: CareColors.coral.withValues(alpha: 0.4),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: CareColors.coral),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: CareColors.navy, fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context)!.careRetry),
            ),
          ],
        ),
      ),
    );
  }
}
