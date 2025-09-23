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
- New enquiry creation
  - storage of those enquiries
  - optional attachments for those enquiries
  - automated enquiry numbering
- Adaptive screen sizing
- Database and storage writing implemented via backend functions, frontend write access blocked
  - as an exception, frontend can write to temporary file storage
  - Cloud Storage rule for clearing out temporary file storage (1+ days old)
- Nested structure of enquiries, responses and comments
- Inline pdf and doc viewing
- Delayed publishing with cloud functions
- Automated locking/unlocking of submission permissions with cloud functions
- Basic custom claims set up, assigns user role and team to their account
  - allows both frontend and backend to query user's access level without database permissions
  - triggers cloud function whenever the `user_data` collection is updated

## MVP
- New accounts can be created
  - only by RC for now, through firebase console
- Scheduled publishing (deployed but all phases not tested)
- RC can skip scheduling as detailed in the rule (only in firebase console for now)
- Basic email alerts
- Colour-coding (optional but good)

## 📌 Future Features

### 🔒 Permissions & Roles
- One "teamLead" role per team
  - Can add/remove members (less burden on RC/admins)
  - Can assign members read-only or write permissions
- Add admin-only features  
  - Skip to end of certain phases  
  - Close enquiries  
- Require email verification (via Firebase Auth)  

### 📤 Publishing & Workflow
- Permit editing prior to submission (be careful of permissions here)
- Anonymity toggle (default ON to start)  
  - optionally allows teams to identify themselves
  - should this always be false for RC?
- Add amendment/interpretation/neither tag on enquiry closure, to allow filtering later  

### 📑 Enquiries & Responses
- Add per-user limits on new enquiries and attachments per day  
- Allow multiple attachments to be uploaded without reselection  
- Alias the documentIDs for breadcrumbs (e.g. `RE#120-R1.2`)  

### 🎨 UI / UX
- Add colour-coding of responses/comments
  - Need to create per-enquiry team IDs for this
  - Add colour assignment on post creation
- Set navigation pane to minimum of:
  - Current width
  - Smallest width where all title text shown
- Add filters/search to navigation pane
- Align flutter with backend, so that buttons are greyed out or hidden if user is not permitted to use them (use custom claims)

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

## Fixes
- Rename variables that shouldn't have "enquiry" in them
- Refactor code once it's all working, and format it as a series of widgets
- Check which widgets/screens are still in use, delete as required

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