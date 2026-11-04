import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../core/locale/locale_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/local_prefs.dart';
import '../../l10n/generated/app_localizations.dart';
import '../family_safety/family_safety_launcher.dart';
import '../family_safety/models/family_models.dart';
import '../family_safety/services/device_identity_service.dart';
import '../family_safety/services/family_repository.dart';
import 'dashboard_screen.dart';
import 'safety_inbox_badge.dart';
import 'widgets/placeholder_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.authService,
    required this.prefs,
    required this.localeController,
    required this.onSignedOut,
    required this.beforeSignOut,
  });

  final AuthService authService;
  final LocalPrefs prefs;
  final LocaleController localeController;
  final VoidCallback onSignedOut;
  final Future<void> Function() beforeSignOut;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _careInboxSubscription;
  StreamSubscription<List<ConnectionRequest>>? _familyInboxSubscription;
  List<SafetyInboxCareRequestState> _careRequestStates = const [];
  List<SafetyInboxFamilyRequestState> _familyRequestStates = const [];
  int _inboxBindingGeneration = 0;

  bool get _isGuest => widget.prefs.isGuest;

  User? get _user => widget.authService.currentUser;

  String get _displayName {
    if (_isGuest) return 'Guest';
    return _user?.displayName?.trim().isNotEmpty == true
        ? _user!.displayName!.trim()
        : (_user?.email?.split('@').first ?? 'there');
  }

  String get _email => _user?.email ?? 'guest@amarguard.app';

  bool get _hasActionableInboxItems {
    final uid = _user?.uid;
    if (_isGuest || uid == null) return false;
    return hasActionableSafetyInboxItems(
      currentUserUid: uid,
      careRequests: _careRequestStates,
      familyRequests: _familyRequestStates,
      readCareRequestIds: widget.prefs.readCareSignalRequestIds(uid).toSet(),
    );
  }

  @override
  void initState() {
    super.initState();
    widget.prefs.careSignalReadChanges.addListener(_onCareSignalReadChanged);
    _bindInboxBadge();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((_) {
      _bindInboxBadge();
    });
  }

  @override
  void dispose() {
    _inboxBindingGeneration++;
    widget.prefs.careSignalReadChanges.removeListener(_onCareSignalReadChanged);
    unawaited(_authSubscription?.cancel());
    unawaited(_careInboxSubscription?.cancel());
    unawaited(_familyInboxSubscription?.cancel());
    super.dispose();
  }

  void _onCareSignalReadChanged() {
    if (mounted) setState(() {});
  }

  void _bindInboxBadge() {
    final generation = ++_inboxBindingGeneration;
    unawaited(_careInboxSubscription?.cancel());
    unawaited(_familyInboxSubscription?.cancel());
    _careInboxSubscription = null;
    _familyInboxSubscription = null;
    _careRequestStates = const [];
    _familyRequestStates = const [];
    if (mounted) setState(() {});

    final user = _user;
    if (_isGuest || user == null) {
      if (mounted) setState(() {});
      return;
    }

    final uid = user.uid;
    _careInboxSubscription = FirebaseFirestore.instance
        .collection('helpRequests')
        .where('recipientUid', isEqualTo: uid)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted || generation != _inboxBindingGeneration) return;
            _careRequestStates = snapshot.docs.map((doc) {
              final data = doc.data();
              return SafetyInboxCareRequestState(
                requestId: doc.id,
                recipientUid: data['recipientUid'] as String? ?? '',
                status: data['status'] as String? ?? '',
              );
            }).toList();
            setState(() {});
          },
          onError: (Object error) {
            debugPrint(
              'Safety inbox CareSignal badge error=${error.runtimeType}',
            );
          },
        );

    unawaited(_bindFamilyInboxBadge(uid, generation));
  }

  Future<void> _bindFamilyInboxBadge(String uid, int generation) async {
    try {
      final deviceId = await DeviceIdentityService(widget.prefs.preferences)
          .currentDeviceId();
      if (!mounted ||
          generation != _inboxBindingGeneration ||
          FirebaseAuth.instance.currentUser?.uid != uid) {
        return;
      }
      final repository = FamilyRepository(
        FirebaseFirestore.instance,
        FirebaseAuth.instance,
      );
      _familyInboxSubscription = repository
          .watchIncomingRequests(deviceId: deviceId)
          .listen(
            (requests) {
              if (!mounted || generation != _inboxBindingGeneration) return;
              _familyRequestStates = requests
                  .map(
                    (request) => SafetyInboxFamilyRequestState(
                      ownerUid: request.ownerUid,
                      status: request.status,
                    ),
                  )
                  .toList();
              setState(() {});
            },
            onError: (Object error) {
              debugPrint(
                'Safety inbox family badge error=${error.runtimeType}',
              );
            },
          );
    } catch (error) {
      debugPrint('Safety inbox family badge setup error=${error.runtimeType}');
    }
  }

  Future<void> _handleSignOut() async {
    await widget.prefs.clearGuest();
    if (!_isGuest && widget.authService.currentUser != null) {
      await widget.beforeSignOut();
      await widget.authService.signOut();
    }
    if (!mounted) return;
    widget.onSignedOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LocaleControllerScope(
        controller: widget.localeController,
        child: _index == 3
            ? ProfilePage(
                displayName: _displayName,
                email: _email,
                isGuest: _isGuest,
                localeController: widget.localeController,
                onSignOut: _handleSignOut,
              )
            : DashboardScreen(
                displayName: _displayName,
                onNotificationsPressed: _openSafetyInbox,
                showNotificationBadge: _hasActionableInboxItems,
                onFamilySafetyPressed: _openFamilySafety,
                onCareSignalPressed: _openCareSignal,
                onSilentSpeakPressed: _openSilentSpeak,
              ),
      ),
      bottomNavigationBar: _BottomNav(
        index: _index,
        onChanged: (i) {
          if (i == 1) {
            _openFamilySafety();
          } else if (i == 2) {
            _openCareSignal();
          } else {
            setState(() => _index = i);
          }
        },
      ),
    );
  }

  Future<void> _openSafetyInbox() async {
    if (_isGuest || _user == null) {
      final l10n = AppLocalizations.of(context)!;
      _showInfo(context, l10n.safetyInboxTitle, l10n.safetyInboxSignInPrompt);
      return;
    }
    await FamilySafetyLauncher.openSafetyInbox(
      context,
      prefs: widget.prefs.preferences,
      auth: FirebaseAuth.instance,
      firestore: FirebaseFirestore.instance,
      localPrefs: widget.prefs,
    );
    if (mounted) setState(() {});
  }

  Future<void> _openFamilySafety() async {
    await FamilySafetyLauncher.open(
      context,
      isGuest: _isGuest,
      prefs: widget.prefs.preferences,
      auth: FirebaseAuth.instance,
      firestore: FirebaseFirestore.instance,
    );
    if (mounted) setState(() => _index = 0);
  }

  Future<void> _openCareSignal() async {
    await FamilySafetyLauncher.openCareSignal(
      context,
      prefs: widget.prefs.preferences,
      auth: FirebaseAuth.instance,
    );
    if (mounted) setState(() => _index = 0);
  }

  Future<void> _openSilentSpeak() async {
    await FamilySafetyLauncher.openSilentSpeak(
      context,
      prefs: widget.prefs.preferences,
      auth: FirebaseAuth.instance,
    );
    if (mounted) setState(() => _index = 0);
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
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
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
        icon: Icons.family_restroom_rounded,
        outlined: Icons.family_restroom_outlined,
        label: l10n.familySafetyTitle,
      ),
      _NavItemData(
        icon: Icons.mic_rounded,
        outlined: Icons.mic_none_rounded,
        label: l10n.careSignalTitle,
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
              Icon(active ? data.icon : data.outlined, size: 22, color: fg),
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
