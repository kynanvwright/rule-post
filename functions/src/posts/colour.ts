// ──────────────────────────────────────────────────────────────────────────────
// File: src/posts/colour.ts
// Purpose: Colour resolution helpers used inside a transaction
// ──────────────────────────────────────────────────────────────────────────────

import {
  getFirestore,
  type Firestore,
  type Transaction,
} from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

/**
 * Resolve the colour for a post given the author's team.
 * - RC gets the "grey" from app_data/colour_wheel.
 * - Other teams use the provided teamColourMap.
 * - If a team is missing from the map (e.g. newly added), falls back to a
 *   deterministic palette pick so the post can still be created.
 */
export async function resolvePostColour(
  tx: Transaction,
  db: Firestore,
  authorTeam: string,
  teamColourMap: Record<string, string>,
): Promise<string> {
  if (authorTeam === "RC") {
    const wheelRef = db.collection("app_data").doc("colour_wheel");
    const wheelSnap = await tx.get(wheelRef);
    if (!wheelSnap.exists) {
      throw new HttpsError(
        "failed-precondition",
        "Colour wheel not configured.",
      );
    }
    return String(wheelSnap.get("grey"));
  }

  const c = teamColourMap[authorTeam];
  if (c) return c;

  // Fallback: team not yet in the colour map (new team, or map was empty).
  // Pick a deterministic colour from the palette so the post can still be
  // created. The colour will be properly assigned when the enquiry's
  // teamColourMap is next regenerated.
  const wheelRef = db.collection("app_data").doc("colour_wheel");
  const wheelSnap = await tx.get(wheelRef);
  const palette = wheelSnap.exists
    ? (wheelSnap.get("base") as string[] | undefined)
    : undefined;

  if (Array.isArray(palette) && palette.length > 0) {
    // Simple hash to pick a stable index
    let h = 0;
    for (let i = 0; i < authorTeam.length; i++) {
      h = (h * 31 + authorTeam.charCodeAt(i)) >>> 0;
    }
    return palette[h % palette.length];
  }

  throw new HttpsError(
    "failed-precondition",
    "Team colour not found and colour wheel palette is not configured.",
  );
}

// ──────────────────────────────────────────────────────────────────────────────
// Deterministic colour assignment helpers
// ──────────────────────────────────────────────────────────────────────────────

function hash32(s: string): number {
  let h = 0x811c9dc5 >>> 0; // FNV-1a offset basis
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 0x01000193); // 16777619
  }
  return h >>> 0;
}

function seededRand(seedStr: string): () => number {
  // xorshift32 seeded from hash
  let x = hash32(seedStr) || 1;
  return () => {
    x ^= x << 13;
    x ^= x >>> 17;
    x ^= x << 5;
    return (x >>> 0) / 0x100000000;
  };
}

function seededShuffle<T>(arr: T[], seed: string): T[] {
  const r = seededRand(seed);
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(r() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/**
 * Fetches palette + teamIds and assigns unique colours deterministically (seeded by enquiryId).
 * Returns the { teamId -> colour } map.
 *
 * NOTE: This function does not write to Firestore; callers should persist the map
 * in the appropriate private meta document (since it may reveal authorTeam).
 */
export async function assignUniqueColoursForEnquiry(
  enquiryId: string,
): Promise<Record<string, string>> {
  const db = getFirestore();

  // Read palette
  const paletteDoc = await db.doc("app_data/colour_wheel").get();
  const palette = paletteDoc.get("base") as unknown as string[] | undefined;

  // Read team IDs
  const teamIdDoc = await db.doc("app_data/team_names").get();
  const teamIds = teamIdDoc.get("nameList") as unknown as string[] | undefined;

  if (
    !Array.isArray(palette) ||
    palette.length === 0 ||
    palette.some((c) => typeof c !== "string")
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Invalid palette: expected non-empty string[].",
    );
  }
  if (
    !Array.isArray(teamIds) ||
    teamIds.length === 0 ||
    teamIds.some((t) => typeof t !== "string")
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Invalid teamIds: expected non-empty string[].",
    );
  }
  if (teamIds.length > palette.length) {
    throw new HttpsError(
      "failed-precondition",
      `Not enough colours: ${teamIds.length} teams but ${palette.length} colours.`,
    );
  }

  // Deterministic unique assignment
  const shuffled = seededShuffle(palette, enquiryId);
  const map: Record<string, string> = {};
  for (let i = 0; i < teamIds.length; i++) {
    map[teamIds[i]] = shuffled[i];
  }

  return map;
}
