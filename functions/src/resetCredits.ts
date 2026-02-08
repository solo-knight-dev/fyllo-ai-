import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";
import * as admin from "firebase-admin";
import { EmailService } from "./services/emailService";

// 🔐 Secure API Key from Firebase Secrets
const resendApiKey = defineSecret("RESEND_API_KEY");

// Run on the 1st of every month at midnight
export const resetMonthlyCredits = onSchedule({
    schedule: "0 0 1 * *",
    timeoutSeconds: 540, // Increased timeout to 9 minutes for large batches
    memory: "512MiB",    // Decent memory for processing
    secrets: [resendApiKey]
}, async (event) => {
    const db = admin.firestore();
    let lastDoc = null;
    let totalProcessed = 0;
    let totalUpdated = 0;

    console.log("🔄 Starting Scalable Monthly Credit Reset...");

    while (true) {
        // 1. Fetch in small chunks (500 is the Firestore Batch limit)
        let query = db.collection("users").limit(500);

        // If we have a lastDoc, start the next query AFTER it (Pagination)
        if (lastDoc) {
            query = query.startAfter(lastDoc);
        }

        const snapshot = await query.get();

        // 2. Break the loop if no more users are found
        if (snapshot.empty) {
            break;
        }

        const batch = db.batch();

        snapshot.docs.forEach((doc) => {
            const data = doc.data();
            const plan = data.plan || "free";

            let newCredits = 10;
            if (plan === "pro") newCredits = 100;
            if (plan === "elite") newCredits = 200;

            // Only update if credits actually need changing (saves money/writes)
            if (data.AiCredits !== newCredits) {
                // 🆕 CRITICAL FIX: Preserve lastSyncAt and lastSyncSource
                // This prevents webhooks from overwriting recent upgrades
                const updateData: any = {
                    AiCredits: newCredits,
                    lastResetAt: admin.firestore.FieldValue.serverTimestamp()
                };

                // 🆕 PRESERVE existing sync metadata (don't overwrite!)
                // If user upgraded in the last hour, keep their sync timestamp
                if (data.lastSyncAt) {
                    const lastSyncTime = data.lastSyncAt.toDate();
                    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);

                    // If sync happened in last hour, preserve it
                    if (lastSyncTime > oneHourAgo) {
                        console.log(`⚠️ User ${doc.id} synced recently (${lastSyncTime.toISOString()}). Preserving sync metadata.`);
                        // Don't add lastSyncAt to update - keep existing value
                    }
                }

                batch.update(doc.ref, updateData);
                totalUpdated++;

                // 📧 Notify Pro/Elite users about credit reset
                if (data.email && (plan === "pro" || plan === "elite")) {
                    // We don't await this inside the loop to avoid slowing down the batch process
                    // Firestore handles many concurrent adds well
                    EmailService.sendCreditResetNotification(data.email, plan, newCredits)
                        .catch(err => console.error(`Failed to send reset email to ${data.email}:`, err));
                }
            }
        });

        // 3. Commit this batch of 500
        await batch.commit();

        totalProcessed += snapshot.docs.length;
        // Set the last document for the next iteration
        lastDoc = snapshot.docs[snapshot.docs.length - 1];

        console.log(`Processed ${totalProcessed} users (${totalUpdated} updated)...`);
    }

    console.log(`✅ Successfully reset credits for ${totalProcessed} users total (${totalUpdated} updated).`);
});