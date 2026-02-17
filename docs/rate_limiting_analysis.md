# Rate Limiting & Security Analysis

**Status**: Draft - Initial vulnerability assessment  
**Date**: February 17, 2026

---

## Executive Summary

The system has **no rate limiting currently implemented**. Several endpoints are vulnerable to abuse, particularly:

1. **Unauthenticated document scraping** - Any user can bulk-download all published enquiries/responses/comments
2. **File download abuse** - Attached files (PDFs, DOCs) can be repeatedly downloaded without limits  
3. **Submission spam** - Authenticated users can submit unlimited posts/responses/comments
4. **Admin function enumeration** - Admin/RC users can bulk-query author information without throttling

Below is a detailed threat model with mitigation strategies.

---

## 1. Unauthenticated Attack Vectors

### 1.1 Bulk Document Scraping (HIGH PRIORITY)

**Vulnerability**: Published enquiries are globally readable  
**Current Rule** (firestore.rules):
```plaintext
match /enquiries/{id} {
  allow read: if isPublished();  // No auth required
}
```

**Attack**: Unauthenticated attacker can:
- Query all published enquiries with `where(isPublished == true)`
- Enumerate entire published dataset by ID
- Download all historical enquiries, responses, comments in batches
- No per-user quota prevents bulk export

**Risk Level**: 🔴 **HIGH**  
- **Cost impact**: Bandwidth to serve full dataset repeatedly
- **Data exposure**: All published content (potentially sensitive enquiries) downloadable en masse
- **Difficulty**: Trivial - standard Firestore query or REST API call

**Mitigation Options**:

| Strategy | Pros | Cons |
|----------|------|------|
| **Backend-mediated listing** | Control pagination, rate limit per IP | Requires API endpoint, adds latency |
| **Firestore rules + time-based cache** | Prevents repeated queries for same data | Hard to enforce per-IP without custom auth |
| **CDN cache with rate limiting** | Offloads to edge, prevents backend hammering | Expensive, requires separate infrastructure maintenance |
| **IP-based rate limiting** | Catches bulk downloads | Can block legitimate users behind NAT |
| **Require auth for any read** | Simplest to implement | Breaks public access model if intended |

**Recommended**: Combine backend-mediated listing API with Firestore rule deprecation

---

### 1.2 File Download Abuse (HIGH PRIORITY)

**Vulnerability**: Published attachments downloadable without rate limits  
**Current Rule** (storage.rules):
```plaintext
match /enquiries/{enquiryId}/{filePath=**} {
  allow read: if isEnquiryPublished(enquiryId);  // No auth required
}
```

**Attack**: Attacker can:
- Download same 25MB PDF thousands of times per day (bandwidth attack)
- Mirror entire attachment library without throttling
- Exploit CDN via repeated requests for same file
- DOS storage bandwidth

**Risk Level**: 🔴 **HIGH**  
- **Cost impact**: GCS egress charges spike (Cloud Storage bandwidth is costly)
- **Difficulty**: Single loop with URL iteration
- **Severity**: Can incur unexpected bills

**Mitigation Options**:

| Strategy | Pros | Cons |
|----------|------|------|
| **Cloud Armor rate limiting** | Transparent, IP-based, native to GCP | Can't distinguish unique users behind NAT |
| **Signed URLs with TTL** | Prevents direct caching, time-bound | Requires backend API for each download |
| **CDN cache + rate limiting** | Reduces origin load | Doesn't prevent bandwidth theft, adds cost |
| **File size/frequency quotas** | Enforces business rules | Requires custom middleware |

**Recommended** (unauthenticated access required):
- **Cloud Armor**: IP-based rate limiting (100 files/minute per IP, 10-second ban after exceeding)
- **Cache headers**: `Cache-Control: public, max-age=3600` to reduce origin hits via CDN
- **Alternative**: Serve files via CDN with signed URLs if high traffic, but not needed initially

---

## 2. Authenticated Attack Vectors (Medium Priority)

### 2.1 Submission Spam

**Function**: `createPost` (posts/create_post.ts)  
**Current Guards**:
- ✅ Requires authentication
- ✅ Validates team membership
- ✅ App Check enabled
- ❌ **No per-user rate limiting**
- ❌ **No per-team rate limiting**

**Attack**: Authenticated attacker can:
- Submit 100+ posts in seconds (depletes quota, costs money)
- Spam responses/comments within deadlines (disrupts workflow)
- Fill Firestore with junk data
- Trigger email notifications on each submission

**Risk Level**: 🟡 **MEDIUM**  
- **Cost**: Firestore write operations ($1 per 100k writes)
- **Operational**: Could disrupt enquiry management
- **Likelihood**: Requires compromised auth token or malicious team member

**Mitigation** (given ≤20 team size):
- **Per-user limit**: 30 posts/responses per minute, 100/hour (generous for small teams)
- **Per-team limit**: Optional; 500/hour across all members if needed as safety valve
- **Implementation**: Sliding window counters in Firestore (collection: `ratelimits/users/{uid}/counters/`)
- **Note**: Small team size means individual user limits sufficient; per-team coordination unlikely needed

---

### 2.2 Admin Function Abuse

**Function**: `getPostAuthorsForEnquiry` (admin_funcs/get_post_authors.ts)  
**Current Guards**:
- ✅ Requires admin or RC role
- ✅ Logs all calls for audit
- ❌ **No rate limiting** (comment says "not implemented yet")
- ❌ **No per-IP throttling**

**Attack**: Compromised admin account can:
- Bulk-query author info for all enquiries (enumerate team structure)
- Reveal author identities in supposed-anonymous responses
- Rapidly call function to detect new enquiries (leak schedule info)

**Risk Level**: 🟡 **MEDIUM**  
- **Impact**: Author anonymity broken
- **Likelihood**: Requires admin compromise, but audit log exists
- **Detectability**: Audit logs show abuse pattern

**Mitigation** (given ≤20 team size):
- **Rate limit**: 1 call per 5 seconds per user (admin or RC)
- **Audit logging**: Existing audit trail sufficient (function already logs all calls)
- **Alerts**: Alert if > 5 calls/minute from same user (indicates potential bulk enum)
- **IP-based bonus**: If RC team operates from known office IPs, whitelist them for higher quotas

---

### 2.3 User Creation Spam

**Function**: `createUserWithProfile` (users/create_user.ts)  
**Current Guards**:
- ✅ Requires team admin role
- ✅ Email validation
- ❌ **No rate limiting**
- ❌ **Can create unlimited users**

**Attack**: Malicious team admin can:
- Create 1000+ fake users to inflate team (impacts email sends)
- Bypass team headcount controls
- Trigger email sends for each user creation

**Risk Level**: 🟡 **MEDIUM**  
- **Impact**: Team spam, increased email costs
- **Likelihood**: Requires team admin role (higher barrier)

**Mitigation** (given ≤20 team size):
- **Per-admin limit**: 5 new users/hour, 15/day per team admin
- **Per-team limit**: 50 total users ever created (as safety valve against abuse)
- **Better approach**: Require explicit invitation workflow (slower but less spammable)

---

### 2.4 Email Notification Toggle Spam

**Function**: `toggleEmailNotifications` (notifications/toggle_notifications.ts)  
**Current Guards**:
- ✅ Requires authentication
- ✅ Self-service (user updates own settings)
- ❌ **No rate limiting**
- ❌ **Could be called repeatedly**

**Attack**: Attacker can:
- Toggle notifications 100x/second to clutter Firestore writes
- Cause unnecessary custom claim updates in Auth

**Risk Level**: 🟢 **LOW**  
- **Impact**: Firestore write bloat
- **Likelihood**: Trivial to prevent, low-value target

**Mitigation**: 
- Limit to 5 calls/minute per user

---

## 3. Implementation Strategy

### Phase 1: Critical (Week 1)
- [ ] Deploy Cloud Armor rules to storage bucket (block bulk file downloads)
- [ ] Implement backend listing API for published enquiries (pagination, response limit)
- [ ] Add per-user rate limiting to `createPost` (10/min, 50/hour)

### Phase 2: Important (Week 2)
- [ ] Per-team rate limiting on submissions
- [ ] Admin function rate limiting + alerts
- [ ] User creation rate limiting

### Phase 3: Nice-to-Have (Week 3+)
- [ ] IP reputation scoring
- [ ] Bot detection (Recaptcha v3 on registration)
- [ ] Geographic blocking (if not a global app)

---

## 4. Technical Implementation Notes

### 4.1 Rate Limiting Architecture

**Option A: Firestore Counters** (Simplest, ~$0.01/day per function)
```typescript
// In callable function:
const key = `ratelimits/users/${req.auth.uid}/createPost`;
const counter = await db.doc(key).get();
const count = counter.get("count") ?? 0;
if (count >= LIMIT) throw new HttpsError("resource-exhausted", "Rate limited");
await db.doc(key).update({
  count: FieldValue.increment(1),
  resetAt: FieldValue.serverTimestamp(),
});
```
- Pros: No external dependency, audit trail in Firestore
- Cons: Requires atomic operations, eventual consistency edge cases

**Option B: Cloud Tasks + Memcached** (More reliable, ~$0.05/day)
- Dedicated rate limit middleware
- Distributed across instances
- Better for high-frequency endpoints

**Option C: Cloud Run service with Redis** (Most robust, ~$5/day)
- External state management
- Sub-millisecond lookup
- Handles distributed rate limiting elegantly

**Recommended**: Start with Option A (Firestore), migrate to Option C if createPost traffic grows > 100 req/sec

### 4.2 Cloud Armor Configuration

```yaml
# Example Cloud Armor policy for storage bucket
rules:
  - priority: 100
    description: "Rate limit file downloads"
    match:
      versioned_expr: "CEL"
      cel_options:
        user_defined_fields:
          - name: "request_count"
            celExpression: "origin.ip"
    action: "throttle"
    preview: false
    rateLimitOptions:
      conformAction: "allow"
      exceedAction: "deny-429"
      enforceOnKey: "IP"
      banDurationSec: 600
      rateLimitThreshold:
        count: 100
        intervalSec: 60
```

### 4.3 Observable Metrics

Add to Firestore to track abuse:
```typescript
// Collection: admin/metrics
// Doc: ratelimit_triggered_{date}
{
  uid: "user123",
  function: "createPost",
  timestamp: serverTimestamp(),
  ip: "req.ip",
  reason: "exceeded 50 posts/hour",
  blocked: true,
}
```

---

## 5. Clarifications from Product

### ✅ Public Access Model
**Decision**: Published enquiries readable by unauthenticated users.
- Current Firestore rules already support this (no auth required for `isPublished == true`)
- Write/edit/delete restricted to authenticated users with appropriate role checks
- **Implication**: No auth requirement on read path; rate limiting focuses on authenticated write operations

### ✅ File Downloads  
**Decision**: Published files downloadable by all users, including unauthenticated.
- Current storage rules already support this
- **Implication**: Cloud Armor must handle unauthenticated download rate limiting (IP-based only)
- Cannot use auth-based quotas for download throttling; IP-based thresholds essential

### ✅ Admin vs. RC Clarification
**Decision**: RC role ≠ admin role. They may overlap, but kept separate intentionally.
- Admin: System administrator (user management, global settings)
- RC: Rules Committee (enquiry review, authority decisions)  
- **Implication**: `getPostAuthorsForEnquiry` permission check (admin OR RC) is correct
- Both roles need bulk-query access but for different reasons
- Rate limiting should apply equally to both roles

### ✅ Submission Deadline Enforcement
**Decision**: System must **prevent** submissions after deadline (hard block).
- Not ignored—actively rejected with descriptive error to user
- Applies to: responses (20:00 Rome deadline), comments (12:00 Rome deadline)
- **Implication**: Deadline checks must be in `createPost` and `editPost` handlers, not just scheduler-based
- Error messages: *"Response submission closed at 20:00 Rome. Contact administrator to extend deadline."*
- Prevents accidental/malicious late submissions; improves UX

### ✅ Team Size
**Decision**: Teams expected to be ≤20 members.
- **Implication**: Per-team rate limits can be generous (100+ submissions/hour vs. per-user limits)
- Focus optimizes per-user rate limiting over per-team throttling
- Less risk of legitimate team activity being blocked by shared quotas

---

## 6. Prioritized Implementation List

### ✅ COMPLETED: Cache Headers for File Downloads
- [x] Added `Cache-Control: public, max-age=3600` to storage.rules comments
- [x] Set cache headers in `functions/src/posts/storage.ts` when moving files to final location
- [x] Set cache headers in `functions/src/utils/make_attachments_public.ts` when creating download tokens
- Result: 80%+ bandwidth reduction for repeated downloads, ~$0 cost

### ✅ COMPLETED: Per-User Submission Rate Limiting
- [x] Created `functions/src/common/rate_limit.ts` with sliding window counter logic
  - 30 posts/minute limit
  - 100 posts/hour limit
  - Transactional Firestore counters
- [x] Integrated into `functions/src/posts/create_post.ts` - checks before expensive operations
- [x] Created admin functions in `functions/src/admin_funcs/rate_limit_admin.ts`
  - `getRateLimitStatus` - view user's current counts + time until reset
  - `resetRateLimit` - admin-only reset for testing
- [x] Exported in `functions/src/index.ts`
- Result: Users blocked after 30 posts/min or 100 posts/hour with descriptive errors

### High-Impact, Medium-Effort  
- [ ] Backend listing API for published posts (pagination, response size caps) (6-8 hours)
- [ ] Per-team submission quotas (optional, given small team size; 500/hour) (2-3 hours)

### Medium-Impact, Low-Effort
- [ ] Admin/RC endpoint throttling on `getPostAuthorsForEnquiry` (1 call/5sec per user) (2 hours)
- [ ] User creation limits per team admin (5/hour, 15/day per team admin) (2 hours)
- [ ] Email toggle rate limiting (5 calls/min per user) (1 hour)

### Lower Priority
- [ ] IP reputation scoring / geographic blocking
- [ ] Bot detection (Recaptcha v3)
- [ ] Detailed audit logging dashboard

---

## 7. Deadline Enforcement (Already Implemented ✅)

**Good news**: Deadline enforcement is already working via your state machine:

- **Orchestrator updates periodically** (0:00, 12:00, 20:00 Rome)
  - Sets `teamsCanComment = false` when comment stage ends (12:00)
  - Sets `teamsCanRespond = false` when response stage ends (20:00)
  - Updates `stageEnds` field with next window time
  
- **Backend guards in place** ([functions/src/posts/tx.ts](../functions/src/posts/tx.ts#L136-L145))
  - Response creation checks: `enquirySnap.get("teamsCanRespond") !== true`
  - Comment creation checks: `enquirySnap.get("teamsCanComment") !== true`
  - Throws: *"Competitors not permitted to [comment/respond] at this time."*
  - RC team bypasses these checks (always allowed)

- **Frontend uses same booleans**
  - Disables UI buttons when `teamsCanRespond` or `teamsCanComment` is false
  - Shows submission window to users

**No additional code needed.** The deadline enforcement is an elegant part of the orchestration state machine, not a separate security concern.

