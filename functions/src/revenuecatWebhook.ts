import * as admin from "firebase-admin";
import { onRequest } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { EmailService } from "./services/emailService";

// 🔐 Secure API Key from Firebase Secrets
const resendApiKey = defineSecret("RESEND_API_KEY");

export const revenuecatWebhook = onRequest(
  { secrets: [resendApiKey] },
  async (req, res) => {
    try {
      const event = req.body.event;

      // Safety check for bad requests
      if (!event || !event.app_user_id) {
        console.error("Invalid webhook payload: Missing event or app_user_id");
        res.status(400).send({ ok: false, message: "Invalid payload" });
        return;
      }

      const uid = event.app_user_id;
      let plan = "free";

      // RevenueCat sends entitlement_ids as an array of strings
      const entitlements: string[] = event.entitlement_ids ?? [];

      // 🆕 FETCH CURRENT STATE FIRST (Critical for preventing downgrades)
      const userRef = admin.firestore().doc(`users/${uid}`);
      const userDoc = await userRef.get();
      const userData = userDoc.data();
      const currentPlan = userData?.plan || "free";
      const lastSyncAt = userData?.lastSyncAt?.toDate();

      console.log(`📨 Webhook received for ${uid}: Type=${event.type}, Entitlements=[${entitlements}], Current Plan=${currentPlan}`);

      // 1. Logic for Active Subscriptions (Including Upgrades)
      const isActiveEvent = [
        "INITIAL_PURCHASE",
        "RENEWAL",
        "UNCANCELLATION",
        "NON_RENEWING_PURCHASE",
        "PRODUCT_CHANGE", // Handle PRO→ELITE upgrades
      ].includes(event.type);

      if (isActiveEvent) {
        // Priority: Elite > Pro > Free
        if (entitlements.includes("Elite")) {
          plan = "elite";
          console.log(`🔹 Webhook says: ELITE`);
        } else if (entitlements.includes("Pro")) {
          plan = "pro";
          console.log(`📈 Webhook says: PRO`);
        }

        // 🆕 防护 #1: Prevent downgrades from stale webhooks
        const planHierarchy: { [key: string]: number } = {
          free: 0,
          pro: 1,
          elite: 2
        };

        if (planHierarchy[plan] < planHierarchy[currentPlan]) {
          console.warn(
            `⚠️ STALE WEBHOOK DETECTED! Attempted downgrade: ${currentPlan} → ${plan}. ` +
            `Ignoring this webhook to preserve user's current plan.`
          );
          res.status(200).send({
            ok: true,
            message: "Stale webhook ignored - user already on higher plan"
          });
          return; // ← EXIT HERE! Don't update Firestore
        }

        // 🆕 防护 #2: Timestamp check - ignore webhooks older than last manual sync
        if (event.event_timestamp_ms && lastSyncAt) {
          const webhookTime = new Date(event.event_timestamp_ms);

          if (webhookTime < lastSyncAt) {
            console.warn(
              `⏰ OLD WEBHOOK DETECTED! Webhook time: ${webhookTime.toISOString()}, ` +
              `Last sync: ${lastSyncAt.toISOString()}. Ignoring outdated webhook.`
            );
            res.status(200).send({
              ok: true,
              message: "Outdated webhook ignored - newer sync already processed"
            });
            return; // ← EXIT HERE! Don't update with old data
          }
        }
      }

      // 2. Logic for Ended Subscriptions
      if (event.type === "EXPIRATION") {
        plan = "free";
        console.log(`📉 User ${uid} subscription expired. Downgrading to FREE`);

        // Notify user about expiration
        if (userData?.email) {
          await EmailService.sendSubscriptionExpired(userData.email);
        }
      }

      // 2.5 Handle Cancellation (No-op for plan change)
      if (event.type === "CANCELLATION") {
        console.log(`ℹ️ User ${uid} cancelled auto-renewal. Plan maintained until expiration.`);
        res.status(200).send({ ok: true, message: "Cancellation logged" });
        return;
      }

      // 3. CREDIT ALLOCATION (Monthly Limit)
      let credits = 10;
      if (plan === "pro") credits = 100;
      if (plan === "elite") credits = 200;

      console.log(`💳 Allocating ${credits} credits for ${plan} plan`);

      // 🆕 OPTIMIZATION: Only update if plan actually changed
      if (plan === currentPlan) {
        console.log(`ℹ️ No plan change detected. User already on ${plan}. Skipping Firestore update.`);
        res.status(200).send({
          ok: true,
          message: "No update needed - plan unchanged"
        });
        return;
      }

      // 🔐 Sync to Firebase Auth (For Security Rules)
      // This allows request.auth.token.plan in Firestore rules
      await admin.auth().setCustomUserClaims(uid, { plan });

      // 🔄 Sync to Firestore (For Frontend UI)
      // IMPORTANT: Always reset credits to full amount on plan change
      await userRef.set(
        {
          plan,
          AiCredits: credits, // Reset to full credits on plan change
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastWebhookType: event.type, // 🆕 Track last webhook for debugging
        },
        { merge: true }
      );

      console.log(`✅ Successfully updated user ${uid}: ${currentPlan} → ${plan} with ${credits} credits`);

      // 📧 Send Confirmation Email (New Subscriptions/Upgrades)
      const userEmail = userData?.email;
      if (userEmail && plan !== "free") {
        await EmailService.sendSubscriptionSuccess(userEmail, plan, credits);
      }

      res.status(200).send({ ok: true, plan, credits });

    } catch (e: any) {
      console.error("❌ RevenueCat webhook error:", e);
      res.status(500).send({ ok: false, error: e.message });
    }
  });