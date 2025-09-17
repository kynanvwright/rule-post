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

## Other Notes

- Check how it looks on various devices
