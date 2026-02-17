# Roadmap

## Purpose

To record ideas for future development and document observed bugs.

## Bugs
- Emails
    - sent emails are bouncing (provisional fix implemented, waiting to check results)
- Performance
    - on an initial website visit, everything is quite slow to load. This improves later due to caching
- Multiple sessions
    - when you have multiple tabs open, behaviour can be inconsistent

## Future Work

- Rate limiting
    - we need to restrict downloads and any functions that can be triggered by unauthenticated users, otherwise the website is susceptible to attack
    - also consider limiting to authenticated users, and emailing admins with details when rates are hit
- Unused code
    - check through cloud functions and other widgets etc to ensure they're still in use
- Review 'publishEvents' collection
    - should these be deleted instead of marked as processed?

## General thoughts
- How do deadlines work if the RC responds late?
    - should Competitors get extra time, or should we keep the original schedule?
- What happens to pending submissions if the RC progresses an enquiry using their override?
    - should they be blocked from speeding up the process in some cases?