# News & Insights — FE brief (22 Sep 2026)

Two new data sets on the stock page, one new list on Home. Backend is live and populated; nothing here needs a BE change.

## 1. `GET /v1/stocks/:mint/insights` — the brokerage half of the stock page

Cached 5 min. Pre-IPO stocks (OPENAI, ANTHROPIC, KALSHI…) return the same shape with `nasdaq`, `stats`, `company`, `earnings` all `null` — render only what is non-null.

```json
{ "mint": "Xsc9…9qEh", "symbol": "NVDAX", "ticker": "NVDA",
  "market": { "isOpen": false, "session": "pre-market", "holiday": null, "alwaysOn": true },
  "nasdaq": { "last": 227.38, "change": 5.11, "changePct": 2.299, "open": 222.935, "high": 228.5,
              "low": 221.56, "prevClose": 222.27, "asOf": 1790020800 },
  "premiumVsLastPct": -0.11,
  "stats": { "high52w": 236.54, "low52w": 164.27, "marketCapUsd": 5479858105333, "peTtm": 27.98,
             "epsTtm": 7.91, "dividendYieldPct": 0.03349, "beta": 2.22 },
  "company": { "name": "NVIDIA Corp", "sector": "Semiconductors", "exchange": "NASDAQ NMS - GLOBAL MARKET",
               "website": "https://www.nvidia.com/", "ipo": "1999-01-22", "logo": "https://…png" },
  "earnings": { "date": "2026-11-17", "when": "after close", "inDays": 55, "epsEstimate": 2.5231,
                "quarter": 3, "year": 2027 },
  "asOf": 1790079491 }
```

Where it goes on the stock page (Overview tab):

- **Market row** in Market stats, replacing today's "After hours · trades 24/7 here":
  `session` → "Pre-market" / "Market open" / "After hours" / "Closed", then always "· trades 24/7 here".
- **Fair value card**, one extra line under Premium: `Nasdaq last close $227.38 · here −0.11%` from `nasdaq.prevClose` + `premiumVsLastPct`. Keep the existing mark-based Premium row as is; this one is the number a user can check on any finance site.
- **Earnings badge** under the header when `earnings.inDays <= 30`: "Earnings in 6 days · Nov 17, after close". Above 30 days put it in Key stats instead.
- **Key stats card** (new, below Market stats): 52-week range as a bar with `low52w`/`high52w` and a dot at the current on-chain price; then Market cap, P/E, EPS, Dividend yield, Beta. Hide any null row; hide the whole card when `stats` is null.
- **About tab**: `company.name`, `sector`, `exchange`, `IPO`, `website` (tap → in-app browser), above the existing Issuer / Category / Mint rows.

## 2. News

Three endpoints, all cached 60 s, same item shape everywhere.

```
GET /v1/stocks/:mint/news?limit=5        stock page, News tab
GET /v1/news?mints=<a,b,c>&limit=30      Home → News; with mints those stocks come first
GET /v1/news/ticker                      headline strip, 12 items, one per stock, movers first
```

```json
{ "items": [ {
  "id": "7f963fce…", "mint": "Xsc9…9qEh", "symbol": "NVDAX", "name": "NVIDIA",
  "image": "https://www.stonkfun.xyz/api/asset/quote-logo/…",      // stock logo, always present
  "priceUsd": 226.85, "change24h": 1.14,                            // for the chip on the row
  "title": "Nvidia CEO Jensen Huang says 'nothing would give me more joy' than to pay more taxes",
  "summary": "While California faces a billionaire exodus ahead of the November 3 wealth tax vote…",
  "source": "Yahoo Finance",
  "url": "https://finance.yahoo.com/economy/policy/articles/nvidia-ceo-jensen-huang-says-091500918.html",
  "articleImage": "https://s.yimg.com/…png",                        // often a generic outlet logo
  "publishedAt": 1790068500,
  "impact": "minor", "direction": "bullish", "confidence": 0.58, "tier1": false
} ] }
```

Field notes:
- `impact` is `none | minor | material | major | critical`, `direction` is `bullish | bearish | neutral`, both **nullable** (not scored yet, or the model was not confident). Never invent a badge when null.
- Show the direction badge only when `direction != null`; the backend already withholds it below 50 % confidence.
- `articleImage` is often the outlet's generic logo. Use it only if you can tell it apart from a real photo; otherwise use `image` (the stock logo). A 40 px rounded square either way.
- `tier1` marks a named outlet (Reuters, Bloomberg, CNBC, WSJ, Barron's, AP, Axios…). Optional: a small dot or heavier source label.
- Articles that are listicles, SEO filler, or only mention the company are already dropped server-side (Jev scores every article; 125 of 242 were dropped in the first pass).

### Row
```
[logo 40]  NVDAX ▲1.14% · Yahoo Finance · 2h ago   [MATERIAL] [BEARISH]
           Nvidia's Forecast Assumes No Data Center Chip Sales to
           China. The Sept. 24 Summit Could Change That.
```
Two-line title clamp. The `NVDAX ▲1.14%` chip taps through to the stock page; the rest of the row opens the article sheet.

### Article sheet
Full title, `summary`, source · time, impact/direction badges, then the article itself in `SFSafariViewController` with `entersReaderIfAvailable = true` (stays inside ApeMe), and a sticky **Trade NVDAx** button that pushes the stock page with the Buy sheet open. No API gives full article text; the reader view is the article.

### Placements
1. **Stock page**: segmented control under Buy/Sell — `Overview | News | About`. Overview keeps everything that is there today plus the insights cards. News = `/v1/stocks/:mint/news?limit=5`, "More" loads 20. Empty state: "No news yet for NVDAx".
2. **Home**: add a 5th chip — `Pre-IPO · Movers · Explore · Watchlist · News`. Calls `/v1/news?mints=<held+watched>&limit=30`; without mints it still returns the newest across all stocks, so it works signed-out.
3. **Headline strip** under the price ticker on Home: `/v1/news/ticker`, one headline per stock, biggest movers first, scrolling. Tap → article sheet.
4. **Live**: stock rooms now emit `{"t":"news","mint","symbol","title","source","url","publishedAt"}` — use it for a "1 new" badge on the News tab while the page is open. Refetching on appear is fine as a fallback.

Freshness: the ingest runs every 5 minutes on our box and walks the whole stock list every 20 minutes, so a headline shows up within ~20 min of publication.
