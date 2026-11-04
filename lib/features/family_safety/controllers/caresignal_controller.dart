import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/caresignal_api.dart';
import '../services/caresignal_recorder.dart';

enum CareSignalStage {
  idle,
  recording,
  transcribing,
  processing,
  awaitingConfirmation,
  sending,
  sent,
  failed,
  cancelled,
}

class CareSignalController extends ChangeNotifier {
  CareSignalController({
    required this.api,
    required this.recorder,
    required this.deviceId,
    required this.languageCode,
    this.available = true,
  });

  factory CareSignalController.unavailable({
    required FirebaseAuth auth,
    required String deviceId,
    required String languageCode,
  }) {
    return CareSignalController(
      api: CareSignalApi(
        config: const CareSignalConfig(baseUrl: 'http://127.0.0.1:1'),
        auth: auth,
      ),
      recorder: CareSignalRecorder(),
      deviceId: deviceId,
      languageCode: languageCode,
      available: false,
    );
  }

  final CareSignalApi api;
  final CareSignalRecorderService recorder;
  final String deviceId;
  String languageCode;
  final bool available;

  CareSignalStage _stage = CareSignalStage.idle;
  String? _errorMessage;
  String? _errorCode;
  String _transcript = '';
  String _originalTranscript = '';
  CareSignalSummary? _summary;
  CareSignalHelpRequest? _sentRequest;
  List<CareSignalHelpRequest> _sentRequests = const <CareSignalHelpRequest>[];
  List<CareSignalHelpRequest> _inboxRequests = const <CareSignalHelpRequest>[];
  String? _inboxRequestsErrorCode;
  final Map<String, String> _idempotencyKeys = <String, String>{};
  String? _sentRequestsError;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  bool _consentGiven = false;
  bool _isDisposed = false;

  CareSignalStage get stage => _stage;
  String? get errorMessage => _errorMessage;
  String? get errorCode => _errorCode;
  String get transcript => _transcript;
  String get originalTranscript => _originalTranscript;
  CareSignalSummary? get summary => _summary;
  CareSignalHelpRequest? get sentRequest => _sentRequest;
  List<CareSignalHelpRequest> get sentRequests => _sentRequests;
  String? get sentRequestsError => _sentRequestsError;
  List<CareSignalHelpRequest> get inboxRequests => _inboxRequests;
  String? get inboxRequestsErrorCode => _inboxRequestsErrorCode;
  Duration get recordingDuration => _recordingDuration;
  bool get consentGiven => _consentGiven;

  void setLanguageCode(String code) {
    if (languageCode == code) return;
    languageCode = code;
    notifyListeners();
  }

  void setTranscript(String value) {
    _transcript = value;
    notifyListeners();
  }

  void giveConsent(bool value) {
    _consentGiven = value;
    notifyListeners();
  }

  void reset() {
    _stage = CareSignalStage.idle;
    _errorMessage = null;
    _errorCode = null;
    _transcript = '';
    _originalTranscript = '';
    _summary = null;
    _sentRequest = null;
    _sentRequests = const <CareSignalHelpRequest>[];
    _idempotencyKeys.clear();
    _recordingDuration = Duration.zero;
    _recordingTimer?.cancel();
    _recordingTimer = null;
    _consentGiven = false;
    notifyListeners();
  }

  void prepareConfirmedHelpMessage(String value) {
    final message = value.trim();
    _transcript = message;
    _originalTranscript = message;
    _summary = null;
    _sentRequest = null;
    _idempotencyKeys.clear();
    _errorCode = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> prepareConsent() async {
    _errorMessage = null;
    _errorCode = null;
    if (!available) {
      throw const CareSignalException(
        'backend_not_configured',
        'The CareSignal AI service is not configured for this build.',
      );
    }
    final granted = await recorder.hasPermission();
    if (!granted) {
      throw const CareSignalException(
        'microphone_permission_denied',
        'Microphone permission was denied.',
      );
    }
    _stage = CareSignalStage.idle;
    notifyListeners();
  }

  Future<bool> startRecording() async {
    _errorMessage = null;
    _errorCode = null;
    try {
      final started = await recorder.start();
      if (!started) return false;
      _recordingDuration = Duration.zero;
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _recordingDuration += const Duration(seconds: 1);
        notifyListeners();
      });
      _stage = CareSignalStage.recording;
      notifyListeners();
      return true;
    } on CareSignalException catch (error) {
      _fail(error.code, error.message);
      return false;
    } catch (_) {
      _fail('microphone_error', 'The microphone could not be started.');
      return false;
    }
  }

  Future<void> cancelRecording() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    await recorder.cancel();
    _stage = CareSignalStage.cancelled;
    notifyListeners();
  }

  Future<bool> stopRecordingAndTranscribe() async {
    _recordingTimer?.cancel();
    _recordingTimer = null;
    if (!_consentGiven) {
      _fail(
        'consent_required',
        'Consent is required before the recording can be processed.',
      );
      return false;
    }
    _stage = CareSignalStage.transcribing;
    notifyListeners();
    File? recordingFile;
    var transcribed = false;
    try {
      final path = await recorder.stop();
      if (path.isEmpty) {
        _fail('empty_recording', 'No audio was captured.');
      } else {
        recordingFile = File(path);
      }
      if (recordingFile != null && await isEmptyRecording(recordingFile)) {
        _fail('empty_recording', 'No audio was captured.');
      } else if (recordingFile != null) {
        final transcript = await api.transcribe(
          audioFile: recordingFile,
          language: languageCode,
          consentToProcess: _consentGiven,
        );
        _originalTranscript = transcript;
        _transcript = transcript;
        _stage = CareSignalStage.awaitingConfirmation;
        notifyListeners();
        transcribed = true;
      }
    } on CareSignalException catch (error) {
      _fail(error.code, error.message);
    } on SocketException {
      _fail(
        'backend_unreachable',
        'The CareSignal backend could not be reached.',
      );
    } on TimeoutException {
      _fail(
        'backend_timeout',
        'The CareSignal backend took too long to respond.',
      );
    } catch (_) {
      _fail('transcription_failed', 'The recording could not be transcribed.');
    }
    if (recordingFile != null) {
      try {
        if (await recordingFile.exists()) await recordingFile.delete();
      } on FileSystemException catch (error) {
        debugPrint(
          'CareSignal recorder stage=cleanup error=${error.runtimeType}',
        );
        _fail(
          'audio_cleanup_failed',
          'Temporary audio could not be removed from this device.',
        );
        transcribed = false;
      }
    }
    return transcribed;
  }

  Future<bool> processTranscript() async {
    if (_transcript.trim().isEmpty) {
      _fail('empty_transcript', 'The transcript is empty.');
      return false;
    }
    _stage = CareSignalStage.processing;
    notifyListeners();
    try {
      final summary = await api.process(
        transcript: _transcript,
        originalTranscript: _originalTranscript.isEmpty
            ? _transcript
            : _originalTranscript,
        language: languageCode,
        deviceId: deviceId,
      );
      _summary = summary;
      _stage = CareSignalStage.awaitingConfirmation;
      notifyListeners();
      return true;
    } on CareSignalException catch (error) {
      _fail(error.code, error.message);
      return false;
    } on SocketException {
      _fail(
        'backend_unreachable',
        'The CareSignal backend could not be reached.',
      );
      return false;
    } on TimeoutException {
      _fail(
        'backend_timeout',
        'The CareSignal backend took too long to respond.',
      );
      return false;
    } catch (_) {
      _fail('processing_failed', 'The AI could not process the request.');
      return false;
    }
  }

  Future<bool> sendHelpRequest({required String recipientUid}) async {
    final summary = _summary;
    if (summary == null) {
      _fail('no_summary', 'Generate the help summary first.');
      return false;
    }
    if (recipientUid.trim().isEmpty) {
      _fail('no_recipient', 'Choose a family member to notify.');
      return false;
    }
    if (!summary.approvedRecipients.any(
      (recipient) => recipient.uid == recipientUid,
    )) {
      _fail('recipient_not_approved', 'Choose an approved family member.');
      return false;
    }
    if (_sentRequest != null) {
      return _sentRequest!.recipientUid == recipientUid;
    }
    _stage = CareSignalStage.sending;
    notifyListeners();
    try {
      final request = await api.sendHelpRequest(
        recipientUid: recipientUid,
        language: languageCode,
        originalMessage: _originalTranscript.isEmpty
            ? _transcript
            : _originalTranscript,
        originalTranscript: _originalTranscript.isEmpty
            ? _transcript
            : _originalTranscript,
        generatedSummary: summary.assistanceSummary,
        verifiedDataSnapshot: _snapshot(summary),
        senderDeviceId: deviceId,
        idempotencyKey: _idempotencyKey(recipientUid),
        requestType: summary.requestType,
        detectedLanguage: summary.detectedLanguage,
        suggestedSafeActions: summary.suggestedSafeActions,
      );
      _sentRequest = request;
      _sentRequests = _mergeRequest(_sentRequests, request);
      _stage = CareSignalStage.sent;
      debugPrint(
        'CareSignal request API status=saved requestId=${request.requestId} '
        'notification=${request.notificationStatus}',
      );
      notifyListeners();
      return true;
    } on CareSignalException catch (error) {
      _fail(error.code, error.message);
      return false;
    } on SocketException {
      _fail(
        'backend_unreachable',
        'The CareSignal backend could not be reached.',
      );
      return false;
    } on TimeoutException {
      _fail(
        'backend_timeout',
        'The CareSignal backend took too long to respond.',
      );
      return false;
    } catch (_) {
      _fail('send_failed', 'The help request could not be sent.');
      return false;
    }
  }

  Map<String, dynamic> _snapshot(CareSignalSummary summary) {
    return <String, dynamic>{
      'last_authorized_location': summary.lastAuthorizedLocation,
      'location_accuracy': summary.locationAccuracy,
      'location_timestamp': summary.locationTimestamp,
      'location_freshness_status': summary.locationFreshnessStatus,
      'last_reported_battery': summary.lastReportedBattery,
      'request_type': summary.requestType,
      'detected_language': summary.detectedLanguage,
      'suggested_safe_actions': summary.suggestedSafeActions,
    };
  }

  List<CareSignalHelpRequest> _mergeRequest(
    List<CareSignalHelpRequest> current,
    CareSignalHelpRequest request,
  ) {
    final merged = <CareSignalHelpRequest>[
      request,
      ...current.where((item) => item.requestId != request.requestId),
    ];
    merged.sort((left, right) {
      final leftTime =
          left.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightTime =
          right.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return rightTime.compareTo(leftTime);
    });
    return merged;
  }

  String _idempotencyKey(String recipientUid) {
    return _idempotencyKeys.putIfAbsent(recipientUid, () {
      final random = Random.secure();
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final salt = random.nextInt(1 << 32).toRadixString(16);
      return 'cs-$stamp-$salt';
    });
  }

  Future<List<CareSignalHelpRequest>> loadInbox() async {
    try {
      final items = await api.inbox();
      if (_isDisposed) return items;
      _inboxRequests = items;
      _inboxRequestsErrorCode = null;
      debugPrint('CareSignal inbox outcome=loaded count=${items.length}');
      notifyListeners();
      return items;
    } on CareSignalException catch (error) {
      if (_isDisposed) return const <CareSignalHelpRequest>[];
      debugPrint('CareSignal inbox category=${error.code}');
      _errorCode = error.code;
      _errorMessage = error.message;
      _inboxRequestsErrorCode = error.code;
      notifyListeners();
      return const <CareSignalHelpRequest>[];
    } on SocketException {
      if (_isDisposed) return const <CareSignalHelpRequest>[];
      debugPrint('CareSignal inbox category=backend_unreachable');
      _errorCode = 'backend_unreachable';
      _errorMessage = 'The CareSignal backend could not be reached.';
      _inboxRequestsErrorCode = _errorCode;
      notifyListeners();
      return const <CareSignalHelpRequest>[];
    } on TimeoutException {
      if (_isDisposed) return const <CareSignalHelpRequest>[];
      debugPrint('CareSignal inbox category=backend_timeout');
      _errorCode = 'backend_timeout';
      _errorMessage = 'The CareSignal backend took too long to respond.';
      _inboxRequestsErrorCode = _errorCode;
      notifyListeners();
      return const <CareSignalHelpRequest>[];
    } catch (error) {
      if (_isDisposed) return const <CareSignalHelpRequest>[];
      debugPrint(
        'CareSignal inbox category=unexpected_error '
        'type=${error.runtimeType}',
      );
      _errorCode = 'backend_unreachable';
      _errorMessage = 'The CareSignal backend could not be reached.';
      _inboxRequestsErrorCode = _errorCode;
      notifyListeners();
      return const <CareSignalHelpRequest>[];
    }
  }

  Future<CareSignalHelpRequest?> loadRequest(String requestId) async {
    try {
      return await api.getRequest(requestId);
    } on CareSignalException catch (error) {
      if (_isDisposed) return null;
      _errorCode = error.code;
      _errorMessage = error.message;
      notifyListeners();
      return null;
    } on SocketException {
      if (_isDisposed) return null;
      _errorCode = 'backend_unreachable';
      _errorMessage = 'The CareSignal backend could not be reached.';
      notifyListeners();
      return null;
    } on TimeoutException {
      if (_isDisposed) return null;
      _errorCode = 'backend_timeout';
      _errorMessage = 'The CareSignal backend took too long to respond.';
      notifyListeners();
      return null;
    }
  }

  Future<List<CareSignalHelpRequest>> loadSent() async {
    try {
      final items = await api.sent();
      if (_isDisposed) return items;
      _sentRequests = items;
      _sentRequestsError = null;
      notifyListeners();
      return items;
    } on CareSignalException catch (error) {
      if (_isDisposed) return const <CareSignalHelpRequest>[];
      debugPrint(
        'CareSignal sent history status=${error.statusCode ?? 'unknown'} '
        'category=${error.code}',
      );
      _errorCode = error.code;
      _errorMessage = error.message;
      _sentRequestsError = error.message;
      notifyListeners();
      return const <CareSignalHelpRequest>[];
    } catch (_) {
      if (_isDisposed) return const <CareSignalHelpRequest>[];
      debugPrint(
        'CareSignal sent history status=unknown category=unexpected_error',
      );
      _errorCode = 'backend_unreachable';
      _errorMessage = 'The CareSignal backend could not be reached.';
      _sentRequestsError = _errorMessage;
      notifyListeners();
      return const <CareSignalHelpRequest>[];
    }
  }

  Future<bool> acknowledge(String requestId) async {
    try {
      final updated = await api.acknowledge(requestId);
      if (_isDisposed) return false;
      _sentRequest = updated;
      _inboxRequests = _mergeRequest(_inboxRequests, updated);
      notifyListeners();
      return true;
    } on CareSignalException catch (error) {
      if (_isDisposed) return false;
      _errorCode = error.code;
      _errorMessage = error.message;
      notifyListeners();
      return false;
    }
  }

  void _fail(String code, String message) {
    _errorCode = code;
    _errorMessage = message;
    _stage = CareSignalStage.failed;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _recordingTimer?.cancel();
    api.dispose();
    recorder.dispose();
    super.dispose();
  }
}
