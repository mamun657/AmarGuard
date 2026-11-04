import 'package:amarguard/features/family_safety/models/family_models.dart';
import 'package:amarguard/features/family_safety/screens/safety_inbox_screen.dart';
import 'package:amarguard/features/family_safety/services/caresignal_api.dart';
import 'package:amarguard/features/family_safety/theme/care_colors.dart';
import 'package:amarguard/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const receiverUid = 'receiver-1';

void main() {
  testWidgets('empty inbox displays a calm empty state', (tester) async {
    await tester.pumpWidget(_inboxApp());
    await tester.pumpAndSettle();

    expect(find.text('Safety Inbox'), findsOneWidget);
    expect(find.text("You're all caught up"), findsOneWidget);
    expect(
      find.text(
        'New help requests and family access approvals will appear here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('does not render records belonging to another user', (
    tester,
  ) async {
    await tester.pumpWidget(
      _inboxApp(
        careRequests: [_careRequest(recipientUid: 'someone-else')],
        familyRequests: [_familyRequest(ownerUid: 'someone-else')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text("You're all caught up"), findsOneWidget);
    expect(find.text('CareSignal Help Request'), findsNothing);
    expect(find.text('Family Access Request'), findsNothing);
  });

  testWidgets('opening a request marks it read and opens existing details', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    var markedRead = false;
    await tester.pumpWidget(
      _inboxApp(
        navigatorKey: navigatorKey,
        careRequests: [_careRequest()],
        markCareRequestRead: (_) async {
          markedRead = true;
        },
        openCareRequest: (request) async {
          await navigatorKey.currentState!.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const Scaffold(
                body: Center(child: Text('Help request details')),
              ),
            ),
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Unread'), findsOneWidget);
    expect(find.textContaining('Awaiting response'), findsOneWidget);
    await tester.tap(find.text('CareSignal Help Request'));
    await tester.pumpAndSettle();

    expect(markedRead, isTrue);
    expect(find.text('Help request details'), findsOneWidget);
    navigatorKey.currentState!.pop();
    await tester.pumpAndSettle();

    expect(find.text('Read'), findsOneWidget);
    expect(find.textContaining('Awaiting response'), findsOneWidget);
    expect(find.text('Acknowledged'), findsNothing);
  });

  testWidgets('shows only pending family access requests', (tester) async {
    await tester.pumpWidget(
      _inboxApp(
        familyRequests: [
          _familyRequest(),
          _familyRequest(
            viewerUid: 'approved-viewer',
            viewerName: 'Already approved',
            status: 'approved',
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Family Access Request'), findsOneWidget);
    expect(find.text('Family member'), findsOneWidget);
    expect(find.text('Already approved'), findsNothing);
    expect(find.text('Pending approval'), findsOneWidget);
  });

  testWidgets('does not invent a timestamp for a family access request', (
    tester,
  ) async {
    await tester.pumpWidget(
      _inboxApp(familyRequests: [_familyRequest(requestedAt: null)]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Not available'), findsOneWidget);
    expect(find.text('Just now'), findsNothing);
  });
}

Widget _inboxApp({
  GlobalKey<NavigatorState>? navigatorKey,
  List<CareSignalHelpRequest> careRequests = const [],
  List<ConnectionRequest> familyRequests = const [],
  Future<void> Function(String requestId)? markCareRequestRead,
  Future<void> Function(CareSignalHelpRequest request)? openCareRequest,
}) {
  return MaterialApp(
    navigatorKey: navigatorKey,
    theme: ThemeData(
      scaffoldBackgroundColor: CareColors.ivory,
      colorScheme: ColorScheme.fromSeed(seedColor: CareColors.teal),
    ),
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('bn')],
    home: SafetyInboxScreen(
      currentUserUid: receiverUid,
      readCareRequestIds: const <String>{},
      loadCareRequests: () async => careRequests,
      loadFamilyRequests: () async => familyRequests,
      markCareRequestRead: markCareRequestRead ?? (_) async {},
      openCareRequest: openCareRequest ?? (_) async {},
      openFamilyRequest: (_) async {},
    ),
  );
}

CareSignalHelpRequest _careRequest({String recipientUid = receiverUid}) {
  return CareSignalHelpRequest(
    requestId: 'help-1',
    senderUid: 'sender-1',
    recipientUid: recipientUid,
    status: 'sent',
    notificationStatus: 'submitted',
    originalMessage: 'Please help.',
    generatedSummary: 'A family member needs help.',
    verifiedDataSnapshot: const <String, dynamic>{},
    requestedAt: DateTime.utc(2026, 11, 4, 12),
  );
}

ConnectionRequest _familyRequest({
  String ownerUid = receiverUid,
  String viewerUid = 'viewer-1',
  String viewerName = 'Family member',
  String status = 'pending',
  DateTime? requestedAt,
}) {
  return ConnectionRequest(
    viewerUid: viewerUid,
    invitationId: 'invite-1',
    ownerUid: ownerUid,
    viewerDisplayName: viewerName,
    viewerEmail: 'family@example.test',
    requestedAt: requestedAt,
    status: status,
  );
}
