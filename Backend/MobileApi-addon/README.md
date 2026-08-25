# MobileApi iOS Backend Extension (Deprecated)

**Deprecated.** iOS backend work now lives in the standalone XenForo add-on [`Backend/IosApi-addon`](../IosApi-addon/README.md) at `/ios-api/v1/`. That add-on depends on `Ekitapligim/MobileApi` without modifying Android routes or source.

Do **not** merge this patch into the Android `MobileApi-addon` checkout anymore.

## Replacement Workflow

```powershell
.\Scripts\build-ios-api-addon.ps1
.\Scripts\build-ios-api-addon.ps1 -CreateZip
```

Install `Ekitapligim/IosApi` in XenForo Admin after `Ekitapligim/MobileApi` is active.

## Historical Note

These files previously extended the shared XenForo `Ekitapligim/MobileApi` add-on for the native iOS app through `Scripts/apply-mobileapi-ios-patch.ps1`. The same controllers and services were migrated into `Ekitapligim/IosApi` with namespace `Ekitapligim\IosApi`.

## Legacy Endpoints (now under `/ios-api/v1/`)

- `POST /ios-api/v1/auth/apple`
- `GET /ios-api/v1/book-detail/{thread_id}` (delegates to MobileApi `Book`)
- `POST /ios-api/v1/billing/app-store/verify`
- `POST /ios-api/v1/members/{user_id}/block|unblock`
- `GET /ios-api/v1/me/blocked-members`
- `POST /ios-api/v1/posts/{post_id}/report`
- `GET|POST /ios-api/v1/me/terms`, `POST /ios-api/v1/me/terms/accept`
- `POST /ios-api/v1/billing/app-store/notifications`

See [`Backend/IosApi-addon/README.md`](../IosApi-addon/README.md) for current installation, Apple configuration, and deployment steps.
