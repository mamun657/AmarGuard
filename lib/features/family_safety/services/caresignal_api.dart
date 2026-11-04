import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class CareSignalException implements Exception {
  const CareSignalException(this.code, this.message, {this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'CareSignalException($code)';
}

class CareSignalConfig {
  const CareSignalConfig({required this.baseUrl});

  final String baseUrl;

  static String _defaultBaseUrl() {
    if (kIsWeb) {
      return 'http://localhost:8001';
    }
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8001';
    }
    return 'http://127.0.0.1:8001';
  }

  static const String fromEnvironment = String.fromEnvironment(
    'CARESIGNAL_API_BASE_URL',
    defaultValue: '',
  );

  static CareSignalConfig resolve() {
    final raw = fromEnvironment.trim();
    final value = raw.isNotEmpty ? raw : _defaultBaseUrl();
    if (Uri.tryParse(value)?.host.isEmpty != false) {
      throw const CareSignalException(
        'missing_base_url',
        'CARESIGNAL_API_BASE_URL is not a valid backend URL. Set it to your running FastAPI host, for example http://10.0.2.2:8001 on Android emulators or http://<PC-LAN-IP>:8001 on a physical device.',
      );
    }
    return CareSignalConfig(baseUrl: value);
  }
}

typedef CareSignalTokenProvider = Future<String?> Function();

class CareSignalApi {
  CareSignalApi({
    required this.config,
    this.auth,
    http.Client? client,
    this._tokenProvider,
  }) : _client = client ?? http.Client();

  final CareSignalConfig config;
  final FirebaseAuth? auth;
  final http.Client _client;
  final CareSignalTokenProvider? _tokenProvider;

  void dispose() {
    _client.close();
  }

  Uri _uri(String path) {
    final base = config.baseUrl.endsWith('/')
        ? config.baseUrl.substring(0, config.baseUrl.length - 1)
        : config.baseUrl;
    return Uri.parse('$base$path');
  }

  Future<String> _token({bool forceRefresh = false}) async {
    final String? token;
    if (_tokenProvider != null) {
      token = await _tokenProvider();
    } else {
      final user = auth?.currentUser;
      token = await user?.getIdToken(forceRefresh);
    }
    if (token == null || token.isEmpty) {
      throw const CareSignalException(
        'unauthenticated',
        'Sign in before using CareSignal AI.',
      );
    }
    return token;
  }

  Future<Map<String, dynamic>> _postMultipart(
    String path, {
    required Map<String, String> fields,
    Map<String, String>? files,
  }) async {
    final response = await _sendAuthenticated(path, (token) async {
      final request = http.MultipartRequest('POST', _uri(path))
        ..headers['Authorization'] = 'Bearer $token'
        ..fields.addAll(fields);
      for (final entry in (files ?? const <String, String>{}).entries) {
        request.files.add(
          await http.MultipartFile.fromPath(
            entry.key,
            entry.value,
            filename: 'recording.wav',
          ),
        );
      }
      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 60));
      return http.Response.fromStream(streamed);
    });
    return _decode(response);
  }

  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, dynamic> payload, {
    Map<String, String>? query,
  }) async {
    final uri = _uri(path).replace(queryParameters: query);
    final response = await _sendAuthenticated(path, (token) {
      return _client
          .post(
            uri,
            headers: <String, String>{
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 45));
    });
    return _decode(response);
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final response = await _sendAuthenticated(path, (token) {
      return _client
          .get(
            _uri(path),
            headers: <String, String>{'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 30));
    });
    return _decode(response);
  }

  Future<http.Response> _sendAuthenticated(
    String path,
    Future<http.Response> Function(String token) send,
  ) async {
    final uid = auth?.currentUser?.uid;
    late String token;
    try {
      token = await _token();
    } on FirebaseAuthException catch (error) {
      debugPrint(
        'CareSignal API endpoint=$path status=none category=${error.code} '
        'authorization_present=false',
      );
      rethrow;
    } on CareSignalException catch (error) {
      debugPrint(
        'CareSignal API endpoint=$path status=none category=${error.code} '
        'authorization_present=false',
      );
      rethrow;
    }
    if (uid != null && auth?.currentUser?.uid != uid) {
      throw const CareSignalException(
        'unauthenticated',
        'The signed-in account changed during the request.',
      );
    }
    var response = await send(token);
    _logResponse(path, response);
    if (response.statusCode != 401 || auth == null || uid == null) {
      return response;
    }

    if (auth!.currentUser?.uid != uid) {
      throw const CareSignalException(
        'unauthenticated',
        'The signed-in account changed during the request.',
        statusCode: 401,
      );
    }
    try {
      token = await _token(forceRefresh: true);
    } on FirebaseAuthException catch (error) {
      debugPrint(
        'CareSignal API endpoint=$path status=401 category=${error.code} '
        'authorization_present=false attempt=refresh',
      );
      rethrow;
    } on CareSignalException catch (error) {
      debugPrint(
        'CareSignal API endpoint=$path status=401 category=${error.code} '
        'authorization_present=false attempt=refresh',
      );
      rethrow;
    }
    response = await send(token);
    _logResponse(path, response, attempt: 'refresh');
    return response;
  }

  void _logResponse(
    String path,
    http.Response response, {
    String attempt = 'initial',
  }) {
    debugPrint(
      'CareSignal API endpoint=$path status=${response.statusCode} '
      'category=${_errorCategory(response)} authorization_present=true '
      'attempt=$attempt',
    );
  }

  String _errorCategory(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return 'success';
    }
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map && error['code'] is String) {
          return error['code'] as String;
        }
      }
    } on FormatException {
      return 'invalid_error_response';
    }
    return 'http_error';
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body = <String, dynamic>{};
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } catch (_) {
        body = <String, dynamic>{};
      }
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body;
    }
    final error = body['error'];
    final code = error is Map && error['code'] is String
        ? error['code'] as String
        : 'request_failed';
    final message = error is Map && error['message'] is String
        ? error['message'] as String
        : 'The CareSignal AI service is unavailable right now.';
    throw CareSignalException(code, message, statusCode: response.statusCode);
  }

  Future<String> transcribe({
    required File audioFile,
    required String language,
    required bool consentToProcess,
  }) async {
    final body = await _postMultipart(
      '/voice/transcribe',
      fields: <String, String>{
        'consent_to_process': consentToProcess ? 'true' : 'false',
        'language': language,
      },
      files: <String, String>{'audio': audioFile.path},
    );
    final transcript = body['transcript'];
    if (transcript is! String || transcript.trim().isEmpty) {
      throw const CareSignalException(
        'empty_transcript',
        'No speech was detected in the recording.',
      );
    }
    return transcript.trim();
  }

  Future<CareSignalSummary> process({
    required String transcript,
    required String originalTranscript,
    required String language,
    required String deviceId,
  }) async {
    final body = await _postJson('/agent/process', <String, dynamic>{
      'transcript': transcript,
      'original_transcript': originalTranscript,
      'language': language,
      'device_id': deviceId,
    });
    return CareSignalSummary.fromJson(
      (body['summary'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  Future<CareSignalHelpRequest> sendHelpRequest({
    required String recipientUid,
    required String language,
    required String originalMessage,
    required String originalTranscript,
    required String generatedSummary,
    required Map<String, dynamic> verifiedDataSnapshot,
    required String senderDeviceId,
    required String idempotencyKey,
    required String requestType,
    required String detectedLanguage,
    required List<String> suggestedSafeActions,
    bool includeLocation = true,
  }) async {
    final body = await _postJson('/help-request', <String, dynamic>{
      'recipient_uid': recipientUid,
      'language': language,
      'original_message': originalMessage,
      'original_transcript': originalTranscript,
      'generated_summary': generatedSummary,
      'verified_data_snapshot': verifiedDataSnapshot,
      'sender_device_id': senderDeviceId,
      'idempotency_key': idempotencyKey,
      'request_type': requestType,
      'detected_language': detectedLanguage,
      'suggested_safe_actions': suggestedSafeActions,
      'include_location': includeLocation,
    });
    return CareSignalHelpRequest.fromJson(
      (body['request'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  Future<List<CareSignalRecipient>> familyContacts({
    required String deviceId,
  }) async {
    final body = await _postJson(
      '/family/contacts',
      const <String, dynamic>{},
      query: <String, String>{'device_id': deviceId},
    );
    final contacts = body['approved_contacts'];
    if (contacts is! List) return const <CareSignalRecipient>[];
    return contacts
        .whereType<Map<String, dynamic>>()
        .map(CareSignalRecipient.fromJson)
        .toList();
  }

  Future<List<CareSignalHelpRequest>> inbox() async {
    final body = await _get('/help-request/inbox');
    final items = body['requests'];
    if (items is! List) return const <CareSignalHelpRequest>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(CareSignalHelpRequest.fromJson)
        .toList();
  }

  Future<List<CareSignalHelpRequest>> sent() async {
    final body = await _get('/help-request/sent');
    final items = body['requests'];
    if (items is! List) return const <CareSignalHelpRequest>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(CareSignalHelpRequest.fromJson)
        .toList();
  }

  Future<CareSignalHelpRequest> acknowledge(String requestId) async {
    final body = await _postJson(
      '/help-request/acknowledge',
      <String, dynamic>{},
      query: <String, String>{'request_id': requestId},
    );
    return CareSignalHelpRequest.fromJson(
      (body['request'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  Future<CareSignalHelpRequest> getRequest(String requestId) async {
    final body = await _get('/help-request/${Uri.encodeComponent(requestId)}');
    return CareSignalHelpRequest.fromJson(
      (body['request'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  Future<void> registerFcmToken(String token) async {
    await _postJson('/fcm/register', <String, dynamic>{
      'token': token,
      'platform': 'android',
    });
  }

  Future<void> unregisterFcmToken(String token) async {
    await _postJson('/fcm/unregister', <String, dynamic>{
      'token': token,
      'platform': 'android',
    });
  }
}

class CareSignalRecipient {
  const CareSignalRecipient({
    required this.uid,
    required this.displayName,
    required this.alias,
    required this.relationship,
  });

  final String uid;
  final String displayName;
  final String alias;
  final String relationship;

  static CareSignalRecipient fromJson(Map<String, dynamic> json) {
    return CareSignalRecipient(
      uid: (json['recipient_uid'] ?? '').toString(),
      displayName: (json['display_name'] ?? '').toString(),
      alias: (json['alias'] ?? '').toString(),
      relationship: (json['relationship'] ?? 'other').toString(),
    );
  }
}

class CareSignalSummary {
  const CareSignalSummary({
    required this.requestType,
    required this.detectedLanguage,
    required this.originalTranscript,
    required this.userConfirmedTranscript,
    required this.assistanceSummary,
    required this.locationFreshnessStatus,
    required this.suggestedSafeActions,
    required this.approvedRecipients,
    required this.recipientMatchStatus,
    this.suggestedRecipientUid,
    this.lastAuthorizedLocation,
    this.locationAccuracy,
    this.locationTimestamp,
    this.lastReportedBattery,
  });

  final String requestType;
  final String detectedLanguage;
  final String originalTranscript;
  final String userConfirmedTranscript;
  final String assistanceSummary;
  final String locationFreshnessStatus;
  final List<String> suggestedSafeActions;
  final List<CareSignalRecipient> approvedRecipients;
  final String? suggestedRecipientUid;
  final String recipientMatchStatus;
  final Map<String, dynamic>? lastAuthorizedLocation;
  final double? locationAccuracy;
  final String? locationTimestamp;
  final Map<String, dynamic>? lastReportedBattery;

  bool get hasLocation => lastAuthorizedLocation != null;

  int? get batteryLevel {
    final value = lastReportedBattery?['level'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }

  static CareSignalSummary fromJson(Map<String, dynamic> json) {
    final location = json['last_authorized_location'];
    final battery = json['last_reported_battery'];
    final actions = json['suggested_safe_actions'];
    final recipients = json['approved_recipient_options'];
    final accuracy = json['location_accuracy'];
    return CareSignalSummary(
      requestType: (json['request_type'] ?? 'unknown').toString(),
      detectedLanguage: (json['detected_language'] ?? 'en').toString(),
      originalTranscript: (json['original_transcript'] ?? '').toString(),
      userConfirmedTranscript: (json['user_confirmed_transcript'] ?? '')
          .toString(),
      assistanceSummary: (json['assistance_summary'] ?? '').toString(),
      locationFreshnessStatus:
          (json['location_freshness_status'] ?? 'unavailable').toString(),
      suggestedSafeActions: actions is List
          ? actions.map((item) => item.toString()).toList()
          : const <String>[],
      approvedRecipients: recipients is List
          ? recipients
                .whereType<Map<String, dynamic>>()
                .map(CareSignalRecipient.fromJson)
                .toList()
          : const <CareSignalRecipient>[],
      suggestedRecipientUid: json['suggested_recipient_uid']?.toString(),
      recipientMatchStatus:
          (json['recipient_match_status'] ?? 'manual_selection').toString(),
      lastAuthorizedLocation: location is Map<String, dynamic>
          ? location
          : null,
      locationAccuracy: accuracy is num ? accuracy.toDouble() : null,
      locationTimestamp: json['location_timestamp']?.toString(),
      lastReportedBattery: battery is Map<String, dynamic> ? battery : null,
    );
  }
}

class CareSignalHelpRequest {
  const CareSignalHelpRequest({
    required this.requestId,
    required this.senderUid,
    required this.recipientUid,
    required this.status,
    required this.notificationStatus,
    required this.originalMessage,
    required this.generatedSummary,
    required this.verifiedDataSnapshot,
    this.requestedAt,
    this.acknowledgedAt,
  });

  final String requestId;
  final String senderUid;
  final String recipientUid;
  final String status;
  final String notificationStatus;
  final String originalMessage;
  final String generatedSummary;
  final Map<String, dynamic> verifiedDataSnapshot;
  final DateTime? requestedAt;
  final DateTime? acknowledgedAt;

  bool get isAcknowledged => status == 'acknowledged';

  Map<String, dynamic>? get location {
    final value = verifiedDataSnapshot['last_authorized_location'];
    return value is Map<String, dynamic> ? value : null;
  }

  int? get batteryLevel {
    final value = verifiedDataSnapshot['last_reported_battery'];
    if (value is! Map<String, dynamic>) return null;
    final level = value['level'];
    if (level is int) return level;
    if (level is num) return level.toInt();
    return null;
  }

  String? get senderPhoneNumber {
    final value = verifiedDataSnapshot['sender_phone_number'];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  String? get senderDisplayName {
    final value = verifiedDataSnapshot['sender_display_name'];
    if (value is String && value.trim().isNotEmpty) return value.trim();
    return null;
  }

  String get requestType =>
      (verifiedDataSnapshot['request_type'] ?? 'unknown').toString();

  static CareSignalHelpRequest fromJson(Map<String, dynamic> json) {
    final snapshot = json['verified_data_snapshot'];
    return CareSignalHelpRequest(
      requestId: (json['request_id'] ?? '').toString(),
      senderUid: (json['sender_uid'] ?? '').toString(),
      recipientUid: (json['recipient_uid'] ?? '').toString(),
      status: (json['status'] ?? 'sent').toString(),
      notificationStatus: (json['notification_status'] ?? 'pending').toString(),
      originalMessage: (json['original_message'] ?? '').toString(),
      generatedSummary: (json['generated_summary'] ?? '').toString(),
      verifiedDataSnapshot: snapshot is Map<String, dynamic>
          ? snapshot
          : const <String, dynamic>{},
      requestedAt: _parseDate(json['requested_at']),
      acknowledgedAt: _parseDate(json['acknowledged_at']),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }
}
