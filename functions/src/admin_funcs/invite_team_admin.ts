// ──────────────────────────────────────────────────────────────────────────────
// File: src/admin_funcs/invite_team_admin.ts
// Purpose: Allows the super admin (role=admin) to create a new team admin
//          for a specified team. Creates Auth user, Firestore profile, and
//          sends a welcome email with password reset link.
// ──────────────────────────────────────────────────────────────────────────────
import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { createTransport } from "nodemailer";

const auth = getAuth();
const db = getFirestore();

type InviteTeamAdminPayload = {
  email: string;
  team: string;
};

export const inviteTeamAdmin = onCall(
  {
    cors: true,
    enforceAppCheck: true,
    secrets: ["GMAIL_USER", "GMAIL_APP_PASSWORD"],
  },
  async (req) => {
    // 1) Auth: caller must be the super admin (role=admin)
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "You must be signed in.");

    const callerRole = req.auth?.token.role;
    if (callerRole !== "admin") {
      throw new HttpsError(
        "permission-denied",
        "Only the site admin can invite team admins.",
      );
    }

    // 2) Validate payload
    const { email, team } = req.data as InviteTeamAdminPayload;
    if (!email || typeof email !== "string" || !email.includes("@")) {
      throw new HttpsError("invalid-argument", "Missing or invalid email.");
    }
    if (!team || typeof team !== "string" || team.trim().length === 0) {
      throw new HttpsError("invalid-argument", "Missing or invalid team.");
    }

    const trimmedTeam = team.trim().toUpperCase();
    const trimmedEmail = email.trim().toLowerCase();

    // 3) Create the Auth user
    let userRecord;
    try {
      userRecord = await auth.createUser({ email: trimmedEmail });
      console.log("✅ New team admin user created:", userRecord.uid);
    } catch (e: unknown) {
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

      if (code && map[code]) throw map[code];

      console.error("❌ Auth error:", e);
      throw new HttpsError("internal", "Failed to create auth user.");
    }

    // 4) Create Firestore profile doc with team + teamAdmin
    try {
      await db
        .collection("user_data")
        .doc(userRecord.uid)
        .set({
          email: userRecord.email ?? trimmedEmail,
          role: "user",
          team: trimmedTeam,
          teamAdmin: true,
          emailNotificationsOn: false,
          emailNotificationsScope: "all",
          createdAt: FieldValue.serverTimestamp(),
        });
      console.log("✅ Firestore entry created for team admin:", userRecord.uid);
    } catch (e) {
      console.error("❌ Firestore error:", e);

      // Rollback: remove orphaned Auth user
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

    // 5) Generate password reset link
    const transporter = createTransport({
      service: "gmail",
      auth: {
        user: process.env.GMAIL_USER as string,
        pass: process.env.GMAIL_APP_PASSWORD as string,
      },
    });

    const link = await auth.generatePasswordResetLink(trimmedEmail, {
      url: "https://rulepost.acofficials.org",
      handleCodeInApp: false,
    });
    console.log("✅ Password reset link created");

    // 6) Send welcome email
    const recipientName = getNameFromEmail(trimmedEmail);
    let emailSent = true;
    try {
      await transporter.sendMail({
        from: `"Rule Post" <${process.env.GMAIL_USER}>`,
        to: trimmedEmail,
        subject: "You've been invited as a Team Admin on Rule Post",
        html: `<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
<body style="margin:0;padding:0;">
  <p>Hi ${recipientName},</p>
  <p>You've been invited as a <strong>Team Admin</strong> for team <strong>${trimmedTeam}</strong> on Rule Post, the website for rule enquiries in the 38th America's Cup.</p>
  <p>As team admin you can add and remove members for your team.</p>
  <p>Click the button below to set your password and get started:</p>
  <p><a href="${link}" style="display:inline-block;padding:10px 16px;border-radius:6px;text-decoration:none;">Set your password</a></p>
  <p>If you didn't expect this, you can ignore this email.</p>
</body>
</html>`,
      });
      console.log("✅ Welcome email sent to team admin");
    } catch (emailErr) {
      // User was already created — don't throw. Return success with a warning
      // so the site admin knows to use "Send Password Reset" to resend.
      console.error(
        "❌ Failed to send welcome email (team admin was created):",
        emailErr,
      );
      emailSent = false;
    }

    return {
      uid: userRecord.uid,
      email: userRecord.email,
      team: trimmedTeam,
      emailSent,
    };
  },
);

function getNameFromEmail(email: string): string {
  const localPart = email.split("@")[0];
  const dotParts = localPart.split(".");

  if (dotParts.length > 1) {
    return dotParts
      .map((part) => part.charAt(0).toUpperCase() + part.slice(1).toLowerCase())
      .join(" ");
  }

  return localPart.charAt(0).toUpperCase() + localPart.slice(1).toLowerCase();
}
