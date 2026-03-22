import { Resend } from 'resend';

// Branding Constants
const APP_LOGO_URL = "https://firebasestorage.googleapis.com/v0/b/fyllo-ai.firebasestorage.app/o/unnamed.png?alt=media&token=1b7a811b-0aac-4316-857e-08ba98d7a92b";
const DEV_LOGO_URL = "https://firebasestorage.googleapis.com/v0/b/fyllo-ai.firebasestorage.app/o/599014284_17844482877632596_2199277206328223072_n.jpg?alt=media&token=359e3eb5-a66a-4b73-9b6e-4da508e52732";

const LOGO_HTML = `<img src="${APP_LOGO_URL}" width="80" height="80" style="border-radius: 16px; display: block; margin: 0 auto 20px auto;" alt="Fyllo AI Logo">`;
const FOOTER_HTML = `
<hr>
<div style="text-align: center;">
    <img src="${DEV_LOGO_URL}" width="40" height="40" style="border-radius: 50%; display: block; margin: 10px auto 5px auto;" alt="Fidus Tech Logo">
    <p style="font-size: 12px; color: #666; margin: 0;">from Fidus Tech</p>
</div>`;

export interface EmailData {
    to: string | string[];
    subject: string;
    html: string;
}

// 🔐 Get Resend client - uses RESEND_API_KEY secret from environment
let resendClient: Resend | null = null;

function getResendClient(): Resend {
    if (!resendClient) {
        const apiKey = process.env.RESEND_API_KEY;
        if (!apiKey) {
            throw new Error("RESEND_API_KEY secret not configured");
        }
        resendClient = new Resend(apiKey);
    }
    return resendClient;
}

export class EmailService {
    /**
     * Sends an email using the Resend SDK.
     */
    static async sendEmail(data: EmailData): Promise<void> {
        try {
            const { to, subject, html } = data;
            const resend = getResendClient();
            const response = await resend.emails.send({
                from: 'Fyllo AI <hello@fidusai.tech>',
                to: Array.isArray(to) ? to : [to],
                subject,
                html,
            });

            if (response.error) {
                throw new Error(response.error.message);
            }

            console.log(`📧 Email sent via Resend to: ${to}`);
        } catch (error) {
            console.error("❌ Failed to send email via Resend:", error);
        }
    }

    /**
     * Helper to send subscription confirmation
     */
    static async sendSubscriptionSuccess(email: string, plan: string, credits: number) {
        return this.sendEmail({
            to: email,
            subject: `Welcome to Fyllo AI ${plan.toUpperCase()}!`,
            html: `
        ${LOGO_HTML}
        <h1>Subscription Confirmed</h1>
        <p>Thank you for subscribing to the <strong>${plan}</strong> plan.</p>
        <p>Your account has been credited with <strong>${credits}</strong> AI credits.</p>
        
        <div style="background-color: #f8f9fa; padding: 15px; border-radius: 12px; margin: 20px 0; border: 1px solid #eee;">
            <p style="font-size: 13px; color: #666; margin: 0;">
                🌍 <strong>A Note on Timing:</strong> To keep things consistent for everyone, our credits refresh on a global schedule based on US Central Time. Depending on where you are in the world, you might see your new credits arrive a little earlier or later than your local midnight!
            </p>
        </div>

        <p>Happy Expense planning!</p>
        ${FOOTER_HTML}
      `,
        });
    }

    /**
     * Helper to send credit reset notification
     */
    static async sendCreditResetNotification(email: string, plan: string, credits: number) {
        return this.sendEmail({
            to: email,
            subject: `Your Monthly ${plan.toUpperCase()} Credits are Here!`,
            html: `
        ${LOGO_HTML}
        <h1>Credits Reset Successfully</h1>
        <p>Your monthly credits for the <strong>${plan}</strong> plan have been reset.</p>
        <p>You now have <strong>${credits}</strong> credits available for use.</p>
        <p>Happy Expense planning!</p>
        ${FOOTER_HTML}
      `,
        });
    }

    /**
     * Helper to send subscription expiration notice
     */
    static async sendSubscriptionExpired(email: string) {
        return this.sendEmail({
            to: email,
            subject: "Your Fyllo AI Subscription has Expired",
            html: `
        ${LOGO_HTML}
        <h1>Subscription Expired</h1>
        <p>Your subscription has expired and your account has been moved to the Free plan.</p>
        <p>To continue enjoying premium features, please resubscribe in the app.</p>
        <p>Happy Expense planning!</p>
        ${FOOTER_HTML}
      `,
        });
    }

    /**
     * Helper to send welcome email
     */
    static async sendWelcomeEmail(email: string, name: string) {
        return this.sendEmail({
            to: email,
            subject: "Welcome to Fyllo AI!",
            html: `
        ${LOGO_HTML}
        <h1>Welcome, ${name}!</h1>
        <p>Thank you for joining Fyllo AI, your intelligent expense planning companion.</p>
        <p>We've started you off with your initial credits. You can start scanning receipts and can get insights over your expenses.</p>
        <p>If you have any questions, just reply to this email!</p>
        <hr>
        <p>Follow us on Instagram for updates: <a href="https://www.instagram.com/fidus.tech?igsh=eDN2M3VkMWlicDgx">@fidus.tech</a></p>
        ${FOOTER_HTML}
      `,
        });
    }

    /**
     * Helper to send referral success notification
     */
    static async sendReferralSuccess(email: string, rewardAmount: number, totalReferrals: number) {
        return this.sendEmail({
            to: email,
            subject: "🎉 You earned Referral Credits!",
            html: `
        ${LOGO_HTML}
        <h1>Great News!</h1>
        <p>Someone just signed up using your referral code.</p>
        <p>We've added <strong>${rewardAmount} AI Credits</strong> to your account as a thank you.</p>
        <p>You have now referred <strong>${totalReferrals}</strong> friends to Fyllo AI!</p>
        <p>Keep sharing and keep earning. Happy Expense planning!</p>
        ${FOOTER_HTML}
      `,
        });
    }
}
