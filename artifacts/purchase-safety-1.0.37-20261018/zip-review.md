# Exact ZIP purchase compatibility review

- Package: `artifacts/library-favorites-20261018/Ekitapligim-IosApi.zip`, version `1.0.37` / `1000037`.
- SHA-256: `DE46E68120D9BC8685E4A0703D289A16BA8F8FE6A1654E8F421F1C9DD462CC75`.
- Baseline: `artifacts/purchase-recheck-20261013/Ekitapligim-IosApi.zip`, version `1.0.36` / `1000036`, SHA-256 `746DA9D5A6F06DAB19D57055A49526F015F68D4CC74FCD860CD0D20CDC168809`.
- Alternate baseline `artifacts/renewable-20261013/Ekitapligim-IosApi.zip` is byte-identical to this baseline.

All 137 payload file names and bytes were compared with the 136-file baseline. One new file, six changed files, no removals; 130 existing files are byte-identical. Repeating the comparison after normalizing only line endings gives the same change set. No absolute/traversal paths, duplicate entries or case aliases were found.

## Exact changed files

- Added `Service/LibraryShelfManager.php`.
- Changed `Api/Controller/MeLibrary.php`, `Api/Controller/MeLibraryItem.php`, `Api/Controller/UgcControllerTrait.php`, `Setup.php`, `README.md`, `addon.json`.

## Billing unchanged

The App Store verify and notification API controllers and public wrappers, reconciliation cron, transaction store, entitlement policy, term schedule, entitlement service, membership synchronizer, Apple root certificate, routes and code event listeners are byte-identical to 1.0.36. The same full-payload comparison covers all other registration/configuration files.

`Setup.php` adds only `upgrade1000037Step1`, whose body contains a comment. It does not migrate tables, alter account data or modify premium entitlements. All earlier install/upgrade methods are unchanged.

The new library service creates/deletes only BookThreads shelf/favorite entities and reads their snapshot. It holds the current user's `xf_user` row lock briefly during that transaction to serialize shelf/favorite requests; it does not update user fields, call purchase services, acquire App Store locks or write entitlement/group data. The other changed controllers are limited to library mutation input/output and community permission serialization.

## Exact archive versus current workspace

All packaged PHP source files match the workspace byte-for-byte. The one differing packaged source file is `_data/routes.xml`: the workspace additionally has an unrelated `me-audio-comments` route. The ZIP's route file itself is unchanged from 1.0.36, including purchase routes.

This is a source/package compatibility review. It makes no claim of a newly executed live Apple purchase, deployment, or production database integration run. SHA evidence for every payload file is in `zip-comparison.json`.
