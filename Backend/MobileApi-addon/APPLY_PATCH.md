# Applying The iOS MobileApi Patch

Use this script to apply the iOS backend scaffold into an existing `Ekitapligim/MobileApi` addon checkout.

Example using the Android project copy:

```powershell
.\Scripts\apply-mobileapi-ios-patch.ps1 -AddonPath "C:\Users\Monster\Downloads\startdesign (1)\MobileApi-addon"
```

To also create an installable XenForo addon zip:

```powershell
.\Scripts\apply-mobileapi-ios-patch.ps1 `
  -AddonPath "C:\Users\Monster\Downloads\startdesign (1)\MobileApi-addon" `
  -CreateZip `
  -OutputDirectory "C:\Users\Monster\Downloads\startdesign (1)\release-archive"
```

The script:

- Copies scaffold controllers into `Api/Controller`.
- Creates matching `Pub/Controller` aliases.
- Merges `routes-fragment.xml` into `_data/routes.xml`.
- Runs PHP syntax checks when PHP is installed.
- Optionally creates a XenForo upload zip.

Local validation note: this script was tested against a temporary copy of the Android `MobileApi-addon`; it added 18 routes and created an iOS patch zip without modifying the source Android project copy.

After applying:

1. Install or upgrade the addon in XenForo.
2. Clear/rebuild XenForo route caches if needed.
3. Run `Scripts/api-smoke-test.ps1` against public HTTPS staging.
4. Harden Apple auth and App Store JWS verification before production.
