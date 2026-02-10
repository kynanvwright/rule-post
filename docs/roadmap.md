# Roadmap

## Purpose

To record ideas for future development and document observed bugs.

## Bugs

- Submission windows
    - currently set to 5 minutes before the hour, potentially blocking legitimate submissions
        - suggested solve: lock submissions on the hour, move scheduled functions to 1-5 minutes past
- Closing an enquiry
    - current process requires RC submission then another button click in the RC Panel
    - this opens team repsonses for a while
    - instead, RC should have the option to auto-end enquiry when their submission publishes
- Navigation
    - if you attempt to navigate to a page that requires authentication, you get a GoRouter error instead of being redirected
- UI
    - On a cell phone or small device, "sideWidgets" don't wrap, so they take up lots of space and make the content squish onto 4-5 lines
- Performance
    - on an initial website visit, everything is quite slow to load. This improves later due to caching
- Multiple sessions
    - when you have multiple tabs open, behaviour can be inconsistent

## Future Work

- Rate limiting
    - we need to restrict downloads and any functions that can be triggered by unauthenticated users, otherwise the website is susceptible to attack
    - also consider limiting to authenticated users, and emailing admins with details when rates are hit
- Emails
    - set up mailing list that always gets notified for new enquiries
        - alternatively have separate buttons for enquiry notification vs global notification
    - notify teams when an enquiry round is ending and they haven't submitted
- Publication
    - users should be able to see when comments will next be published, during open submission periods
- Login
    - make sure Google/Bitwarden can autofill credentials
- Data structure
    - many fields are currently duplicated
    - have a more relational database, with single sources of truth
        - save storage
        - prevent values from only being updated in some places
- Post drafts
    - should there be a delete option?
- Unused code
    - check through cloud functions and other widgets etc to ensure they're still in use
- Review 'publishEvents' collection
    - should these be deleted instead of marked as processed?
- Deleted enquiry drafts
    - check if numbering gets messed up (including other drafts)
- Response submission
    - users reported confusion when attempting to do a round 2 submission. Consider whether we should add a response button on the RC reponse itself, so they don't have to navigate up to the enquiry first.

## General thoughts
- How do deadlines work if the RC responds late?
    - should Competitors get extra time, or should we keep the original schedule?
- What happens to pending submissions if the RC progresses an enquiry using their override?
    - should they be blocked from speeding up the process in some cases?