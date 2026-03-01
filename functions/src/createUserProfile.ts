import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { defineSecret } from "firebase-functions/params";
import { EmailService } from "./services/emailService";

// 🔐 Secure API Key from Firebase Secrets
const resendApiKey = defineSecret("RESEND_API_KEY");

// Note: admin.initializeApp() is usually called in index.ts

export const createUserProfile = onDocumentCreated(
  {
    document: "users/{uid}",
    secrets: [resendApiKey]
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const uid = event.params.uid;
    const data = snap.data() as Record<string, any>;

    const defaultPlan = "free";
    const referralReward = 5;

    try {
      // 2️⃣ Handle Referral Logic
      const referredBy = data.referredBy;
      let initialCredits = 5; // Default Free Credits

      if (referredBy && typeof referredBy === "string" && referredBy.trim() !== "") {
        console.log(`🔗 User ${uid} signed up with referral from: ${referredBy}`);

        const inviterRef = admin.firestore().collection("users").doc(referredBy);
        const inviterDoc = await inviterRef.get();

        if (inviterDoc.exists) {
          // Award credits to inviter
          await inviterRef.update({
            AiCredits: admin.firestore.FieldValue.increment(referralReward),
            referralCount: admin.firestore.FieldValue.increment(1),
          });

          // 📧 Notify inviter about referral success
          const inviterData = inviterDoc.data();
          if (inviterData?.email) {
            const newReferralCount = (inviterData.referralCount || 0) + 1;
            EmailService.sendReferralSuccess(inviterData.email, referralReward, newReferralCount)
              .catch(err => console.error("Failed to send referral email:", err));
          }

          // Award credits to invitee (the new user)
          initialCredits += referralReward;

          // Log the referral for history/audit
          await admin.firestore().collection("referrals").add({
            inviterId: referredBy,
            inviteeId: uid,
            inviteeEmail: data.email || "",
            rewardAmount: referralReward,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            status: "completed",
            type: "dual_reward"
          });

          console.log(`✅ Awarded ${referralReward} credits to both inviter ${referredBy} and invitee ${uid}`);
        } else {
          console.warn(`⚠️ Inviter ${referredBy} not found. Skipping reward.`);
        }
      }

      // 3️⃣ Initialize Firestore user doc
      await snap.ref.set(
        {
          uid,
          email: data.email || "",
          name: data.name || "New User",
          photo: data.photo || "",
          AiCredits: initialCredits,
          plan: defaultPlan,
          termsAccepted: false, // Ensure new users must accept terms
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      // 3️⃣ Set Auth custom claims
      await admin.auth().setCustomUserClaims(uid, {
        plan: defaultPlan,
      });

      console.log(`✅ Fidus User ${uid} initialized with ${defaultPlan} plan`);

      // 📧 Send Welcome Email
      if (data.email) {
        EmailService.sendWelcomeEmail(data.email, data.name || "New User")
          .catch(err => console.error("Failed to send welcome email:", err));
      }
    } catch (e) {
      console.error("❌ User profile init failed:", e);
    }
  }
);