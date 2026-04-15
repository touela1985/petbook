const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { getFirestore } = require('firebase-admin/firestore');
const { initializeApp } = require('firebase-admin/app');

initializeApp();

// ─── Lost Report created → notify all lost_reports topic subscribers ─────────

exports.onLostReportCreated = onDocumentCreated(
  'lost_reports/{reportId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const parts = [];
    if (data.petName) parts.push(data.petName);
    if (data.type) parts.push(data.type);
    if (data.lastSeenLocation) parts.push(`📍 ${data.lastSeenLocation}`);

    const body =
      parts.length > 0
        ? parts.join(' · ')
        : 'Ένα ζωάκι χάθηκε στην περιοχή σου.';

    try {
      await getMessaging().send({
        notification: { title: 'Νέο χαμένο ζωάκι', body },
        data: {
          type: 'new_lost_report',
          reportId: event.params.reportId,
        },
        topic: 'lost_reports',
      });
    } catch (err) {
      console.error('[petbook] FCM send error:', err);
    }
  }
);

// ─── Found Report message created → notify the receiver directly ─────────────

exports.onFoundPetMessageCreated = onDocumentCreated(
  'found_pet_messages/{messageId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const receiverUserId = data.receiverUserId;
    const senderUserId   = data.senderUserId;

    // Guard: no receiver → nothing to do
    if (!receiverUserId) return;

    // Guard: sender == receiver → skip self-message
    if (senderUserId && senderUserId === receiverUserId) return;

    // Look up the receiver's FCM token from users/{receiverUserId}
    let fcmToken;
    try {
      const userDoc = await getFirestore()
        .collection('users')
        .doc(receiverUserId)
        .get();

      if (!userDoc.exists) return;
      fcmToken = userDoc.data()?.fcmToken;
    } catch (err) {
      console.error('[petbook] User lookup failed:', err);
      return;
    }

    // Guard: no token → cannot deliver
    if (!fcmToken) return;

    // Guard: no reportId → cannot deep-link
    const reportId = data.reportId;
    if (!reportId) return;

    try {
      await getMessaging().send({
        notification: {
          title: 'Νέο μήνυμα για ζώο που βρέθηκε',
          body: 'Έχεις νέο μήνυμα σε αναφορά',
        },
        data: {
          type: 'new_found_message',
          reportId: reportId,
        },
        token: fcmToken,
      });
    } catch (err) {
      console.error('[petbook] FCM found message notification error:', err);
    }
  }
);

// ─── Lost Sighting created → notify the report owner directly ────────────────

exports.onLostSightingCreated = onDocumentCreated(
  'lost_sightings/{sightingId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const reportId        = data.reportId;
    const submittedByUserId = data.submittedByUserId;

    // Guard: no reportId → cannot look up owner or deep-link
    if (!reportId) return;

    // Fetch the lost report to find the owner's userId
    let reportData;
    try {
      const reportDoc = await getFirestore()
        .collection('lost_reports')
        .doc(reportId)
        .get();
      if (!reportDoc.exists) return;
      reportData = reportDoc.data();
    } catch (err) {
      console.error('[petbook] Lost report lookup failed:', err);
      return;
    }

    const ownerUserId = reportData?.userId;

    // Guard: no owner → cannot notify
    if (!ownerUserId) return;

    // Guard: submitter is the owner → skip self-notification
    if (submittedByUserId && submittedByUserId === ownerUserId) return;

    // Look up the owner's FCM token
    let fcmToken;
    try {
      const userDoc = await getFirestore()
        .collection('users')
        .doc(ownerUserId)
        .get();
      if (!userDoc.exists) return;
      fcmToken = userDoc.data()?.fcmToken;
    } catch (err) {
      console.error('[petbook] User lookup failed:', err);
      return;
    }

    // Guard: no token → cannot deliver
    if (!fcmToken) return;

    // Build a human-friendly body from the sighting location + pet name
    const petName = (reportData.petName && reportData.petName.trim())
      ? reportData.petName.trim()
      : null;

    const location = (data.location && data.location.trim())
      ? data.location.trim()
      : null;

    let body = 'Κάποιος είδε το ζωάκι σου!';
    if (petName && location) {
      body = `Κάποιος είδε τον/την ${petName} κοντά στο ${location}`;
    } else if (petName) {
      body = `Κάποιος είδε τον/την ${petName}!`;
    } else if (location) {
      body = `Θέαση κοντά στο ${location}`;
    }

    try {
      await getMessaging().send({
        notification: {
          title: 'Νέα θέαση για χαμένο ζωάκι',
          body,
        },
        data: {
          type: 'new_lost_sighting',
          reportId: reportId,
        },
        token: fcmToken,
      });
    } catch (err) {
      console.error('[petbook] FCM sighting notification error:', err);
    }
  }
);

// ─── Lost Report message created → notify the receiver directly ──────────────

exports.onLostPetMessageCreated = onDocumentCreated(
  'lost_pet_messages/{messageId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const receiverUserId = data.receiverUserId;
    const senderUserId   = data.senderUserId;

    // Guard: no receiver → nothing to do
    if (!receiverUserId) return;

    // Guard: sender == receiver → skip self-message
    if (senderUserId && senderUserId === receiverUserId) return;

    // Look up the receiver's FCM token from users/{receiverUserId}
    let fcmToken;
    try {
      const userDoc = await getFirestore()
        .collection('users')
        .doc(receiverUserId)
        .get();

      if (!userDoc.exists) return;
      fcmToken = userDoc.data()?.fcmToken;
    } catch (err) {
      console.error('[petbook] User lookup failed:', err);
      return;
    }

    // Guard: no token → cannot deliver
    if (!fcmToken) return;

    // Build notification payload with safe fallbacks
    const senderName = (data.senderName && data.senderName.trim())
      ? data.senderName.trim()
      : 'Κάποιος';

    const rawMessage = (data.message && data.message.trim())
      ? data.message.trim()
      : '';

    const preview = rawMessage.length > 80
      ? rawMessage.substring(0, 80) + '…'
      : rawMessage;

    const body = preview
      ? `${senderName}: ${preview}`
      : 'Έλαβες νέο μήνυμα.';

    // Guard: no reportId → cannot deep-link
    const reportId = data.reportId;
    if (!reportId) return;

    try {
      await getMessaging().send({
        notification: {
          title: 'Νέο μήνυμα για χαμένο ζωάκι',
          body,
        },
        data: {
          type: 'new_lost_message',
          reportId: reportId,
        },
        token: fcmToken,
      });
    } catch (err) {
      console.error('[petbook] FCM message notification error:', err);
    }
  }
);
