<p align="center"><img src="docs/icon.png" width="120" alt="CatWalk icon"></p>

# CatWalk

An in-app network inspector for iOS, with no third-party dependencies. It captures the app's HTTP(S)
traffic and shows it in a searchable list with request, response, headers, cookies and TLS details.
It can also answer requests with mock responses. Everything is kept in memory and gone when the app exits.

- iOS 15+, Swift 6.2 toolchain, SwiftUI and UIKit hosts
- Captures `URLSession.shared` and custom sessions (Alamofire and others), including POST bodies and redirects
- TLS version, cipher suite and certificate chain with SHA-256 and SPKI pinning hashes. Your own SSL pinning keeps deciding.
- Mock rules (exact, path, prefix, contains, regex), editable in the app and created from a captured response
- Filters, JSON tree, copy as cURL, HAR export, request replay
- Compiled out of Release builds by default

## Install

Swift Package Manager:

```swift
.package(url: "https://github.com/alifu/CatWalk.git", branch: "main")
```

Add the `CatWalk` library to your app target.

## Set up

Start it as early as possible. Sessions created before `start` are not captured.

```swift
import CatWalk

@main
struct MyApp: App {
    init() {
        CatWalk.start(configuration: CWConfiguration(triggers: [.shake, .floatingBubble]))
    }
    var body: some Scene { WindowGroup { ContentView() } }
}
```

UIKit: call `CatWalk.start(...)` in `application(_:didFinishLaunchingWithOptions:)`.

### Opening the inspector

| How | Code |
|---|---|
| Shake the device | `triggers: [.shake]` (the default) |
| Floating bubble with a live request count | `triggers: [.floatingBubble]` |
| SwiftUI sheet | `.catWalk(isPresented: $show)` |
| UIKit, over the top view controller | `CatWalk.present()` |
| UIKit, a controller you push or present | `CatWalk.makeViewController()` |

Use `triggers: []` to open it only from your own code.

## Configuration

```swift
CWConfiguration(
    maxBodyBytes: 1_048_576,                 // kept per body; the app still gets the full body
    redactedHeaders: ["Authorization", "Proxy-Authorization"],
    interceptCustomSessions: true,           // also capture URLSessionConfiguration.default/.ephemeral
    maxTransactions: 500,                    // oldest are evicted first
    maxTotalBodyBytes: 50 * 1024 * 1024,     // all captured bodies together
    ignoredHosts: ["*.analytics.example.com"],
    triggers: [.shake],
    isEnabled: true                          // feed from a remote flag to switch CatWalk off
)
```

Ignored hosts take `api.example.com` or `*.example.com` (the domain and all subdomains). Their requests never
reach CatWalk. You can edit the list at runtime with `CatWalk.ignore(host:)` and in the inspector's Settings.

## Mocking

```swift
try CatWalk.mock(CWMockRule.get("/products").respond(status: 200, json: ["products": []]))
try CatWalk.mock(CWMockRule.post("https://api.example.com/login").respond(status: 401, delay: 1.5))
try CatWalk.mock(CWMockRule.get("/profile").fail(with: .notConnectedToInternet))
try CatWalk.mock(CWMockRule.matching(.regex(#"/users/\d+$"#), method: "GET").respond(status: 404))
```

- `get("/path")` matches the path on any host; a string containing `://` matches the full URL.
- Exact-URL rules are tried before pattern rules, then pattern rules in the order you added them.
- Mocked requests never reach the network and show up as **Mocked** in the list.
- In the inspector: swipe a row or use "Mock this response" to pre-fill a rule from a captured response; the
  **Mocks** screen enables, edits and deletes rules.
- Rules last until the app exits, so register the ones you want in code at launch.

## Release builds

The inspector is compiled in for **Debug** builds only. In Release every `CatWalk` API still exists but does
nothing (no `URLProtocol` registered, no swizzling, no UI), so you don't need `#if` in your app, and
`CatWalk.isEnabled` is `false`.

To keep it in a Release build, for example for QA or TestFlight, enable the package trait:

```swift
.package(url: "https://github.com/alifu/CatWalk.git", branch: "main", traits: ["CatWalkAlwaysOn"])
```

Use `CWConfiguration(isEnabled:)` or `CatWalk.setEnabled(_:)` as a runtime kill switch on top of that.

## Privacy

- Captured data lives in memory only. Nothing is written to disk, and everything is erased when the app exits.
- `Authorization` and `Proxy-Authorization` values are replaced by a placeholder before they are stored.
  Add `Cookie` and `Set-Cookie` to `redactedHeaders` to hide cookie values too, or pass `[]` to see everything.
- Request bodies and URLs are captured as sent. Don't ship a Release build with the trait on to end users.

## Limitations

CatWalk is a `URLProtocol`, so like netfox it does not see:

- `URLSessionWebSocketTask`, background sessions, `AVPlayer`, or `WKWebView` traffic
- sessions created before `CatWalk.start` (unless they use `URLSession.shared`)
- timing breakdowns (DNS, connect, TLS): only total duration is shown

## Development

```sh
xcodebuild test -scheme CatWalk -destination 'platform=iOS Simulator,name=iPhone 17'
```

`docs/icon.svg` is the source of the icon; the asset catalog holds a vector PDF of the same artwork.
