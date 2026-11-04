import 'dart:convert';
import 'dart:io';

import 'package:amarguard/features/family_safety/controllers/caresignal_controller.dart';
import 'package:amarguard/features/family_safety/services/caresignal_api.dart';
import 'package:amarguard/features/family_safety/services/caresignal_recorder.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeRecorder implements CareSignalRecorderService {
  _FakeRecorder({this.permissionGranted = true, this.recordingPath = ''});

  bool permissionGranted;
  String recordingPath;
  bool _recording = false;
  bool cancelled = false;

  @override
  bool get isRecording => _recording;

  @override
  Future<bool> hasPermission() async => permissionGranted;

  @override
  Future<bool> start({String path = ''}) async {
    _recording = true;
    return true;
  }

  @override
  Future<String> stop() async {
    _recording = false;
    return recordingPath;
  }

  @override
  Future<void> cancel() async {
    cancelled = true;
    _recording = false;
  }

  @override
  Future<void> dispose() async {}
}

http.Response _jsonResponse(Object payload, {int status = 200}) =>
    http.Response(
      jsonEncode(payload),
      status,
      headers: <String, String>{'content-type': 'application/json'},
    );

CareSignalApi _api(
  Future<http.Response> Function(http.Request request) handler,
) {
  return CareSignalApi(
    config: const CareSignalConfig(baseUrl: 'http://localhost:8000'),
    tokenProvider: () async => 'test-token',
    client: MockClient(handler),
  );
}

class _FakeFirebaseUser implements User {
  _FakeFirebaseUser(this.tokens);

  final List<String> tokens;
  final List<bool> refreshRequests = <bool>[];

  @override
  String get uid => 'verified-user';

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    refreshRequests.add(forceRefresh);
    return tokens[refreshRequests.length - 1];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeFirebaseAuth implements FirebaseAuth {
  _FakeFirebaseAuth(this.user);

  final User user;

  @override
  User get currentUser => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

CareSignalController _controller(
  CareSignalApi api,
  CareSignalRecorderService recorder,
) {
  return CareSignalController(
    api: api,
    recorder: recorder,
    deviceId: 'device-1',
    languageCode: 'bn',
  );
}

void main() {
  test('CareSignal API sends the Firebase bearer token', () async {
    late http.Request captured;
    final api = _api((request) async {
      captured = request;
      return _jsonResponse(<String, dynamic>{'requests': <dynamic>[]});
    });

    await api.sent();

    expect(captured.headers['authorization'], 'Bearer test-token');
  });

  test(
    'approved family contacts come from the authenticated endpoint',
    () async {
      late http.Request captured;
      final api = _api((request) async {
        captured = request;
        return _jsonResponse(<String, dynamic>{
          'approved_contacts': <dynamic>[
            <String, dynamic>{
              'recipient_uid': 'family-1',
              'display_name': 'A family member',
              'relationship': 'parent',
            },
          ],
        });
      });

      final contacts = await api.familyContacts(deviceId: 'device-1');

      expect(captured.url.path, '/family/contacts');
      expect(captured.url.queryParameters['device_id'], 'device-1');
      expect(contacts.single.uid, 'family-1');
      expect(contacts.single.displayName, 'A family member');
    },
  );

  test('SilentSpeak help payload explicitly excludes location', () async {
    late http.Request captured;
    final api = _api((request) async {
      captured = request;
      return _jsonResponse(<String, dynamic>{
        'request': <String, dynamic>{
          'request_id': 'request-1',
          'sender_uid': 'owner-1',
          'recipient_uid': 'family-1',
          'status': 'sent',
          'notification_status': 'submitted',
          'original_message': 'আমার সাহায্য দরকার।',
          'generated_summary': 'আমার সাহায্য দরকার।',
          'verified_data_snapshot': <String, dynamic>{},
        },
      });
    });

    await api.sendHelpRequest(
      recipientUid: 'family-1',
      language: 'bn',
      originalMessage: 'আমার সাহায্য দরকার।',
      originalTranscript: 'আমার সাহায্য দরকার।',
      generatedSummary: 'আমার সাহায্য দরকার।',
      verifiedDataSnapshot: const <String, dynamic>{},
      senderDeviceId: 'device-1',
      idempotencyKey: 'silent-speak-key-0001',
      requestType: 'general',
      detectedLanguage: 'bn',
      suggestedSafeActions: const <String>[],
      includeLocation: false,
    );

    final payload = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(payload['include_location'], isFalse);
    expect(payload['original_message'], 'আমার সাহায্য দরকার।');
    expect(payload['verified_data_snapshot'], isEmpty);
  });

  test(
    'sent history preserves backend HTTP status and error category',
    () async {
      final api = _api((request) async {
        expect(request.url.path, '/help-request/sent');
        return _jsonResponse(<String, dynamic>{
          'error': <String, dynamic>{
            'code': 'firestore_access_failed',
            'message': 'Firestore could not complete the data request.',
          },
        }, status: 503);
      });

      await expectLater(
        api.sent(),
        throwsA(
          isA<CareSignalException>()
              .having((error) => error.statusCode, 'statusCode', 503)
              .having((error) => error.code, 'code', 'firestore_access_failed'),
        ),
      );
    },
  );

  test('a 401 refreshes the Firebase ID token only once', () async {
    final user = _FakeFirebaseUser(<String>[
      'expired-test-id-token',
      'refreshed-test-id-token',
    ]);
    final auth = _FakeFirebaseAuth(user);
    var requestCount = 0;
    final api = CareSignalApi(
      config: const CareSignalConfig(baseUrl: 'http://localhost:8000'),
      auth: auth,
      client: MockClient((request) async {
        requestCount += 1;
        if (requestCount == 1) {
          expect(
            request.headers['authorization'],
            'Bearer expired-test-id-token',
          );
          return _jsonResponse(<String, dynamic>{
            'error': <String, dynamic>{
              'code': 'unauthorized',
              'message': 'Invalid or expired Firebase ID token.',
            },
          }, status: 401);
        }
        expect(
          request.headers['authorization'],
          'Bearer refreshed-test-id-token',
        );
        return _jsonResponse(<String, dynamic>{'requests': <dynamic>[]});
      }),
    );

    expect(await api.sent(), isEmpty);
    expect(requestCount, 2);
    expect(user.refreshRequests, <bool>[false, true]);
  });

  test('microphone permission denied blocks the care signal flow', () async {
    final recorder = _FakeRecorder(permissionGranted: false);
    final api = _api((_) async => _jsonResponse(<String, dynamic>{}));
    final controller = _controller(api, recorder);

    await expectLater(
      controller.prepareConsent(),
      throwsA(
        isA<CareSignalException>().having(
          (error) => error.code,
          'code',
          'microphone_permission_denied',
        ),
      ),
    );
  });

  test('empty recording is rejected before transcription', () async {
    final directory = await Directory.systemTemp.createTemp('caresignal_test');
    final audioFile = File('${directory.path}/empty.wav');
    await audioFile.writeAsBytes(<int>[0, 0, 0, 0]);

    final recorder = _FakeRecorder(recordingPath: audioFile.path);
    var transcribeCalls = 0;
    final api = _api((_) async {
      transcribeCalls += 1;
      return _jsonResponse(<String, dynamic>{'transcript': 'unused'});
    });
    final controller = _controller(api, recorder);

    controller.giveConsent(true);
    final ok = await controller.stopRecordingAndTranscribe();

    expect(ok, isFalse);
    expect(transcribeCalls, 0);
    expect(controller.stage, CareSignalStage.failed);
    expect(controller.errorCode, 'empty_recording');

    await directory.delete(recursive: true);
  });

  test('consent is required before the recording is uploaded', () async {
    final directory = await Directory.systemTemp.createTemp('caresignal_test');
    final audioFile = File('${directory.path}/recording.wav');
    await audioFile.writeAsBytes(List<int>.filled(128, 1));

    final recorder = _FakeRecorder(recordingPath: audioFile.path);
    var uploadCalls = 0;
    final api = _api((_) async {
      uploadCalls += 1;
      return _jsonResponse(<String, dynamic>{'transcript': 'আমি হারিয়ে গেছি'});
    });
    final controller = _controller(api, recorder);

    final ok = await controller.stopRecordingAndTranscribe();

    expect(ok, isFalse);
    expect(uploadCalls, 0);

    await directory.delete(recursive: true);
  });

  test('transcription preserves the original statement for review', () async {
    final directory = await Directory.systemTemp.createTemp('caresignal_test');
    final audioFile = File('${directory.path}/recording.wav');
    await audioFile.writeAsBytes(List<int>.filled(128, 1));

    final recorder = _FakeRecorder(recordingPath: audioFile.path);
    final api = _api((request) async {
      if (request.url.path.endsWith('/voice/transcribe')) {
        return _jsonResponse(<String, dynamic>{
          'transcript': 'আমি পথ হারিয়ে ফেলেছি',
        });
      }
      return _jsonResponse(<String, dynamic>{});
    });
    final controller = _controller(api, recorder);

    controller.giveConsent(true);
    final ok = await controller.stopRecordingAndTranscribe();

    expect(ok, isTrue);
    expect(controller.transcript, 'আমি পথ হারিয়ে ফেলেছি');
    expect(controller.originalTranscript, 'আমি পথ হারিয়ে ফেলেছি');
    expect(await audioFile.exists(), isFalse);

    controller.setTranscript('আমি পথ হারিয়েছি');
    expect(controller.transcript, 'আমি পথ হারিয়েছি');
    expect(controller.originalTranscript, 'আমি পথ হারিয়ে ফেলেছি');

    await directory.delete(recursive: true);
  });

  test('agent response becomes a summary with approved recipients', () async {
    final api = _api((request) async {
      if (request.url.path.endsWith('/agent/process')) {
        return _jsonResponse(<String, dynamic>{
          'summary': <String, dynamic>{
            'request_type': 'lost',
            'detected_language': 'bn',
            'original_transcript': 'আমি পথ হারিয়ে ফেলেছি',
            'user_confirmed_transcript': 'আমি পথ হারিয়ে ফেলেছি',
            'assistance_summary': 'ব্যবহারকারী পথ হারিয়ে ফেলেছেন।',
            'last_authorized_location': <String, dynamic>{
              'latitude': 23.8,
              'longitude': 90.4,
              'accuracy': 12.0,
            },
            'location_accuracy': 12.0,
            'location_timestamp': '2026-01-01T10:00:00+00:00',
            'location_freshness_status': 'fresh',
            'last_reported_battery': <String, dynamic>{'level': 55},
            'approved_recipient_options': <dynamic>[
              <String, dynamic>{
                'recipient_uid': 'viewer-1',
                'display_name': 'Son',
                'alias': 'My son',
                'relationship': 'child',
              },
            ],
            'suggested_recipient_uid': 'viewer-1',
            'recipient_match_status': 'matched',
            'suggested_safe_actions': <dynamic>['Contact your son'],
            'consent_required': true,
          },
        });
      }
      return _jsonResponse(<String, dynamic>{});
    });
    final controller = _controller(api, _FakeRecorder());

    controller.setTranscript('আমি পথ হারিয়ে ফেলেছি');
    final ok = await controller.processTranscript();

    expect(ok, isTrue);
    expect(controller.stage, CareSignalStage.awaitingConfirmation);
    expect(controller.summary, isNotNull);
    expect(controller.summary!.requestType, 'lost');
    expect(controller.summary!.approvedRecipients.length, 1);
    expect(controller.summary!.approvedRecipients.first.uid, 'viewer-1');
    expect(controller.summary!.approvedRecipients.first.alias, 'My son');
    expect(controller.summary!.suggestedRecipientUid, 'viewer-1');
    expect(controller.summary!.recipientMatchStatus, 'matched');
    expect(controller.summary!.hasLocation, isTrue);
    expect(controller.summary!.batteryLevel, 55);
  });

  test(
    'sending a help request requires a recipient and posts the snapshot',
    () async {
      final requests = <http.Request>[];
      final api = _api((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/agent/process')) {
          return _jsonResponse(<String, dynamic>{
            'summary': <String, dynamic>{
              'request_type': 'lost',
              'detected_language': 'bn',
              'original_transcript': 'আমি পথ হারিয়ে ফেলেছি',
              'user_confirmed_transcript': 'আমি পথ হারিয়ে ফেলেছি',
              'assistance_summary': 'summary',
              'location_freshness_status': 'unavailable',
              'approved_recipient_options': <dynamic>[
                <String, dynamic>{
                  'recipient_uid': 'viewer-1',
                  'display_name': 'Son',
                },
              ],
              'consent_required': true,
            },
          });
        }
        return _jsonResponse(<String, dynamic>{
          'created': true,
          'request': <String, dynamic>{
            'request_id': 'req_1',
            'sender_uid': 'owner-1',
            'recipient_uid': 'viewer-1',
            'status': 'sent',
            'original_message': 'আমি পথ হারিয়ে ফেলেছি',
            'generated_summary': 'summary',
            'verified_data_snapshot': <String, dynamic>{},
          },
        });
      });
      final controller = _controller(api, _FakeRecorder());

      final noRecipient = await controller.sendHelpRequest(recipientUid: '');
      expect(noRecipient, isFalse);
      expect(requests, isEmpty);

      controller.setTranscript('আমি পথ হারিয়ে ফেলেছি');
      final processed = await controller.processTranscript();
      expect(processed, isTrue);

      final sent = await controller.sendHelpRequest(recipientUid: 'viewer-1');
      expect(sent, isTrue);
      expect(controller.stage, CareSignalStage.sent);
      expect(
        await controller.sendHelpRequest(recipientUid: 'viewer-1'),
        isTrue,
      );
      final helpRequests = requests
          .where((request) => request.url.path.endsWith('/help-request'))
          .toList();
      expect(helpRequests, hasLength(1));
      final payload =
          jsonDecode(helpRequests.first.body) as Map<String, dynamic>;
      expect(payload['recipient_uid'], 'viewer-1');
      expect(payload['sender_device_id'], 'device-1');
    },
  );

  test('an unapproved UID is rejected before the send endpoint', () async {
    final requests = <http.Request>[];
    final api = _api((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/agent/process')) {
        return _jsonResponse(<String, dynamic>{
          'summary': <String, dynamic>{
            'approved_recipient_options': <dynamic>[
              <String, dynamic>{
                'recipient_uid': 'viewer-1',
                'display_name': 'father',
                'relationship': 'parent',
              },
            ],
          },
        });
      }
      return _jsonResponse(<String, dynamic>{});
    });
    final controller = _controller(api, _FakeRecorder());
    controller.setTranscript('আমার বাবা');
    await controller.processTranscript();

    expect(await controller.sendHelpRequest(recipientUid: 'son-uid'), isFalse);
    expect(
      requests.where((request) => request.url.path.endsWith('/help-request')),
      isEmpty,
    );
    expect(controller.errorCode, 'recipient_not_approved');
  });

  test('a retry after a transient error reuses the idempotency key', () async {
    final requestBodies = <Map<String, dynamic>>[];
    var failedOnce = false;
    final api = _api((request) async {
      if (request.url.path.endsWith('/agent/process')) {
        return _jsonResponse(<String, dynamic>{
          'summary': <String, dynamic>{
            'approved_recipient_options': <dynamic>[
              <String, dynamic>{
                'recipient_uid': 'viewer-1',
                'display_name': 'father',
                'relationship': 'parent',
              },
            ],
          },
        });
      }
      requestBodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      if (!failedOnce) {
        failedOnce = true;
        return _jsonResponse(<String, dynamic>{
          'error': <String, dynamic>{
            'code': 'temporary_failure',
            'message': 'try again',
          },
        }, status: 503);
      }
      return _jsonResponse(<String, dynamic>{
        'request': <String, dynamic>{
          'request_id': 'req_retry',
          'sender_uid': 'owner-1',
          'recipient_uid': 'viewer-1',
          'status': 'sent',
          'notification_status': 'unavailable',
          'original_message': 'আমার বাবা',
          'generated_summary': 'summary',
          'verified_data_snapshot': <String, dynamic>{},
        },
      });
    });
    final controller = _controller(api, _FakeRecorder());
    controller.setTranscript('আমার বাবা');
    await controller.processTranscript();

    expect(await controller.sendHelpRequest(recipientUid: 'viewer-1'), isFalse);
    expect(await controller.sendHelpRequest(recipientUid: 'viewer-1'), isTrue);
    expect(requestBodies, hasLength(2));
    expect(
      requestBodies[0]['idempotency_key'],
      requestBodies[1]['idempotency_key'],
    );
  });

  test('backend errors are surfaced without leaking credentials', () async {
    final api = _api((_) async {
      return _jsonResponse(<String, dynamic>{
        'error': <String, dynamic>{
          'code': 'unauthorized',
          'message': 'Meta Model API rejected the configured credential.',
        },
      }, status: 502);
    });
    final controller = _controller(api, _FakeRecorder());

    controller.setTranscript('I am lost');
    final ok = await controller.processTranscript();

    expect(ok, isFalse);
    expect(controller.stage, CareSignalStage.failed);
    expect(controller.errorCode, 'unauthorized');
    expect(controller.errorMessage, isNot(contains('Bearer')));
  });

  test('cancel clears the flow without sending anything', () async {
    var calls = 0;
    final api = _api((_) async {
      calls += 1;
      return _jsonResponse(<String, dynamic>{});
    });
    final recorder = _FakeRecorder();
    final controller = _controller(api, recorder);

    await controller.startRecording();
    await controller.cancelRecording();

    expect(recorder.cancelled, isTrue);
    expect(calls, 0);
    expect(controller.stage, CareSignalStage.cancelled);
  });

  test('sent requests are kept in the controller after sending', () async {
    final api = _api((request) async {
      if (request.url.path.endsWith('/agent/process')) {
        return _jsonResponse(<String, dynamic>{
          'summary': <String, dynamic>{
            'request_type': 'lost',
            'detected_language': 'bn',
            'original_transcript': 'আমি পথ হারিয়ে ফেলেছি',
            'user_confirmed_transcript': 'আমি পথ হারিয়ে ফেলেছি',
            'assistance_summary': 'summary',
            'location_freshness_status': 'unavailable',
            'approved_recipient_options': <dynamic>[
              <String, dynamic>{
                'recipient_uid': 'viewer-1',
                'display_name': 'Son',
              },
            ],
          },
        });
      }
      return _jsonResponse(<String, dynamic>{
        'request': <String, dynamic>{
          'request_id': 'req_1',
          'sender_uid': 'owner-1',
          'recipient_uid': 'viewer-1',
          'status': 'sent',
          'original_message': 'আমি পথ হারিয়ে ফেলেছি',
          'generated_summary': 'summary',
          'verified_data_snapshot': <String, dynamic>{},
          'requested_at': '2026-01-01T10:00:00+00:00',
        },
      });
    });
    final controller = _controller(api, _FakeRecorder());
    controller.setTranscript('আমি পথ হারিয়ে ফেলেছি');
    await controller.processTranscript();
    final sent = await controller.sendHelpRequest(recipientUid: 'viewer-1');
    expect(sent, isTrue);
    expect(controller.sentRequests, hasLength(1));
    expect(controller.sentRequests.first.requestId, 'req_1');
    expect(controller.sentRequests.first.isAcknowledged, isFalse);
  });

  test(
    'sent requests survive a restart and report the acknowledgement',
    () async {
      final api = _api((request) async {
        if (request.url.path.endsWith('/help-request/sent')) {
          return _jsonResponse(<String, dynamic>{
            'requests': <dynamic>[
              <String, dynamic>{
                'request_id': 'req_1',
                'sender_uid': 'owner-1',
                'recipient_uid': 'viewer-1',
                'status': 'acknowledged',
                'original_message': 'I am lost',
                'generated_summary': 'summary',
                'verified_data_snapshot': <String, dynamic>{},
                'requested_at': '2026-01-01T10:00:00+00:00',
                'acknowledged_at': '2026-01-01T10:05:00+00:00',
              },
            ],
          });
        }
        return _jsonResponse(<String, dynamic>{});
      });
      final controller = _controller(api, _FakeRecorder());
      final loaded = await controller.loadSent();
      expect(loaded, hasLength(1));
      expect(controller.sentRequests, hasLength(1));
      expect(controller.sentRequests.first.isAcknowledged, isTrue);
    },
  );

  test(
    'the send payload carries the request type and suggested actions',
    () async {
      final requests = <http.Request>[];
      final api = _api((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/agent/process')) {
          return _jsonResponse(<String, dynamic>{
            'summary': <String, dynamic>{
              'request_type': 'lost',
              'detected_language': 'bn',
              'original_transcript': 'আমি পথ হারিয়ে ফেলেছি',
              'user_confirmed_transcript': 'আমি পথ হারিয়ে ফেলেছি',
              'assistance_summary': 'summary',
              'location_freshness_status': 'unavailable',
              'approved_recipient_options': <dynamic>[
                <String, dynamic>{'recipient_uid': 'viewer-1'},
              ],
              'suggested_safe_actions': <dynamic>['Contact your son'],
            },
          });
        }
        return _jsonResponse(<String, dynamic>{
          'request': <String, dynamic>{
            'request_id': 'req_1',
            'status': 'sent',
            'verified_data_snapshot': <String, dynamic>{},
          },
        });
      });
      final controller = _controller(api, _FakeRecorder());
      controller.setTranscript('আমি পথ হারিয়ে ফেলেছি');
      await controller.processTranscript();
      await controller.sendHelpRequest(recipientUid: 'viewer-1');
      final helpRequests = requests
          .where((request) => request.url.path.endsWith('/help-request'))
          .toList();
      expect(helpRequests, hasLength(1));
      final payload =
          jsonDecode(helpRequests.first.body) as Map<String, dynamic>;
      expect(payload['request_type'], 'lost');
      expect(payload['detected_language'], 'bn');
      expect(payload['suggested_safe_actions'], <String>['Contact your son']);
    },
  );
}
