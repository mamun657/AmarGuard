import 'dart:convert';

import 'package:amarguard/features/family_safety/controllers/caresignal_controller.dart';
import 'package:amarguard/features/family_safety/services/caresignal_api.dart';
import 'package:amarguard/features/family_safety/services/caresignal_recorder.dart';
import 'package:amarguard/features/silent_speak/models/silent_speak_models.dart';
import 'package:amarguard/features/silent_speak/screens/silent_speak_family_help_screen.dart';
import 'package:amarguard/features/silent_speak/screens/silent_speak_listen_screen.dart';
import 'package:amarguard/features/silent_speak/screens/silent_speak_mode_selection_screen.dart';
import 'package:amarguard/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeRecorder implements CareSignalRecorderService {
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

http.Response _json(Object body) => http.Response(
  jsonEncode(body),
  200,
  headers: const <String, String>{'content-type': 'application/json'},
);

CareSignalController _controller(
  Future<http.Response> Function(http.Request request) handler,
) {
  return CareSignalController(
    api: CareSignalApi(
      config: const CareSignalConfig(baseUrl: 'http://localhost:8000'),
      tokenProvider: () async => 'test-token',
      client: MockClient(handler),
    ),
    recorder: _FakeRecorder(),
    deviceId: 'device-1',
    languageCode: 'bn',
  );
}

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('en'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('en'), Locale('bn')],
  home: home,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('intent messages are deterministic and never add a diagnosis', () {
    final message = buildSpeakForMeMessage(const <SilentSpeakIntent>[
      SilentSpeakIntent.contactFamily,
      SilentSpeakIntent.feelUnwell,
    ], inBangla: true);

    expect(
      message,
      'আমার অসুস্থ লাগছে। অনুগ্রহ করে আমার পরিবারের সঙ্গে যোগাযোগ করতে সাহায্য করুন।',
    );
    expect(message, isNot(contains('হার্ট অ্যাটাক')));
    expect(buildSpeakForMeMessage(const [], inBangla: false), isEmpty);
  });

  testWidgets(
    'Speak for Me creates a large offline message from card choices',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      final controller = _controller((_) async => _json(<String, dynamic>{}));
      await tester.pumpWidget(
        _app(
          SilentSpeakModeSelectionScreen(prefs: prefs, controller: controller),
        ),
      );

      await tester.tap(find.byType(SwitchListTile));
      await tester.tap(find.text('I Cannot Speak'));
      await tester.pumpAndSettle();
      expect(find.text('Speak for Me'), findsOneWidget);

      await tester.tap(find.text('I feel unwell'));
      await tester.ensureVisible(find.text('Contact my family'));
      await tester.tap(find.text('Contact my family'));
      await tester.pumpAndSettle();
      expect(
        find.text('I do not feel well. Please help me contact my family.'),
        findsOneWidget,
      );

      await tester.ensureVisible(find.text('Show message'));
      await tester.tap(find.text('Show message'));
      await tester.pumpAndSettle();
      expect(find.text('Show this message'), findsOneWidget);
      expect(
        find.text('I do not feel well. Please help me contact my family.'),
        findsOneWidget,
      );
      expect(
        find.text('Read aloud is unavailable on this device.'),
        findsOneWidget,
      );
      expect(
        prefs.getString('silent_speak_preferred_mode'),
        SilentSpeakMode.speakForMe.name,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets(
    'Listen & Understand keeps manual text local and shows speaker prompt',
    (tester) async {
      final controller = _controller((_) async => _json(<String, dynamic>{}));
      await tester.pumpWidget(
        _app(Scaffold(body: SilentSpeakListenScreen(controller: controller))),
      );

      expect(find.text('Start Listening'), findsOneWidget);
      expect(find.text('Microphone active'), findsNothing);
      await tester.enterText(
        find.byType(TextField).first,
        'The train leaves at six.',
      );
      expect(controller.transcript, 'The train leaves at six.');

      await tester.tap(find.text('Show this to the speaker'));
      await tester.pumpAndSettle();
      expect(
        find.text('I cannot hear. Please type your message.'),
        findsOneWidget,
      );

      controller.dispose();
    },
  );

  testWidgets('family help sends only the confirmed message without location', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    late Map<String, dynamic> helpPayload;
    final controller = _controller((request) async {
      if (request.url.path == '/family/contacts') {
        return _json(<String, dynamic>{
          'approved_contacts': <dynamic>[
            <String, dynamic>{
              'recipient_uid': 'family-1',
              'display_name': 'Family member',
              'relationship': 'parent',
            },
          ],
        });
      }
      helpPayload = jsonDecode(request.body) as Map<String, dynamic>;
      return _json(<String, dynamic>{
        'request': <String, dynamic>{
          'request_id': 'request-1',
          'sender_uid': 'owner-1',
          'recipient_uid': 'family-1',
          'status': 'sent',
          'notification_status': 'submitted',
          'original_message': 'I need help.',
          'generated_summary': 'I need help.',
          'verified_data_snapshot': <String, dynamic>{},
        },
      });
    });
    controller.setTranscript('This private conversation must stay local.');

    await tester.pumpWidget(
      _app(
        Scaffold(
          body: SilentSpeakFamilyHelpScreen(
            controller: controller,
            initialMessage: '',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'I need help.');
    await tester.tap(find.text('Family member'));
    await tester.tap(find.text('Review request'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm and send'));
    await tester.pumpAndSettle();

    expect(helpPayload['include_location'], isFalse);
    expect(helpPayload['original_message'], 'I need help.');
    expect(helpPayload['original_transcript'], 'I need help.');
    expect(helpPayload['recipient_uid'], 'family-1');
    expect(
      helpPayload['original_message'],
      isNot('This private conversation must stay local.'),
    );
    expect(find.text('Request saved on the server.'), findsOneWidget);

    controller.dispose();
  });
}
