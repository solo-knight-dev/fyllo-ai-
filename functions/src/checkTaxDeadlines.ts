
import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

// Schedule: Every Monday at 9:00 AM
export const checkTaxDeadlines = onSchedule("every monday 09:00", async (event) => {
    const today = new Date();

    // Comprehensive tax deadlines for all 8 supported jurisdictions
    const deadlines = [
        // 🇺🇸 UNITED STATES (IRS)
        { country: "USA", month: 4, day: 15, message: "🇺🇸 US Tax Day! File your federal return by April 15." },
        { country: "USA", month: 1, day: 15, message: "🇺🇸 Q4 Estimated Tax Payment due January 15." },
        { country: "USA", month: 4, day: 15, message: "🇺🇸 Q1 Estimated Tax Payment due April 15." },
        { country: "USA", month: 6, day: 15, message: "🇺🇸 Q2 Estimated Tax Payment due June 15." },
        { country: "USA", month: 9, day: 15, message: "🇺🇸 Q3 Estimated Tax Payment due September 15." },
        { country: "USA", month: 10, day: 15, message: "🇺🇸 Extended Filing Deadline (if requested) - October 15." },

        // 🇬🇧 UNITED KINGDOM (HMRC)
        { country: "UK", month: 1, day: 31, message: "🇬🇧 Self Assessment Tax Return deadline - January 31." },
        { country: "UK", month: 7, day: 31, message: "🇬🇧 Payment on Account (2nd installment) due July 31." },
        { country: "UK", month: 10, day: 5, message: "🇬🇧 Paper Tax Return deadline - October 5." },
        { country: "UK", month: 10, day: 31, message: "🇬🇧 Register for Self Assessment if self-employed." },

        // 🇨🇦 CANADA (CRA)
        { country: "CANADA", month: 4, day: 30, message: "🇨🇦 Individual Tax Return deadline - April 30." },
        { country: "CANADA", month: 6, day: 15, message: "🇨🇦 Self-Employed Tax Return deadline - June 15." },
        { country: "CANADA", month: 3, day: 15, message: "🇨🇦 Quarterly Installment Payment due (March 15)." },
        { country: "CANADA", month: 6, day: 15, message: "🇨🇦 Quarterly Installment Payment due (June 15)." },
        { country: "CANADA", month: 9, day: 15, message: "🇨🇦 Quarterly Installment Payment due (September 15)." },
        { country: "CANADA", month: 12, day: 15, message: "🇨🇦 Quarterly Installment Payment due (December 15)." },

        // 🇦🇺 AUSTRALIA (ATO)
        { country: "AUSTRALIA", month: 10, day: 31, message: "🇦🇺 Individual Tax Return deadline - October 31." },
        { country: "AUSTRALIA", month: 5, day: 15, message: "🇦🇺 Lodge Tax Return via registered agent by May 15 (extended)." },
        { country: "AUSTRALIA", month: 7, day: 1, message: "🇦🇺 New Financial Year begins - Start organizing your records!" },
        { country: "AUSTRALIA", month: 1, day: 28, message: "🇦🇺 PAYG Installment due (Q2) - January 28." },
        { country: "AUSTRALIA", month: 4, day: 28, message: "🇦🇺 PAYG Installment due (Q3) - April 28." },

        // 🇮🇳 INDIA (Income Tax Department)
        { country: "INDIA", month: 7, day: 31, message: "🇮🇳 Individual Tax Return filing deadline - July 31." },
        { country: "INDIA", month: 10, day: 31, message: "🇮🇳 Tax Audit filing deadline - October 31." },
        { country: "INDIA", month: 11, day: 30, message: "🇮🇳 Revised/Belated Return deadline - November 30." },
        { country: "INDIA", month: 3, day: 31, message: "🇮🇳 Financial Year ends - March 31. Start tax planning!" },
        { country: "INDIA", month: 6, day: 15, message: "🇮🇳 Advance Tax Installment (Q1) due - June 15." },
        { country: "INDIA", month: 9, day: 15, message: "🇮🇳 Advance Tax Installment (Q2) due - September 15." },
        { country: "INDIA", month: 12, day: 15, message: "🇮🇳 Advance Tax Installment (Q3) due - December 15." },

        // 🇸🇬 SINGAPORE (IRAS)
        { country: "SINGAPORE", month: 4, day: 15, message: "🇸🇬 Individual Tax Filing deadline - April 15." },
        { country: "SINGAPORE", month: 4, day: 18, message: "🇸🇬 E-Filing (Paper) deadline - April 18." },
        { country: "SINGAPORE", month: 11, day: 30, message: "🇸🇬 Corporate Tax Return deadline (estimate) - November 30." },
        { country: "SINGAPORE", month: 3, day: 1, message: "🇸🇬 Tax Season begins - Prepare your records!" },

        // 🇦🇪 UAE (FTA - Federal Tax Authority)
        { country: "UAE", month: 1, day: 31, message: "🇦🇪 Corporate Tax Return deadline - January 31 (for Dec year-end)." },
        { country: "UAE", month: 3, day: 31, message: "🇦🇪 VAT Return (Q1) deadline - March 31." },
        { country: "UAE", month: 6, day: 30, message: "🇦🇪 VAT Return (Q2) deadline - June 30." },
        { country: "UAE", month: 9, day: 30, message: "🇦🇪 VAT Return (Q3) deadline - September 30." },
        { country: "UAE", month: 12, day: 31, message: "🇦🇪 VAT Return (Q4) deadline - December 31." },
        { country: "UAE", month: 7, day: 28, message: "🇦🇪 Corporate Tax Registration (if applicable) - July 28." },

        // 🇮🇪 IRELAND (Revenue)
        { country: "IRELAND", month: 10, day: 31, message: "🇮🇪 Self-Assessment Tax Return deadline (ROS online) - October 31." },
        { country: "IRELAND", month: 11, day: 15, message: "🇮🇪 Self-Assessment Tax Return deadline (paper) - November 15." },
        { country: "IRELAND", month: 1, day: 15, message: "🇮🇪 Preliminary Tax Payment deadline - January 15." },
        { country: "IRELAND", month: 10, day: 31, message: "🇮🇪 Pay & File (corporation tax) - October 31." },
    ];

    const notificationsToSend: Promise<string>[] = [];

    // Check if we're within 14 days of any deadline
    for (const d of deadlines) {
        const deadlineDate = new Date(today.getFullYear(), d.month - 1, d.day);
        const daysUntilDeadline = Math.ceil((deadlineDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));

        // Send notification if:
        // 1. Exactly 14 days before (2 weeks warning)
        // 2. Exactly 7 days before (1 week warning)
        // 3. Exactly 3 days before (urgent warning)
        // 4. On the deadline day itself
        const shouldNotify = daysUntilDeadline === 14 ||
            daysUntilDeadline === 7 ||
            daysUntilDeadline === 3 ||
            daysUntilDeadline === 0;

        if (shouldNotify) {
            console.log(`📌 Processing ${d.country} deadline (${daysUntilDeadline} days until)...`);

            let lastDoc = null;
            let jurisdictionProcessed = 0;

            while (true) {
                // Fetch users with this jurisdiction in batches of 500
                let query = admin.firestore()
                    .collection("users")
                    .where("jurisdiction", "==", d.country)
                    .limit(500);

                if (lastDoc) {
                    query = query.startAfter(lastDoc);
                }

                const usersSnap = await query.get();

                if (usersSnap.empty) break;

                let urgencyPrefix = "";
                if (daysUntilDeadline === 0) urgencyPrefix = "⚠️ TODAY: ";
                else if (daysUntilDeadline === 3) urgencyPrefix = "⏰ 3 DAYS: ";
                else if (daysUntilDeadline === 7) urgencyPrefix = "📅 1 WEEK: ";
                else if (daysUntilDeadline === 14) urgencyPrefix = "📌 2 WEEKS: ";

                const batchNotifications: Promise<any>[] = [];

                usersSnap.forEach(doc => {
                    const token = doc.data().fcmToken;
                    if (token) {
                        batchNotifications.push(
                            admin.messaging().send({
                                token: token,
                                notification: {
                                    title: daysUntilDeadline === 0 ? "🚨 Tax Deadline TODAY!" : "Tax Deadline Alert",
                                    body: urgencyPrefix + d.message,
                                },
                                android: {
                                    notification: {
                                        color: "#00FFFF", // Cyan Brand Color
                                        icon: "stock_ticker_update",
                                        priority: daysUntilDeadline <= 3 ? "high" : "default"
                                    }
                                },
                                apns: {
                                    payload: {
                                        aps: {
                                            sound: daysUntilDeadline === 0 ? "default" : undefined
                                        }
                                    }
                                },
                                data: {
                                    type: "tax_alert",
                                    country: d.country,
                                    daysUntil: daysUntilDeadline.toString(),
                                    deadline: `${d.month}/${d.day}`
                                }
                            })
                        );
                    }
                });

                // Send this batch of notifications
                const batchResults = await Promise.allSettled(batchNotifications);
                const batchSuccess = batchResults.filter(r => r.status === "fulfilled").length;
                const batchFail = batchResults.filter(r => r.status === "rejected").length;

                jurisdictionProcessed += usersSnap.docs.length;
                notificationsToSend.push(Promise.resolve(`Batch: ${batchSuccess} sent, ${batchFail} failed`));

                console.log(`   Processed batch of ${usersSnap.docs.length} users for ${d.country}. Total for this deadline: ${jurisdictionProcessed}`);

                // Set the last document for next iteration
                lastDoc = usersSnap.docs[usersSnap.docs.length - 1];
            }
        }
    }

    const results = await Promise.allSettled(notificationsToSend);
    const successful = results.filter(r => r.status === "fulfilled").length;
    const failed = results.filter(r => r.status === "rejected").length;

    console.log(`✅ Tax Deadline Check Complete: ${successful} sent, ${failed} failed`);
});
