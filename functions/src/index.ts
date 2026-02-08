import * as admin from "firebase-admin";

admin.initializeApp();

// export all functions
export * from "./createUserProfile";
export * from "./revenuecatWebhook";
export * from "./checkTaxDeadlines";
export * from "./analyzeReceipt";
export * from "./resetCredits";
