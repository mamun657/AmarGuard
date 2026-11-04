import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../models/family_models.dart';

String relationshipLabel(BuildContext context, RelationshipType type) {
  final l10n = AppLocalizations.of(context)!;
  switch (type) {
    case RelationshipType.parent:
      return l10n.careRelationshipParent;
    case RelationshipType.child:
      return l10n.careRelationshipChild;
    case RelationshipType.spouse:
      return l10n.careRelationshipSpouse;
    case RelationshipType.sibling:
      return l10n.careRelationshipSibling;
    case RelationshipType.guardian:
      return l10n.careRelationshipGuardian;
    case RelationshipType.caregiver:
      return l10n.careRelationshipCaregiver;
    case RelationshipType.friend:
      return l10n.careRelationshipFriend;
    case RelationshipType.other:
      return l10n.careRelationshipOther;
  }
}

String careSignalRelationshipLabel(BuildContext context, String raw) {
  final l10n = AppLocalizations.of(context)!;
  switch (raw) {
    case 'parent':
      return l10n.careRelationshipParent;
    case 'child':
      return l10n.careRelationshipChild;
    case 'spouse':
      return l10n.careRelationshipSpouse;
    case 'sibling':
      return l10n.careRelationshipSibling;
    case 'guardian':
      return l10n.careRelationshipGuardian;
    case 'caregiver':
      return l10n.careRelationshipCaregiver;
    case 'friend':
      return l10n.careRelationshipFriend;
    default:
      return l10n.careRelationshipOther;
  }
}

String requestTypeLabel(BuildContext context, String raw) {
  final l10n = AppLocalizations.of(context)!;
  switch (raw) {
    case 'lost':
      return l10n.careSignalRequestTypeLost;
    case 'emergency':
      return l10n.careSignalRequestTypeEmergency;
    case 'check_in':
      return l10n.careSignalRequestTypeCheckIn;
    case 'general':
      return l10n.careSignalRequestTypeGeneral;
    default:
      return l10n.careSignalRequestTypeUnknown;
  }
}

String relativeTimeLabel(BuildContext context, DateTime timestamp) {
  final l10n = AppLocalizations.of(context)!;
  final now = DateTime.now().toUtc();
  final moment = timestamp.toUtc();
  final difference = now.difference(moment);
  if (difference.isNegative || difference.inSeconds < 60) {
    return l10n.careJustNow;
  }
  if (difference.inMinutes < 60) {
    return l10n.careMinutesAgo(difference.inMinutes);
  }
  if (difference.inHours < 24) {
    return l10n.careHoursAgo(difference.inHours);
  }
  return l10n.careDaysAgo(difference.inDays);
}

String formatCoordinates(double latitude, double longitude) {
  final lat = latitude.toStringAsFixed(5);
  final lng = longitude.toStringAsFixed(5);
  return '$lat, $lng';
}

String formatAccuracy(double accuracy) {
  if (accuracy <= 0) return '--';
  if (accuracy < 1000) return '${accuracy.toStringAsFixed(0)} m';
  return '${(accuracy / 1000).toStringAsFixed(1)} km';
}

String formatDateTime(BuildContext context, DateTime timestamp) {
  final local = timestamp.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year;
  return '$day/$month/$year $hour:$minute';
}
