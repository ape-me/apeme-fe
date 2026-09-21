# apeme-fe

ApeMe iOS app. Native Swift + SwiftUI, iOS 17+, dark only. See [HANDOFF.md](HANDOFF.md) before touching anything.

Backend: https://apme-be.iamjoey.workers.dev · Artifacts: `docs/artifacts/` · API shapes: `docs/api/`

## Run

Open `ApeMe.xcodeproj`, pick an iPhone 17 Pro Max simulator, ⌘R. No dependencies.

## Layout

```
ApeMe/
  App/         entry, AppState (mode, wallet, watchlists, navigation), routes, root shell
  Design/      Theme tokens, Skin (Invest blue / Ape green), type scale, Fmt number rules
  Models/      one Codable type per file, mirrors docs/api/contract.ts
  Network/     API (stale-while-revalidate, disk cache), LiveSocket (ws rooms, ping, backoff)
  Components/  rows, pills, buttons, badges, tab bar, mode switch
  Charts/      LineChart (halftone fill, fair-value dash, scrub), CandleChart
  Features/    Onboarding · Home · Markets · Stock · Floor · Token · Portfolio · You · Trade
```

Buy / Ape / Sell / Launch / Deposit are simulated until the swap and launch endpoints land.
