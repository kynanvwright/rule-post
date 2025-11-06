# Rule Post App
A website for facilitating America's Cup Rule Enquiries.

## General Structure
- **Frontend**: Built with [Flutter](https://flutter.dev/) (Dart).
- **Backend**: Implemented with [Firebase Cloud Functions](https://firebase.google.com/docs/functions) (TypeScript).
- **Services**: Uses Firebase Authentication, Cloud Storage for Firebase, and Firebase Hosting.

## Current Features
- Authentication
  - sign in/out
  - registration blocked outside of firebase console
  - app check feature looks for bots
  - log in to post
  - team admins can create new users
- New enquiry creation
  - storage of those enquiries
  - optional attachments for those enquiries
  - automated enquiry numbering
- Nested structure of enquiries, responses and comments
  - coloured by author, unique mapping per enquiry
- Database and storage writing implemented via backend functions, frontend write access blocked
  - as an exception, frontend can write to temporary file storage
  - Cloud Storage rule for clearing out temporary file storage (1+ days old)
- Delayed publishing with cloud functions
- Automated locking/unlocking of submission permissions with cloud functions
  - frontend buttons aligned with backend permissions
- Basic custom claims set up, assigns user role and team to their account
  - allows both frontend and backend to query user's access level without database permissions
  - triggers cloud function whenever the `user_data` collection is updated
- Inline pdf and doc viewing
- Adaptive screen sizing
- Enquiry filtering and title text search

## Targets

### MVP
- New accounts can be created [done]
- Scheduled publishing [done]
- RC can skip scheduling as detailed in the rule [done]
- Basic email alerts [done]
- Colour-coding (optional but good) [done]

### Published version
- Site mostly used while logged out [done]
  - only log in for posting or notification settings [done]
- One team lead user per team, can add new users [done]
- Email notifications with customisation [done]
- Publishing permissions move via schedule or RC acceleration [done]
  - allow alternative stage lengths [done]
- Identify RC in all of their posts [done]
- Pre-publication editing available after submission [done]
- Search/filter in navigation pane [done]
- Robust testing
- Allow RC to close the enquiry in their response
  - allow RC to close enqury with button [done]
  - add mechanism for circulating for Docusign?
- Add commercial product area

## 📌 Future Features

### 🔒 Permissions & Roles
- Require email verification (via Firebase Auth)
  - superseded by allowing team leads to add accounts
- Limit the access of cloud functions. Full admin may not be necessary and increase exploitation risk.
- Check that users can't edit or delete (Firebase Rules)
- Add rate limiting on functions and queries

### 📤 Publishing & Workflow
- Anonymity toggle (default ON to start)  
  - optionally allows teams to identify themselves
- Add amendment/interpretation/neither tag on enquiry closure, to allow filtering later
  - done, need to add matching filters and status chips
- have a page summarising all open enquiry deadlines

### 📑 Enquiries & Responses
- Add per-user limits on new enquiries and attachments per day

### 🎨 UI / UX
- Set navigation pane to minimum of:
  - Current width
  - Smallest width where all title text shown
- In navigation pane, allow final RC response to be labelled 'interpretation' or 'amendment'
- Add subheaders to navigation pane for rounds
- Add symbols with colour-coding for colour-blind folks
- Make left pane collapsible
- Consider making the logo having matching text colour to "Rule Post"
- Indicate when an enquiry has an unusual stage length
- Tighten padding on phones

### 📧 Notifications & Alerts
- Add (toggleable) email alerts to users for when:
  - posts are published [done]
  - deadlines are approaching (and the team hasn't submitted)
- Add email alerts for admins when server/Firestore billing costs are spiking
- Extend notifications to WhatsApp/text
- Add website alert for new posts, allow them to be ignored or read, as a way of tracking what's been read

### 🛠 Testing & Validation
- Make testing pages for attempting to read/write from the frontend without proper permissions  
  - Test as signed in vs signed out  
  - Try to read author IDs  
  - Try to edit published posts  
  - Try to read unpublished posts  
  - Try to read unpublished post attachments
  - Try to read/write app_data and user_data
  - Try to edit user roles

### 🗂 Data & Models
- Write data models in JSON, then run code to convert into Dart and TypeScript (one source of truth)
- Consolidate data models for post types

### Commercial Product Requests

### Read Receipts
- Mark all as unread for new users
- Allow all posts to be marked as read with button press
- Have unread posts dropdown with links
- Show dot for unread content in:
  - Nav pane
  - Child stream tiles
- For stream tiles, show dot next to comments if they're unread, instead of response
- Have button to mark post as unread for all users
  - Shouldn't need to be used much, but good for testing

## Fixes
- Check which widgets/screens are still in use, delete as required
- Look for edge cases where RC speeds up stage end and team response gets stuck. 
  - Need to block submission in that case so it doesn't end up getting published in the next round, or alongside the RC without them reading it.
- Enforce overall enquiry timeline even if RC responds late
  - notify Competitors that they have slightly less time than is ideal
- Fix stage ends to be on the hour and cloud functions to run at 1 minute past
- Should the email digest delete entries rather than marking them as processed?
- Switch childrenSection streams to providers to avoid reload on log-in?
- Check cloud functions and delete ones that aren't in use
- the enquiryNumber on unpublished enquiries can be wrong if a draft gets deleted

## Other Notes
- Check how it looks on various devices

### Useful commands to remember (Powershell)
- firebase firestore:indexes --project rule-post > firestore.indexes.json (download indexes from console)
- npx ts-node makeAdmin.ts (run local script to assign custom role attributes)
- firebase deploy --only functions:createPost (update/create one function)
- firebase deploy (update all firebase from local files, functions, rules etc)
- npx eslint "src/**/*.{js,ts,tsx}" --fix (fix formatting of ts files)
- flutter clean (remove compiled code from flutter build after making decent changes)
- flutter pub get (rebuilds what was lost during flutter clean)
- flutter run -d chrome (run flutter app locally in chrome)
- npx ts-node applyClaims.ts --serviceAccount ./serviceAccountKey.json --collection user_data [--uids uid1,uid2] [--fields role,team] [--dry-run] [--replace]