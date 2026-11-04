import '../../../l10n/generated/app_localizations.dart';
import 'family_exceptions.dart';

String familySafetyErrorMessage(AppLocalizations l10n, Object error) {
  if (error is FamilySafetyException) {
    switch (error.code) {
      case FamilySafetyErrorCode.unauthenticated:
        return l10n.careGuestBlockedBody;
      case FamilySafetyErrorCode.selfInvitation:
        return l10n.careSelfInvitation;
      case FamilySafetyErrorCode.invitationNotFound:
        return l10n.careInvitationNotFound;
      case FamilySafetyErrorCode.invitationExpired:
        return l10n.careInvitationExpired;
      case FamilySafetyErrorCode.invitationClosed:
        return l10n.careInvitationClosed;
      case FamilySafetyErrorCode.invitationMalformed:
        return l10n.careInvitationMalformed;
      case FamilySafetyErrorCode.invalidInvitation:
        return l10n.careInvitationInvalid;
      case FamilySafetyErrorCode.duplicateRequest:
        return l10n.careRequestAlreadyPending;
      case FamilySafetyErrorCode.alreadyProcessed:
        return l10n.careRequestAlreadyProcessed;
      case FamilySafetyErrorCode.permissionDenied:
        return l10n.careInvitationPermissionDenied;
      case FamilySafetyErrorCode.approvalPermissionDenied:
        return l10n.careApprovalPermissionDenied;
      case FamilySafetyErrorCode.network:
        return l10n.errorNoInternet;
      case FamilySafetyErrorCode.unknown:
        return l10n.errorGeneric;
    }
  }
  return l10n.errorGeneric;
}
