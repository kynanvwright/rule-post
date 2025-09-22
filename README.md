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

## MVP
- Each team has an account
- Scheduled publishing (deployed but not tested)
- RC can skip scheduling as detailed in the rule
- Basic email alerts
- Colour-coding (optional but good)

## Future Features
- Doublecheck that backend functions are ensuring user has correct permissions
- Delay publishing to specific times
  - permit editing prior to submission
  - make sure storage rules stop unpublished attachments from being read
- Create enquiry phases and restrict user submissions accordingly
  - include limiting each team to one response per round
- Allocate users to teams
  - Consider having a 'master user' for each team who can add and remove members, and overwrite their drafts
  - they could also chose if a user can write or only read
- Add admin-only features
  - skip to end of certain phases
  - close enquiries
- Add colour-coding of responses/comments
  - need to create per-enquiry team IDs for this
- Fix up homescreen
  - resize panes
  - actually show enquiry details [done]
  - redo filters (Open, Closed, My Unpublished)
- Allow multiple attachments to be uploaded without reselection
- Add per-user limits on new enquiries and attachments per day
- Add email alerts for when costs are spiking
- Make testing pages for attempting to read/write from the frontend without proper permissions
  - test as signed in vs signed out
  - try to read author IDs
  - try to edit published posts
  - try to read unpublished posts
- Add custom claims to users, to set their roles and teams based on the user_data collection
  - this allows conditional formatting of pages based on roles/teams, without exposing user data
  - create a cloud function to update the custom claims whenever the user_data collection is changed in certain ways
- Write data models in json, then run code to convert into dart and typescript (one source of truth)
- Update enquiry round when RC responses published
- anonymity toggle (will be default on to start)
- Alias the documentIDs
- Set left pane to minimum of:
  - current width
  - smallest width where all title text shown
- Add filters/search to left pane
- Write working day funciton, and leave room for match date to be input

## Fixes
- Consolidate data models for posts/enquiries
- Rename variables that shouldn't have "enquiry" in them
- Refactor code once it's all working, and format it as a series of widgets
- Check which widgets/screens are still in use


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