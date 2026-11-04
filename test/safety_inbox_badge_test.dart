import 'package:amarguard/data/services/local_prefs.dart';
import 'package:amarguard/features/home/safety_inbox_badge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const receiverUid = 'receiver-1';

  test('badge is absent when there are no unread or actionable requests', () {
    expect(
      hasActionableSafetyInboxItems(
        currentUserUid: receiverUid,
        careRequests: const [],
        familyRequests: const [],
        readCareRequestIds: const {},
      ),
      isFalse,
    );
    expect(
      hasActionableSafetyInboxItems(
        currentUserUid: receiverUid,
        careRequests: const [
          SafetyInboxCareRequestState(
            requestId: 'acknowledged-read',
            recipientUid: receiverUid,
            status: 'acknowledged',
          ),
        ],
        familyRequests: const [],
        readCareRequestIds: const {'acknowledged-read'},
      ),
      isFalse,
    );
  });

  test('badge remains for unread or unacknowledged CareSignal requests', () {
    expect(
      hasActionableSafetyInboxItems(
        currentUserUid: receiverUid,
        careRequests: const [
          SafetyInboxCareRequestState(
            requestId: 'sent-and-read',
            recipientUid: receiverUid,
            status: 'sent',
          ),
        ],
        familyRequests: const [],
        readCareRequestIds: const {'sent-and-read'},
      ),
      isTrue,
    );
    expect(
      hasActionableSafetyInboxItems(
        currentUserUid: receiverUid,
        careRequests: const [
          SafetyInboxCareRequestState(
            requestId: 'acknowledged-unread',
            recipientUid: receiverUid,
            status: 'acknowledged',
          ),
        ],
        familyRequests: const [],
        readCareRequestIds: const {},
      ),
      isTrue,
    );
  });

  test('badge appears only for this receiver and pending family requests', () {
    expect(
      hasActionableSafetyInboxItems(
        currentUserUid: receiverUid,
        careRequests: const [
          SafetyInboxCareRequestState(
            requestId: 'other-user',
            recipientUid: 'someone-else',
            status: 'sent',
          ),
        ],
        familyRequests: const [
          SafetyInboxFamilyRequestState(
            ownerUid: receiverUid,
            status: 'pending',
          ),
        ],
        readCareRequestIds: const {},
      ),
      isTrue,
    );
    expect(
      hasActionableSafetyInboxItems(
        currentUserUid: receiverUid,
        careRequests: const [],
        familyRequests: const [
          SafetyInboxFamilyRequestState(
            ownerUid: receiverUid,
            status: 'approved',
          ),
          SafetyInboxFamilyRequestState(
            ownerUid: 'someone-else',
            status: 'pending',
          ),
        ],
        readCareRequestIds: const {},
      ),
      isFalse,
    );
  });

  test(
    'marking a request read notifies the home badge and persists by user',
    () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await LocalPrefs.create();
      var readStateChanges = 0;
      prefs.careSignalReadChanges.addListener(() => readStateChanges++);

      await prefs.markCareSignalRequestRead(receiverUid, 'request-1');

      expect(
        prefs.readCareSignalRequestIds(receiverUid),
        contains('request-1'),
      );
      expect(readStateChanges, 1);
    },
  );
}
