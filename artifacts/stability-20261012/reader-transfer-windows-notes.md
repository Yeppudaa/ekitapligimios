# Reader transfer verification — 2026-10-12

Executed from the repository root:

```powershell
Start-Transcript -Path artifacts/stability-20261012/reader-transfer-windows.log -Force
try { & ./Scripts/reader-transfer-test-windows.ps1 }
finally { Stop-Transcript }
```

Result: all 11 `ValidatedBookFileTransferTests` XCTest cases passed, exit code 0. Swift 6.3.3 compiled the actual production transfer file and test file in Swift 5.10 package language mode. No Swift compiler concurrency warnings were emitted. SwiftPM reported a non-fatal Windows debug-directory symbolic-link warning. The trailing Swift Testing line says zero tests because these 11 cases use XCTest; the individual XCTest executions are listed earlier in the transcript.

The harness lives under `.codex-temp/file-transfer-harness`, which is separate from the shared core build. It copies only the specified Swift implementation and XCTest file, adds `FoundationNetworking` imports, and supplies test-only compatibility names for the unsupported iOS file-protection attributes. It makes no production-source modifications and performs no recursive deletion.

Covered behavior includes reader bearer refresh and retry, repeated resource denial without another refresh, external/forbidden requests without refresh, account changes during refresh, unavailable secure-storage providers, transient refresh errors, temporary-file cleanup, HTTPS JSON redirects, Drive source normalization, oversized/insecure redirect rejection, late progress suppression, and disk-full error mapping.

This validates the request/retry/file-validation logic with injected downloads and token providers. It does not validate native Apple URLSession networking, redirects exercised by a real transport, Keychain availability, iOS data protection, SwiftUI rendering, or device/background behavior. Those require the iOS XCTest/UI-test and device checks on macOS.
