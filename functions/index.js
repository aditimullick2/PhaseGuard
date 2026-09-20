/**
 * PhaseGuard — Firebase Cloud Function
 * 
 * Triggers on every new call document and sends a high-priority FCM push
 * notification to the callee's device, enabling background/killed app wake-up.
 * 
 * Deploy:
 *   cd functions
 *   npm install
 *   firebase deploy --only functions
 */

const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();

exports.sendCallNotification = onDocumentCreated(
  "calls/{callId}",
  async (event) => {
    const call = event.data?.data();
    const callId = event.params.callId;

    if (!call) {
      console.error("No call data found");
      return;
    }

    // Only send notification for new incoming calls
    if (call.status !== "calling") {
      console.log(`Skipping notification for status: ${call.status}`);
      return;
    }

    const calleeId = call.calleeId;
    const callerName = call.callerName;
    const callType = call.type; // "audio" | "video"

    if (!calleeId) {
      console.error("No calleeId in call document");
      return;
    }

    // Fetch callee's FCM token from Firestore
    const calleeDoc = await getFirestore()
      .collection("users")
      .doc(calleeId)
      .get();

    if (!calleeDoc.exists) {
      console.error(`Callee user doc not found: ${calleeId}`);
      return;
    }

    const fcmToken = calleeDoc.data()?.fcmToken;
    if (!fcmToken) {
      console.warn(
        `Callee ${calleeId} has no FCM token — they may not receive the notification`
      );
      return;
    }

    // Build FCM message
    const message = {
      token: fcmToken,
      // Data payload (always delivered, even for backgrounded/killed apps)
      data: {
        callId: callId,
        callerId: call.callerId,
        callerName: callerName,
        calleeId: calleeId,
        callType: callType,
        channelName: call.agoraChannelName,
        type: "incoming_call",
      },
      // Notification (displayed when app is in foreground or notification shade)
      notification: {
        title: `Incoming ${callType === "video" ? "Video" : "Audio"} Call`,
        body: `${callerName} is calling you...`,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "incoming_calls",
          priority: "max",
          defaultVibrateTimings: true,
          defaultSound: true,
          // Full-screen intent for incoming call UI on locked screen
          visibility: "public",
        },
        // Time-to-live: 30 seconds (matches call timeout)
        ttl: 30000,
      },
      apns: {
        headers: {
          "apns-priority": "10",
          "apns-push-type": "alert",
        },
        payload: {
          aps: {
            alert: {
              title: `Incoming ${callType === "video" ? "Video" : "Audio"} Call`,
              body: `${callerName} is calling you...`,
            },
            sound: "default",
            badge: 1,
            category: "INCOMING_CALL",
          },
        },
      },
    };

    try {
      const response = await getMessaging().send(message);
      console.log(`FCM notification sent to ${calleeId}: ${response}`);
    } catch (error) {
      console.error(`Failed to send FCM notification to ${calleeId}:`, error);

      // If the token is invalid, clear it from Firestore so we don't retry
      if (
        error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered"
      ) {
        await getFirestore()
          .collection("users")
          .doc(calleeId)
          .update({ fcmToken: null });
        console.log(`Cleared invalid FCM token for user ${calleeId}`);
      }
    }
  }
);