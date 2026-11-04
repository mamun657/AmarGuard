import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../controllers/family_safety_controller.dart';
import '../models/family_models.dart';
import '../theme/care_colors.dart';
import '../widgets/care_components.dart';
import '../widgets/care_formatters.dart';
import '../widgets/care_widgets.dart';
import 'family_member_details_screen.dart';

class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({super.key, required this.controller});

  final FamilySafetyController controller;

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
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
    final watched = widget.controller.authorizedConnections;
    final connections = watched;

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
          l10n.careFamilyMembersTitle,
          style: const TextStyle(
            color: CareColors.navy,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: connections.isEmpty
            ? CareEmptyState(
                icon: Icons.family_restroom_rounded,
                title: l10n.careNoMembers,
                message: l10n.careNoMembersBody,
              )
            : ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                itemCount: connections.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final connection = connections[index];
                  return CareMemberCard(
                    name: connection.viewerDisplayName,
                    relationshipLabel: relationshipLabel(
                      context,
                      connection.grant.relationship,
                    ),
                    freshness: connection.freshness,
                    freshnessLabel: freshnessLabelFor(
                      context,
                      connection.freshness,
                    ),
                    batteryLevel: connection.presence?.batteryLevel ?? -1,
                    isCharging: connection.presence?.isCharging ?? false,
                    lastSeenLabel: relativeTimeLabel(
                      context,
                      connection.presence?.lastSuccessfulUpload ??
                          connection.location?.syncedAt ??
                          connection.location?.capturedAt ??
                          connection.grant.grantedAt,
                    ),
                    onTap: () => _openConnection(connection),
                  );
                },
              ),
      ),
    );
  }

  Future<void> _openConnection(FamilyConnection connection) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FamilyMemberDetailsScreen(
          controller: widget.controller,
          grant: connection.grant,
          connection: connection,
          onEdit: (context) => _editAlias(context, connection),
          onRemove: (context) => _removeConnection(context, connection),
        ),
      ),
    );
  }

  Future<void> _editAlias(
    BuildContext dialogHostContext,
    FamilyConnection connection,
  ) async {
    final field = TextEditingController(text: connection.viewerDisplayName);
    final alias = await showDialog<String>(
      context: dialogHostContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit family member'),
        content: TextField(controller: field, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, field.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    field.dispose();
    if (alias == null || alias.trim().isEmpty) return;
    await widget.controller.updateConnectionAlias(connection, alias);
  }

  Future<void> _removeConnection(
    BuildContext dialogHostContext,
    FamilyConnection connection,
  ) async {
    final confirmed = await showDialog<bool>(
      context: dialogHostContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove family member?'),
        content: const Text(
          'You will no longer be able to view this member location.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.controller.removeConnection(connection);
      if (mounted) Navigator.pop(context);
    }
  }
}
