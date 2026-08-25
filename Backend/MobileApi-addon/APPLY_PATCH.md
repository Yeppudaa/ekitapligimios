# Applying The iOS MobileApi Patch (Deprecated)

**Do not use this workflow.** iOS backend changes now ship through the standalone [`Backend/IosApi-addon`](../IosApi-addon/README.md) at `/ios-api/v1/`.

```powershell
.\Scripts\build-ios-api-addon.ps1 -CreateZip
```

The legacy patch script aborts unless `-ForceDeprecated` is passed:

```powershell
.\Scripts\apply-mobileapi-ios-patch.ps1 -AddonPath "..." -ForceDeprecated
```

That path merges iOS code into the shared Android `MobileApi-addon` and is retained only for historical reference.
