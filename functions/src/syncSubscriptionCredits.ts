import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";

// 🔐 Secure API Key from Firebase Secrets
const revenueCatApiKey = defineSecret("REVENUECAT_API_KEY");

/**
 * Secure Cloud Function to sync subscription credits
 * Called immediately after purchase to update credits without waiting for webhook
 * Uses RevenueCat REST API to verify purchases server-side
 */
export const syncSubscriptionCredits = onCall(
    { secrets: [revenueCatApiKey] },
    async (request) => {
        // 1. Verify Authentication
        if (!request.auth) {
            throw new HttpsError("unauthenticated", "Must be logged in");
        }

        const uid = request.auth.uid;

        try {
            console.log(`🔄 Syncing credits for user: ${uid}`);

            // 2. Access RevenueCat API Key from secrets
            const revenueCatSecretKey = revenueCatApiKey.value();

            // 3. Verify with RevenueCat REST API
            const response = await fetch(`https://api.revenuecat.com/v1/subscribers/${uid}`, {
                method: "GET",
                headers: {
                    "Authorization": `Bearer ${revenueCatSecretKey}`,
                    "Content-Type": "application/json",
                    "Accept": "application/json"
                },
            });

            if (!response.ok) {
                console.error(`❌ RevenueCat API error: ${response.status} ${response.statusText}`);
                throw new HttpsError("internal", "Failed to verify subscription with RevenueCat");
            }

            const subscriberData = await response.json();
            const entitlements = subscriberData.subscriber?.entitlements || {};

            console.log(`🔍 Found entitlements for ${uid}:`, JSON.stringify(entitlements, null, 2));

            // 4. Determine plan based on active entitlements (Priority: Elite > Pro > Free)
            let plan = "free";
            let entitlementFound = false;

            // Check Elite first (highest priority)
            if (entitlements.Elite?.expires_date) {
                const expiresDate = new Date(entitlements.Elite.expires_date);
                if (expiresDate > new Date()) {
                    plan = "elite";
                    entitlementFound = true;
                    console.log(`🔹 Elite entitlement active until ${expiresDate.toISOString()}`);
                }
            }

            // Check Pro only if Elite not found
            if (!entitlementFound && entitlements.Pro?.expires_date) {
                const expiresDate = new Date(entitlements.Pro.expires_date);
                if (expiresDate > new Date()) {
                    plan = "pro";
                    entitlementFound = true;
                    console.log(`📈 Pro entitlement active until ${expiresDate.toISOString()}`);
                }
            }

            // 🆕 SAFETY CHECK: Verify we found an active entitlement
            if (!entitlementFound && plan === "free") {
                console.warn(`⚠️ No active entitlements found for ${uid}. User may have cancelled or refunded.`);
            }

            // 5. Calculate credits based on plan
            let credits = 10;   // Free tier
            if (plan === "pro") credits = 100;
            if (plan === "elite") credits = 200;

            // 6. Get current plan to log the change
            const userRef = admin.firestore().doc(`users/${uid}`);
            const userDoc = await userRef.get();
            const currentPlan = userDoc.data()?.plan || "free";

            console.log(`📊 Plan change: ${currentPlan} → ${plan} (Credits: ${credits})`);

            // 7. Update Firestore with timestamp protection
            await userRef.set({
                plan: plan,
                AiCredits: credits,
                lastSyncAt: admin.firestore.FieldValue.serverTimestamp(), // 🆕 Track manual sync time
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                lastSyncSource: "manual", // 🆕 Track that this was a manual sync
            }, { merge: true });

            // 8. Update Auth custom claims for security rules
            await admin.auth().setCustomUserClaims(uid, { plan });

            console.log(`✅ Successfully synced credits for ${uid}: ${plan} → ${credits} credits`);

            return {
                success: true,
                plan,
                credits,
                previousPlan: currentPlan,
                message: `Upgraded to ${plan.toUpperCase()} with ${credits} credits`
            };

        } catch (error: any) {
            console.error("❌ Error syncing credits:", error);

            // Provide more helpful error messages
            if (error.code === "unauthenticated") {
                throw error; // Re-throw auth errors as-is
            }

            throw new HttpsError(
                "internal",
                `Failed to sync subscription: ${error.message || "Unknown error"}`
            );
        }
    });