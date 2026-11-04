import 'dart:async';

import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../controllers/caresignal_controller.dart';
import '../theme/care_colors.dart';
import '../theme/care_theme.dart';
import '../widgets/care_widgets.dart';
import 'caresignal_processing_screen.dart';
import 'caresignal_transcript_screen.dart';
import 'caresignal_widgets.dart';

class CareSignalRecordingScreen extends StatefulWidget {
  const CareSignalRecordingScreen({super.key, required this.controller});

  final CareSignalController controller;

  @override
  State<CareSignalRecordingScreen> createState() =>
      _CareSignalRecordingScreenState();
}

class _CareSignalRecordingScreenState extends State<CareSignalRecordingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _pulse.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = widget.controller;
    final isRecording = controller.stage == CareSignalStage.recording;
    final isTranscribing = controller.stage == CareSignalStage.transcribing;
    final seconds = controller.recordingDuration.inSeconds;
    final timerLabel =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: CareColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CareSignalBackBar(
                onBack: () => _cancel(context),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.careSignalRecordingTitle,
                style: CareTheme.text(
                  context,
                  Theme.of(context).textTheme.headlineSmall,
                  size: 23,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.careSignalRecordingHint,
                style: CareTheme.text(
                  context,
                  Theme.of(context).textTheme.bodyMedium,
                  color: CareColors.slate,
                  size: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, child) {
                          final scale = isRecording
                              ? 1 + (_pulse.value * 0.12)
                              : 1.0;
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 168,
                              height: 168,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (isRecording
                                        ? CareColors.coral
                                        : CareColors.teal)
                                    .withValues(alpha: 0.12),
                              ),
                              child: Center(
                                child: Container(
                                  width: 116,
                                  height: 116,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isRecording
                                        ? CareColors.coral
                                        : CareColors.teal,
                                    boxShadow: [
                                      BoxShadow(
                                        color:
                                            (isRecording
                                                    ? CareColors.coral
                                                    : CareColors.teal)
                                                .withValues(alpha: 0.3),
                                        blurRadius: 22,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    isRecording
                                        ? Icons.graphic_eq_rounded
                                        : Icons.mic_rounded,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 22),
                      Text(
                        timerLabel,
                        style: CareTheme.text(
                          context,
                          Theme.of(context).textTheme.displaySmall,
                          size: 34,
                          weight: FontWeight.w800,
                          color: isRecording
                              ? CareColors.navy
                              : CareColors.slate,
                        ),
                      ),
                      const SizedBox(height: 6),
                      CareStatusPill(
                        label: isRecording
                            ? l10n.careSignalRecordingTitle
                            : isTranscribing
                            ? l10n.careSignalTranscribing
                            : controller.stage == CareSignalStage.failed
                            ? l10n.careSignalFailed
                            : controller.stage == CareSignalStage.awaitingConfirmation
                            ? l10n.careSignalAwaitingConfirmation
                            : l10n.careSignalNeedHelp,
                        color: isRecording
                            ? CareColors.coral
                            : isTranscribing
                            ? CareColors.gold
                            : controller.stage == CareSignalStage.failed
                            ? CareColors.coral
                            : CareColors.teal,
                        icon: isRecording
                            ? Icons.mic_rounded
                            : isTranscribing
                            ? Icons.hourglass_top_rounded
                            : controller.stage == CareSignalStage.failed
                            ? Icons.error_outline_rounded
                            : controller.stage == CareSignalStage.awaitingConfirmation
                            ? Icons.check_circle_outline_rounded
                            : Icons.mic_none_rounded,
                      ),
                      if (controller.errorMessage != null) ...[
                        const SizedBox(height: 16),
                        CareErrorBanner(message: controller.errorMessage!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (isRecording)
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: OutlinedButton.icon(
                          onPressed: () => _cancel(context),
                          style: CareTheme.secondaryButtonStyle(),
                          icon: const Icon(Icons.close_rounded, size: 20),
                          label: Text(l10n.careSignalCancel),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: () => _stop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CareColors.coral,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(27),
                            ),
                          ),
                          icon: const Icon(Icons.stop_rounded, size: 22),
                          label: Text(l10n.careSignalStopRecording),
                        ),
                      ),
                    ),
                  ],
                )
              else if (isTranscribing)
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: null,
                    style: CareTheme.primaryButtonStyle(
                      background: CareColors.slate,
                    ),
                    child: Text(l10n.careSignalTranscribing),
                  ),
                )
              else
                SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () => _start(context),
                    style: CareTheme.primaryButtonStyle(),
                    icon: const Icon(Icons.mic_rounded, size: 20),
                    label: Text(l10n.careSignalNeedHelp),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _start(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!context.mounted) return;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: CareColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Text(
          AppLocalizations.of(dialogContext)!.careSignalConsentTitle,
          style: const TextStyle(
            color: CareColors.navy,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          AppLocalizations.of(dialogContext)!.careSignalConsentBody,
          style: const TextStyle(color: CareColors.slate, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(foregroundColor: CareColors.slate),
            child: Text(
              AppLocalizations.of(dialogContext)!.careSignalConsentDeny,
            ),
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
            child: Text(
              AppLocalizations.of(dialogContext)!.careSignalConsentAllow,
            ),
          ),
        ],
      ),
    );
    if (proceed != true) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: CareColors.navy,
            content: Text(
              AppLocalizations.of(messenger.context)!.careSignalConsentDeny,
            ),
          ),
        );
      }
      return;
    }
    widget.controller.giveConsent(true);
    final started = await widget.controller.startRecording();
    if (!started) return;
    if (messenger.mounted) {
      messenger.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: CareColors.navy,
          content: Text(
            AppLocalizations.of(messenger.context)!.careSignalConsentAllow,
          ),
        ),
      );
    }
  }

  Future<void> _stop(BuildContext context) async {
    final navigator = Navigator.of(context);
    final ok = await widget.controller.stopRecordingAndTranscribe();
    if (!ok) return;
    if (!navigator.mounted) return;
    final proceed = await navigator.push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            CareSignalTranscriptScreen(controller: widget.controller),
      ),
    );
    if (proceed != true) return;
    if (!navigator.mounted) return;
    await navigator.push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            CareSignalProcessingScreen(controller: widget.controller),
      ),
    );
  }

  Future<void> _cancel(BuildContext context) async {
    final navigator = Navigator.of(context);
    await widget.controller.cancelRecording();
    if (navigator.mounted) navigator.pop(false);
  }
}
