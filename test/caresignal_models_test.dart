import 'dart:io';

import 'package:amarguard/features/family_safety/services/caresignal_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('care signal config uses the correct local backend default for this platform', () {
    final expected = Platform.isAndroid
        ? 'http://10.0.2.2:8001'
        : 'http://127.0.0.1:8001';
    expect(CareSignalConfig.resolve().baseUrl, expected);
  });

  test('care signal summary parses a verified payload', () {
    final summary = CareSignalSummary.fromJson(<String, dynamic>{
      'request_type': 'lost',
      'detected_language': 'bn',
      'original_transcript': 'আমি পথ হারিয়ে ফেলেছি',
      'user_confirmed_transcript': 'আমি পথ হারিয়ে ফেলেছি',
      'assistance_summary': 'ব্যবহারকারী পথ হারিয়ে ফেলেছেন।',
      'last_authorized_location': <String, dynamic>{
        'latitude': 23.8,
        'longitude': 90.4,
        'accuracy': 12.5,
      },
      'location_accuracy': 12.5,
      'location_timestamp': '2026-01-01T10:00:00+00:00',
      'location_freshness_status': 'fresh',
      'last_reported_battery': <String, dynamic>{'level': 55},
      'approved_recipient_options': <dynamic>[
        <String, dynamic>{
          'recipient_uid': 'viewer-1',
          'display_name': 'Son',
          'relationship': 'child',
        },
      ],
      'suggested_safe_actions': <dynamic>['Contact a family member'],
      'consent_required': true,
    });

    expect(summary.requestType, 'lost');
    expect(summary.detectedLanguage, 'bn');
    expect(summary.hasLocation, isTrue);
    expect(summary.locationAccuracy, 12.5);
    expect(summary.batteryLevel, 55);
    expect(summary.approvedRecipients.length, 1);
    expect(summary.approvedRecipients.first.uid, 'viewer-1');
    expect(summary.originalTranscript, summary.userConfirmedTranscript);
    expect(summary.suggestedSafeActions, isNotEmpty);
  });

  test(
    'care signal summary reports missing location without inventing values',
    () {
      final summary = CareSignalSummary.fromJson(<String, dynamic>{
        'request_type': 'lost',
        'detected_language': 'en',
        'assistance_summary': 'User reported being lost.',
        'location_freshness_status': 'sharing_disabled',
      });

      expect(summary.hasLocation, isFalse);
      expect(summary.locationAccuracy, isNull);
      expect(summary.locationTimestamp, isNull);
      expect(summary.batteryLevel, isNull);
      expect(summary.approvedRecipients, isEmpty);
    },
  );

  test('help request parses snapshot and status', () {
    final request = CareSignalHelpRequest.fromJson(<String, dynamic>{
      'request_id': 'req_abc',
      'sender_uid': 'owner-1',
      'recipient_uid': 'viewer-1',
      'status': 'acknowledged',
      'original_message': 'I am lost',
      'generated_summary': 'User reported being lost.',
      'verified_data_snapshot': <String, dynamic>{
        'last_authorized_location': <String, dynamic>{
          'latitude': 23.8,
          'longitude': 90.4,
        },
        'last_reported_battery': <String, dynamic>{'level': 42},
      },
      'requested_at': '2026-01-01T10:00:00+00:00',
      'acknowledged_at': '2026-01-01T10:05:00+00:00',
    });

    expect(request.isAcknowledged, isTrue);
    expect(request.requestId, 'req_abc');
    expect(request.batteryLevel, 42);
    expect(request.location?['latitude'], 23.8);
    expect(request.requestedAt, isNotNull);
    expect(request.acknowledgedAt, isNotNull);
  });

  test(
    'help request without a snapshot reports no location and no battery',
    () {
      final request = CareSignalHelpRequest.fromJson(<String, dynamic>{
        'request_id': 'req_abc',
        'status': 'sent',
        'original_message': 'I am lost',
        'generated_summary': 'User reported being lost.',
        'verified_data_snapshot': <String, dynamic>{},
      });

      expect(request.isAcknowledged, isFalse);
      expect(request.location, isNull);
      expect(request.batteryLevel, isNull);
      expect(request.requestedAt, isNull);
    },
  );

  test('help request exposes the sender phone and request type', () {
    final request = CareSignalHelpRequest.fromJson(<String, dynamic>{
      'request_id': 'req_abc',
      'status': 'sent',
      'original_message': 'I am lost',
      'generated_summary': 'User reported being lost.',
      'verified_data_snapshot': <String, dynamic>{
        'sender_phone_number': '+8801700000000',
        'sender_display_name': 'Owner',
        'request_type': 'lost',
      },
    });

    expect(request.senderPhoneNumber, '+8801700000000');
    expect(request.senderDisplayName, 'Owner');
    expect(request.requestType, 'lost');
  });

  test('help request without a phone number reports it as missing', () {
    final request = CareSignalHelpRequest.fromJson(<String, dynamic>{
      'request_id': 'req_abc',
      'status': 'sent',
      'verified_data_snapshot': <String, dynamic>{},
    });

    expect(request.senderPhoneNumber, isNull);
    expect(request.senderDisplayName, isNull);
    expect(request.requestType, 'unknown');
  });
}
