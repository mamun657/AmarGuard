class SafetyInboxCareRequestState {
  const SafetyInboxCareRequestState({
    required this.requestId,
    required this.recipientUid,
    required this.status,
  });

  final String requestId;
  final String recipientUid;
  final String status;
}

class SafetyInboxFamilyRequestState {
  const SafetyInboxFamilyRequestState({
    required this.ownerUid,
    required this.status,
  });

  final String ownerUid;
  final String status;
}

bool hasActionableSafetyInboxItems({
  required String currentUserUid,
  required Iterable<SafetyInboxCareRequestState> careRequests,
  required Iterable<SafetyInboxFamilyRequestState> familyRequests,
  required Set<String> readCareRequestIds,
}) {
  return careRequests.any(
        (request) =>
            request.recipientUid == currentUserUid &&
            (request.status == 'sent' ||
                (request.status == 'acknowledged' &&
                    !readCareRequestIds.contains(request.requestId))),
      ) ||
      familyRequests.any(
        (request) =>
            request.ownerUid == currentUserUid && request.status == 'pending',
      );
}
