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

Local validation note: this script was applied to the local XenForo add-on, upgraded it through MobileApi `1.0.83`, audited all 49 public route templates, passed PHP syntax checks, and created a verified iOS patch ZIP without modifying the Android project source copy.

After applying:

1. Install or upgrade the addon in XenForo.
2. Clear/rebuild XenForo route caches if needed.
3. Run `Scripts/api-smoke-test.ps1` against public HTTPS staging.
4. Generate the public deployment directory with `Scripts/prepare-public-deployment.ps1 -TeamId "YOUR_TEAM_ID"`.
5. Publish its AASA file and configure the Apple server secrets documented in `README.md` outside source control.
6. Run `Scripts/public-release-audit.ps1`, authenticated smoke tests, and real Apple sandbox verification before production.
