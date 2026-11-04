import 'dart:async';

import 'package:flutter/material.dart';

import '../../../features/family_safety/controllers/caresignal_controller.dart';
import '../../../l10n/generated/app_localizations.dart';
import 'silent_speak_family_help_screen.dart';
import 'silent_speak_speak_screen.dart';

class SilentSpeakListenScreen extends StatefulWidget {
  const SilentSpeakListenScreen({super.key, required this.controller});

  final CareSignalController controller;

  @override
  State<SilentSpeakListenScreen> createState() =>
      _SilentSpeakListenScreenState();
}

class _SilentSpeakListenScreenState extends State<SilentSpeakListenScreen> {
  late final TextEditingController _transcriptController;
  final TextEditingController _responseController = TextEditingController();
  bool _isUpdatingTranscript = false;

  CareSignalController get _controller => widget.controller;

  bool get _isRecording => _controller.stage == CareSignalStage.recording;

  @override
  void initState() {
    super.initState();
    _transcriptController = TextEditingController(text: _controller.transcript);
    _controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_isRecording) unawaited(_controller.cancelRecording());
    _transcriptController.dispose();
    _responseController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (!_transcriptController.text.isNotEmpty ||
        _controller.stage == CareSignalStage.awaitingConfirmation ||
        _controller.stage == CareSignalStage.failed) {
      _isUpdatingTranscript = true;
      _transcriptController.value = TextEditingValue(
        text: _controller.transcript,
        selection: TextSelection.collapsed(
          offset: _controller.transcript.length,
        ),
      );
      _isUpdatingTranscript = false;
    }
    setState(() {});
  }

  Future<void> _startRecording() async {
    if (!_controller.available) {
      setState(() {});
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final allowed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.silentSpeakPrivacyTitle),
        content: Text(l10n.silentSpeakPrivacyBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.careSignalConsentDeny),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.careSignalConsentAllow),
          ),
        ],
      ),
    );
    if (allowed != true || !mounted) return;
    _controller.giveConsent(true);
    await _controller.startRecording();
  }

  Future<void> _stopAndTranscribe() async {
    await _controller.stopRecordingAndTranscribe();
  }

  Future<void> _retry() async {
    if (_isRecording) await _controller.cancelRecording();
    _controller.reset();
    _transcriptController.clear();
    setState(() {});
  }

  Future<void> _back() async {
    if (_isRecording) await _controller.cancelRecording();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _showSpeakerPrompt() async {
    final l10n = AppLocalizations.of(context)!;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SilentSpeakMessageScreen(message: l10n.silentSpeakSpeakerPrompt),
      ),
    );
  }

  String _recordingError(AppLocalizations l10n) {
    return switch (_controller.errorCode) {
      'microphone_permission_denied' => l10n.careSignalMicDenied,
      'microphone_format_unsupported' => l10n.silentSpeakAudioUnsupported,
      'empty_recording' || 'empty_transcript' => l10n.silentSpeakNoSpeech,
      'backend_unreachable' ||
      'backend_timeout' => l10n.silentSpeakApiUnavailable,
      'unauthenticated' => l10n.silentSpeakFamilySignIn,
      _ => _controller.errorMessage ?? l10n.silentSpeakApiUnavailable,
    };
  }

  Future<void> _askFamily() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SilentSpeakFamilyHelpScreen(
          controller: _controller,
          initialMessage: '',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isTranscribing = _controller.stage == CareSignalStage.transcribing;
    final error = _controller.errorMessage;
    return PopScope<void>(
      canPop: !_isRecording,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_back());
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F6FC),
        appBar: AppBar(
          title: Text(l10n.silentSpeakListenTitle),
          backgroundColor: const Color(0xFFF8F6FC),
          leading: IconButton(
            tooltip: l10n.silentSpeakBack,
            onPressed: _back,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              Text(
                l10n.silentSpeakListenHint,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: const Color(0xFF514B5B), height: 1.45),
              ),
              const SizedBox(height: 16),
              if (_isRecording)
                Semantics(
                  liveRegion: true,
                  label: l10n.silentSpeakMicrophoneActive,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE7E5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFB3261E)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.mic_rounded, color: Color(0xFFB3261E)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l10n.silentSpeakMicrophoneActive,
                            style: const TextStyle(
                              color: Color(0xFF7F1D1D),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          _durationLabel(_controller.recordingDuration),
                          style: const TextStyle(
                            color: Color(0xFF7F1D1D),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isRecording || isTranscribing
                      ? null
                      : _startRecording,
                  icon: const Icon(Icons.mic_rounded),
                  label: Text(l10n.silentSpeakStartListening),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D756D),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFD8D3E0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              if (_isRecording) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: _stopAndTranscribe,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(l10n.silentSpeakStopRecording),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB3261E),
                      side: const BorderSide(color: Color(0xFFB3261E)),
                    ),
                  ),
                ),
              ],
              if (isTranscribing) ...[
                const SizedBox(height: 14),
                const Center(child: CircularProgressIndicator()),
              ],
              if (!_controller.available) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.silentSpeakApiUnavailable,
                  style: const TextStyle(color: Color(0xFF8A4300)),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE7E5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _recordingError(l10n),
                      style: const TextStyle(color: Color(0xFF7F1D1D)),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _ConversationCard(
                title: l10n.silentSpeakTranscriptTitle,
                child: TextField(
                  controller: _transcriptController,
                  minLines: 3,
                  maxLines: 6,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    hintText: l10n.silentSpeakTranscriptEmpty,
                    border: InputBorder.none,
                  ),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 20,
                    height: 1.5,
                    color: Colors.black,
                  ),
                  onChanged: (value) {
                    if (!_isUpdatingTranscript) {
                      _controller.setTranscript(value);
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _showSpeakerPrompt,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  foregroundColor: const Color(0xFF673AB7),
                ),
                icon: const Icon(Icons.text_fields_rounded),
                label: Text(l10n.silentSpeakShowSpeakerPrompt),
              ),
              const SizedBox(height: 18),
              _ConversationCard(
                title: l10n.silentSpeakMyResponse,
                child: TextField(
                  controller: _responseController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: l10n.silentSpeakResponseHint,
                    border: InputBorder.none,
                  ),
                  style: Theme.of(context).textTheme.bodyLarge
                      ?.copyWith(fontSize: 18, height: 1.45),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: isTranscribing ? null : _retry,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l10n.silentSpeakTryAgain),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _askFamily,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: const Color(0xFF0D756D),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.family_restroom_rounded),
                label: Text(l10n.silentSpeakAskFamily),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _durationLabel(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE0DCE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
