# Roadmap

## Purpose

To record ideas for future development and document observed bugs.

## Bugs
- Emails
    - ✅ check the rules to see if emails should send at 1200 NZT on a monday (0000 Europe/Rome) — **VALIDATED**: sendPublishDigest runs at 0:05, 12:05, 20:05 Rome daily; publishes events created at 0:00 and 12:00. Correct timing for weekend submissions. (5-minute skew is acceptable)
    - sent emails are bouncing (provisional fix implemented, waiting to check results)
- Performance
    - on an initial website visit, everything is quite slow to load. This improves later due to caching
- Multiple sessions
    - when you have multiple tabs open, behaviour can be inconsistent

## Future Work

- Submission timing orchestration ✅ IMPLEMENTED (Phase 1 — Orchestrator)
    - ~~currently submissions are locked and unlocked by a series of scheduled functions~~
    - ~~we have a lot of different functions running around the same times~~
    - ~~these have no proper order, it's just that submissions are locked after drafts are published~~
    - **Fixed:** Implemented orchestration wrapper that runs publishers sequentially, then sends digest
    - No submission locks added; submissions remain valid through to the deadline hour
    - orchestrate0000: enquiryPublisher → commentPublisher → committeeResponsePublisher → scheduleRefresher → sendDigestory
    - orchestrate1200: enquiryPublisher → commentPublisher → sendDigest
    - orchestrate2000: teamResponsePublisher → sendDigest
    - All individual publishers remain as testable helpers; orchestrator calls them in sequence
- Rate limiting
    - we need to restrict downloads and any functions that can be triggered by unauthenticated users, otherwise the website is susceptible to attack
    - also consider limiting to authenticated users, and emailing admins with details when rates are hit
- Emails
    - notify teams when an enquiry round is ending and they haven't submitted
- Data structure
    - many fields are currently duplicated
    - have a more relational database, with single sources of truth
        - save storage
        - prevent values from only being updated in some places
- Submission timing
    - currently submissions are locked and unlocked by a series of scheduled functions
    - we have a lot of different functions running around the same times
    - these have no proper order, it's just that submissions are locked after drafts are published
    - we should create a proper flow which is race-safe and makes sure things are done in the proper order
- Unused code
    - check through cloud functions and other widgets etc to ensure they're still in use
- Review 'publishEvents' collection
    - should these be deleted instead of marked as processed?

## General thoughts
- How do deadlines work if the RC responds late?
    - should Competitors get extra time, or should we keep the original schedule?
- What happens to pending submissions if the RC progresses an enquiry using their override?
    - should they be blocked from speeding up the process in some cases?