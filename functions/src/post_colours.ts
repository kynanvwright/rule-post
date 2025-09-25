import { getFirestore } from "firebase-admin/firestore";

function hash32(s: string): number {
  let h = 2166136261 >>> 0;
  for (let i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function seededRand(seedStr: string): () => number {
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
 * Fetches palette + teamIds from enquiries/{enquiryId}, assigns unique colours
 * deterministically (seeded by enquiryId), writes teamColourMap back to the doc,
 * and returns the map.
 */
export async function assignUniqueColoursForEnquiry(
  enquiryId: string,
): Promise<Record<string, string>> {
  // ---- Read lists (adjust field names if needed) ----
  const db = getFirestore();
  const paletteDoc = await db.doc("app_data/colour_wheel").get();
  const palette = (paletteDoc.get("base") as string[]) ?? [];
  const teamIdDoc = await db.doc("app_data/team_names").get();
  const teamIds = (teamIdDoc.get("nameList") as string[]) ?? [];

  if (
    !Array.isArray(palette) ||
    palette.length === 0 ||
    palette.some((c) => typeof c !== "string")
  ) {
    throw new Error("Invalid palette: expected string[]");
  }
  if (
    !Array.isArray(teamIds) ||
    teamIds.length === 0 ||
    teamIds.some((t) => typeof t !== "string")
  ) {
    throw new Error("Invalid teamIds: expected string[]");
  }

  if (teamIds.length > palette.length) {
    throw new Error(
      `Not enough colours: ${teamIds.length} teams but ${palette.length} colours`,
    );
  }

  // ---- Deterministic unique assignment ----
  const shuffled = seededShuffle(palette, enquiryId);
  const map: Record<string, string> = {};
  for (let i = 0; i < teamIds.length; i++) {
    map[teamIds[i]] = shuffled[i];
  }

  return map;
}
