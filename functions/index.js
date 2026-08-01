const { onSchedule } = require('firebase-functions/v2/scheduler');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

function getContractDueDate(contractStartDate, referenceDate) {
  const dueDay = contractStartDate.getDate();
  const year = referenceDate.getFullYear();
  const month = referenceDate.getMonth();
  const lastDay = new Date(year, month + 1, 0).getDate();
  const day = dueDay <= lastDay ? dueDay : lastDay;
  return new Date(year, month, day, 23, 59, 59);
}

exports.checkDuePayments = onSchedule(
  {
    schedule: 'every 24 hours',
    timeZone: 'UTC',
    serviceAccountEmail: 'rentpay-app-76517@appspot.gserviceaccount.com'
  },
  async (event) => {
    const now = new Date();

    const usersSnapshot = await db.collection('users').get();

    const messages = [];

    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      if (userData.role !== 'tenant' || !userData.ownerId) {
        continue;
      }

      const tenantId = userDoc.id;
      const roomQuery = await db
        .collection('rooms')
        .where('tenantId', '==', tenantId)
        .limit(1)
        .get();

      if (roomQuery.empty) {
        continue;
      }

      const roomData = roomQuery.docs[0].data();
      const paymentStatus = roomData.paymentStatus || 'unpaid';
      if (paymentStatus === 'paid') {
        continue;
      }

      const contractsSnapshot = await db
        .collection('contracts')
        .where('tenantId', '==', tenantId)
        .get();

      let activeContract = null;
      for (const contractDoc of contractsSnapshot.docs) {
        const contractData = contractDoc.data();
        const status = contractData.status || '';
        if (['Expired', 'Cancelled', 'Terminated'].includes(status)) {
          continue;
        }
        const startDate = contractData.startDate?.toDate?.();
        if (startDate) {
          if (!activeContract || startDate > activeContract.startDate) {
            activeContract = { ...contractData, startDate };
          }
        }
      }

      if (!activeContract) {
        continue;
      }

      const dueDate = getContractDueDate(activeContract.startDate, now);
      const sendReminder = now >= dueDate;

      if (!sendReminder) {
        continue;
      }

      const fcmToken = userData.fcmToken;
      if (!fcmToken) {
        continue;
      }

      const message = {
        token: fcmToken,
        notification: {
          title: 'RentPay Reminder',
          body: `Your rent is due today. Please pay your bill to stop the reminder.`,
        },
        data: {
          roomNumber: roomData.roomNumber || '',
        },
      };

      messages.push(message);
    }

    const promises = messages.map((message) => admin.messaging().send(message));
    await Promise.allSettled(promises);

    return null;
  }
);
