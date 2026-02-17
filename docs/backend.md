# Backend Architecture

## Overview
The backend relies on Firebase services:  
- **Firestore** (primary data store)  
- **Cloud Functions** (business logic)  
- **Cloud Storage** (attachments)  
- **Authentication** (users and custom claims)  
- **Hosting** (Flutter Web deployment)

## Post Flow
- This website is primarily intended as a host for AC38 Rule Enquiries
- It is expected that posts will flow as follows:
  - Post created in frontend
  - Post saved to database via backend (if checks are passed)
  - Post is scheduled for publication
  - Post may be edited prior to publication
  - Post is published
  - Post viewable by all
- Post scheduling is set out in the AC Technical Regulations
- Posts are nested as follows:
  - Enquiries (the initial question/amendment raised by a team or RC)
  - Responses (detailed responses to the enquiry or other responses)
  - Comments (brief feedback or agreement relating to a response)

---

# Cloud Functions
- Cloud functions have full admin permissions, and can bypass firebase rules about read/write access
- Any restrictions on user team or role must be explicitly included in the function
- Functions are written in TypeScript

## User-Triggered

### All Users

#### createPost
- generate a post, which stays in unpublished draft form until the next scheduled publication time
- until published, this can only be viewed by members of the team that authored it

#### editPost
- edit an unpublished post that your team drafted

#### toggleEmailNotifications
- allows you to choose if you receive emails when new posts are published

### Team Admins

#### createUserWithProfile
- create a user for your team
- sends a password reset email via "Resend"

#### deleteUser
- delete a user from your team

### Admin/RC

#### changeStageLength
- allows the default number of working days between enquiry stages to be changed
- this is primarily for high-urgency enquiries before events, to speed up resolution

#### closeEnquiry
- allows the RC to close an enquiry once concluded
- they are required to indicate how it ended (interpretation, amendment etc)

#### getPostAuthorsForEnquiry
- retrieves author team identities for all posts (responses, comments) in an enquiry
- RC/admin only; returns map of {postId: authorTeam}
- server-mediated for security; all calls logged for audit trail
- prevents author identity leakage to non-admin users

#### responseInstantPublisher
- allows the RC to instantly publish a scheduled post, completing the current enquiry stage
- can be used on both Competitor or RC responses

#### markPostUnread
- allows an admin to mark a post as unread to test the "unread post" mechanisms

## Scheduled (via Orchestrator)

✅ **New Architecture (Phase 1):** All scheduled publications are now coordinated through an orchestrator pattern to eliminate race conditions and ensure consistent ordering.

Instead of independent scheduled functions running at fixed times, the system uses three orchestrator functions that call publishers **sequentially**:

### orchestrate0000 (0:00 Europe/Rome)
Runs every day at 0:00 Rome time:
1. Publishes unpublished enquiries
2. Publishes pending comments
3. Publishes RC responses (when stage window closed)
4. Updates comment publication schedule
5. Sends digest emails to users

### orchestrate1200 (12:00 Europe/Rome)
Runs every day at 12:00 Rome time:
1. Publishes unpublished enquiries
2. Publishes pending comments
3. Sends digest emails to users

### orchestrate2000 (20:00 Europe/Rome)
Runs every day at 20:00 Rome time (response submission deadline):
1. Publishes team (competitor) responses
2. Sends digest emails to users

#### Helper Functions (called by orchestrators)

##### enquiry_publisher → doEnquiryPublish()
- Helper function that publishes unpublished enquiries
- Opens permission for team responses
- **Scheduling:** Called by orchestrate0000 and orchestrate1200
- **Standalone export:** Commented out (use orchestrator instead)

##### team_response_publisher → doTeamResponsePublish()
- Helper function that publishes team responses after deadline
- Opens permission for team comments and RC response
- **Scheduling:** Called by orchestrate2000
- **Standalone export:** Commented out (use orchestrator instead)

##### comment_publisher → doCommentPublish()
- Helper function that publishes pending comments
- Only runs on working days
- **Scheduling:** Called by orchestrate0000 and orchestrate1200
- **Standalone export:** Commented out (use orchestrator instead)

##### committee_response_publisher → doCommitteeResponsePublish()
- Helper function that publishes RC responses
- Ends a round by closing comment permissions and opening responses
- Only runs on working days
- **Scheduling:** Called by orchestrate0000
- **Standalone export:** Commented out (use orchestrator instead)

##### comment_publication_schedule → doCommentPublicationScheduleRefresh()
- Helper function that updates the next comment publication time
- Stores result in `app_data/date_times.nextCommentPublicationTime`
- **Scheduling:** Called by orchestrate0000
- **Standalone export:** Commented out (use orchestrator instead)

##### send_publish_digest → doSendPublishDigest()
- Helper function that sends email digests to subscribed users
- Queries publishEvents collection and sends digest emails
- **Scheduling:** Called by orchestrate0000, orchestrate1200, orchestrate2000
- **Standalone export:** Commented out (use orchestrator instead)
- **No time offset:** Previously ran at 0:05/12:05/20:05; now runs immediately after publishes complete

## Orchestration Details

**Why orchestrators?**
- Eliminates race conditions from concurrent scheduled functions
- Ensures all publishes complete before digest emails are sent
- Guarantees consistent execution order (no time offsets needed)
- Prevents duplicate emails or incomplete digests

**Submission Deadlines (not blocked by system):**
- Enquiries: No deadline; can submit anytime
- Responses: Deadline 20:00 Europe/Rome; system respects submissions up to the deadline
- Comments: Deadline 12:00 Europe/Rome; system respects submissions up to the deadline

Deadlines are **not enforced by locks**. The system uses window permissions (teamsCanRespond, teamsCanComment) to control when submissions are accepted. The orchestrator publishes at the deadline time; submissions before are accepted, after are rejected by permissions.

---

## Event-triggered

### User custom claims (syncCustomClaims)
- if a document in the user_data collection is updated, the firebase custom claims for that user are also updated
- these custom claims are attributes that can be accessed from the frontend and used for conditional logic relating to user team and role

### Publish Events
- triggered when a post's "isPublished" switches to true, and records an entry in the publishEvents collection, including:
  - onEnquiryIsPublishedUpdated
  - onResponseIsPublishedUpdated
  - onCommentIsPublishedUpdated

### Deletion
- triggered when a post is deleted, to clean up other related documents (attachments, read receipts etc)
  - onEnquiryDeleted
  - onResponseDeleted
  - onCommentDeleted

## Other
- There are lots of helper functions which deal with:
  - payload validation
  - attachments
  - tile colours
  - working days and scheduling
- There are also some functions which can be triggered using curl, for testing.

---

## Firestore Structure

### app_data
Small collection containing:
- colour wheel containing possible tile colours
- counter for the current highest enquiry number
- valid team names

### drafts
- contains a folder for each team
- each team may only read their own folder
- used to display your draft posts alongside the published ones
- could probably be replaced with better logic in the enquiries collection, but this way ensures that the post authors are never publicly exposed

### enquiries
- this collection contains the majority of the website data, the post details
- posts are nested as follows, enquiry -> response -> comment
- all post fields are publically accessible
- any sensitive fields are hidden in a "meta" subcollection, which only the backend can access
  - includes the author's team

### publishEvents
- records recent publications, to notify users via email

### user_data
- records users and their data
- important fields are synchronised to fibrebase custom claims
- has unreadPosts as a subcollection, which records which posts have not been read by the user
  - these are highlighted visually in the app

---

## Security Rules Overview

### Objectives
- **Website content can be read without logging in**
- **Writing/editing is restricted to authenticated users**
- **Posts must be anonymous**
- **Posts must only be readable:**
  - **once published**
  - **as drafts by the authoring team**
- **Posts must only be editable:**
  - **before publication**
  - **by the authoring team**
- **Author identities remain hidden from all users except admin/RC** (see "Author Reveal" below)

### Author Reveal (Admin/RC only)
- Author team identities are stored in protected `/meta/data` subcollections (inaccessible to frontend)
- RC/admin users can call `getPostAuthorsForEnquiry(enquiryId)` to retrieve author identities
- This is a **server-mediated** endpoint: author data never stored on client, only in backend logs
- All calls are logged (uid, enquiryId, timestamp) for audit trail
- Frontend displays "By [Team]" tags only to admin/RC users
- **Security model**:
  - Firestore rules unchanged; `/meta/data` remains fully restricted
  - Backend has full admin access; can safely fetch meta documents
  - Frontend cannot access author data directly; must use callable function
  - Non-admins never fetch authors (Riverpod provider gated by role check)

### Implementation
- Firebase implements deny-by-default to the frontend
- Writing requires user to be logged in and pass multiple checks
- Frontend writing very limited (e.g. user's own read receipts)
- User may read post if it is:
  - published
  - unpublished, and user is logged in as a member of the author team
- User may write to temporary storage to test that attachment is valid

---

## Notifications
- email capability provided by "Resend"
- runs immediately after each scheduled publishing event completes (orchestrator ensures all publishes done first)
- sent at 0:00, 12:00, 20:00 Europe/Rome (no longer offset by +5 minutes)
- digest emails group enquiries, responses, and comments separately
- users can opt for "all" notifications or "enquiries only"
- unread tracking updated when posts are published

**Email Digest Flow:**
1. Publisher functions update post isPublished flag
2. Firestore trigger captures the publish event → creates publishEvent document
3. Orchestrator calls doSendPublishDigest()
4. Digest function queries unprocessed publishEvents, groups by type
5. Sends digest emails to subscribed users (two variants: all / enquiries-only)
6. Marks events as processed

### Future Work
- Add txt/WhatsApp options
- Add notification options for:
  - Stage transitions
  - Upcoming deadlines (if you haven't submitted)
  - A specific enquiry rather than all of them

---

## Known Bugs & Future Work
### Bugs
- [blank for now]
### Future Work
- Notifications (see section)
- Make the database more relational, instead of creating duplicate info which can drift
- When enquiries are closed with an amendment, automate a DocuSign process
- Some user data hangs around after deletion by team admin
- Could integrate drafts with enquiries with better permission logic

---