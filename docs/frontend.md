# Frontend Architecture

## Overview
The frontend is built using **Flutter Web**, with Riverpod for state management and GoRouter for navigation.  
This document explains the structure, major components, and conventions.

---

## Project Structure (High-Level)
- main: simple wrapper, runs bootstrap and app
- app: calls router, determines MaterialApp settings
- bootstrap: firebase, app check and persistence
- firebase_options: per-platform option selection
- router: navigation
- theme: light and dark themes

### api/
contains functions which pass payloads to the backend google cloud functions, including:
- post creation/editing
- user creation/deletion
- RC/admin functions which close enquiries or skip enquiry stages
- user notification setting changes
- testing functions

### auth/
- login screen (technically a "dialog" pop-up)
- login functions
- pre-function checks to ensure correct authorisation

### content/
- screens/
  - post detail screens
  - user screen
  - help/FAQ screen

- widgets/
  - various frames, cards & tiles which appear on the post detail screens
  - loading graphics

### core/
- buttons
  - post creation/deletion
  - navigation
  - menus
  - mark post as read/unread

- models
  - error types
  - backend function payloads
  - types
  - attachments
  - filters

- widgets
  - app scaffolding and top banner
  - navigation panes
  - adaptive screen sizing
  - RC/admin panel
  - various helpers


### debug/
- custom logging so that nothing runs in production 

### navigation/
- navigation functions for consistent behaviour 

### riverpod/
handles anything where variable data must be looked up, including:
- user permissions
- post details
- filters
- team members

---

## Navigation (GoRouter)

### Structure
- Root router  
- Subroutes for enquiries, responses, comments  
- Navigation pane selection logic  

### Deep Linking
- URL structure pattern:  
  `/enquiries/:id`, `/enquiry/:id/responses/:id`

---

## Attachment Handling

### Temporary Storage Workflow
- During frontend post creation, user files are uploaded to a temporary location
  - this tests if the file is suitable
  - but doesn't provide write access to the 'permanent' file storage location
- If the backend post creation function runs successfully, this temprorary file is removed
- The temporary files have a lifecycle and will be deleted after 1 day

### File Preview
- Inline PDF/DOC/DOCX viewer  
- On preview failure, will trigger file download
- Download button also available

---
## UI
### Responsive Layout
- Resizes elements based on screen/window size
- Collapses nav pane if screen is too narrow (e.g. mobile)

### Theming & Styling

- Themes are based on the background colour of the AC38 logo
- Light and dark themes generated on this colour seed
- Default font

---

## Permissions
- Frontend permissions are set in the firebase console, or can be deployed as code
  - Firestore (Database):
    - Firebase Console -> Firestore Database -> Rules OR
    - firestore.rules (local file)
  - Firebase Storage (Files)
    - Firebase Console -> Storage -> Rules OR
    - storages.rules (local file)
- Note that deploying the local code can overwrite changes made in the firebase console

---

## Known Bugs & Future Work
### Bugs
- When multiple tabs of the website are open, the behaviour can be strange, and caching doesn't seem to work
- The website can be quite slow, look at options to speed it up
  - some of this is from "AppCheck"
### Future Work
- Create a page full of frontend functions that shouldn't work, to check that backend enforcement is working as intended

---

## Useful commands for local dev version
- flutter clean (remove compiled code from flutter build after making decent changes)
- flutter pub get (rebuilds what was lost during flutter clean)
- flutter run -d chrome (run flutter app locally in chrome)

---