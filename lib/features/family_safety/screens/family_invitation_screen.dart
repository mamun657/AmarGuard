import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../controllers/family_safety_controller.dart';
import '../models/family_models.dart';
import '../services/family_error_messages.dart';
import '../services/secure_token.dart';
import '../theme/care_colors.dart';
import '../theme/care_theme.dart';
import '../widgets/care_formatters.dart';
import '../widgets/care_widgets.dart';
import 'family_invitation_review_screen.dart';

class FamilyInvitationScreen extends StatefulWidget {
  const FamilyInvitationScreen({
    super.key,
    required this.controller,
  });

  final FamilySafetyController controller;

  @override
  State<FamilyInvitationScreen> createState() => _FamilyInvitationScreenState();
}

class _FamilyInvitationScreenState extends State<FamilyInvitationScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isGenerating = false;
  bool _isLookingUp = false;
  String? _lookupError;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _codeController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final invitation = widget.controller.activeInvitation;
    final pendingRequests =
        widget.controller.requests.where((item) => item.isPending).toList();

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
          l10n.careAddFamilyMemberTitle,
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
            Text(
              l10n.careAddFamilyMemberSubtitle,
              style: CareTheme.text(
                context,
                Theme.of(context).textTheme.bodyMedium,
                color: CareColors.slate,
                size: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            _InviteCodeCard(
              invitation: invitation,
              isGenerating: _isGenerating,
              onGenerate: _generateInvitation,
              onCopy: _copyInvitation,
              onShare: _shareInvitation,
              onRemove: _removeInvitation,
            ),
            const SizedBox(height: 14),
            _EnterCodeCard(
              controller: _codeController,
              isLookingUp: _isLookingUp,
              errorMessage: _lookupError,
              onSubmit: _submitCode,
            ),
            if (pendingRequests.isNotEmpty) ...[
              const SizedBox(height: 24),
              CareSectionHeader(title: l10n.carePendingRequests),
              const SizedBox(height: 12),
              for (final request in pendingRequests) ...[
                _PendingRequestCard(
                  request: request,
                  onApprove: () => _approveRequest(request),
                  onReject: () => _rejectRequest(request),
                ),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _generateInvitation() async {
    setState(() => _isGenerating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.controller.createInvitation();
    } catch (_) {
      if (!messenger.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: CareColors.coral,
          content: Text(
            AppLocalizations.of(messenger.context)!.careInvitationNotFound,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _copyInvitation() async {
    final invitation = widget.controller.activeInvitation;
    if (invitation == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(
      ClipboardData(text: SecureToken.formatCode(invitation.invitationId)),
    );
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: CareColors.teal,
        content: Text(l10n.careInvitationCopied),
      ),
    );
  }

  Future<void> _shareInvitation() async {
    final invitation = widget.controller.activeInvitation;
    if (invitation == null) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final code = SecureToken.formatCode(invitation.invitationId);
    final link = 'amarguard://invite?code=$code';
    await SharePlus.instance.share(
      ShareParams(
        text: '$code\n${l10n.careInvitationSafetyNote}',
        uri: Uri.parse(link),
        subject: l10n.careAddFamilyMemberTitle,
      ),
    );
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: CareColors.teal,
        content: Text(l10n.careInvitationShared),
      ),
    );
  }

  Future<void> _removeInvitation() async {
    final invitation = widget.controller.activeInvitation;
    if (invitation == null) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CareColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Text(
          l10n.careRemoveInvitationConfirm,
          style: const TextStyle(
            color: CareColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          l10n.careRemoveInvitationBody,
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
            child: Text(l10n.careRemoveInvitation),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.controller.cancelInvitation(invitation.invitationId);
  }

  Future<void> _submitCode() async {
    final l10n = AppLocalizations.of(context)!;
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _lookupError = l10n.careInvitationCodeEmpty);
      return;
    }
    setState(() {
      _isLookingUp = true;
      _lookupError = null;
    });
    try {
      final invitation = await widget.controller.lookupInvitation(code);
      if (!mounted) return;
      setState(() => _isLookingUp = false);
      if (widget.controller.isOwnInvitation(invitation)) {
        setState(() => _lookupError = l10n.careSelfInvitation);
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => FamilyInvitationReviewScreen(
            controller: widget.controller,
            invitation: invitation,
          ),
        ),
      );
      _codeController.clear();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLookingUp = false;
        _lookupError = familySafetyErrorMessage(l10n, error);
      });
    }
  }

  Future<void> _approveRequest(ConnectionRequest request) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    try {
      await widget.controller.approveRequest(request);
      if (!messenger.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: CareColors.teal,
          content: Text(l10n.careRequestApproved),
        ),
      );
    } catch (error) {
      if (!messenger.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: CareColors.coral,
          content: Text(familySafetyErrorMessage(l10n, error)),
        ),
      );
    }
  }

  Future<void> _rejectRequest(ConnectionRequest request) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    try {
      await widget.controller.rejectRequest(request);
      if (!messenger.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: CareColors.navy,
          content: Text(l10n.careRequestRejected),
        ),
      );
    } catch (error) {
      if (!messenger.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: CareColors.coral,
          content: Text(familySafetyErrorMessage(l10n, error)),
        ),
      );
    }
  }
}

class _InviteCodeCard extends StatelessWidget {
  const _InviteCodeCard({
    required this.invitation,
    required this.isGenerating,
    required this.onGenerate,
    required this.onCopy,
    required this.onShare,
    required this.onRemove,
  });

  final FamilyInvitation? invitation;
  final bool isGenerating;
  final VoidCallback onGenerate;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasInvitation = invitation != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: CareTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CareColors.seaMist,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.qr_code_2_rounded,
                  color: CareColors.teal,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.careInvitationCodeLabel,
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
          const SizedBox(height: 14),
          if (hasInvitation)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: CareColors.seaMist,
                borderRadius: BorderRadius.circular(CareTheme.radiusControl),
                border: Border.all(color: CareColors.tealSoft),
              ),
              child: Column(
                children: [
                  Text(
                    SecureToken.formatCode(invitation!.invitationId),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: CareColors.navy,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  CareStatusPill(
                    label: l10n.careInvitationExpiresIn(
                      invitation!.expiresAt.difference(DateTime.now().toUtc()).inHours,
                      invitation!.expiresAt
                          .difference(DateTime.now().toUtc())
                          .inMinutes
                          .remainder(60),
                    ),
                    color: CareColors.teal,
                    icon: Icons.schedule_rounded,
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
              decoration: BoxDecoration(
                color: CareColors.ivory,
                borderRadius: BorderRadius.circular(CareTheme.radiusControl),
                border: Border.all(color: CareColors.navySoft),
              ),
              child: Text(
                l10n.careGenerateInvitation,
                textAlign: TextAlign.center,
                style: CareTheme.text(
                  context,
                  Theme.of(context).textTheme.bodyMedium,
                  color: CareColors.slate,
                  size: 13,
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (hasInvitation) ...[
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: onCopy,
                      style: CareTheme.primaryButtonStyle(),
                      icon: const Icon(Icons.copy_rounded, size: 18),
                      label: Text(
                        l10n.careCopyInvitationLink,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: onShare,
                      style: CareTheme.secondaryButtonStyle(),
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: Text(
                        l10n.careShareInvitation,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onRemove,
              style: TextButton.styleFrom(foregroundColor: CareColors.coral),
              child: Text(l10n.careRemoveInvitation),
            ),
          ] else
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isGenerating ? null : onGenerate,
                style: CareTheme.primaryButtonStyle(),
                icon: isGenerating
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.add_rounded, size: 20),
                label: Text(l10n.careGenerateInvitation),
              ),
            ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: CareColors.goldSoft,
              borderRadius: BorderRadius.circular(CareTheme.radiusControl),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: CareColors.gold,
                  size: 18,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    l10n.careInvitationSafetyNote,
                    style: CareTheme.text(
                      context,
                      Theme.of(context).textTheme.bodySmall,
                      color: CareColors.navy,
                      size: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnterCodeCard extends StatelessWidget {
  const _EnterCodeCard({
    required this.controller,
    required this.isLookingUp,
    required this.errorMessage,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool isLookingUp;
  final String? errorMessage;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: CareTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: CareColors.navySoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.key_rounded,
                  color: CareColors.navy,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.careEnterInvitationCode,
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
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            style: const TextStyle(
              color: CareColors.navy,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: l10n.careInvitationCodeHint,
              hintStyle: const TextStyle(
                color: CareColors.markerUnavailable,
                fontSize: 14,
                letterSpacing: 0.4,
              ),
              filled: true,
              fillColor: CareColors.ivory,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 15,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: CareColors.navySoft),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: CareColors.teal,
                  width: 1.5,
                ),
              ),
              errorText: errorMessage,
            ),
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: isLookingUp ? null : onSubmit,
              style: CareTheme.primaryButtonStyle(),
              icon: isLookingUp
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.login_rounded, size: 19),
              label: Text(l10n.careEnterInvitationCode),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingRequestCard extends StatelessWidget {
  const _PendingRequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  final ConnectionRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final name = familyPersonLabel(
      displayName: request.viewerDisplayName,
      email: request.viewerEmail,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: CareTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CareAvatar(name: name, size: 42),
              const SizedBox(width: 11),
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
                      relationshipLabel(context, request.relationship),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CareTheme.text(
                        context,
                        Theme.of(context).textTheme.bodySmall,
                        color: CareColors.slate,
                        size: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              CareStatusPill(
                label: l10n.careRequestStatusPending,
                color: CareColors.gold,
                icon: Icons.hourglass_top_rounded,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: onReject,
                    style: CareTheme.secondaryButtonStyle(
                      foreground: CareColors.coral,
                      borderColor: CareColors.coral.withValues(alpha: 0.4),
                    ),
                    child: Text(l10n.careReject),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: onApprove,
                    style: CareTheme.primaryButtonStyle(
                      minimumSize: const Size.fromHeight(46),
                    ),
                    child: Text(l10n.careApprove),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
