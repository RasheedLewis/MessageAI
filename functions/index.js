/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const functions = require("firebase-functions");
const { setGlobalOptions } = functions;
const admin = require("firebase-admin");

admin.initializeApp();

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

exports.sendMessageNotification = functions.firestore
    .document("conversations/{conversationId}/messages/{messageId}")
    .onCreate(async (snapshot, context) => {
        const messageData = snapshot.data();
        if (!messageData) {
            console.log("[Notification] No message data, exiting");
            return null;
        }

        const { conversationId } = context.params;
        const senderId = messageData.senderId;

        try {
            const conversationSnap = await admin
                .firestore()
                .collection("conversations")
                .doc(conversationId)
                .get();

            if (!conversationSnap.exists) {
                console.log(`[Notification] Conversation ${conversationId} not found.`);
                return null;
            }

            const conversation = conversationSnap.data();
            const participantIds = conversation.participants || [];
            const recipients = participantIds.filter((id) => id !== senderId);

            if (recipients.length === 0) {
                console.log("[Notification] No recipients for this message.");
                return null;
            }

            const userRefs = recipients.map((uid) => admin
                .firestore()
                .collection("users")
                .doc(uid));

            const userSnaps = await admin.firestore().getAll(...userRefs);
            const tokens = [];

            userSnaps.forEach((snap) => {
                if (!snap.exists) {
                    return;
                }
                const data = snap.data();
                if (data && data.fcmToken) {
                    tokens.push(data.fcmToken);
                }
            });

            if (tokens.length === 0) {
                console.log("[Notification] No FCM tokens available for recipients.");
                return null;
            }

            const notificationTitle = conversation.title || "New Message";
            const hasContent = messageData.content &&
                messageData.content.trim().length > 0;
            const bodyText = hasContent ?
                messageData.content : "Sent you a message";

            const payload = {
                tokens,
                notification: {
                    title: notificationTitle,
                    body: bodyText,
                },
                data: {
                    conversationId,
                    messageId: context.params.messageId,
                    senderId,
                },
            };

            const response = await admin.messaging().sendEachForMulticast(payload);
            if (response.failureCount > 0) {
                console.log("[Notification] Some notifications failed", response.responses);
            }

            return null;
        } catch (error) {
            console.error("[Notification] Failed to send notification", error);
            return null;
        }
    });
