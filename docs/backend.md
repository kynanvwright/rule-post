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

### Admins/RC

#### changeStageLength
- allows the default number of working days between enquiry stages to be changed
- this is primarily for high-urgency enquiries before events, to speed up resolution

#### closeEnquiry
- allows the RC to close an enquiry once concluded
- they are required to indicate how it ended (interpretation, amendment etc)

#### responseInstantPublisher
- allows the RC to instantly publish a scheduled post, completing the current enquiry stage
- can be used on both Competitor or RC responses

#### markPostUnread
- allows an admin to mark a post as unread to test the "unread post" mechanisms

## Scheduled

#### enquiryPublisher
- publishes an enquiry, making it visible to all (along with any attachments)
- opens permission for team responses

#### teamResponsePublisher
- publishes all team responses, making them visible to all (along with any attachments)
- opens permission for team comments and RC response

#### commentPublisher
- publishes comments, making them visible to all

#### committeeResponsePublisher
- publishes the RC response, making it visible to all (along with any attachments)
- ends the round, closing comment permissions and opening responses for teams

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
- runs 5 minutes after each scheduled publishing event

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