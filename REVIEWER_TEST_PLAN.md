# Reviewer Test Plan

This plan is for the account and environment provided to Apple App Review.

## Required Environment
- Public HTTPS staging or production URL.
- No localhost/private network dependency.
- Reviewer account with safe demo data.
- At least one reviewer-safe book with valid rights for reading/download testing.
- At least one forum/thread/post where report and reply permissions can be tested.
- At least one demo user ID that can be blocked/unblocked safely.
- A reviewer-safe conversation containing no real user private data, plus a demo recipient who can receive a test message.

## Account
- Username/email: `[CREATE_REVIEWER_ACCOUNT]`
- Password: store only in App Store Connect review notes.
- Role: normal member or premium member, depending on features submitted.
- The account must not require SMS, VPN, private email inbox access, or developer intervention.
- Registration mode requires matching passwords and acceptance of the Terms of Service and Privacy Policy. Review should use the prepared account instead of creating another account unless Apple specifically needs to test registration.
- Password reset always displays a generic confirmation and does not reveal whether an email address is registered.

## Test Cases
1. Launch app and log in.
2. Browse catalog and search.
3. Open book detail, open one related book, return, submit a reviewer-safe comment/rating, and report the demo comment.
4. Open reader and verify progress updates.
5. Download a book and verify it appears in Downloads.
6. Open Library shelves.
7. Open Community, forum, thread, and post detail.
8. Report content.
9. Block and unblock a demo user.
10. Browse Members, open the demo profile, follow/unfollow it, then block/unblock it.
11. Open profile, edit the reviewer-safe about/location/website fields, save, and verify the values reload; then open notifications.
12. With a disposable reviewer account, change email using the current password and complete confirmation if required. Change password, verify the current device remains signed in with rotated tokens, and verify an older mobile session is rejected.
13. Open Messages, view the demo conversation, send a reply, and create a message to the demo recipient.
14. With a disposable password account, start account deletion and verify the request is accepted once and repeated submission returns the same pending request.
15. With a disposable Sign in with Apple account, start account deletion and verify Apple authorization plus all mobile sessions are revoked before the request is accepted.
16. Purchase and restore premium in StoreKit sandbox, if premium is submitted.

## Evidence To Capture Before Submission
- Clean Debug build result.
- Clean Release archive result.
- Unit test result.
- UI test result.
- StoreKit sandbox purchase/restore result.
- Staging API smoke test result.
- Accessibility smoke test notes.
- Apple token exchange/revocation server log evidence with token values redacted.
- Disposable-account deletion completion evidence showing request PII scrubbed and XenForo cleanup jobs completed.
