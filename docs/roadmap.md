# Roadmap

## Purpose

To record ideas for future development and document observed bugs.

## Bugs

- Performance
    - on an initial website visit, everything is quite slow to load. This improves later due to caching
- Multiple sessions
    - when you have multiple tabs open, behaviour can be inconsistent

## Future Work

- Rate limiting
    - we need to restrict downloads and any functions that can be triggered by unauthenticated users, otherwise the website is susceptible to attack
    - also consider limiting to authenticated users, and emailing admins with details when rates are hit
- Emails
    - notify teams when an enquiry round is ending and they haven't submitted
- Login
    - make sure Google/Bitwarden can autofill credentials
- Data structure
    - many fields are currently duplicated
    - have a more relational database, with single sources of truth
        - save storage
        - prevent values from only being updated in some places
- Submission timing
    - currently submissions are locked and unlocked by a series of scheduled functions
    - we have a lot of different functions running around the same times
    - these have no proper order, it's just that submissions are locked after drafts are published
    - we should create a proper flow which is race-safe and makes sure things are done in the proper order
- Unused code
    - check through cloud functions and other widgets etc to ensure they're still in use
- Review 'publishEvents' collection
    - should these be deleted instead of marked as processed?
- Response submission
    - users reported confusion when attempting to do a round 2 submission. Consider whether we should add a response button on the RC reponse itself, so they don't have to navigate up to the enquiry first.

## General thoughts
- How do deadlines work if the RC responds late?
    - should Competitors get extra time, or should we keep the original schedule?
- What happens to pending submissions if the RC progresses an enquiry using their override?
    - should they be blocked from speeding up the process in some cases?