import 'dart:async';
import 'dart:io';

import 'package:amarguard/features/family_safety/controllers/caresignal_controller.dart';
import 'package:amarguard/features/family_safety/controllers/family_safety_controller.dart';
import 'package:amarguard/features/family_safety/screens/caresignal_home_screen.dart';
import 'package:amarguard/features/family_safety/screens/caresignal_inbox_screen.dart';
import 'package:amarguard/features/family_safety/screens/caresignal_processing_screen.dart';
import 'package:amarguard/features/family_safety/screens/caresignal_summary_screen.dart';
import 'package:amarguard/features/family_safety/screens/family_safety_screen.dart';
import 'package:amarguard/features/family_safety/services/caresignal_api.dart';
import 'package:amarguard/features/family_safety/services/caresignal_recorder.dart';
import 'package:amarguard/features/family_safety/theme/care_colors.dart';
import 'package:amarguard/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lottie/lottie.dart';

class _LoadingFamilySafetyController extends Fake
    implements FamilySafetyController {
  @override
  CareLoadState get loadState => CareLoadState.loading;

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  Future<void> initialize({required bool isGuest}) async {}
}

class _TestRecorder implements CareSignalRecorderService {
  @override
  bool get isRecording => false;

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> hasPermission() async => false;

  @override
  Future<bool> start({String path = ''}) async => false;

  @override
  Future<String> stop() async => '';
}

CareSignalController _careSignalController(
  Future<http.Response> Function(http.Request) handler,
) {
  return CareSignalController(
    api: CareSignalApi(
      config: const CareSignalConfig(baseUrl: 'http://localhost:8000'),
      tokenProvider: () async => 'test-token',
      client: MockClient(handler),
    ),
    recorder: _TestRecorder(),
    deviceId: 'test-device',
    languageCode: 'en',
  );
}

Widget _localizedApp(Widget home) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  testWidgets(
    'CareSignal processing shows the chatbot animation and routes to results',
    (tester) async {
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.binding.setSurfaceSize(null);
      });
      await tester.binding.setSurfaceSize(const Size(360, 640));
      final pendingResponse = Completer<http.Response>();
      final controller = _careSignalController((_) => pendingResponse.future)
        ..setTranscript('I need help');

      await tester.pumpWidget(
        _localizedApp(CareSignalProcessingScreen(controller: controller)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(LottieBuilder), findsOneWidget);
      expect(find.byType(Lottie), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('caresignal-thinking-animation')),
        findsOneWidget,
      );
      expect(find.text('Care Signal AI is thinking'), findsOneWidget);
      expect(
        find.text(
          'Reading your request and loading only the family data you already approved.',
        ),
        findsNothing,
      );
      expect(find.text('Understanding your request'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      final animationFinder = find.byKey(
        const ValueKey<String>('caresignal-thinking-animation'),
      );
      final titleFinder = find.text('Care Signal AI is thinking');
      final animationSize = tester.getSize(animationFinder);
      final animationRect = tester.getRect(animationFinder);
      final titleRect = tester.getRect(titleFinder);
      expect(animationSize.width, inInclusiveRange(240, 280));
      expect(
        animationSize.width / animationSize.height,
        closeTo(1080 / 644, 0.01),
      );
      expect(animationRect.center.dx, closeTo(180, 1));
      expect(titleRect.top - animationRect.bottom, closeTo(18, 1));
      expect((animationRect.top + titleRect.bottom) / 2, closeTo(333, 2));
      expect(tester.widget<Text>(titleFinder).style?.color, CareColors.navy);
      expect(tester.takeException(), isNull);

      await tester.binding.setSurfaceSize(const Size(440, 800));
      pendingResponse.complete(
        http.Response(
          '{"summary":{}}',
          200,
          headers: const {'content-type': 'application/json'},
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(CareSignalSummaryScreen), findsOneWidget);
      expect(find.byType(LottieBuilder), findsNothing);
      controller.dispose();
    },
  );

  testWidgets('CareSignal processing honors reduced-motion preferences', (
    tester,
  ) async {
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    final pendingResponse = Completer<http.Response>();
    final controller = _careSignalController((_) => pendingResponse.future)
      ..setTranscript('I need help');

    await tester.pumpWidget(
      _localizedApp(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: CareSignalProcessingScreen(controller: controller),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      tester.widget<LottieBuilder>(find.byType(LottieBuilder)).animate,
      isFalse,
    );
    expect(find.byType(Lottie), findsOneWidget);

    pendingResponse.complete(
      http.Response(
        '{"summary":{}}',
        200,
        headers: const {'content-type': 'application/json'},
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    controller.dispose();
  });

  testWidgets(
    'CareSignal processing keeps the existing retry flow on failure',
    (tester) async {
      addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
      final pendingResponse = Completer<http.Response>();
      final controller = _careSignalController((_) => pendingResponse.future)
        ..setTranscript('I need help');

      await tester.pumpWidget(
        _localizedApp(CareSignalProcessingScreen(controller: controller)),
      );
      await tester.pump();
      pendingResponse.completeError(
        const SocketException('network unavailable'),
      );
      await tester.pump();
      await tester.pump();

      expect(
        find.text('The CareSignal backend could not be reached.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      controller.dispose();
    },
  );

  testWidgets('Family Safety initial load displays the Lottie loader', (
    tester,
  ) async {
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    await tester.pumpWidget(
      _localizedApp(
        FamilySafetyScreen(
          controller: _LoadingFamilySafetyController(),
          isGuest: false,
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('amarguard-loading-animation')),
      findsOneWidget,
    );
    expect(
      tester.getSize(
        find.byKey(const ValueKey<String>('amarguard-loading-animation')),
      ),
      const Size(160, 160),
    );
    final artworkTransform = tester.widget<Transform>(
      find
          .ancestor(
            of: find.byKey(
              const ValueKey<String>('amarguard-loading-animation'),
            ),
            matching: find.byType(Transform),
          )
          .first,
    );
    expect(artworkTransform.transform.getMaxScaleOnAxis(), 2.2);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'CareSignal sent requests show Lottie, then an error and retry empty state',
    (tester) async {
      addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
      var calls = 0;
      final pendingResponse = Completer<http.Response>();
      final controller = _careSignalController((request) async {
        calls++;
        if (calls == 1) return pendingResponse.future;
        return http.Response(
          '{"requests":[]}',
          200,
          headers: const {'content-type': 'application/json'},
        );
      });

      await tester.pumpWidget(
        _localizedApp(
          CareSignalHomeScreen(controller: controller, onBack: () {}),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey<String>('amarguard-loading-animation')),
        findsOneWidget,
      );

      pendingResponse.completeError(
        const SocketException('network unavailable'),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Retry'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('amarguard-loading-animation')),
        findsNothing,
      );

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      expect(
        find.text('You have not sent any help request yet.'),
        findsOneWidget,
      );
      expect(calls, 2);
      controller.dispose();
    },
  );

  testWidgets('CareSignal keeps existing sent requests during refresh', (
    tester,
  ) async {
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    var calls = 0;
    final pendingRefresh = Completer<http.Response>();
    final controller = _careSignalController((request) async {
      calls++;
      if (calls == 1) {
        return http.Response(
          '{"requests":[{"request_id":"req_old","sender_uid":"owner-1",'
          '"recipient_uid":"viewer-1","status":"sent",'
          '"original_message":"Help","generated_summary":"Previously loaded request",'
          '"verified_data_snapshot":{},'
          '"requested_at":"2026-01-01T10:00:00+00:00"}]}',
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      return pendingRefresh.future;
    });
    await controller.loadSent();

    await tester.pumpWidget(
      _localizedApp(
        CareSignalHomeScreen(controller: controller, onBack: () {}),
      ),
    );
    await tester.pump();
    expect(find.text('Previously loaded request'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('amarguard-loading-animation')),
      findsNothing,
    );

    pendingRefresh.completeError(const SocketException('network unavailable'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Previously loaded request'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    controller.dispose();
  });

  testWidgets('CareSignal inbox loading failure shows retry, not a spinner', (
    tester,
  ) async {
    addTearDown(() async => tester.pumpWidget(const SizedBox.shrink()));
    var calls = 0;
    final pendingResponse = Completer<http.Response>();
    final controller = _careSignalController((request) async {
      calls++;
      if (calls == 1) return pendingResponse.future;
      return http.Response(
        '{"requests":[]}',
        200,
        headers: const {'content-type': 'application/json'},
      );
    });

    await tester.pumpWidget(
      _localizedApp(CareSignalInboxScreen(controller: controller)),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('amarguard-loading-animation')),
      findsOneWidget,
    );
    pendingResponse.completeError(const SocketException('network unavailable'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Retry'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('amarguard-loading-animation')),
      findsNothing,
    );

    await tester.tap(find.text('Retry'));
    await tester.pump();
    await tester.pump();

    expect(find.text('No help requests yet.'), findsOneWidget);
    expect(calls, 2);
    controller.dispose();
  });

  test(
    'CareSignal list requests do not notify after controller disposal',
    () async {
      final sentStarted = Completer<void>();
      final pendingSent = Completer<http.Response>();
      final sentController = _careSignalController((request) {
        sentStarted.complete();
        return pendingSent.future;
      });
      final sentLoad = sentController.loadSent();
      await sentStarted.future;
      sentController.dispose();
      pendingSent.completeError(const SocketException('network unavailable'));
      expect(await sentLoad, isEmpty);

      final inboxStarted = Completer<void>();
      final pendingInbox = Completer<http.Response>();
      final inboxController = _careSignalController((request) {
        inboxStarted.complete();
        return pendingInbox.future;
      });
      final inboxLoad = inboxController.loadInbox();
      await inboxStarted.future;
      inboxController.dispose();
      pendingInbox.completeError(const SocketException('network unavailable'));
      expect(await inboxLoad, isEmpty);
    },
  );
}
