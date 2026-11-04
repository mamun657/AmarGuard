import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../features/family_safety/controllers/caresignal_controller.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../models/silent_speak_models.dart';
import 'silent_speak_listen_screen.dart';
import 'silent_speak_speak_screen.dart';

class SilentSpeakModeSelectionScreen extends StatefulWidget {
  const SilentSpeakModeSelectionScreen({
    super.key,
    required this.prefs,
    required this.controller,
  });

  final SharedPreferences prefs;
  final CareSignalController controller;

  @override
  State<SilentSpeakModeSelectionScreen> createState() =>
      _SilentSpeakModeSelectionScreenState();
}

class _SilentSpeakModeSelectionScreenState
    extends State<SilentSpeakModeSelectionScreen> {
  static const _preferredModeKey = 'silent_speak_preferred_mode';
  late bool _rememberMode;

  @override
  void initState() {
    super.initState();
    _rememberMode = widget.prefs.getString(_preferredModeKey) != null;
  }

  Future<void> _selectMode(SilentSpeakMode mode) async {
    if (_rememberMode) {
      await widget.prefs.setString(_preferredModeKey, mode.name);
    }
    if (!mounted) return;
    final screen = switch (mode) {
      SilentSpeakMode.speakForMe => SilentSpeakSpeakScreen(
        controller: widget.controller,
      ),
      SilentSpeakMode.listenAndUnderstand => SilentSpeakListenScreen(
        controller: widget.controller,
      ),
    };
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  Future<void> _toggleRemember(bool value) async {
    setState(() => _rememberMode = value);
    if (!value) {
      await widget.prefs.remove(_preferredModeKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final preferredMode = widget.prefs.getString(_preferredModeKey);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F6FC),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: l10n.silentSpeakBack,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ),
            const SizedBox(height: 8),
            const Icon(
              Icons.accessibility_new_rounded,
              size: 48,
              color: Color(0xFF673AB7),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.silentSpeakTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: const Color(0xFF21133A),
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.silentSpeakModeTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.silentSpeakModeHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: const Color(0xFF5F5969), height: 1.4),
            ),
            const SizedBox(height: 24),
            _ModeCard(
              icon: Icons.chat_bubble_outline_rounded,
              title: l10n.silentSpeakSpeakMode,
              description: l10n.silentSpeakSpeakDescription,
              selected: preferredMode == SilentSpeakMode.speakForMe.name,
              onTap: () => _selectMode(SilentSpeakMode.speakForMe),
            ),
            const SizedBox(height: 14),
            _ModeCard(
              icon: Icons.hearing_disabled_rounded,
              title: l10n.silentSpeakListenMode,
              description: l10n.silentSpeakListenDescription,
              selected:
                  preferredMode == SilentSpeakMode.listenAndUnderstand.name,
              onTap: () => _selectMode(SilentSpeakMode.listenAndUnderstand),
            ),
            const SizedBox(height: 20),
            Semantics(
              label: l10n.silentSpeakRememberMode,
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                minTileHeight: 56,
                value: _rememberMode,
                onChanged: _toggleRemember,
                title: Text(
                  l10n.silentSpeakRememberMode,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                activeThumbColor: const Color(0xFF673AB7),
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $description',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            constraints: const BoxConstraints(minHeight: 132),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected
                    ? const Color(0xFF673AB7)
                    : const Color(0xFFE0DCE8),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF0E9FF),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: const Color(0xFF673AB7), size: 30),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5F5969),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.arrow_forward_ios_rounded,
                  color: const Color(0xFF673AB7),
                  size: selected ? 24 : 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
