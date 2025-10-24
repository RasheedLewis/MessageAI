/**
 * Cloud Functions entry point for MessageAI.
 */

const admin = require("firebase-admin");
const functions = require("firebase-functions/v1");

admin.initializeApp();

functions.logger.info("Functions initialized");

exports.sendMessageNotification = functions.firestore
    .document("conversations/{conversationId}/messages/{messageId}")
    .onCreate(async (snapshot, context) => {
        const messageData = snapshot.data();
        if (!messageData) {
            functions.logger.warn("No message data, aborting notification.");
            return null;
        }

        const { conversationId } = context.params;
        const senderId = messageData.senderId;

        try {
            const conversationDoc = await admin.firestore()
                .collection("conversations")
                .doc(conversationId)
                .get();

            if (!conversationDoc.exists) {
                functions.logger.warn(
                    `Conversation ${conversationId} not found.`,
                );
                return null;
            }

            const conversation = conversationDoc.data();
            const participants = conversation.participants || [];
            const recipients = participants.filter((id) => id !== senderId);

            if (recipients.length === 0) {
                functions.logger.info(
                    "No recipients to notify for this message.",
                );
                return null;
            }

            const userRefs = recipients.map((uid) => admin.firestore()
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
                functions.logger.info(
                    "No FCM tokens found for recipients.",
                );
                return null;
            }

            const title = conversation.title || "New Message";
            const hasContent = messageData.content &&
                messageData.content.trim().length > 0;
            const body = hasContent ?
                messageData.content :
                "Sent you a message";

            const payload = {
                tokens,
                notification: {
                    title,
                    body,
                },
                data: {
                    conversationId,
                    messageId: context.params.messageId,
                    senderId,
                },
            };

            const response = await admin.messaging()
                .sendEachForMulticast(payload);
            if (response.failureCount > 0) {
                functions.logger.warn(
                    "Some notifications failed",
                    response.responses,
                );
            }

            return null;
        } catch (error) {
            functions.logger.error(
                "Unable to send notification",
                error,
            );
            return null;
        }
    });

