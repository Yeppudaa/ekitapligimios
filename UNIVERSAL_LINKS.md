# Universal Links Setup

Gift wheel (2026-09-27): repository AASA now includes exact `/hediye-carki` and `/hediye-carki/` paths, mapped to native `gift-wheel`. Existing associated-domain entitlements suffice. Deployment and on-device Universal Link verification remain pending; no server file was changed by this task.

The app entitlement includes:

```text
applinks:ekitapligim.com
applinks:www.ekitapligim.com
```

Production file in this repo:

```text
Web/.well-known/apple-app-site-association
```

Host the JSON at:

```text
https://ekitapligim.com/.well-known/apple-app-site-association
https://www.ekitapligim.com/.well-known/apple-app-site-association
```

The production Team ID is `QA67383767`; keep the deployed file synchronized with this source.

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appIDs": [
          "QA67383767.com.ekitapligim.app"
        ],
        "components": [
          { "/": "/books/*", "comment": "Book details" },
          { "/": "/konular/*", "comment": "Turkish book/thread URLs" },
          { "/": "/threads/*", "comment": "Forum threads" },
          { "/": "/forum/*", "comment": "Forums" },
          { "/": "/book-authors/*", "comment": "Authors" },
          { "/": "/book-publishers/*", "comment": "Publishers" },
          { "/": "/book-requests/*", "comment": "Book requests" }
        ]
      }
    ]
  }
}
```

Serve the file without a `.json` extension and with `application/json`.

`RootView` receives associated-domain URLs through SwiftUI `.onOpenURL`, validates them with `DeepLinkParser`, and forwards only recognized Ekitapligim routes to `AppContainer.open(route:)`. Home/catalog/community links select their native tab; book, thread, forum, author, publisher, and request links open a native route sheet. Foreign hosts and unknown paths are ignored.
