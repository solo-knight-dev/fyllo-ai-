import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

/// Fyllo AI Brand Colors
class FylloColors {
  // New Brand Colors
  static const defaultCyan = Color(0xFF00D1FF);
  static const secondaryBlue = Color(0xFF00A3FF);
  
  // Supporting Colors
  static const obsidian = Color(0xFF0D0D0D);
  static const darkGray = Color(0xFF1A1A1A);
  static const mediumGray = Color(0xFF2A2A2A);
  
  // Status Colors
  static const success = Color(0xFF00D1FF);
  static const error = Color(0xFFFF4444);
  static const warning = Color(0xFFFFAA00);
  static const info = Color(0xFF00D1FF);
}

/// App Branding
class FylloApp {
  static const appName = 'Fyllo AI';
  static const tagline = 'Smart AI powered finance tracker';
  static const description = 'AI-powered smart finance tracker with intelligent insights';
  
  // Old tagline for reference: 'THE AUDIT-PROOF ERA'
}

/// Subscription Plans
class FylloPlans {
  static const free = 'free';
  static const pro = 'pro';
  static const elite = 'elite';
  
  // RevenueCat Product IDs (MUST match exactly with Google Play Console)
  static const proMonthlyProductId = 'pro_monthly:monthly';
  static const eliteMonthlyProductId = 'elite_monthly:monthly';
  
  // RevenueCat Entitlement IDs (MUST match exactly with RevenueCat Dashboard)
  static const proEntitlement = 'Pro';
  static const eliteEntitlement = 'Elite';
}

/// Feature Access
class FylloFeatures {
  // Free Plan
  static const freeExpenseScans = 10;
  static const freeAiInsights = true;
  
  // Pro Plan
  static const proExpenseScans = 100;
  static const proPdfExport = true;
  static const proAdvancedInsights = true;
  
  // Elite Plan
  static const eliteExpenseScans = 200;
  static const elitePdfExport = true;
  static const eliteAdvancedInsights = true;
  static const elitePrioritySupport = true;
  static const eliteCustomReports = true;
}

/// Terms and Privacy
class FylloLegal {
  static const termsOfService = '''
Fyllo AI - Terms of Service

1. Service Description
Fyllo AI is an AI-powered smart finance tracker that helps you manage expenses and gain financial insights.

2. User Responsibilities
- Provide accurate financial information
- Maintain account security
- Use the service in compliance with applicable laws

3. Subscription Terms
- Subscriptions auto-renew unless cancelled
- Refunds subject to platform policies (Google Play/App Store)
- Features may vary by subscription tier

4. Data Usage
- Your financial data is processed to provide AI insights
- We use industry-standard encryption
- Data is stored securely in Firebase

5. Limitation of Liability
Fyllo AI provides financial insights but is not a substitute for professional financial advice.

For full terms, visit: https://fyllo.ai/terms
''';

  static const privacyPolicy = '''
Fyllo AI - Privacy Policy

We respect your privacy and are committed to protecting your personal data.

1. Data Collection
- Account information (email, name)
- Financial transaction data (expenses, receipts)
- Usage analytics

2. Data Usage
- Provide AI-powered financial insights
- Improve service quality
- Send important notifications

3. Data Storage
- Stored securely in Firebase
- Encrypted in transit and at rest
- Retained as long as your account is active

4. Data Sharing
- We do not sell your data
- Third-party services (Firebase, RevenueCat) used for functionality
- Compliance with legal requirements when necessary

5. Your Rights
- Access your data
- Request data deletion
- Opt-out of marketing communications

For full policy, visit: https://fyllo.ai/privacy
''';
}