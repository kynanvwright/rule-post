// ──────────────────────────────────────────────────────────────────────────────
// File: src/admin_funcs/test_send_digest.ts
// Purpose: Admin-only function to test deadline reminder emails with sample data
// Usage: Call with { email, includeDeadlines: true } to see a preview
// ──────────────────────────────────────────────────────────────────────────────
import { logger } from "firebase-functions";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { createTransport } from "nodemailer";

import { REGION } from "../common/config";

type TestSendDigestRequest = {
  recipientEmail: string;
  includeDeadlines?: boolean;
  includeActivity?: boolean;
};

/**
 * Admin-only: send a test digest email to verify deadline reminder formatting
 *
 * Usage:
 * const res = await testSendDigest({
 *   recipientEmail: 'your@email.com',
 *   includeDeadlines: true,      // Shows a sample deadline expiring in 6 hours
 *   includeActivity: true         // Shows sample posts/responses
 * });
 */
export const testSendDigest = onCall<TestSendDigestRequest>(
  {
    region: REGION,
    timeoutSeconds: 30,
    secrets: ["GMAIL_USER", "GMAIL_APP_PASSWORD"],
  },
  async (request) => {
    try {
      // Check admin role
      if (!request.auth) {
        throw new HttpsError("unauthenticated", "Not logged in");
      }

      const claimsAsAny = request.auth.token as Record<string, unknown>;
      const isAdmin = claimsAsAny.role === "admin";
      if (!isAdmin) {
        throw new HttpsError(
          "permission-denied",
          "Only admins can send test digests",
        );
      }

      const { recipientEmail } = request.data;
      if (!recipientEmail || typeof recipientEmail !== "string") {
        throw new HttpsError("invalid-argument", "recipientEmail is required");
      }

      const includeDeadlines = request.data.includeDeadlines ?? true;
      const includeActivity = request.data.includeActivity ?? true;

      // Build sample HTML
      let html = `
      <!DOCTYPE html>
      <html>
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif; line-height: 1.5;">
          <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
            <h1>📧 Rule Post – Digest Test Email</h1>
            <p><strong>This is a test email to preview deadline reminders and activity updates.</strong></p>
`;

      if (includeDeadlines) {
        html += `
            <div style="background-color: #fee; border: 4px solid #d32f2f; padding: 16px; margin: 20px 0; border-radius: 4px;">
              <h2 style="color: #d32f2f; margin-top: 0;">⏰ Response Deadline Alert</h2>
              <p><strong>Your team has not yet responded to:</strong></p>
              <ul style="padding-left: 20px;">
                <li>
                  <strong>ENQ-001: Sample Enquiry Title</strong><br>
                  <span style="font-size: 14px; color: #666;">Deadline: 20:00 Rome Time (in ~6 hours)</span>
                </li>
              </ul>
              <p style="margin-bottom: 0; font-size: 12px; color: #d32f2f;">
                <strong>⚠️ Act now to avoid missing this deadline.</strong>
              </p>
            </div>
`;
      }

      if (includeActivity) {
        html += `
            <div style="margin: 20px 0;">
              <h2>📰 New Publications</h2>
              
              <div style="background-color: #f5f5f5; padding: 12px; margin: 12px 0; border-radius: 4px;">
                <h3 style="margin-top: 0;">New Enquiry</h3>
                <p><strong>ENQ-002: Example Enquiry</strong></p>
                <p>This is a sample enquiry to demonstrate the digest email format.</p>
              </div>

              <div style="background-color: #f5f5f5; padding: 12px; margin: 12px 0; border-radius: 4px;">
                <h3 style="margin-top: 0;">New Response</h3>
                <p><strong>Response to ENQ-001</strong> from Challenge Team</p>
                <p>This demonstrates how responses appear in the digest.</p>
              </div>

              <div style="background-color: #f5f5f5; padding: 12px; margin: 12px 0; border-radius: 4px;">
                <h3 style="margin-top: 0;">New Comment</h3>
                <p><strong>Comment on Response to ENQ-001</strong></p>
                <p>This shows the comment format in the digest.</p>
              </div>
            </div>
`;
      }

      html += `
            <hr style="border: none; border-top: 1px solid #ddd; margin: 20px 0;">
            <p style="font-size: 12px; color: #666; margin: 0;">
              This is a test email sent to verify deadline reminder formatting.<br>
              <strong>Note:</strong> In production, this email is only sent if there's actual new activity or an expiring deadline.
            </p>
          </div>
        </body>
      </html>
`;

      // Send with Gmail SMTP
      const transporter = createTransport({
        service: "gmail",
        auth: {
          user: process.env.GMAIL_USER as string,
          pass: process.env.GMAIL_APP_PASSWORD as string,
        },
      });
      const fromAddress = `"Rule Post" <${process.env.GMAIL_USER}>`;
      await transporter.sendMail({
        from: fromAddress,
        to: recipientEmail,
        subject: "Rule Post – Test Digest Email",
        html,
      });

      logger.info("[testSendDigest] Test email sent successfully", {
        recipientEmail,
        includeDeadlines,
        includeActivity,
      });

      return {
        ok: true,
        message: `Test email sent to ${recipientEmail}`,
      };
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unknown error";
      logger.error("[testSendDigest] Failed to send test email", {
        error: message,
      });

      if (error instanceof HttpsError) {
        throw error;
      }

      throw new HttpsError("internal", `Failed to send test email: ${message}`);
    }
  },
);
