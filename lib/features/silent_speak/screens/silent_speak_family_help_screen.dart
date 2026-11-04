import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../features/family_safety/controllers/caresignal_controller.dart';
import '../../../features/family_safety/services/caresignal_api.dart';
import '../../../l10n/generated/app_localizations.dart';

class SilentSpeakFamilyHelpScreen extends StatefulWidget {
  const SilentSpeakFamilyHelpScreen({
    super.key,
    required this.controller,
    required this.initialMessage,
  });

  final CareSignalController controller;
  final String initialMessage;

  @override
  State<SilentSpeakFamilyHelpScreen> createState() =>
      _SilentSpeakFamilyHelpScreenState();
}

class _SilentSpeakFamilyHelpScreenState
    extends State<SilentSpeakFamilyHelpScreen> {
  late final TextEditingController _messageController;
  List<CareSignalRecipient> _recipients = const <CareSignalRecipient>[];
  String? _selectedUid;
  String? _errorMessage;
  String? _idempotencyKey;
  CareSignalHelpRequest? _savedRequest;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: widget.initialMessage);
    _messageController.addListener(_onMessageChanged);
    unawaited(_loadRecipients());
  }

  @override
  void dispose() {
    _messageController
      ..removeListener(_onMessageChanged)
      ..dispose();
    super.dispose();
  }

  void _onMessageChanged() {
    if (_savedRequest != null) return;
    _idempotencyKey = null;
    if (mounted) setState(() {});
  }

  Future<void> _loadRecipients() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final recipients = await widget.controller.api.familyContacts(
        deviceId: widget.controller.deviceId,
      );
      if (!mounted) return;
      setState(() {
        _recipients = recipients;
        _loading = false;
      });
    } on CareSignalException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyError(AppLocalizations.of(context)!, error);
        _loading = false;
      });
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _errorMessage = AppLocalizations.of(context)!
            .silentSpeakFamilyRequestFailed;
        _loading = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _errorMessage = AppLocalizations.of(context)!
            .silentSpeakFamilyRequestFailed;
        _loading = false;
      });
    } catch (error) {
      debugPrint('SilentSpeak family contacts error=${error.runtimeType}');
      if (!mounted) return;
      setState(() {
        _errorMessage = AppLocalizations.of(context)!
            .silentSpeakFamilyRequestFailed;
        _loading = false;
      });
    }
  }

  String _friendlyError(AppLocalizations l10n, CareSignalException error) {
    if (error.code == 'unauthenticated') return l10n.silentSpeakFamilySignIn;
    if (error.code == 'backend_unreachable' ||
        error.code == 'backend_timeout' ||
        error.code == 'request_failed') {
      return l10n.silentSpeakFamilyRequestFailed;
    }
    return error.message;
  }

  String _newIdempotencyKey() {
    final random = Random.secure();
    final salt = random.nextInt(1 << 32).toRadixString(16);
    return 'ss-${DateTime.now().millisecondsSinceEpoch}-$salt';
  }

  CareSignalRecipient? get _selectedRecipient {
    for (final recipient in _recipients) {
      if (recipient.uid == _selectedUid) return recipient;
    }
    return null;
  }

  Future<void> _reviewAndSend() async {
    final l10n = AppLocalizations.of(context)!;
    final recipient = _selectedRecipient;
    final message = _messageController.text.trim();
    if (recipient == null || message.isEmpty) {
      setState(() {
        _errorMessage = recipient == null
            ? l10n.silentSpeakFamilyNoRecipients
            : l10n.silentSpeakEnterMessage;
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.silentSpeakFamilyConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.silentSpeakFamilyConfirmBody),
            const SizedBox(height: 12),
            Text(
              recipient.displayName,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            SelectableText(message),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.careSignalCancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.silentSpeakFamilySend),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final selected = recipient;
    final language = Localizations.localeOf(context).languageCode == 'bn'
        ? 'bn'
        : 'en';
    final idempotencyKey = _idempotencyKey ??= _newIdempotencyKey();
    setState(() {
      _sending = true;
      _errorMessage = null;
    });
    try {
      final request = await widget.controller.api.sendHelpRequest(
        recipientUid: selected.uid,
        language: language,
        originalMessage: message,
        originalTranscript: message,
        generatedSummary: message,
        verifiedDataSnapshot: const <String, dynamic>{},
        senderDeviceId: widget.controller.deviceId,
        idempotencyKey: idempotencyKey,
        requestType: 'general',
        detectedLanguage: language,
        suggestedSafeActions: const <String>[],
        includeLocation: false,
      );
      if (!mounted) return;
      setState(() {
        _savedRequest = request;
        _sending = false;
      });
    } on CareSignalException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyError(AppLocalizations.of(context)!, error);
        _sending = false;
      });
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _errorMessage = AppLocalizations.of(context)!
            .silentSpeakFamilyRequestFailed;
        _sending = false;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _errorMessage = AppLocalizations.of(context)!
            .silentSpeakFamilyRequestFailed;
        _sending = false;
      });
    } catch (error) {
      debugPrint('SilentSpeak help request error=${error.runtimeType}');
      if (!mounted) return;
      setState(() {
        _errorMessage = AppLocalizations.of(context)!
            .silentSpeakFamilyRequestFailed;
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FC),
      appBar: AppBar(
        title: Text(l10n.silentSpeakFamilyTitle),
        backgroundColor: const Color(0xFFF8F6FC),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            Text(
              l10n.silentSpeakFamilyHint,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(height: 1.45, color: const Color(0xFF514B5B)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _messageController,
              minLines: 3,
              maxLines: 6,
              maxLength: 4000,
              readOnly: _savedRequest != null,
              decoration: InputDecoration(
                labelText: l10n.silentSpeakFamilyMessageLabel,
                hintText: l10n.silentSpeakFamilyMessageHint,
                alignLabelWithHint: true,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE9F5F1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.privacy_tip_outlined,
                    color: Color(0xFF0D756D),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(l10n.silentSpeakFamilyPrivacy)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              l10n.silentSpeakFamilyRecipients,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (_loading)
              Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                  Text(l10n.silentSpeakFamilyLoading),
                ],
              )
            else if (_recipients.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _errorMessage ?? l10n.silentSpeakFamilyNoRecipients,
                ),
              )
            else
              RadioGroup<String>(
                groupValue: _selectedUid,
                onChanged: (value) {
                  if (_savedRequest != null) return;
                  setState(() {
                    _selectedUid = value;
                    _idempotencyKey = null;
                  });
                },
                child: Column(
                  children: [
                    ..._recipients.map(
                      (recipient) => Semantics(
                        button: true,
                        selected: recipient.uid == _selectedUid,
                        child: Card(
                          color: Colors.white,
                          child: RadioListTile<String>(
                            value: recipient.uid,
                            title: Text(
                              recipient.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(recipient.relationship),
                            activeColor: const Color(0xFF673AB7),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_errorMessage != null && _recipients.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Color(0xFFB3261E)),
              ),
            ],
            if (_savedRequest != null) ...[
              const SizedBox(height: 16),
              _RequestSavedCard(request: _savedRequest!),
            ],
            const SizedBox(height: 20),
            if (_savedRequest == null)
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _loading || _sending || _recipients.isEmpty
                      ? null
                      : _reviewAndSend,
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _sending
                        ? l10n.silentSpeakFamilySending
                        : l10n.silentSpeakFamilyPreview,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF673AB7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              )
            else
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.silentSpeakBack),
              ),
          ],
        ),
      ),
    );
  }
}

class _RequestSavedCard extends StatelessWidget {
  const _RequestSavedCard({required this.request});

  final CareSignalHelpRequest request;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final statusMessage = request.isAcknowledged
        ? l10n.silentSpeakFamilyAcknowledged
        : switch (request.notificationStatus) {
            'submitted' => l10n.silentSpeakFamilyNotificationSubmitted,
            'failed' ||
            'unavailable' => l10n.silentSpeakFamilyNotificationFailed,
            _ => l10n.careSignalStatusPending,
          };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE9F5F1),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF78BBA7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.silentSpeakFamilySaved,
              style: const TextStyle(
                color: Color(0xFF0D756D),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(statusMessage),
          ],
        ),
      ),
    );
  }
}
