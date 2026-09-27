import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/locale/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/local_prefs.dart';
import '../../l10n/generated/app_localizations.dart';
import 'dashboard_screen.dart';
import 'widgets/placeholder_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.authService,
    required this.prefs,
    required this.localeController,
    required this.onSignedOut,
  });

  final AuthService authService;
  final LocalPrefs prefs;
  final LocaleController localeController;
  final VoidCallback onSignedOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  bool get _isGuest => widget.prefs.isGuest;

  User? get _user => widget.authService.currentUser;

  String get _displayName {
    if (_isGuest) return 'Guest';
    return _user?.displayName?.trim().isNotEmpty == true
        ? _user!.displayName!.trim()
        : (_user?.email?.split('@').first ?? 'there');
  }

  String get _email => _user?.email ?? 'guest@amarguard.app';

  Future<void> _handleSignOut() async {
    await widget.prefs.clearGuest();
    if (!_isGuest && widget.authService.currentUser != null) {
      await widget.authService.signOut();
    }
    if (!mounted) return;
    widget.onSignedOut();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tabs = <_TabSpec>[
      _TabSpec(
        body: DashboardScreen(
          displayName: _displayName,
          onMenuPressed: () => _showInfo(
            context,
            l10n.snackMenuTitle,
            l10n.snackMenuBody,
          ),
          onNotificationsPressed: () => _showInfo(
            context,
            l10n.snackNotificationsTitle,
            l10n.snackNotificationsBody,
          ),
        ),
      ),
      _TabSpec(body: const AnalyzeCallPage()),
      _TabSpec(body: const AnalyzePage()),
      _TabSpec(body: const HistoryPage()),
      _TabSpec(
        body: ProfilePage(
          displayName: _displayName,
          email: _email,
          isGuest: _isGuest,
          localeController: widget.localeController,
          onSignOut: _handleSignOut,
        ),
      ),
    ];

    return Scaffold(
      body: LocaleControllerScope(
        controller: widget.localeController,
        child: IndexedStack(
          index: _index,
          children: tabs.map((t) => t.body).toList(),
        ),
      ),
      bottomNavigationBar: _BottomNav(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
      ),
    );
  }

  void _showInfo(BuildContext context, String title, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec({required this.body});
  final Widget body;
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = [
      _NavItemData(
        icon: Icons.home_rounded,
        outlined: Icons.home_outlined,
        label: l10n.navHome,
      ),
      _NavItemData(
        icon: Icons.shield_rounded,
        outlined: Icons.shield_outlined,
        label: l10n.navProtect,
      ),
      _NavItemData(
        icon: Icons.center_focus_strong_rounded,
        outlined: Icons.center_focus_strong_outlined,
        label: l10n.navAnalyze,
      ),
      _NavItemData(
        icon: Icons.history_rounded,
        outlined: Icons.history_outlined,
        label: l10n.navHistory,
      ),
      _NavItemData(
        icon: Icons.person_rounded,
        outlined: Icons.person_outline_rounded,
        label: l10n.navProfile,
      ),
    ];
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        height: 68,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavItem(
                  data: items[i],
                  active: index == i,
                  onTap: () => onChanged(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.icon,
    required this.outlined,
    required this.label,
  });

  final IconData icon;
  final IconData outlined;
  final String label;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.data,
    required this.active,
    required this.onTap,
  });

  final _NavItemData data;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = active ? AppColors.primary : AppColors.textTertiary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? data.icon : data.outlined,
                size: 22,
                color: fg,
              ),
              const SizedBox(height: 3),
              Flexible(
                child: Text(
                  data.label,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                  softWrap: true,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.15,
                    color: fg,
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}