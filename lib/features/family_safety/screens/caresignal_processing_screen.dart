import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../controllers/caresignal_controller.dart';
import '../theme/care_colors.dart';
import '../theme/care_theme.dart';
import '../widgets/care_widgets.dart';
import 'caresignal_summary_screen.dart';
import 'caresignal_widgets.dart';

class CareSignalProcessingScreen extends StatefulWidget {
  const CareSignalProcessingScreen({super.key, required this.controller});

  final CareSignalController controller;

  @override
  State<CareSignalProcessingScreen> createState() =>
      _CareSignalProcessingScreenState();
}

class _CareSignalProcessingScreenState
    extends State<CareSignalProcessingScreen> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _run() async {
    final navigator = Navigator.of(context);
    final ok = await widget.controller.processTranscript();
    if (!ok) return;
    if (!navigator.mounted) return;
    await navigator.pushReplacement<void, void>(
      MaterialPageRoute<void>(
        builder: (_) => CareSignalSummaryScreen(controller: widget.controller),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = widget.controller;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    return Scaffold(
      backgroundColor: CareColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CareSignalBackBar(onBack: () => Navigator.of(context).pop()),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final animationHeight = math.min(
                      175.0,
                      constraints.maxHeight * 0.55,
                    );
                    final animationWidth = math.min(
                      math.min(280.0, constraints.maxWidth),
                      animationHeight * (1080 / 644),
                    );
                    final fittedHeight = animationWidth * (644 / 1080);

                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: animationWidth,
                            height: fittedHeight,
                            child: Semantics(
                              image: true,
                              label: 'Care Signal animation',
                              child: Lottie.asset(
                                'assets/images/Chatbot animation.json',
                                key: const ValueKey<String>(
                                  'caresignal-thinking-animation',
                                ),
                                repeat: true,
                                animate: !reduceMotion,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Center(
                                      child: Icon(
                                        Icons.smart_toy_outlined,
                                        size: 64,
                                        color: CareColors.navy,
                                      ),
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Care Signal AI is thinking',
                            textAlign: TextAlign.center,
                            style: CareTheme.text(
                              context,
                              Theme.of(context).textTheme.headlineSmall,
                              size: 22,
                              weight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (controller.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: CareErrorBanner(
                    message: controller.errorMessage!,
                    onRetry: _run,
                    retryLabel: l10n.careRetry,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
