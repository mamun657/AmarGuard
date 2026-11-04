import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amarguard/core/theme/app_theme.dart';
import 'package:amarguard/features/home/dashboard_screen.dart';
import 'package:amarguard/l10n/generated/app_localizations.dart';

void main() {
  testWidgets(
    'DashboardScreen renders all sections without errors on small screen (English)',
    (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('bn')],
          home: Scaffold(
            body: DashboardScreen(
              displayName: 'didar',
              onNotificationsPressed: () {},
              onFamilySafetyPressed: () {},
              onCareSignalPressed: () {},
              onSilentSpeakPressed: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AmarGuard', findRichText: true), findsOneWidget);
      expect(find.byIcon(Icons.menu_rounded), findsNothing);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      expect(
        find.byKey(const ValueKey('home-notification-badge')),
        findsNothing,
      );
      expect(find.text('didar', findRichText: true), findsOneWidget);
      expect(find.text("You're Protected"), findsOneWidget);
      expect(find.text('Quick Actions'), findsOneWidget);
      expect(find.text('Family Safety'), findsOneWidget);
      expect(find.text('Care Signal'), findsOneWidget);
      expect(find.text('Silent Speak'), findsOneWidget);
      expect(find.byType(ClipOval), findsNWidgets(3));
      final icons = find.byType(Image);
      expect(icons, findsNWidgets(3));
      final careSignalIcon = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/icons/care_signal_action.png',
      );
      expect(careSignalIcon, findsOneWidget);
      expect(tester.getSize(careSignalIcon), const Size(38, 38));
      expect(tester.widget<Image>(careSignalIcon).fit, BoxFit.contain);
      final careSignalCenter = tester.getCenter(careSignalIcon);
      expect(
        careSignalCenter,
        tester.getCenter(
          find.ancestor(of: careSignalIcon, matching: find.byType(ClipOval)),
        ),
      );
      for (final icon in icons.evaluate()) {
        final image = icon.widget as Image;
        if ((image.image as AssetImage).assetName !=
            'assets/icons/care_signal_action.png') {
          expect(
            tester.getSize(find.byWidget(icon.widget)),
            const Size(52, 52),
          );
        }
      }
    },
  );

  testWidgets(
    'DashboardScreen renders all sections without errors on small screen (Bengali)',
    (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(locale: const Locale('bn')),
          locale: const Locale('bn'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('bn')],
          home: Scaffold(
            body: DashboardScreen(
              displayName: 'দিদার',
              onNotificationsPressed: () {},
              onFamilySafetyPressed: () {},
              onCareSignalPressed: () {},
              onSilentSpeakPressed: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('AmarGuard', findRichText: true), findsOneWidget);
      expect(find.byIcon(Icons.menu_rounded), findsNothing);
      expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
      expect(
        find.byKey(const ValueKey('home-notification-badge')),
        findsNothing,
      );
      expect(find.text('দিদার', findRichText: true), findsOneWidget);
      expect(find.text('আপনি সুরক্ষিত'), findsOneWidget);
      expect(find.text('দ্রুত কাজ'), findsOneWidget);
      expect(find.text('পরিবারের সুরক্ষা'), findsOneWidget);
      expect(find.text('কেয়ার সিগন্যাল'), findsOneWidget);
      expect(find.text('সাইলেন্ট স্পিক'), findsOneWidget);
    },
  );

  testWidgets('notification badge appears only when actionable items exist', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('bn')],
        home: Scaffold(
          body: DashboardScreen(
            displayName: 'didar',
            onNotificationsPressed: () {},
            showNotificationBadge: true,
            onFamilySafetyPressed: () {},
            onCareSignalPressed: () {},
            onSilentSpeakPressed: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home-notification-badge')),
      findsOneWidget,
    );
  });

  testWidgets('notification bell opens the inbox action', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('bn')],
        home: Scaffold(
          body: DashboardScreen(
            displayName: 'didar',
            onNotificationsPressed: () => opened = true,
            onFamilySafetyPressed: () {},
            onCareSignalPressed: () {},
            onSilentSpeakPressed: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));

    expect(opened, isTrue);
  });
}
