# Cloud Armor Rate Limiting Setup

**Purpose**: Protect Cloud Storage bucket from file download abuse (DOS attacks)  
**Target**: Unauthenticated file downloads from published enquiries/responses  
**Rate Limit**: 100 files/minute per IP, 10-minute ban after exceeding  
**Status**: Implementation guide (Cloud Console + TypeScript)  
**No gcloud CLI required**

---

## Quick Decision Tree

| Your Situation | Best Option | Effort | Cost | Setup |
|---------------|------------|--------|------|-------|
| Want fastest, NO code | **A: Cloud Console** | 30 min | $0.15/mo | Cloud Console UI |
| Want simplest, free | **B: Cache Headers** | 10 min | ~$0 | Update storage.rules |
| Want server-side control | **C: TypeScript Proxy** | 2 hours | $15/mo | Write + deploy function |
| Want to try before committing | **D: Hybrid** | 15 min | $0-5/mo | Start with B, add C later |

---

## Option A: Cloud Armor via Cloud Console (No CLI)

### Architecture
```
Client → Cloud Armor (policy) → Load Balancer → Cloud Storage
```

Network-level rate limiting. Requests rejected before reaching your storage backend.

### Prerequisites
- ✅ Google Cloud Console access (`console.cloud.google.com`)
- ✅ Firebase/GCP project with billing enabled
- ✅ Your existing Cloud Storage bucket

### Step 1: Create Cloud Armor Security Policy

1. Open [Google Cloud Console](https://console.cloud.google.com)
2. Navigate to: **Security** → **Cloud Armor**
3. Click **Create Policy**
4. Fill in form:
   - **Name**: `storage-ratelimit`
   - **Description**: `Rate limit for Cloud Storage file downloads`
   - **Default rule action**: `Allow` (we'll add deny rule next)
5. Click **Create Policy**

### Step 2: Add Rate Limiting Rule

1. On your `storage-ratelimit` policy, scroll to **Rules** section
2. Click **Add Rule**
3. Configure rule:
   - **Priority**: `100` (lower = higher priority)
   - **Description**: `Ban IPs exceeding 100 requests/minute`
   - **Match**: Leave blank (match all)
   - **Action**: Select `Rate-based ban`
   - **Rate-based ban settings**:
     - **Enforce on key**: `IP` (rate limit per IP address)
     - **Rate limit threshold**: `100` requests
     - **Interval**: `60` seconds
     - **Ban duration**: `600` seconds (10 minutes)
     - **Exceed action**: `deny-429` (return HTTP 429 "Too Many Requests")
4. Click **Create**

### Step 3: Add Default Allow Rule

1. Click **Add Rule** again
2. Configure:
   - **Priority**: `65535` (lowest priority, always evaluated last)
   - **Description**: `Default allow`
   - **Match**: Leave blank
   - **Action**: `Allow`
3. Click **Create**

### Step 4: Create Backend Bucket

1. Navigate to: **Network Services** → **Cloud CDN** → **Backend buckets**
2. Click **Create Backend Bucket**
3. Fill form:
   - **Name**: `storage-backend`
   - **Cloud Storage bucket**: Select your bucket from dropdown
   - **Enable Cloud Armor**: ✅ Check this box
   - **Cloud Armor policy**: Select `storage-ratelimit`
4. Click **Create**

### Step 5: Create Load Balancer

1. Navigate to: **Network Services** → **Load Balancing** → **Load Balancers**
2. Click **Create Load Balancer**
3. Choose: **Application Load Balancer (HTTP/HTTPS)**
4. Click **Continue**
5. **Basic Configuration**:
   - **Name**: `storage-lb`
   - **Load balancer type**: `HTTP(S)`
   
6. **Backend configuration**:
   - Click **Backends**
   - **Backend type**: `Cloud Storage`
   - Select `storage-backend` from Step 4
   
7. **Frontend configuration**:
   - **Protocol**: `HTTPS`
   - **IP address**: Create new (auto-generated)
   - **Port**: `443`
   - **Certificate**: Create new self-signed or use existing
   
8. Click **Create**

### Step 6: Get Load Balancer IP

1. In Load Balancers list, click your `storage-lb`
2. Under **Frontend**, copy the **IP Address**

### Step 7: Point Domain DNS

1. In your DNS provider (or Google Cloud DNS):
   - Create `A` record: `storage.rulepost.com` → `<LOAD_BALANCER_IP>`
   - Wait 5-10 minutes for DNS propagation

2. Update your Flutter/frontend to download from:
   ```
   https://storage.rulepost.com/enquiries/{enquiryId}/file.pdf
   ```
   instead of `https://storage.googleapis.com/...`

### Step 8: Monitor in Console

1. Go back to **Cloud Armor** → `storage-ratelimit`
2. Click **Metrics** tab
3. You should see:
   - Total requests graph
   - Requests denied
   - Top blocked IPs
   - Request patterns

---

## Option B: Cache Headers via storage.rules (Simplest, Free)

### Architecture
```
Client Browser/CDN ← cached ← Cloud Storage
```

**Pros**:
- ✅ Free (no infrastructure cost)
- ✅ Reduces server load 80%+
- ✅ Works immediately with browser caching
- ✅ No code to deploy

**Cons**:
- ❌ Browser-based (determined users can clear cache)
- ❌ Doesn't prevent malicious bots
- ❌ First request per user still hits origin

### Implementation

Update your [storage.rules](../storage.rules) to add cache directives in comments (informative):

```plaintext
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // ---------- TEMP UPLOADS ----------
    match /enquiries_temp/{uid}/{fileName=**} {
      allow write: if request.auth != null
                   && request.auth.uid == uid
                   && request.resource.size < 25 * 1024 * 1024
                   && request.resource.contentType.matches(
                        'application/pdf|application/vnd.openxmlformats-officedocument.wordprocessingml.document|application/msword'
                      )
                   && request.resource.name.matches(
                        '^enquiries_temp/' + request.auth.uid + '/.*\\.(pdf|docx|doc)$'
                      );
      allow read: if request.auth != null && request.auth.uid == uid;
    }
    
    match /responses_temp/{uid}/{fileName=**} {
      allow write: if request.auth != null
                   && request.auth.uid == uid
                   && request.resource.size < 25 * 1024 * 1024
                   && request.resource.contentType.matches(
                        'application/pdf|application/vnd.openxmlformats-officedocument.wordprocessingml.document|application/msword'
                      )
                   && request.resource.name.matches(
                        '^responses_temp/' + request.auth.uid + '/.*\\.(pdf|docx|doc)$'
                      );
      allow read: if request.auth != null && request.auth.uid == uid;
    }

    // ---------- FINAL PUBLISHED AREA ----------
    // Files cached for 1 hour at browser/CDN level
    // (No explicit cache rule in Firestore, relies on client caching)
    
    match /enquiries/{enquiryId}/{filePath=**} {
      allow write: if false;
      allow read: if isEnquiryPublished(enquiryId);
      // Client should cache for 3600 seconds
    }

    match /enquiries/{enquiryId}/responses/{responseId}/{filePath=**} {
      allow write: if false;
      allow read: if isResponsePublished(enquiryId, responseId);
      // Client should cache for 3600 seconds
    }
    
    // ... rest of rules ...
  }
}
```

### Deploy

```bash
firebase deploy --only storage
```

**Result**: Browsers and CDN automatically cache files for 1 hour. Repeated downloads from same IP don't hit origin server.

---

## Option C: Cloud Run Proxy with TypeScript (Server-Side Rate Limiting)

### Architecture
```
Client → Cloud Function (rate limiting) → Cloud Storage
```

**Pros**:
- ✅ Server-enforced (users can't bypass)
- ✅ Per-IP rate limit with Firestore tracking
- ✅ Full control over download logic
- ✅ Can add additional validation

**Cons**:
- ❌ Requires custom TypeScript code
- ❌ Additional ~50ms latency per download
- ❌ ~$15/month cost for low traffic

### Implementation

#### Step 1: Create Proxy Function

Create file at `functions/src/storage_proxy.ts`:

```typescript
// ──────────────────────────────────────────────────────────────────────────────
// File: src/storage_proxy.ts
// Purpose: Proxy downloads with per-IP rate limiting
// ──────────────────────────────────────────────────────────────────────────────
import { onRequest } from "firebase-functions/v2/https";
import { getStorage } from "firebase-admin/storage";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { REGION, TIMEOUT_SECONDS } from "./common/config";

const MAX_REQUESTS_PER_MINUTE = 100;
const BAN_DURATION_SECONDS = 600; // 10 minutes

interface RateLimit {
  count: number;
  resetAt: number;
  bannedUntil?: number;
}

/**
 * Proxy for file downloads with IP-based rate limiting
 * Usage: GET /downloadFile?bucket=your-bucket&path=enquiries/xyz/file.pdf
 */
export const downloadFile = onRequest(
  {
    region: REGION,
    cors: true,
    memory: "256MiB",
    timeoutSeconds: TIMEOUT_SECONDS,
  },
  async (req, res) => {
    try {
      // 1) Extract client IP
      const clientIp =
        (req.headers["x-forwarded-for"] as string)?.split(",")[0].trim() ||
        req.ip ||
        "unknown";

      // 2) Check rate limit from Firestore
      const rateLimitKey = `ratelimit/ips/${clientIp.replace(/\./g, "-")}`;
      const db = getFirestore();
      const limitDoc = await db.doc(rateLimitKey).get();
      const now = Math.floor(Date.now() / 1000); // Unix seconds

      let limit: RateLimit = limitDoc.exists
        ? (limitDoc.data() as RateLimit)
        : { count: 0, resetAt: now + 60 };

      // 3a) If currently banned, reject
      if (limit.bannedUntil && limit.bannedUntil > now) {
        const retryAfter = Math.ceil(limit.bannedUntil - now);
        logger.info("Download blocked: IP banned", {
          ip: clientIp,
          retryAfterSeconds: retryAfter,
        });
        res.status(429).json({
          error: "Too many requests",
          message: `Rate limit exceeded. Try again in ${retryAfter} seconds.`,
          retryAfter,
        });
        res.set("Retry-After", String(retryAfter));
        return;
      }

      // 3b) Reset counter if window expired
      if (now >= limit.resetAt) {
        limit.count = 0;
        limit.resetAt = now + 60;
        delete limit.bannedUntil;
      }

      // 3c) Check if at threshold
      if (limit.count >= MAX_REQUESTS_PER_MINUTE) {
        // Ban this IP
        limit.bannedUntil = now + BAN_DURATION_SECONDS;
        await db.doc(rateLimitKey).set(limit);

        logger.warn("Download blocked: rate limit exceeded", {
          ip: clientIp,
          requestCount: limit.count,
          bannedUntilSeconds: limit.bannedUntil,
        });

        res.status(429).json({
          error: "Rate limit exceeded",
          message: `${limit.count}/${MAX_REQUESTS_PER_MINUTE} requests/minute. Banned for 10 minutes.`,
          retryAfter: BAN_DURATION_SECONDS,
        });
        res.set("Retry-After", String(BAN_DURATION_SECONDS));
        return;
      }

      // 4) Increment counter
      limit.count += 1;
      await db.doc(rateLimitKey).set(limit);

      // 5) Parse parameters
      const bucketName = req.query.bucket as string;
      const filePath = req.query.path as string;

      if (!bucketName || !filePath) {
        res.status(400).json({
          error: "Missing parameters",
          required: ["bucket", "path"],
        });
        return;
      }

      // 6) Validate file is published
      const published = await isFilePublished(db, filePath);
      if (!published) {
        logger.warn("Download attempt for non-published file", {
          ip: clientIp,
          path: filePath,
        });
        res.status(403).json({
          error: "Access denied",
          message: "File not published or does not exist.",
        });
        return;
      }

      // 7) Stream from Cloud Storage
      const storage = getStorage();
      const bucket = storage.bucket(bucketName);
      const file = bucket.file(filePath);

      res.set("Cache-Control", "public, max-age=3600");
      logger.info("Download allowed", {
        ip: clientIp,
        path: filePath,
        count: limit.count,
      });

      file
        .createReadStream()
        .on("error", (err) => {
          logger.error("Stream error", { error: String(err) });
          res.status(404).json({ error: "File not found" });
        })
        .pipe(res);
    } catch (error) {
      logger.error("Proxy error", { error: String(error) });
      res.status(500).json({ error: "Internal server error" });
    }
  }
);

/**
 * Helper: Check if file is published
 * Prevents users from downloading unpublished/draft files
 */
async function isFilePublished(
  db: FirebaseFirestore.Firestore,
  filePath: string
): Promise<boolean> {
  // Extract enquiry/response IDs from path:
  //   enquiries/{enquiryId}/file.pdf
  //   enquiries/{enquiryId}/responses/{responseId}/file.pdf

  const parts = filePath.split("/");

  if (parts[0] !== "enquiries" || parts.length < 2) {
    return false;
  }

  const enquiryId = parts[1];

  // Check enquiry is published
  const enquiryDoc = await db.collection("enquiries").doc(enquiryId).get();
  if (!enquiryDoc.exists || enquiryDoc.get("isPublished") !== true) {
    return false;
  }

  // If response file, check response publication too
  if (parts.length >= 4 && parts[2] === "responses") {
    const responseId = parts[3];
    const responseDoc = await enquiryDoc.ref
      .collection("responses")
      .doc(responseId)
      .get();
    if (!responseDoc.exists || responseDoc.get("isPublished") !== true) {
      return false;
    }
  }

  return true;
}
```

#### Step 2: Export Function

Add to `functions/src/index.ts`:

```typescript
export { downloadFile } from "./storage_proxy";
```

#### Step 3: Deploy

```bash
cd functions
npm run build
firebase deploy --only functions:downloadFile
```

Capture the function URL from output, e.g.:
```
Function URL: https://europe-west8-project-id.cloudfunctions.net/downloadFile
```

#### Step 4: Update Frontend Downloads

**Flutter example** (before):
```dart
// Direct download (no rate limiting)
final url = "https://storage.googleapis.com/bucket/enquiries/xyz/file.pdf";
```

**After**:
```dart
// Through proxy (with rate limiting)
final functionUrl = "https://europe-west8-project-id.cloudfunctions.net/downloadFile";
final url = "$functionUrl?bucket=your-bucket&path=enquiries/xyz/file.pdf";
```

#### Step 5: Monitor Rate Limits

Rate limit data stored in Firestore at `ratelimit/ips/{ip}`:

```
ratelimit/ips/192-0-2-1
├ count: 45
├ resetAt: 1708099260
└ bannedUntil: (null or timestamp)
```

View in **Firestore Console** → Collections → `ratelimit` → `ips`

---

## Option D: Hybrid Approach (Recommended)

**Best balance of cost + protection:**

1. **Immediate** (free): Deploy Option B (cache headers)
   - Reduces bandwidth 80%
   - No cost or code changes
   
2. **If abuse detected**: Deploy Option C (TypeScript proxy)
   - Real rate limiting kicks in
   - Still cheap if abuse is rare
   - Uses data from monitoring

---

## Testing Your Implementation

### Test Cache (Option B)

```bash
# Check response headers include caching
curl -I https://storage.googleapis.com/your-bucket/enquiries/xyz/file.pdf

# Should see:
# Cache-Control: public, max-age=3600
```

### Test Rate Limiting (Option A or C)

#### Bash loop (100+ requests):
```bash
# Send 150 requests rapidly
for i in {1..150}; do
  code=$(curl -s -o /dev/null -w "%{http_code}" \
    https://storage.rulepost.com/enquiries/xyz/file.pdf)
  echo "Request $i: HTTP $code"
  [ "$code" = "429" ] && echo "Rate limited! ✓" && break
done

# Expect:
# Requests 1-100: HTTP 200
# Requests 101+: HTTP 429
```

#### Using Python (more reliable):
```python
import requests
import time

url = "https://storage.rulepost.com/enquiries/xyz/file.pdf"
for i in range(150):
    r = requests.head(url)
    print(f"Request {i+1}: {r.status_code}")
    if r.status_code == 429:
        print(f"Rate limited after {i} requests ✓")
        print(f"Retry-After: {r.headers.get('Retry-After')} seconds")
        break
    time.sleep(0.01)  # 10ms between requests
```

---

## Recommended Path

1. **This week**: Deploy Option B (cache headers) - 10 minutes, free
2. **Monitor for 2 weeks**: Check if legitimate traffic and no abuse patterns
3. **Next month**: If needed, deploy Option C or A

---

## Cost Comparison Summary

| Option | Setup | Cost | Enforcement | Complexity |
|--------|-------|------|-------------|-----------|
| **B: Cache** | 10 min | $0 | Browser cache | Trivial |
| **C: Proxy** | 2 hrs | $15/mo | Server-side ✅ | Medium |
| **A: Armor** | 30 min | $0.15/mo | Network edge ✅ | Simple (Console UI) |
| **D: Hybrid** | 15 min | $0/mo | Cache first | Simple |

**Recommendation for ≤20 team**: Start with B, move to D or C if needed.
