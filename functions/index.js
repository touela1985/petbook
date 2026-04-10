const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { initializeApp } = require('firebase-admin/app');

initializeApp();

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
