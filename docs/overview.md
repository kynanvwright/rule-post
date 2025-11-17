# Overview

## What This App Does

Rule Post is a Flutter + Firebase web application used by America’s Cup teams and the Rules Committee to manage **Rule Enquiries**, **Responses**, and **Comments**.  
It provides a structured discussion workflow with controlled publication, permissions, attachments, and automated timelines.

The system is designed so most users browse openly without logging in, while posting and notification settings require authentication.

---

## High-Level Architecture

### Frontend
- Built with **Flutter Web**
- Uses **Riverpod** for state management
- Responsive layout with:
  - Navigation pane showing enquiries and status
  - Main content pane for posts and discussion threads
- All persistent writes are routed through Cloud Functions

### Backend
- **Firestore** for structured data
- **Cloud Functions (TypeScript)** for:
  - Creating posts
  - Publishing scheduled posts
  - Stage and timing automation
  - Managing unread states
  - Sending email notifications
- **Cloud Storage** for attachments
- **Firebase Hosting** for the web app

### Authentication
- Email/password sign-in
- Custom claims used to define:
  - **role** (`User`, `Admin`)
  - **team** (`RC`, `NZL`, `GBR`...)
  - **teamAdmin** (`true`, `false`)
    - allows user to add/remove members from their team
  - **emailNotificationsOn** (`true`, `false`)

---

## Core Entities

### Enquiry
- Created by RC or teams
- Optional attachments
- Automatically numbered
- Scheduled publishing (with RC override)
- Moves through workflow stages:
  1. Team response window
  2. Team comment & RC response window
  3. Repeat as needed
  4. Closure (Interpretation / Amendment / Neither)

### Response
- Linked to an enquiry
- Created by teams or RC (one response per team per round)
- Attachments supported
- RC responses advance the stage

### Comment
- Linked to a response
- Created by teams
- Multiple comments permitted on each response
- Stage-restricted
- Attachments not supported

---

## Key Features

- **Structured workflow** aligned with official rule processes  
- **Delayed publishing** of posts  
- **Automated opening/closing** of response and RC windows  
- **Email notifications** for new posts and stage changes  
- **Colour-coded authorship** per enquiry  
- **Inline PDF/DOC viewing**  
- **Unread tracking** per user for enquiries, responses, and comments  
- **Search and filter** in the navigation pane  

---

## Data Flow (Simplified)

1. User creates a draft post  
2. Frontend sends payload to a Cloud Function  
3. Cloud Function validates input and writes to Firestore  
4. Post remains hidden until scheduled publish time  
5. Firestore triggers notification/unread updates  
6. Frontend listens to Firestore streams to update UI  

---

## Permissions Model

- Frontend is **read-mostly**
- All writes go through Cloud Functions
- Firestore security rules enforce:
  - No direct writes to core collections
  - Role/team-based access to unpublished content
  - Only temporary storage is directly writable by frontend

---

## Development Philosophy

- **Minimal friction for teams** — users browse logged-out unless posting  
- **Backend-enforced consistency** — rules and timing logic live in Cloud Functions  
- **Predictable stages** — the system reflects AC rulebook timelines  
- **Low-trust client** — frontend cannot bypass workflow constraints  

---

<!-- ## Where to Go Next

- **Architecture**  
  - `architecture/frontend.md`  
  - `architecture/backend.md`  
  - `architecture/data_model.md`  
  - `architecture/auth_and_roles.md`

- **Workflows**  
  - `workflows/enquiries.md`  
  - `workflows/publishing.md`  
  - `workflows/permissions.md`  
  - `workflows/notifications.md`  
  - `workflows/unread_system.md`

- **Ops**  
  - `ops/environment_setup.md`  
  - `ops/deployment.md`  
  - `ops/cloud_functions.md`  

- **Roadmap**  
  - `roadmap/future_features.md`  
  - `roadmap/fixes_and_debt.md`   -->
