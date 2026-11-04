import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:amarguard/core/theme/app_theme.dart';
import 'package:amarguard/features/family_safety/models/family_models.dart';
import 'package:amarguard/features/family_safety/widgets/care_formatters.dart';
import 'package:amarguard/l10n/generated/app_localizations.dart';

void main() {
  group('Elapsed Time Progression', () {
    testWidgets('relativeTimeLabel advances correctly through elapsed buckets', (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('bn')],
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final now = DateTime.now().toUtc();

      final justNow = relativeTimeLabel(capturedContext, now.subtract(const Duration(seconds: 15)));
      expect(justNow, 'Just now');

      final twoMinAgo = relativeTimeLabel(capturedContext, now.subtract(const Duration(minutes: 2)));
      expect(twoMinAgo, '2 min ago');

      final fiveMinAgo = relativeTimeLabel(capturedContext, now.subtract(const Duration(minutes: 5)));
      expect(fiveMinAgo, '5 min ago');

      final twoHoursAgo = relativeTimeLabel(capturedContext, now.subtract(const Duration(hours: 2)));
      expect(twoHoursAgo, '2 h ago');
    });
  });

  group('Location Freshness vs Heartbeat', () {
    test('does not mark old GPS location as fresh when heartbeat or sync was updated', () {
      final now = DateTime.utc(2026, 10, 29, 12, 0);

      final freshnessWithRecentSync = LocationFreshnessEvaluator.evaluate(
        capturedAt: now.subtract(const Duration(minutes: 15)),
        syncedAt: now.subtract(const Duration(seconds: 30)),
        now: now,
      );
      expect(freshnessWithRecentSync, LocationFreshness.stale);

      final freshGps = LocationFreshnessEvaluator.evaluate(
        capturedAt: now.subtract(const Duration(minutes: 2)),
        syncedAt: now.subtract(const Duration(minutes: 2)),
        now: now,
      );
      expect(freshGps, LocationFreshness.fresh);

      final oldGps = LocationFreshnessEvaluator.evaluate(
        capturedAt: now.subtract(const Duration(hours: 8)),
        syncedAt: now.subtract(const Duration(hours: 8)),
        now: now,
      );
      expect(oldGps, LocationFreshness.unavailable);
    });

    test('distinguishes location sync from heartbeat presence fields', () {
      final status = DevicePresenceStatus.fromFirestore({
        'sharingState': 'active',
        'lastHeartbeat': DateTime.utc(2026, 10, 29, 12, 0),
        'lastSuccessfulUpload': DateTime.utc(2026, 10, 29, 11, 45),
        'batteryLevel': 85,
        'permissionState': 'granted',
      });

      expect(status.lastHeartbeat, DateTime.utc(2026, 10, 29, 12, 0));
      expect(status.lastSuccessfulUpload, DateTime.utc(2026, 10, 29, 11, 45));
      expect(status.lastSuccessfulUpload!.isBefore(status.lastHeartbeat!), isTrue);
    });
  });
}

