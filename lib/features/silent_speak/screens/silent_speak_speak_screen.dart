import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../features/family_safety/controllers/caresignal_controller.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/silent_speak_models.dart';
import 'silent_speak_family_help_screen.dart';

class SilentSpeakSpeakScreen extends StatefulWidget {
  const SilentSpeakSpeakScreen({super.key, required this.controller});

  final CareSignalController controller;

  @override
  State<SilentSpeakSpeakScreen> createState() => _SilentSpeakSpeakScreenState();
}

class _SilentSpeakSpeakScreenState extends State<SilentSpeakSpeakScreen> {
  final Set<SilentSpeakIntent> _selected = <SilentSpeakIntent>{};

  String _label(AppLocalizations l10n, SilentSpeakIntent intent) {
    return switch (intent) {
      SilentSpeakIntent.lost => l10n.silentSpeakIntentLost,
      SilentSpeakIntent.feelUnwell => l10n.silentSpeakIntentUnwell,
      SilentSpeakIntent.needWater => l10n.silentSpeakIntentWater,
      SilentSpeakIntent.needHelp => l10n.silentSpeakIntentHelp,
      SilentSpeakIntent.contactFamily => l10n.silentSpeakIntentFamily,
      SilentSpeakIntent.goHome => l10n.silentSpeakIntentHome,
    };
  }

  IconData _icon(SilentSpeakIntent intent) {
    return switch (intent) {
      SilentSpeakIntent.lost => Icons.explore_rounded,
      SilentSpeakIntent.feelUnwell => Icons.favorite_border_rounded,
      SilentSpeakIntent.needWater => Icons.water_drop_outlined,
      SilentSpeakIntent.needHelp => Icons.volunteer_activism_rounded,
      SilentSpeakIntent.contactFamily => Icons.family_restroom_rounded,
      SilentSpeakIntent.goHome => Icons.home_rounded,
    };
  }

  Color _color(SilentSpeakIntent intent) {
    return switch (intent) {
      SilentSpeakIntent.lost => const Color(0xFF2563A6),
      SilentSpeakIntent.feelUnwell => const Color(0xFFB63D4B),
      SilentSpeakIntent.needWater => const Color(0xFF167A8B),
      SilentSpeakIntent.needHelp => const Color(0xFF673AB7),
      SilentSpeakIntent.contactFamily => const Color(0xFF0D756D),
      SilentSpeakIntent.goHome => const Color(0xFF9A5A10),
    };
  }

  String _message(BuildContext context) => buildSpeakForMeMessage(
    _selected,
    inBangla: Localizations.localeOf(context).languageCode == 'bn',
  );

  Future<void> _openFamilyHelp(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SilentSpeakFamilyHelpScreen(
          controller: widget.controller,
          initialMessage: _message(context),
        ),
      ),
    );
  }

  Future<void> _showMessage(BuildContext context) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SilentSpeakMessageScreen(
          message: _message(context),
          onAskFamily: () => _openFamilyHelp(context),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final inBangla = Localizations.localeOf(context).languageCode == 'bn';
    final hasSelection = _selected.isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FC),
      appBar: AppBar(
        title: Text(l10n.silentSpeakSpeakTitle),
        backgroundColor: const Color(0xFFF8F6FC),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            Text(
              l10n.silentSpeakSpeakHint,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: const Color(0xFF5F5969), height: 1.45),
            ),
            const SizedBox(height: 18),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 360 ? 1 : 2;
                final textScale = MediaQuery.textScalerOf(context).scale(1);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: SilentSpeakIntent.values.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisExtent: (154 * textScale)
                        .clamp(154.0, 260.0)
                        .toDouble(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final intent = SilentSpeakIntent.values[index];
                    final selected = _selected.contains(intent);
                    final label = _label(l10n, intent);
                    final color = _color(intent);
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: '$label${selected ? ', selected' : ''}',
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (selected) {
                                _selected.remove(intent);
                              } else {
                                _selected.add(intent);
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected
                                    ? color
                                    : const Color(0xFFE0DCE8),
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_icon(intent), size: 40, color: color),
                                const SizedBox(height: 10),
                                Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        fontSize: inBangla ? 16 : 15,
                                        fontWeight: FontWeight.w800,
                                        height: 1.25,
                                      ),
                                ),
                                if (selected) ...[
                                  const SizedBox(height: 4),
                                  Icon(
                                    Icons.check_circle_rounded,
                                    size: 18,
                                    color: color,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
            const SizedBox(height: 18),
            if (hasSelection)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE0DCE8)),
                ),
                child: Text(
                  _message(context),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: inBangla ? 20 : 18,
                    height: 1.55,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              Text(
                l10n.silentSpeakSelectPrompt,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: const Color(0xFF5F5969)),
              ),
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: ElevatedButton.icon(
                onPressed: hasSelection ? () => _showMessage(context) : null,
                icon: const Icon(Icons.fullscreen_rounded),
                label: Text(l10n.silentSpeakShowMessage),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF673AB7),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFD8D3E0),
                  disabledForegroundColor: const Color(0xFF5F5969),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: hasSelection ? () => _openFamilyHelp(context) : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: const Color(0xFF0D756D),
              ),
              icon: const Icon(Icons.family_restroom_rounded),
              label: Text(l10n.silentSpeakAskFamily),
            ),
          ],
        ),
      ),
    );
  }
}

class SilentSpeakMessageScreen extends StatelessWidget {
  const SilentSpeakMessageScreen({
    super.key,
    required this.message,
    this.onAskFamily,
  });

  final String message;
  final VoidCallback? onAskFamily;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isBangla = Localizations.localeOf(context).languageCode == 'bn';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(l10n.silentSpeakMessageTitle),
        backgroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          children: [
            Text(
              l10n.silentSpeakMessageHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge
                  ?.copyWith(color: const Color(0xFF3B3544)),
            ),
            const SizedBox(height: 32),
            Container(
              constraints: const BoxConstraints(minHeight: 220),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F2FA),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFB7A6D7)),
              ),
              child: SelectableText(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.black,
                  fontSize: isBangla ? 36 : 32,
                  height: 1.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: message));
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(l10n.silentSpeakCopied)));
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.copy_rounded),
              label: Text(l10n.silentSpeakCopy),
            ),
            const SizedBox(height: 8),
            Tooltip(
              message: l10n.silentSpeakReadAloudDisabled,
              child: OutlinedButton.icon(
                onPressed: null,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.volume_up_rounded),
                label: Text(l10n.silentSpeakReadAloudDisabled),
              ),
            ),
            if (onAskFamily != null) ...[
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: onAskFamily,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: const Color(0xFF0D756D),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.family_restroom_rounded),
                label: Text(l10n.silentSpeakAskFamily),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
