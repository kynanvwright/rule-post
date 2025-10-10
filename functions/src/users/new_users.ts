// src/new_users.ts
import { HttpsError } from "firebase-functions/v2/https";
import { beforeUserCreated } from "firebase-functions/v2/identity";

/** Block all self-registration */
export const blockAllSelfRegistration = beforeUserCreated(() => {
  throw new HttpsError("permission-denied", "Self-registration is disabled.");
});
