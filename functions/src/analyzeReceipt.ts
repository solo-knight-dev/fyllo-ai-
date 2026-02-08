
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { defineSecret } from "firebase-functions/params";
import { GoogleGenerativeAI } from "@google/generative-ai";
import * as admin from "firebase-admin";

// 🔐 Secure API Key from Firebase Secrets
const geminiApiKey = defineSecret("GEMINI_API_KEY");

export const analyzeReceipt = onCall(
    { secrets: [geminiApiKey] },
    async (request) => {
        // Access secret at runtime
        const genAI = new GoogleGenerativeAI(geminiApiKey.value());

        // 1. Auth Check
        if (!request.auth) {
            throw new HttpsError("unauthenticated", "User must be logged in.");
        }

        const uid = request.auth.uid;
        const userRef = admin.firestore().collection("users").doc(uid);

        // 2. CREDIT CHECK (Transaction for safety)
        try {
            await admin.firestore().runTransaction(async (t) => {
                const doc = await t.get(userRef);
                const data = doc.data();
                const credits = data?.AiCredits || 0;

                if (credits <= 0) {
                    throw new HttpsError("resource-exhausted", "Insufficient AI Credits. Please upgrade.");
                }
            });
        } catch (e: any) {
            if (e.code === 'resource-exhausted') throw e;
            throw e;
        }

        try {
            // 3. Validate Input
            const { rawText } = request.data;
            if (!rawText || rawText.length < 5) {
                throw new HttpsError("invalid-argument", "OCR failed or empty text.");
            }

            console.log(`Processing Receipt for User: ${uid}`);

            // 4. User Context
            const userDoc = await userRef.get();
            const userData = userDoc.data();
            const jurisdiction = userData?.jurisdiction || "USA";
            const taxBody = userData?.taxBody || "IRS";
            const currentYear = new Date().getFullYear();
            const userPlan = userData?.plan || "free";
            const workType = userData?.workType; // EMPLOYED, SELF_EMPLOYED, BUSINESS, or undefined

            // 4b. Build occupation-specific context (Dynamic & Country-Aware)
            let occupationContext = "";

            if (workType) {
                const countryContext = `${jurisdiction} (${taxBody})`;

                // Dynamic Prompt Injection based on Work Type + Country
                if (workType === "EMPLOYED") {
                    occupationContext = `
                USER PROFILE: Salaried Employee in ${countryContext}
                INSTRUCTION: Identify deductions relevant to employees in ${jurisdiction}. 
                Examples (adapt to local ${taxBody} rules): Unreimbursed professional expenses, union dues, work-related training, or home office (if applicable locally).
                AVOID: Assuming business deductions unless explicitly allowed for employees under ${taxBody} rules.`;
                } else if (workType === "SELF_EMPLOYED") {
                    occupationContext = `
                USER PROFILE: Self-Employed / Freelancer in ${countryContext}
                INSTRUCTION: Apply ${taxBody} rules for sole proprietorships/freelancers. 
                FOCUS: Business expenses, home office (use local calculation methods), vehicle/mileage, and self-employment tax credits.
                TERMINOLOGY: Use the correct local tax forms (e.g., Schedule C for USA, T2125 for Canada, Self Assessment for UK, etc.).`;
                } else if (workType === "BUSINESS") {
                    occupationContext = `
                USER PROFILE: Business Owner (Company/LLC) in ${countryContext}
                INSTRUCTION: Apply corporate tax principles for ${taxBody}.
                FOCUS: Operating expenses, asset depreciation/capital allowances (use local rules like Section 179 for US or Capital Allowances for UK), payroll, and entity-level deductions.
                COMPLIANCE: Cite specific matching rules for ${jurisdiction}.`;
                }
            }

            // 5. TIERED PROMPTS - Different quality based on subscription
            let prompt = "";

            if (userPlan === "elite") {
                // ELITE: Comprehensive analysis with strategic guidance
                prompt = `
            You are an Elite Tax Strategist and Master CPA for the ${jurisdiction} (${taxBody}).
            Your mission is to maximize legal deductions while ensuring 100% compliance and providing strategic tax guidance.
            Current Tax Year: ${currentYear}.
            ${occupationContext}

            ELITE ANALYSIS REQUIREMENTS:
            Analyze this receipt text and provide comprehensive tax intelligence with strategic recommendations.
            
            Receipt Text:
            """
            ${rawText}
            """
            
            Return STRICT JSON only. Do not wrap in markdown or code blocks.

            JSON STRUCTURE (Required):
            {
              "amount": number,
              "merchant": string,
              "category": string,
              "date": string,
              "summary": string,
              "auditorExplanation": string,
              "taxImpact": string,
              "deductionType": string,
              "strategicGuidance": string,
              "optimizationTips": string,
              "riskLevel": string
            }

            ELITE-SPECIFIC FIELDS:
            - "strategicGuidance": Provide 2-3 strategic recommendations for maximizing this deduction or related tax benefits
            - "optimizationTips": Suggest specific actions to optimize tax position (e.g., "Consider bundling similar expenses", "Document business purpose clearly")
            - "riskLevel": Assess audit risk as "Low", "Medium", or "High" with brief justification
            `;
            } else if (userPlan === "pro") {
                // PRO: Detailed analysis with tax impact
                prompt = `
            You are a Professional Tax Auditor and CPA for the ${jurisdiction} (${taxBody}).
            Provide detailed tax analysis with clear deduction guidance.
            Current Tax Year: ${currentYear}.
            ${occupationContext}

            PRO ANALYSIS REQUIREMENTS:
            Analyze this receipt and provide detailed tax insights.
            
            Receipt Text:
            """
            ${rawText}
            """
            
            Return STRICT JSON only. Do not wrap in markdown or code blocks.

            JSON STRUCTURE (Required):
            {
              "amount": number,
              "merchant": string,
              "category": string,
              "date": string,
              "summary": string,
              "auditorExplanation": string,
              "taxImpact": string,
              "deductionType": string,
              "complianceNotes": string
            }

            PRO-SPECIFIC FIELDS:
            - "auditorExplanation": Detailed reasoning citing specific ${taxBody} rules and regulations
            - "taxImpact": Precise deduction percentage with limitations (e.g., "100% Deductible", "50% Meal Limit per IRC Section 274(n)")
            - "deductionType": Specific tax form and line item (e.g., "Schedule C - Line 24b: Travel")
            - "complianceNotes": Any documentation requirements or compliance considerations
            `;
            } else {
                // FREE: Basic extraction (current prompt)
                prompt = `
            You are a Tax Assistant for the ${jurisdiction} (${taxBody}).
            Analyze using available tax laws for the ${currentYear} tax year.
            ${occupationContext}
            DISCLAIMER: You are an AI Assistant, not a lawyer.
        
            Analyze this receipt text and extract JSON ONLY. No markdown.
            
            Receipt Text:
            """
            ${rawText}
            """
            
            Return JSON with these keys:
            - "amount": number (float)
            - "merchant": string (business name)
            - "category": string (e.g. Travel, Meals, Office, Software)
            - "date": string (ISO 8601 YYYY-MM-DD)
            - "summary": string (brief description)
            - "auditorExplanation": string (Why is this deductible? Cite ${taxBody} rules.)
            - "taxImpact": string (e.g. "100% Deductible", "50% Meal Limit")
            - "deductionType": string (Specific tax line item)
            `;
            }

            // 6. Call Gemini 2.5 Flash Lite (The Requested Model)
            // No fallback, as requested we are going "All In" on 2.5 Lite.
            const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash-lite" });

            const result = await model.generateContent(prompt);
            let text = (await result.response).text();

            console.log("Gemini Raw Response:", text);

            // Clean Markdown (just in case the AI adds it despite instructions)
            text = text.replace(/```json/g, "").replace(/```/g, "").trim();
            const resultJson = JSON.parse(text);

            // 7. VERIFY RECEIPT DATA BEFORE DEDUCTION
            // We only charge if we found an amount and a merchant
            const hasAmount = resultJson.amount && resultJson.amount > 0;
            const hasMerchant = resultJson.merchant &&
                !resultJson.merchant.toLowerCase().includes("unknown") &&
                !resultJson.merchant.toLowerCase().includes("none");

            if (!hasAmount || !hasMerchant) {
                console.log("⚠️ Gemini analyzed text but found no valid receipt data. Skipping credit deduction.");
                return {
                    ...resultJson,
                    error: "no_receipt_found",
                    message: "AI could not identify a clear receipt in this image."
                };
            }

            // 8. DEDUCT CREDIT (Only on Real Success)
            await userRef.update({
                AiCredits: admin.firestore.FieldValue.increment(-1),
                AiScanCount: admin.firestore.FieldValue.increment(1)
            });

            console.log(`✅ Valid Receipt Analyzed: ${resultJson.merchant} - ${resultJson.amount}. Credit deducted for ${uid}`);
            return resultJson;

        } catch (e: any) {
            console.error("Gemini Critical Failure:", e);
            throw new HttpsError("internal", `AI Analysis Failed: ${e.message || e}`);
        }
    });
