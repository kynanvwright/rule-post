# RulePost App
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

## Targets

### MVP
- New accounts can be created [done]
  - only by RC for now, through firebase console [superseded]
- Scheduled publishing [deployed] [testing]
- RC can skip scheduling as detailed in the rule (only in firebase console for now)
- Basic email alerts [deployed] [testing]
- Colour-coding (optional but good) [done]

### Published version
- Site mostly used while logged out [done]
  - only log in for posting or notification settings [done]
- One team lead user per team, can add new users [done]
- Email notifications with customisation [partial]
- Publishing permissions move via schedule or RC acceleration
  - allow alternative stage lengths
- Identify RC in all of their posts [done]
- Pre-publication editing available after submission (maybe)
- Search/filter in navigation pane
- Robust testing
- Allow RC to close the enquiry in their response
  - add mechanism for circulating for Docusign?
- Add commercial product area

## 📌 Future Features

### 🔒 Permissions & Roles
- Add admin-only features  
  - Skip to end of certain phases  
  - Close enquiries  
- Require email verification (via Firebase Auth)
- Create static mirror of site for public viewing, updated whenever post details change
- Look into limiting the access of cloud functions. Full admin may not be necessary and increase exploitation risk.
- Check that users can't edit or delete (Firebase Rules)
- Add rate limiting on functions and queries

### 📤 Publishing & Workflow
- Permit editing prior to submission (be careful of permissions here)
- Anonymity toggle (default ON to start)  
  - optionally allows teams to identify themselves
- Add amendment/interpretation/neither tag on enquiry closure, to allow filtering later  

### 📑 Enquiries & Responses
- Add per-user limits on new enquiries and attachments per day  
- Allow multiple attachments to be uploaded without reselection

### 🎨 UI / UX
- Set navigation pane to minimum of:
  - Current width
  - Smallest width where all title text shown
- Add filters/search to navigation pane
- In navigation pane, allow final RC response to be labelled 'interpretation' or 'amendment'
- Add subheaders to navigation pane for rounds
- Add symbols with colour-coding for colour-blind folks
- Make left pane collapsible
- Consider making the logo having matching text colour to "Rule Post"
- Indicate when an enquiry has an unusual stage length

### 📧 Notifications & Alerts
- Add (toggleable) email alerts to users for when:
  - posts are published
  - deadlines are approaching (and the team hasn't submitted)
- Add email alerts for admins when server/Firestore billing costs are spiking
- Extend notifications to WhatsApp/text

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

## Fixes
- Rename variables that shouldn't have "enquiry" in them
- Refactor code once it's all working, and format it as a series of widgets
- Check which widgets/screens are still in use, delete as required
- Look for edge cases where RC speeds up stage end and team response gets stuck. 
  - Need to block submission in that case so it doesn't end up getting published in the next round, or alongside the RC without them reading it.
- If I rapidly change who I'm logged in as, it keeps the old user data (e.g. getting confused about whether I'm RC or not)
  - might be unique to local version, also not a common issue
- make sure that top bar on both sides of two-panel shall have same height
- Enforce overall enquiry timeline even if RC responds late
  - notify Competitors that they have slightly less time than is ideal
- Document attachment is now really slow, look into this and streamline
  - add a loading message to let people know that it may take a while
  - could improve by skipping the temporary upload
- Padding doesn't look even in left header pane
- Response/Comment lists temporarily persist on navigation then disappear
- Fix stage ends to be on the hour and cloud functions to run at 1 minute past

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