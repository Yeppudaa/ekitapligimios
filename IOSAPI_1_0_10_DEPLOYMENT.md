# IosApi 1.0.12 Deployment Runbook

This runbook deploys only `Ekitapligim/IosApi`. Do not upload, rebuild, edit, or uninstall `Ekitapligim/MobileApi` 1.0.136. Android remains on `/mobile-api/v1/`.

## Artifact

- ZIP: `release-archive/Ekitapligim-IosApi.zip`
- Required add-on version: `1.0.12 / 1000012` (monotonic upgrade from servers already running 1.0.11)
- Recalculate and record SHA-256 immediately before staging. The staging-tested hash must exactly match the production upload.

## Backup Before Production

1. Export the currently installed production `Ekitapligim/IosApi` add-on files/ZIP and its `addon.json` version.
2. Take a provider-native database snapshot or encrypted `mysqldump` outside the web root. Never place credentials or the dump in this repository.
3. Record the current MobileApi version and checksum as evidence that it remains unchanged.

## Staging

1. Upload the ZIP and install/upgrade `Ekitapligim/IosApi` through XenForo.
2. Run XenForo's add-on data/cache rebuild and verify the `/ios-api/v1/` routes.
3. Configure non-empty XenForo options `ekIosUgcBlockedTerms` and `ekIosUgcModeratorEmails`.
4. Run `php cmd.php ekitapligim-ios:release-audit`. Any non-zero exit blocks release.
5. Verify `GET /ios-api/v1/legal/terms` and that login/register without the current `accepted_terms_version` fail.
6. For forum topic/reply, book comment, Book Agenda post/comment create/edit, chat send, conversation create/reply: submit a staging-only configured test phrase, expect `422 content_policy_violation`, and verify no row was created.
7. For `forum_post`, `book_comment`, `agenda_post`, `agenda_comment`, `chat_message`, and `conversation_message`: create a report and verify the XenForo report plus moderator email job.
8. Block the demo author from each context. Verify immediate iOS removal and absence after API refresh across forum, book comments, Book Agenda, chat, and conversations. Verify one-to-one refusal and group-message filtering.
9. In staging only, advance controlled event timestamps to verify the 20-hour reminder and 24-hour escalation, then resolve a report and verify `actioned_at` and `closed_at`.
10. Run Swift unit tests, iOS Debug/Release builds, UI/accessibility tests, secret scan, and physical iPhone/iPad reviewer recordings.

## Production Promotion

1. Confirm the production ZIP SHA-256 equals the staging-tested hash.
2. Upgrade only `Ekitapligim/IosApi` and rebuild XenForo add-on data/caches.
3. Configure production moderator emails and managed filter list; run `php cmd.php ekitapligim-ios:release-audit`.
4. Run read-only health checks first, then reviewer-safe authenticated report/block checks.
5. Confirm `/mobile-api/v1/`, MobileApi 1.0.136, Android billing routes, Apple secrets, existing data, and production purchase verification are unchanged.
6. Publish iOS build 18 only after backend verification is complete.

## Rollback

Reinstall the captured previous IosApi ZIP and rebuild XenForo caches. Leave the additive terms/UGC event tables in place; they do not overwrite existing forum, user, message, billing, or MobileApi data. Restore the database snapshot only if an independently verified data-integrity incident requires it.
