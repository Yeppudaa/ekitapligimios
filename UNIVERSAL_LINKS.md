# Universal Links Setup

The app entitlement includes:

```text
applinks:ekitapligim.com
applinks:www.ekitapligim.com
```

Template file in this repo:

```text
Web/.well-known/apple-app-site-association
```

Host the JSON at:

```text
https://ekitapligim.com/.well-known/apple-app-site-association
https://www.ekitapligim.com/.well-known/apple-app-site-association
```

Replace `TEAMID` with the Apple Developer Team ID before deployment.

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appIDs": [
          "TEAMID.com.ekitapligim.app"
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
