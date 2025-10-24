// ──────────────────────────────────────────────────────────────────────────────
// File: src/common/db.ts
// Purpose: instantiate db in one place
// ──────────────────────────────────────────────────────────────────────────────
import { getFirestore } from "firebase-admin/firestore";

export const db = getFirestore();
