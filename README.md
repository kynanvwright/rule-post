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

## Future Features
- Doublecheck that backend functions are ensuring user has correct permissions
- Delay publishing to specific times
  - permit editing prior to submission
  - make sure storage rules stop unpublished attachments from being read
- Add layering of responses and comments underneath enquiries
- Create enquiry phases and restrict user submissions accordingly
  - include limiting each team to one response per round
- Allocate users to teams
  - Consider having a 'master user' for each team who can add and remove members, and overwrite their drafts
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

## Fixes
- Remove placeholder files
- Consolidate data models for posts/enquiries
- Rename variables that shouldn't have "enquiry" in them
- Refactor code once it's all working, and format it as a series of widgets
- New code doesn't automatically reshape when window sizes change
- I can't see response details in this branch
- Try putting the new enquiry button under "Files" above the enquiry list to save space

## Other Notes

- Check how it looks on various devices
