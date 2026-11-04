const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const {
  doc,
  getDoc,
  setDoc,
  updateDoc,
  deleteDoc,
  runTransaction,
  writeBatch,
  Timestamp,
} = require('firebase/firestore');
const fs = require('fs');

const projectId = 'guard-ab0d3';
const owner = { uid: 'owner-1' };
const viewer = { uid: 'viewer-1' };
const stranger = { uid: 'stranger-1' };
const invitationId = 'INVITE1';
const devicePath = 'users/owner-1/devices/device-1';
const locationPath = `${devicePath}/location/current`;
const statusPath = `${devicePath}/status/current`;
const grantPath = `${devicePath}/approvedViewers/viewer-1`;
const requestPath = `familyInvitations/${invitationId}/requests/viewer-1`;
const incomingPath = `${devicePath}/incomingRequests/viewer-1`;
const indexPath = 'familyViewerAccess/viewer-1/grants/owner-1__device-1';

function location(capturedAt = Timestamp.fromMillis(1700000000000)) {
  return {
    ownerUid: 'owner-1',
    deviceId: 'device-1',
    latitude: 23.8,
    longitude: 90.4,
    accuracy: 10,
    capturedAt,
    syncedAt: Timestamp.now(),
    batteryLevel: 80,
    isCharging: false,
    sharingSessionId: 'session-1',
  };
}

async function seed(env) {
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, devicePath), {
      ownerUid: 'owner-1',
      deviceId: 'device-1',
      nickname: 'My Device',
      sharingState: 'stopped',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    });
    await setDoc(doc(db, statusPath), {
      sharingState: 'stopped',
      permissionState: 'granted',
    });
    await setDoc(doc(db, `familyInvitations/${invitationId}`), {
      ownerUid: 'owner-1',
      ownerDisplayName: 'Owner',
      deviceId: 'device-1',
      deviceNickname: 'My Device',
      status: 'open',
      requestedCapabilities: ['viewLocation', 'viewBattery'],
      createdAt: Timestamp.now(),
      expiresAt: Timestamp.fromMillis(Date.now() + 3600000),
    });
  });
}

async function run() {
  const env = await initializeTestEnvironment({
    projectId,
    firestore: { rules: fs.readFileSync('firestore.rules', 'utf8') },
  });
  try {
    await env.clearFirestore();
    await seed(env);
    const ownerDb = env.authenticatedContext(owner.uid).firestore();
    const viewerDb = env.authenticatedContext(viewer.uid).firestore();
    const strangerDb = env.authenticatedContext(stranger.uid).firestore();

    await assertSucceeds(setDoc(doc(ownerDb, 'users/owner-1'), {
      displayName: 'Owner',
      email: 'owner@example.com',
      phoneNumber: '',
      authProvider: 'email',
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    }));
    await assertSucceeds(updateDoc(doc(ownerDb, 'users/owner-1'), {
      displayName: 'Updated Owner',
      updatedAt: Timestamp.now(),
    }));
    await assertFails(updateDoc(doc(viewerDb, 'users/owner-1'), {
      authProvider: 'admin',
    }));
    await assertFails(updateDoc(doc(ownerDb, 'users/owner-1'), {
      authProvider: 'admin',
    }));

    await assertFails(getDoc(doc(viewerDb, locationPath)));
    await assertSucceeds(getDoc(doc(ownerDb, devicePath)));
    await assertSucceeds(getDoc(doc(ownerDb, statusPath)));
    await assertFails(getDoc(doc(viewerDb, devicePath)));
    await assertFails(getDoc(doc(viewerDb, statusPath)));
    await assertSucceeds(updateDoc(doc(ownerDb, devicePath), {
      sharingState: 'active',
      updatedAt: Timestamp.now(),
    }));
    await assertSucceeds(updateDoc(doc(ownerDb, statusPath), {
      sharingState: 'active',
    }));
    await assertSucceeds(setDoc(doc(ownerDb, locationPath), location()));
    await assertFails(setDoc(doc(ownerDb, locationPath), {
      ...location(),
      latitude: 200,
    }));
    await assertFails(setDoc(doc(ownerDb, locationPath), {
      ...location(),
      capturedAt: '2024-01-01T00:00:00.000Z',
    }));
    await assertFails(updateDoc(doc(ownerDb, locationPath), {
      latitude: 23.81,
      capturedAt: Timestamp.fromMillis(1600000000000),
    }));

    const requestPayload = {
      viewerUid: 'viewer-1',
      ownerUid: 'owner-1',
      invitationId,
      viewerDisplayName: 'Viewer',
      viewerEmail: 'viewer@example.com',
      relationship: 'friend',
      requestedCapabilities: ['viewLocation', 'viewBattery'],
      status: 'pending',
      requestedAt: Timestamp.now(),
    };
    const incomingPayload = {
      ...requestPayload,
      deviceId: 'device-1',
    };
    await assertFails(setDoc(doc(viewerDb, incomingPath), requestPayload));
    await assertFails(setDoc(doc(ownerDb, `familyInvitations/${invitationId}/requests/owner-1`), {
      ...requestPayload,
      viewerUid: 'owner-1',
      ownerUid: 'owner-1',
    }));
    await assertFails(runTransaction(viewerDb, async (transaction) => {
      await transaction.get(doc(viewerDb, `familyInvitations/${invitationId}`));
      await transaction.get(doc(viewerDb, devicePath));
      await transaction.get(doc(viewerDb, requestPath));
      transaction.set(doc(viewerDb, requestPath), requestPayload);
      transaction.set(doc(viewerDb, incomingPath), incomingPayload);
    }));
    await assertSucceeds(runTransaction(viewerDb, async (transaction) => {
      await transaction.get(doc(viewerDb, `familyInvitations/${invitationId}`));
      await transaction.get(doc(viewerDb, requestPath));
      await transaction.get(doc(viewerDb, incomingPath));
      transaction.set(doc(viewerDb, requestPath), requestPayload);
      transaction.set(doc(viewerDb, incomingPath), incomingPayload);
    }));
    await assertSucceeds(getDoc(doc(viewerDb, incomingPath)));
    await assertFails(getDoc(doc(strangerDb, incomingPath)));
    await assertFails(runTransaction(viewerDb, async (transaction) => {
      await transaction.get(doc(viewerDb, `familyInvitations/${invitationId}`));
      await transaction.get(doc(viewerDb, requestPath));
      await transaction.get(doc(viewerDb, incomingPath));
      transaction.set(doc(viewerDb, requestPath), requestPayload);
      transaction.set(doc(viewerDb, incomingPath), incomingPayload);
    }));
    await assertFails(updateDoc(doc(viewerDb, requestPath), {
      ownerUid: 'stranger-1',
    }));
    await assertFails(setDoc(doc(viewerDb, `familyInvitations/${invitationId}/requests/viewer-2`), {
      viewerUid: 'viewer-2',
      ownerUid: 'owner-1',
      invitationId,
      requestedCapabilities: ['viewLocation'],
      status: 'pending',
      requestedAt: Timestamp.now(),
    }));

    await assertSucceeds(updateDoc(doc(ownerDb, requestPath), {
      status: 'rejected',
      rejectedAt: Timestamp.now(),
    }));
    await assertSucceeds(updateDoc(doc(ownerDb, incomingPath), {
      status: 'rejected',
      rejectedAt: Timestamp.now(),
    }));
    await assertSucceeds(updateDoc(doc(ownerDb, `familyInvitations/${invitationId}`), {
      status: 'closed',
      updatedAt: Timestamp.now(),
    }));

    const retryInvitationId = 'INVITE2';
    const retryRequestPath =
      `familyInvitations/${retryInvitationId}/requests/viewer-1`;
    const retryPayload = {
      ...requestPayload,
      invitationId: retryInvitationId,
      relationship: 'child',
      requestedAt: Timestamp.now(),
    };
    await assertSucceeds(setDoc(doc(ownerDb, `familyInvitations/${retryInvitationId}`), {
      ownerUid: 'owner-1',
      ownerDisplayName: 'Owner',
      deviceId: 'device-1',
      deviceNickname: 'My Device',
      status: 'open',
      requestedCapabilities: ['viewLocation', 'viewBattery'],
      createdAt: Timestamp.now(),
      expiresAt: Timestamp.fromMillis(Date.now() + 3600000),
    }));
    await assertSucceeds(runTransaction(viewerDb, async (transaction) => {
      await transaction.get(doc(viewerDb, `familyInvitations/${retryInvitationId}`));
      await transaction.get(doc(viewerDb, retryRequestPath));
      await transaction.get(doc(viewerDb, incomingPath));
      transaction.set(doc(viewerDb, retryRequestPath), retryPayload);
      transaction.set(doc(viewerDb, incomingPath), {
        ...retryPayload,
        deviceId: 'device-1',
      });
    }));

    const revokedInvitationId = 'INVITE3';
    await assertSucceeds(setDoc(doc(ownerDb, `familyInvitations/${revokedInvitationId}`), {
      ownerUid: 'owner-1',
      ownerDisplayName: 'Owner',
      deviceId: 'device-1',
      deviceNickname: 'My Device',
      status: 'open',
      requestedCapabilities: ['viewLocation', 'viewBattery'],
      createdAt: Timestamp.now(),
      expiresAt: Timestamp.fromMillis(Date.now() + 3600000),
    }));
    await assertSucceeds(updateDoc(doc(ownerDb, `familyInvitations/${revokedInvitationId}`), {
      status: 'cancelled',
      updatedAt: Timestamp.now(),
    }));
    await assertFails(runTransaction(viewerDb, async (transaction) => {
      const revokedRequestPath =
        `familyInvitations/${revokedInvitationId}/requests/viewer-1`;
      await transaction.get(doc(viewerDb, `familyInvitations/${revokedInvitationId}`));
      await transaction.get(doc(viewerDb, revokedRequestPath));
      await transaction.get(doc(viewerDb, incomingPath));
      transaction.set(doc(viewerDb, revokedRequestPath), {
        ...requestPayload,
        invitationId: revokedInvitationId,
      });
      transaction.set(doc(viewerDb, incomingPath), {
        ...requestPayload,
        invitationId: revokedInvitationId,
        deviceId: 'device-1',
      });
    }));

    const approvalGrantPayload = {
      viewerUid: 'viewer-1',
      ownerUid: 'owner-1',
      deviceId: 'device-1',
      invitationId: retryInvitationId,
      active: true,
      relationship: 'child',
      viewerDisplayName: 'Viewer',
      viewerEmail: 'viewer@example.com',
      grantedAt: Timestamp.now(),
    };
    await assertFails(setDoc(doc(viewerDb, grantPath), approvalGrantPayload));
    await assertSucceeds(runTransaction(ownerDb, async (transaction) => {
      await transaction.get(doc(ownerDb, retryRequestPath));
      await transaction.get(doc(ownerDb, incomingPath));
      await transaction.get(doc(ownerDb, grantPath));
      transaction.set(doc(ownerDb, grantPath), approvalGrantPayload);
      transaction.set(doc(ownerDb, indexPath), {
        ownerUid: 'owner-1',
        deviceId: 'device-1',
        ownerDisplayName: 'Owner',
        relationship: 'child',
        grantedAt: Timestamp.now(),
      });
      transaction.update(doc(ownerDb, retryRequestPath), {
        status: 'approved',
        approvedAt: Timestamp.now(),
      });
      transaction.update(doc(ownerDb, incomingPath), {
        status: 'approved',
        approvedAt: Timestamp.now(),
      });
    }));
    await assertSucceeds(getDoc(doc(ownerDb, grantPath)));
    await assertFails(getDoc(doc(ownerDb, indexPath)));
    await assertSucceeds(getDoc(doc(viewerDb, indexPath)));
    await assertSucceeds(getDoc(doc(viewerDb, devicePath)));
    await assertSucceeds(getDoc(doc(viewerDb, statusPath)));
    await assertSucceeds(getDoc(doc(ownerDb, locationPath)));
    await assertSucceeds(updateDoc(doc(viewerDb, indexPath), {
      alias: 'Dad',
    }));
    await assertSucceeds(setDoc(doc(ownerDb, indexPath), {
      ownerUid: 'owner-1',
      deviceId: 'device-1',
      ownerDisplayName: 'Updated Owner',
      relationship: 'child',
      grantedAt: Timestamp.now(),
    }, { merge: true }));
    const viewerIndexAfterOwnerRefresh = await getDoc(doc(viewerDb, indexPath));
    if (viewerIndexAfterOwnerRefresh.data().alias !== 'Dad') {
      throw new Error('Owner index refresh overwrote viewer alias.');
    }
    const partialInvitationId = 'INVITE_PARTIAL_APPROVAL';
    const partialRequestPath =
      `familyInvitations/${partialInvitationId}/requests/viewer-2`;
    const partialIncomingPath =
      `${devicePath}/incomingRequests/viewer-2`;
    const partialGrantPath =
      `${devicePath}/approvedViewers/viewer-2`;
    const partialIndexPath =
      'familyViewerAccess/viewer-2/grants/owner-1__device-1';
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, `familyInvitations/${partialInvitationId}`), {
        ownerUid: 'owner-1',
        ownerDisplayName: 'Owner',
        deviceId: 'device-1',
        status: 'open',
        requestedCapabilities: ['viewLocation', 'viewBattery'],
        createdAt: Timestamp.now(),
        expiresAt: Timestamp.fromMillis(Date.now() + 3600000),
      });
      const partialPayload = {
        viewerUid: 'viewer-2',
        ownerUid: 'owner-1',
        invitationId: partialInvitationId,
        viewerDisplayName: 'Viewer Two',
        viewerEmail: 'viewer2@example.com',
        relationship: 'friend',
        requestedCapabilities: ['viewLocation', 'viewBattery'],
        status: 'pending',
        requestedAt: Timestamp.now(),
      };
      await setDoc(doc(db, partialRequestPath), partialPayload);
      await setDoc(doc(db, partialIncomingPath), {
        ...partialPayload,
        deviceId: 'device-1',
      });
      await setDoc(doc(db, partialGrantPath), {
        viewerUid: 'viewer-2',
        ownerUid: 'owner-1',
        deviceId: 'device-1',
        invitationId: partialInvitationId,
        active: true,
        relationship: 'friend',
        viewerDisplayName: 'Viewer Two',
        viewerEmail: 'viewer2@example.com',
        grantedAt: Timestamp.now(),
      });
      await setDoc(doc(db, partialIndexPath), {
        ownerUid: 'owner-1',
        deviceId: 'device-1',
        ownerDisplayName: 'Owner',
        relationship: 'friend',
        grantedAt: Timestamp.now(),
        alias: 'My friend',
      });
    });
    await assertSucceeds(runTransaction(ownerDb, async (transaction) => {
      await transaction.get(doc(ownerDb, partialRequestPath));
      await transaction.get(doc(ownerDb, partialIncomingPath));
      await transaction.get(doc(ownerDb, partialGrantPath));
      transaction.set(doc(ownerDb, partialIndexPath), {
        ownerUid: 'owner-1',
        deviceId: 'device-1',
        ownerDisplayName: 'Updated Owner',
        relationship: 'friend',
        grantedAt: Timestamp.now(),
      }, { merge: true });
      transaction.update(doc(ownerDb, partialRequestPath), {
        status: 'approved',
        approvedAt: Timestamp.now(),
      });
      transaction.update(doc(ownerDb, partialIncomingPath), {
        status: 'approved',
        approvedAt: Timestamp.now(),
      });
    }));
    const repairedIndex = await getDoc(
      doc(env.authenticatedContext('viewer-2').firestore(), partialIndexPath),
    );
    if (repairedIndex.data().alias !== 'My friend') {
      throw new Error('Approval retry overwrote the existing viewer alias.');
    }
    await assertFails(updateDoc(doc(strangerDb, indexPath), {
      alias: 'Not Dad',
    }));
    await assertFails(updateDoc(doc(viewerDb, indexPath), {
      ownerUid: 'stranger-1',
    }));
    await assertFails(setDoc(doc(ownerDb, 'familyViewerAccess/viewer-1/grants/fake'), {
      ownerUid: 'owner-1',
      deviceId: 'device-1',
      ownerDisplayName: 'Owner',
      relationship: 'friend',
      grantedAt: Timestamp.now(),
    }));
    await assertFails(setDoc(doc(strangerDb, indexPath), {
      ownerUid: 'owner-1',
      deviceId: 'device-1',
      ownerDisplayName: 'Owner',
      relationship: 'friend',
      grantedAt: Timestamp.now(),
    }));

    await assertSucceeds(getDoc(doc(viewerDb, locationPath)));
    await assertSucceeds(getDoc(doc(viewerDb, statusPath)));
    await assertSucceeds(updateDoc(doc(ownerDb, devicePath), {
      sharingState: 'paused',
      updatedAt: Timestamp.now(),
    }));
    await assertSucceeds(updateDoc(doc(ownerDb, statusPath), {
      sharingState: 'paused',
    }));
    await assertSucceeds(getDoc(doc(viewerDb, locationPath)));
    await assertSucceeds(getDoc(doc(viewerDb, statusPath)));
    await assertSucceeds(updateDoc(doc(ownerDb, devicePath), {
      sharingState: 'stopped',
      updatedAt: Timestamp.now(),
    }));
    await assertSucceeds(updateDoc(doc(ownerDb, statusPath), {
      sharingState: 'stopped',
    }));
    await assertSucceeds(getDoc(doc(viewerDb, devicePath)));
    await assertSucceeds(getDoc(doc(ownerDb, locationPath)));
    await assertSucceeds(getDoc(doc(ownerDb, statusPath)));
    await assertFails(getDoc(doc(viewerDb, locationPath)));
    await assertFails(getDoc(doc(viewerDb, statusPath)));
    await assertSucceeds(updateDoc(doc(ownerDb, devicePath), {
      sharingState: 'permissionDisabled',
      updatedAt: Timestamp.now(),
    }));
    await assertSucceeds(updateDoc(doc(ownerDb, statusPath), {
      sharingState: 'permissionDisabled',
    }));
    await assertSucceeds(getDoc(doc(viewerDb, devicePath)));
    await assertFails(getDoc(doc(viewerDb, locationPath)));
    await assertFails(getDoc(doc(viewerDb, statusPath)));
    await assertSucceeds(getDoc(doc(ownerDb, locationPath)));
    await assertSucceeds(getDoc(doc(ownerDb, statusPath)));
    await assertSucceeds(updateDoc(doc(ownerDb, devicePath), {
      sharingState: 'active',
      updatedAt: Timestamp.now(),
    }));
    await assertSucceeds(updateDoc(doc(ownerDb, statusPath), {
      sharingState: 'active',
    }));
    const revokeBatch = writeBatch(ownerDb);
    revokeBatch.delete(doc(ownerDb, grantPath));
    revokeBatch.delete(doc(ownerDb, indexPath));
    await assertSucceeds(revokeBatch.commit());
    await assertFails(getDoc(doc(viewerDb, locationPath)));
    await assertFails(getDoc(doc(viewerDb, statusPath)));
    await assertFails(getDoc(doc(viewerDb, devicePath)));
    await assertSucceeds(getDoc(doc(ownerDb, devicePath)));
    await assertSucceeds(getDoc(doc(ownerDb, locationPath)));
    await assertSucceeds(getDoc(doc(ownerDb, statusPath)));
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, grantPath), {
        viewerUid: 'viewer-1',
        ownerUid: 'owner-1',
        deviceId: 'device-1',
        invitationId,
        active: true,
        relationship: 'friend',
        viewerDisplayName: 'Viewer',
        viewerEmail: 'viewer@example.com',
        grantedAt: Timestamp.now(),
      });
      await setDoc(doc(db, indexPath), {
        ownerUid: 'owner-1',
        deviceId: 'device-1',
        ownerDisplayName: 'Owner',
        relationship: 'friend',
        grantedAt: Timestamp.now(),
      });
    });
    await assertSucceeds(deleteDoc(doc(ownerDb, grantPath)));
    await assertFails(getDoc(doc(viewerDb, locationPath)));
    await assertFails(getDoc(doc(strangerDb, locationPath)));
    await assertFails(getDoc(doc(ownerDb, 'fcmTokens/client-token')));
    await assertFails(setDoc(doc(ownerDb, 'fcmTokens/client-token'), {
      ownerUid: 'owner-1',
      token: 'client-controlled',
    }));

    await assertHelpRequestRules({
      env,
      ownerDb,
      viewerDb,
      strangerDb,
    });

    console.log('Firestore rules authorization tests passed.');
  } finally {
    await env.cleanup();
  }
}

async function assertHelpRequestRules({ env, ownerDb, viewerDb, strangerDb }) {
  const requestId = 'req_help_1';
  const helpRequestPath = `helpRequests/${requestId}`;

  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, grantPath), {
      viewerUid: 'viewer-1',
      ownerUid: 'owner-1',
      deviceId: 'device-1',
      invitationId,
      active: true,
      relationship: 'friend',
      viewerDisplayName: 'Viewer',
      viewerEmail: 'viewer@example.com',
      grantedAt: Timestamp.now(),
    });
  });

  const request = {
    requestId,
    senderUid: 'owner-1',
    senderDeviceId: 'device-1',
    recipientUid: 'viewer-1',
    requestedAt: Timestamp.now(),
    language: 'bn',
    originalMessage: 'আমি পথ হারিয়ে ফেলেছি',
    originalTranscript: 'আমি পথ হারিয়ে ফেলেছি',
    verifiedDataSnapshot: { last_reported_battery: { level: 55 } },
    generatedSummary: 'User reported being lost.',
    status: 'sent',
    acknowledgedAt: null,
  };

  await assertSucceeds(setDoc(doc(ownerDb, helpRequestPath), request));
  await assertFails(setDoc(doc(strangerDb, helpRequestPath), request));
  await assertFails(setDoc(doc(viewerDb, helpRequestPath), request));
  await assertFails(
    setDoc(doc(ownerDb, 'helpRequests/req_help_stranger'), {
      ...request,
      requestId: 'req_help_stranger',
      senderUid: 'stranger-1',
    }),
  );

  await assertSucceeds(getDoc(doc(ownerDb, helpRequestPath)));
  await assertSucceeds(getDoc(doc(viewerDb, helpRequestPath)));
  await assertFails(getDoc(doc(strangerDb, helpRequestPath)));

  await assertFails(
    updateDoc(doc(ownerDb, helpRequestPath), {
      status: 'acknowledged',
      acknowledgedAt: Timestamp.now(),
    }),
  );
  await assertFails(
    updateDoc(doc(strangerDb, helpRequestPath), {
      status: 'acknowledged',
      acknowledgedAt: Timestamp.now(),
    }),
  );
  await assertSucceeds(
    updateDoc(doc(viewerDb, helpRequestPath), {
      status: 'acknowledged',
      acknowledgedAt: Timestamp.now(),
    }),
  );
  await assertFails(
    updateDoc(doc(viewerDb, helpRequestPath), {
      status: 'acknowledged',
      acknowledgedAt: Timestamp.now(),
      originalMessage: 'tampered',
    }),
  );
  await assertFails(deleteDoc(doc(viewerDb, helpRequestPath)));
  await assertFails(deleteDoc(doc(ownerDb, helpRequestPath)));

  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, grantPath), {
      viewerUid: 'viewer-1',
      ownerUid: 'owner-1',
      deviceId: 'device-1',
      invitationId,
      active: false,
      relationship: 'friend',
      viewerDisplayName: 'Viewer',
      viewerEmail: 'viewer@example.com',
      grantedAt: Timestamp.now(),
    });
  });

  await assertFails(
    setDoc(doc(ownerDb, 'helpRequests/req_help_revoked'), {
      ...request,
      requestId: 'req_help_revoked',
    }),
  );
}

run().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
