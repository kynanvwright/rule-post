# Rule Post

Rule Post is a **Flutter + Firebase** web application used by America’s Cup teams and the Rules Committee to manage **Rule Enquiries**, **Responses**, and **Comments** through a structured, rule-aligned workflow.

Most users can browse content while logged out. **Posting and notification settings require authentication.**

---

## What this repository contains

* **Frontend**: Flutter Web (Dart)
* **Backend**: Firebase Cloud Functions (TypeScript)
* **Firebase services**:

  * Firestore (primary datastore)
  * Cloud Functions (business logic & enforcement)
  * Cloud Storage (attachments)
  * Authentication (email/password + custom claims)
  * Hosting (deployment)

---

## Key features

* **Structured Rule Enquiry workflow**

  * Enquiry → Response → Comment nesting
  * Stage-based windows for team responses, comments, and RC replies
  * RC can close an enquiry as *Interpretation*, *Amendment*, or *Neither*
  * Optional stage-length changes for urgent cases

* **Delayed publishing**

  * Posts exist as drafts until a scheduled publish time
  * RC/admin override for instant publication when required

* **Security-first model**

  * Read-mostly frontend; core writes enforced in Cloud Functions
  * Firestore & Storage rules are deny-by-default for writes
  * Drafts visible only to the authoring team
  * Anonymous public posting (author identity stored in backend-only metadata)

* **Attachments**

  * Enquiries and Responses support attachments
  * Inline preview for PDF/DOC/DOCX with download fallback
  * Temporary upload workflow during post creation

* **Notifications & unread tracking**

  * Email notifications via Resend
  * Per-user unread tracking with visual indicators

* **Usability**

  * Responsive layout (desktop, tablet, mobile)
  * Navigation pane search and filtering
  * Per-enquiry colour-coded authorship (consistent within an enquiry)

---

## Core concepts

### Entities

* **Enquiry**
  Initial question or proposed amendment raised by a team or the Rules Committee.
  Automatically numbered; may include attachments.

* **Response**
  A detailed response to an enquiry, submitted by teams or the RC.
  Attachments supported; RC responses advance the workflow stage.

* **Comment**
  Short feedback on a response. Multiple comments allowed per response.
  Attachments are not supported.

---

## Draft → publish flow (simplified)

1. User creates a draft post in the UI
2. Frontend sends a validated payload to a Cloud Function
3. Cloud Function writes to Firestore and schedules publication
4. A scheduled publisher sets `isPublished = true` at the correct time
5. Publish events generate unread and notification records
6. Frontend listens to Firestore streams and updates the UI

---

## Permissions & roles

Authentication uses email/password. **Custom claims** allow both frontend and backend to enforce permissions without additional database lookups.

Typical claims:

* `role`: `User` / `Admin`
* `team`: `RC`, `NZL`, `GBR`, etc.
* `teamAdmin`: `true | false` (can create/delete users for their team)
* `emailNotificationsOn`: `true | false`

Security goals:

* Published content is readable without login
* Unpublished drafts are only readable by the authoring team
* Editing is only allowed **before publication**, by the authoring team
* Most writes are blocked from the client and enforced in Cloud Functions
* Author identity is never publicly exposed

---

## Repository structure (high level)

```
functions/          # Firebase Cloud Functions (TypeScript)
flutter_app/        # Flutter Web frontend
firestore.rules     # Firestore security rules
storage.rules       # Cloud Storage security rules
docs/               # Architecture & workflow documentation
```

Documentation:

* `docs/overview` – product overview and data flow
* `docs/backend` – Cloud Functions, Firestore structure, security model
* `docs/frontend` – Flutter architecture, UI, navigation, attachments

---

## Getting started (development)

### Prerequisites

* Flutter SDK (Web enabled)
* Node.js + npm
* Firebase CLI
* A Firebase project with:

  * Firestore
  * Authentication (email/password)
  * Cloud Storage
  * Hosting
  * Cloud Functions

### Run the frontend locally

```bash
flutter clean
flutter pub get
flutter run -d chrome
```

### Work on Cloud Functions locally

```bash
npm install
npm run build
# optional
firebase emulators:start
```

---

## Deployment

### Deploy everything

```bash
firebase deploy
```

### Deploy a single function (example)

```bash
firebase deploy --only functions:createPost
```

### Useful maintenance commands

```bash
# Download Firestore indexes from the console project
firebase firestore:indexes --project rule-post > firestore.indexes.json

# Lint and autofix TypeScript
npx eslint "src/**/*.{js,ts,tsx}" --fix
```

---

## Cloud Functions overview

**User-triggered**:

* `createPost`, `editPost`
* `toggleEmailNotifications`
* Team admin: `createUserWithProfile`, `deleteUser`
* RC/admin: `changeStageLength`, `closeEnquiry`, `responseInstantPublisher`

**Scheduled publishers**:

* `enquiryPublisher`
* `teamResponsePublisher`
* `commentPublisher`
* `committeeResponsePublisher`

**Event-triggered**:

* `syncCustomClaims`
* Publish events on `isPublished` transitions
* Deletion cleanup for attachments and unread records

See **`docs/backend`** for full details.

---

## Firestore & Storage model (summary)

Key collections:

* `app_data` – shared configuration (colour wheel, enquiry counter, team names)
* `drafts` – per-team draft visibility
* `enquiries` – public post data with nested responses and comments

  * Sensitive fields live in a backend-only `meta` subcollection
* `publishEvents` – records publications for notifications
* `user_data` – user profiles and unread tracking

---

## Roadmap & Known Issues

* detailed further in docs/roadmap.md

---

## Contributing

This project relies on a **low-trust client** model. When making changes:

* Keep core writes enforced in Cloud Functions
* Be cautious with Firestore/Storage rule changes
* Update documentation when workflows or permissions change

---