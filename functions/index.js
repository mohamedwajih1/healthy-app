const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

const ANDROID_CHANNEL_ID = "healthy_app_notifications";

/**
 * Reads a user's FCM token and display name from Firestore.
 * @param {string} userId Firestore user document id.
 * @return {Promise<{token: ?string, name: string}>}
 */
async function getUser(userId) {
  if (!userId) return {token: null, name: ""};
  const snap = await db.collection("users").doc(userId).get();
  const data = snap.data() || {};
  return {token: data.fcmToken || null, name: data.name || ""};
}

/**
 * Writes an entry into the in-app notifications inbox.
 * @param {string} userId Recipient user id.
 * @param {string} type Notification type (chat | follow | reminder).
 * @param {string} title Notification title.
 * @param {string} body Notification body.
 * @param {!Object<string, string>} data Optional data payload.
 * @return {Promise<void>}
 */
async function writeInbox(userId, type, title, body, data) {
  if (!userId) return;
  try {
    await db.collection("notifications").add({
      userId: userId,
      type: type,
      title: title,
      body: body,
      data: data,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (err) {
    logger.error("Error writing inbox notification", err);
  }
}

/**
 * Sends a push notification to a single device token.
 * @param {string} token Target FCM registration token.
 * @param {string} title Notification title.
 * @param {string} body Notification body.
 * @param {!Object<string, string>} data Optional data payload.
 * @return {Promise<void>}
 */
async function sendToToken(token, title, body, data) {
  if (!token) {
    logger.info("Skipping push: recipient has no fcmToken");
    return;
  }

  try {
    await messaging.send({
      token: token,
      notification: {title: title, body: body},
      data: data,
      android: {
        priority: "high",
        notification: {
          channelId: ANDROID_CHANNEL_ID,
          sound: "default",
        },
      },
      apns: {
        payload: {
          aps: {sound: "default", badge: 1},
        },
      },
    });
    logger.info(`Push sent: ${title}`);
  } catch (err) {
    logger.error("Error sending push", err);
  }
}

// Sends a push to the recipient whenever a new chat message is created.
exports.onNewMessage = onDocumentCreated("messages/{messageId}", async (event) => {
  const message = event.data && event.data.data();
  if (!message) return;

  const {conversationId, senderId} = message;
  const text = (message.text || "").trim();
  if (!conversationId || !senderId) return;

  const convoSnap = await db
      .collection("conversations")
      .doc(conversationId)
      .get();
  const participants = (convoSnap.data() || {}).participants || [];
  const recipientId = participants.find((id) => id !== senderId);
  if (!recipientId) return;

  const [recipient, sender] = await Promise.all([
    getUser(recipientId),
    getUser(senderId),
  ]);

  const title = sender.name || "رسالة جديدة";
  const body = text.length > 0 ? text : "📷 صورة";
  const data = {
    screen: "chat",
    conversationId: conversationId,
    senderId: senderId,
  };

  await Promise.all([
    sendToToken(recipient.token, title, body, data),
    writeInbox(recipientId, "chat", title, body, data),
  ]);
});

// Sends a push to the target user whenever a new follow request is created.
exports.onNewFollowRequest = onDocumentCreated(
    "follow_requests/{requestId}",
    async (event) => {
      const request = event.data && event.data.data();
      if (!request) return;

      const status = request.status || "pending";
      if (status !== "pending") return;

      const fromId = request.from;
      const toId = request.to;
      if (!fromId || !toId) return;

      const [recipient, sender] = await Promise.all([
        getUser(toId),
        getUser(fromId),
      ]);

      const senderName = sender.name || "أخصائي";
      const title = "طلب متابعة";
      const body = `${senderName} يريد متابعتك`;
      const data = {screen: "home", from: fromId};

      await Promise.all([
        sendToToken(recipient.token, title, body, data),
        writeInbox(toId, "follow", title, body, data),
      ]);
    },
);
