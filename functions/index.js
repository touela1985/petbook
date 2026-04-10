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
        topic: 'lost_reports',
      });
    } catch (err) {
      console.error('[petbook] FCM send error:', err);
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

    try {
      await getMessaging().send({
        notification: {
          title: 'Νέο μήνυμα για χαμένο ζωάκι',
          body,
        },
        token: fcmToken,
      });
    } catch (err) {
      console.error('[petbook] FCM message notification error:', err);
    }
  }
);
