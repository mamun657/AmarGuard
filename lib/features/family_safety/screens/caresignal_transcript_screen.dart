import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../controllers/caresignal_controller.dart';
import '../theme/care_colors.dart';
import '../theme/care_theme.dart';
import 'caresignal_widgets.dart';

class CareSignalTranscriptScreen extends StatefulWidget {
  const CareSignalTranscriptScreen({super.key, required this.controller});

  final CareSignalController controller;

  @override
  State<CareSignalTranscriptScreen> createState() =>
      _CareSignalTranscriptScreenState();
}

class _CareSignalTranscriptScreenState
    extends State<CareSignalTranscriptScreen> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(
      text: widget.controller.transcript,
    );
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _textController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = widget.controller;

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
                onBack: () => Navigator.of(context).pop(false),
              ),
              const SizedBox(height: 18),
              Text(
                l10n.careSignalTranscriptTitle,
                style: CareTheme.text(
                  context,
                  Theme.of(context).textTheme.headlineSmall,
                  size: 23,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.careSignalTranscriptHint,
                style: CareTheme.text(
                  context,
                  Theme.of(context).textTheme.bodyMedium,
                  color: CareColors.slate,
                  size: 13.5,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: CareTheme.cardDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.careSignalTranscriptLabel,
                      style: CareTheme.text(
                        context,
                        Theme.of(context).textTheme.bodySmall,
                        color: CareColors.slate,
                        size: 12,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _textController,
                      minLines: 4,
                      maxLines: 8,
                      style: CareTheme.text(
                        context,
                        Theme.of(context).textTheme.bodyLarge,
                        size: 15,
                        height: 1.5,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: CareColors.ivory,
                        contentPadding: const EdgeInsets.all(13),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            CareTheme.radiusControl,
                          ),
                          borderSide: const BorderSide(color: CareColors.navySoft),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(
                            CareTheme.radiusControl,
                          ),
                          borderSide: const BorderSide(color: CareColors.navySoft),
                        ),
                      ),
                      onChanged: controller.setTranscript,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: CareColors.seaMist,
                  borderRadius: BorderRadius.circular(CareTheme.radiusControl),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: CareColors.teal,
                      size: 19,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.careSignalPrivacyNote,
                        style: CareTheme.text(
                          context,
                          Theme.of(context).textTheme.bodySmall,
                          color: CareColors.tealDeep,
                          size: 12.5,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: () {
                    controller.setTranscript(_textController.text);
                    Navigator.of(context).pop(true);
                  },
                  style: CareTheme.primaryButtonStyle(),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: Text(l10n.careSignalContinue),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
