# Scheduled Functions Orchestration Analysis

## ✅ IMPLEMENTED: Phase 1 — Orchestrator Wrapper

The race condition risks have been mitigated by implementing an orchestration layer that runs scheduled functions **sequentially** rather than relying on time offsets.

### Implementation Summary

**Files Created:**
- `functions/src/scheduled_funcs/orchestrator.ts` — Three orchestrator functions that call publishers in sequence

**Files Modified:**
- `functions/src/scheduled_funcs/enquiry_publisher.ts` — Extracted logic into `doEnquiryPublish()` helper
- `functions/src/scheduled_funcs/comment_publisher.ts` — Extracted logic into `doCommentPublish()` helper
- `functions/src/scheduled_funcs/committee_response_publisher.ts` — Extracted logic into `doCommitteeResponsePublish()` helper
- `functions/src/scheduled_funcs/comment_publication_schedule.ts` — Extracted logic into `doCommentPublicationScheduleRefresh()` helper
- `functions/src/scheduled_funcs/team_response_publisher.ts` — Extracted logic into `doTeamResponsePublish()` helper
- `functions/src/notifications/send_publish_digest.ts` — Extracted logic into `doSendPublishDigest()` helper
- `functions/src/index.ts` — Now exports only orchestrator functions, not individual publishers

### What the Orchestrator Does

**orchestrate0000** (0:00 Europe/Rome):
1. Publish enquiries → waits for completion
2. Publish comments → waits for completion
3. Publish RC responses → waits for completion
4. Update comment publication schedule → waits for completion
5. Send digest emails → waits for completion

**orchestrate1200** (12:00 Europe/Rome):
1. Publish enquiries
2. Publish comments
3. Send digest emails

**orchestrate2000** (20:00 Europe/Rome):
1. Publish team (competitor) responses
2. Send digest emails

### Benefits

✅ **No concurrent writes on same document** — Functions run sequentially, not parallel
✅ **Digest always complete** — Email is only sent after all publishes finish
✅ **No time offsets** — No 0:05 delay, no +1 minute skew, no race windows
✅ **Clearer logs** — Each step logs completion with timestamp
✅ **Testable** — Individual helpers can still be unit-tested independently
✅ **No submission locks** — Users can submit responses right up to deadline (20:00), no blocking before deadline

### Schedule Timeline (Europe/Rome timezone)

#### **0:00 slot** (3 concurrent functions + 2 dependent)
- `enquiryPublisher` (0:00) – publishes unpublished enquiries
- `commentPublisher` (0:00) – publishes pending comments  
- `committeeResponsePublisher` (0:00) – publishes RC responses when stage closed
- `commentPublicationScheduleRefresher` (0:01) – updates next pub time (depends on 0:00 ops)
- `sendPublishDigest` (0:05) – sends emails (depends on 0:00 ops finishing)

#### **12:00 slot** (2 concurrent functions + 1 dependent)
- `enquiryPublisher` (12:00) – publishes unpublished enquiries
- `commentPublisher` (12:00) – publishes pending comments
- `sendPublishDigest` (12:05) – sends emails (depends on 12:00 ops finishing)

#### **20:00 slot** (1 function + 1 dependent)
- `teamResponsePublisher` (20:00) – publishes competitor responses after deadline
- `sendPublishDigest` (20:05) – sends emails (depends on 20:00 ops finishing)

---

## Race Condition Risks

### 1. **User-Triggered vs. Scheduled Collision**

**Scenario:** Team submits response at 19:59:50, just before 20:00 deadline

```
19:59:50 — createPost() writes response {responseId: "r123", isPublished: false}
20:00:00 — teamResponsePublisher() queries isPublished == false responses
           → Finds r123 and publishes it
           ✅ Works, but narrow timing window
```

**Risk:** If `createPost` is slow (e.g., attachment processing takes time), the response might be unpublished when `teamResponsePublisher` checks it, causing loss of a response that should have been published.

### 2. **Concurrent Scheduled Functions on Same Document**

**Scenario:** At 0:00, both `commentPublisher` and `committeeResponsePublisher` try to update same enquiry

```
0:00:00 — commentPublisher() reads enquiry, starts publishing comments
0:00:01 — committeeResponsePublisher() reads enquiry, starts publishing RC response
0:00:01 — Firestore contention: both trying to update enquiry.roundNumber, enquiry.stageEnds
          → One fails, needs retry (slows the system)
```

**Risk:** Document write conflicts, retries, delayed digests.

### 3. **Email Digest Before All Publishes Complete**

**Scenario:** `sendPublishDigest` at 0:05 runs while `commentPublicationScheduleRefresher` still writing

```
0:00:00 — enquiryPublisher, commentPublisher, committeeResponsePublisher start
0:01:00 — commentPublicationScheduleRefresher starts (writes to app_data/date_times)
0:05:00 — sendPublishDigest queries publishEvents (might miss stale/in-flight publishes)
          → Email sent with incomplete digest if a publish was still in-flight
```

**Risk:** Users receive incomplete digest; they miss some newly published posts.

---

## Recommendations for Phase 2+ (Future Improvements)

If further improvements are needed, the Phase 1 orchestrator provides a stable foundation for:

1. **Submission freeze windows** (Phase 2)
   - Set `responsesFrozen: true` at 19:50 (10 min before 20:00)
   - `createPost` checks flag and rejects submissions
   - Gives users clear feedback about deadline
   - Prevents last-minute race conditions

2. **Rate limiting on publication** (Phase 2+)
   - Add per-team request throttling
   - Log publication events for audit trail
   
3. **Delivery confirmation** (Phase 3+)
   - Track digest delivery success/failure
   - Re-attempt failed emails
   - Report to admin if digest delivery fails

