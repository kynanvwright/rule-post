import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
// import { defineSecret } from "firebase-functions/params";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { Resend } from "resend";

import { checkUserCreationRateLimit } from "../common/rate_limit";

const auth = getAuth(); // ✅ this returns an Auth instance (not callable)
const db = getFirestore(); // ✅ Firestore instance

type CreateUserPayload = { email: string };

export const createUserWithProfile = onCall(
  { cors: true, enforceAppCheck: true, secrets: ["RESEND_API_KEY"] },
  async (req) => {
    const resend = new Resend(process.env.RESEND_API_KEY as string);
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
      url: "https://rulepost.com", // post-completion redirect
      handleCodeInApp: false, // set true if your app handles OOB codes
      // dynamicLinkDomain: "example.page.link", // if using Firebase Dynamic Links
    });
    console.log("✅ Password reset link created");

    // 6) Send email via Resend
    const recipientName = getNameFromEmail(email);
    await resend.emails.send({
      from: "Rule Post <send@rulepost.com>",
      to: email,
      subject: "Set up your Rule Post account",
      html: `
        <p>Hi ${recipientName},</p>
        <p>You’ve been invited to Rule Post, the website for rule enquiries in the 38th America's Cup. Click the button below to set your password and finish setup.</p>
        <p><a href="${link}" style="display:inline-block;padding:10px 16px;border-radius:6px;text-decoration:none;">Set your password</a></p>
        <p>If you didn’t expect this, you can ignore this email.</p>
      `,
    });
    console.log("✅ Welcome email sent");

    return { uid: userRecord.uid, email: userRecord.email };
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
