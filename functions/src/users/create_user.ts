import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { createTransport } from "nodemailer";

import { checkUserCreationRateLimit } from "../common/rate_limit";

const auth = getAuth(); // ✅ this returns an Auth instance (not callable)
const db = getFirestore(); // ✅ Firestore instance

type CreateUserPayload = { email: string };

export const createUserWithProfile = onCall(
  {
    cors: true,
    enforceAppCheck: true,
    secrets: ["GMAIL_USER", "GMAIL_APP_PASSWORD"],
  },
  async (req) => {
    const transporter = createTransport({
      service: "gmail",
      auth: {
        user: process.env.GMAIL_USER as string,
        pass: process.env.GMAIL_APP_PASSWORD as string,
      },
    });
    // 1) Auth + role
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "You must be signed in.");

    const isTeamAdmin = req.auth?.token.teamAdmin;
    if (!isTeamAdmin) {
      throw new HttpsError("permission-denied", "Team admin only.");
    }

    const { email } = req.data as CreateUserPayload;
    if (!email) {
      throw new HttpsError("invalid-argument", "Missing email");
    }

    // 2) Rate limit: Check per-admin and per-team user creation limits
    const teamName = req.auth?.token.team as string;
    await checkUserCreationRateLimit(uid, teamName);

    // 3) Create the Auth user
    let userRecord;
    try {
      userRecord = await auth.createUser({ email });
      console.log("✅ New user created:", userRecord.uid);
    } catch (e: unknown) {
      // Normalise error shape (covers firebase-admin's errorInfo.code and plain code)
      const err = e as { code?: string; errorInfo?: { code?: string } } | null;
      const code = err?.errorInfo?.code ?? err?.code;

      const map: Record<string, HttpsError> = {
        "auth/email-already-exists": new HttpsError(
          "already-exists",
          "Email already in use.",
        ),
        "auth/invalid-email": new HttpsError(
          "invalid-argument",
          "Invalid email format.",
        ),
      };

      if (code && map[code]) {
        throw map[code];
      }

      console.error("❌ Auth error:", e);
      throw new HttpsError("internal", "Failed to create auth user.");
    }

    // 4) Create Firestore profile doc
    try {
      await db
        .collection("user_data")
        .doc(userRecord.uid)
        .set({
          email: userRecord.email ?? email,
          role: "user",
          team: req.auth?.token.team,
          emailNotificationsOn: false,
          emailNotificationsScope: "all",
          createdAt: FieldValue.serverTimestamp(),
        });
      console.log("✅ Firestore entry created for:", userRecord.uid);
    } catch (e) {
      console.error("❌ Firestore error:", e);

      // Attempt rollback so you don't keep an orphaned Auth user
      try {
        await auth.deleteUser(userRecord.uid);
        console.log(
          "🧹 Rolled back auth user after Firestore failure:",
          userRecord.uid,
        );
      } catch (cleanupErr) {
        console.error("⚠️ Failed to clean up orphaned user:", cleanupErr);
      }

      throw new HttpsError(
        "internal",
        "User created, but failed to create profile document.",
      );
    }

    // 5) Generate password reset link (lets them set their own password)
    const link = await auth.generatePasswordResetLink(email, {
      url: "https://rulepost.acofficials.org",
      handleCodeInApp: false,
    });
    console.log("✅ Password reset link created");

    // 6) Send email via Gmail SMTP
    const recipientName = getNameFromEmail(email);
    let emailSent = true;
    try {
      await transporter.sendMail({
        from: `"Rule Post" <${process.env.GMAIL_USER}>`,
        to: email,
        subject: "Set up your Rule Post account",
        html: `<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;padding:0;">
  <p>Hi ${recipientName},</p>
  <p>You've been invited to Rule Post, the website for rule enquiries in the 38th America's Cup. Click the button below to set your password and finish setup.</p>
  <p><a href="${link}" style="display:inline-block;padding:10px 16px;border-radius:6px;text-decoration:none;">Set your password</a></p>
  <p>If you didn't expect this, you can ignore this email.</p>
</body>
</html>`,
      });
      console.log("✅ Welcome email sent");
    } catch (emailErr) {
      // User was already created — don't throw. Return success with a warning
      // so the admin knows to use "Send Password Reset" to resend.
      console.error(
        "❌ Failed to send welcome email (user was created):",
        emailErr,
      );
      emailSent = false;
    }

    return { uid: userRecord.uid, email: userRecord.email, emailSent };
  },
);

function getNameFromEmail(email: string): string {
  // Get everything before the @
  const localPart = email.split("@")[0];

  // Try splitting by "."
  const dotParts = localPart.split(".");

  if (dotParts.length > 1) {
    // Capitalize each part
    return dotParts
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase())
      .join(" ");
  }

  // Fallback: just capitalize the localPart
  return localPart.charAt(0).toUpperCase() + localPart.slice(1).toLowerCase();
}
