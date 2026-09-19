# apeme-fe — read this first

The iPhone app for **ApeMe**: a pump.fun-style live floor for memes launched against tokenized stocks on Solana. Native Swift, iOS only. This repo is empty on purpose; the Mac session creates the Xcode project. Written 2026-09-18 from the VPS session that built the indexer and backend. Everything below is verified, not planned.

## Rules (Joey's, non-negotiable)
- **No AI attribution anywhere.** No `Co-Authored-By: Claude`, no "Generated with Claude" in commits, PRs, code or files. Everything under his GitHub profile (`iam-joey`, darushyam143@gmail.com).
- Native Swift + SwiftUI. Never React Native, Expo, Flutter or web. iOS only for v1.
- Keep replies short and concrete. He reviews visual artifacts (dark theme). One artifact per topic; make a new one for a new topic.
- Dark UI for this app.
- Confirm before anything irreversible or infra-level; committing and pushing work he asked for is fine without asking.

## Deadline
Stocklana hackathon, submit by **Fri 25 Sep 2026, 4pm ET**. Plan: Fri–Sun three read-only screens · Mon Privy wallet + one-tap ape via Jupiter · Tue Meteora DBC + PreStocks bounty angles · Wed–Fri TestFlight, demo video, submit with a day spare.

## What already exists (don't rebuild)
| service | repo | state |
|---|---|---|
| Indexer (Rust, on the VPS) | `ape-me/ape-indexer` | live: every trade on 6 launchpad programs against 85 stock mints → Postgres, ~1s after confirm |
| Backend (Hono on Cloudflare Workers) | `ape-me/apme-be` | live at **https://apme-be.iamjoey.workers.dev** |
| App (this repo) | `ape-me/apeme-fe` | not started |

The app talks only to the backend. Never to Solana RPC or Postgres.

## The API (live now, no auth)
```
GET /health
GET /v1/ticker?memes=10&stonks=10  (alias /api/ticker)   → {updatedAt, tokens:[{id, kind:meme|stonk, label, logo, change24h, price}]}  memes first, by 24h volume
GET /v1/stocks?issuer=prestocks                         → {stocks:[Stock], asOf}   Pre-IPO tab. issuer=xstocks,backpack → Stocks tab. Omit for all. Sorted by heat.
GET /v1/stocks/:mint                                    → Stock                    stock page header
GET /v1/floor?stock=<mint>&limit=30&<filters>            → {stock, new:[card], graduating:[card], graduated:[card], asOf}   one call = whole floor screen; omit stock for all stocks
GET /v1/tokens?column=new|graduating|graduated&stock=&sort=&limit=50&cursor=&<filters>   → {tokens:[card], next}   one column, paged
GET /v1/stocks/:mint/tokens?column=&sort=&limit=50&cursor=&<filters>   → {stock, tokens:[TokenCard], next}
GET /v1/tokens/:mint                                    → TokenHeader
GET /v1/tokens/:mint/candles?tf=1m|5m|15m|1h|4h|1d&limit=300&before=   → {mint, tf, candles:[{t,o,h,l,c,v,n}]}  oldest→newest
GET /v1/tokens/:mint/trades?limit=100&before=           → {mint, trades:[Trade]}  newest first
WS  wss://…/ws/floor      every trade on every token
WS  wss://…/ws/stock:<mint>   trades + launches on one stock's floor (the stock page)
WS  wss://…/ws/:mint      trades for one token
```
- **Stock fields** (Sun 20 Sep): `priceUsd` (Jupiter, what a buyer pays) · `markUsd` = fair value (PreStocks' mark for pre-IPO, the real Nasdaq price for xStocks/Backpack) · `premiumPct` = token vs fair value (+15 = trades 15% above; the badge on the card) · `liquidityUsd` · `stockVol24hUsd buys24h sells24h` = the stock's own trading · `heat` = launches×10 + wallets + meme volume/1000 (24h; the ranking) · `launched24h memeVol24hUsd wallets24h` = its floor · `king` = `{mint, symbol, image, vol24hUsd}` top meme by 24h volume, or null · `issuer` = prestocks | xstocks | backpack · `category` = preipo | stock | etf. Crypto pairs are never returned. Real response: `docs/api/stocks-prestocks.json`.
- Columns: `new` = on the curve, created in the last 24h, newest first · `graduating` = on the curve, progress ≥ 60%, highest first · `graduated` = on the AMM, by 1h volume.
- Sorts: `new mcap vol5m vol1h vol24h txns1h progress change1h change24h` (default per column as above).
- Filters (all optional, combinable): `minMcap maxMcap minVol1h minVol24h minAge maxAge (minutes) minProgress maxProgress minTxns1h minBuys24h maxTax (bps) minHolders maxTop10 maxDev maxSnipers launchpad=stonkfun,pumpfun,dbc dexPaid=1 social=1 q=<search>`.
- Card fields beyond the basics: `vol5mUsd buys5m sells5m vol1hUsd buys1h sells1h change1h athMcapUsd holders top10Pct devPct snipersPct website twitter telegram dexPaid dexPaidAt dexBoosts`. Holder fields are computed from our own trade tape (exact for tokens indexed since birth, null for older backfilled tokens). Thresholds pump.fun uses: top10 > 20% red, dev > 20% red / < 5% green, snipers > 10% red, holders < 10 red.
- Floor socket also sends `{t:"token", event:"created"|"graduated", mint, symbol, name, quoteMint, launchpad, creator, createdAt, ts}` the second a pool is created or graduates; fetch `/v1/tokens/:mint` for the full card.
- Exact shapes: `docs/api/contract.ts` (zod, the source of truth). Real responses captured today: `docs/api/*.json`. Generate the Swift `Codable` models from these; field names are camelCase and stable.
- WebSocket frames are **JSON arrays** of `{t:"trade", mint, sig, ts, slot, side, wallet, base, quote, priceQuote, priceUsd}`. Send the text `ping` every 25s, server replies `pong`. Reconnect with backoff on close; on reconnect, refetch `/trades` to fill the gap.
- Errors: `{error, requestId}` with 400 / 404 / 429 / 500. Rate limit 600 requests per minute per IP. Reads are edge-cached 2–5s, so polling faster than that is pointless; use the sockets for live.
- Money semantics: `priceQuote` = stock units per meme (e.g. NVDAx per NIU). `priceUsd = priceQuote × stock.priceUsd`. `mcapUsd` is already computed. Trade `base`/`quote` are what the wallet paid/received (transfer tax included), same as explorers show. `taxBps` = the meme's transfer tax (100 = 1%). `phase` is `curve` (on the launch curve, `progressPct` toward graduation) or `graduated` (on an AMM). `marketOpen` = NYSE regular session.
- Test ids: NVDAx `Xsc9qvGR1efVDFGLrVsmkzv3qi45LTBjeUKSPmx9qEh`; busiest meme on it, NIU `GXL9wD1F5TzVXfZ33fKkBxeuNi7wKMUR25SDEBGEZ9mN`.

## Apelist (landing-page waitlist, live)
Base: `https://apme-be.iamjoey.workers.dev/api/apelist`. Turnstile **site key** (public): `0x4AAAAAAE7uvyin5VEgyZCu`, domains apeme.fun / www / localhost.
- `POST /` `{email, turnstile, ref?}` → 201 `{ok:true}` new · 200 `{ok:true}` existing (treat the same) · 400 `{ok:false,error:"invalid_email"|"bot"}` · 429 `rate_limited` · 500 `server`
- `GET /count` → `{count}` (60s cache) · `GET /confirm?t=` → 302 to `https://apeme.fun/?confirmed=1|0`
- CORS allows only apeme.fun, www.apeme.fun, http://localhost:5173. Confirmation email goes out via Resend from hey@apeme.fun.

## The screens (updated Sun 20 Sep: Pre-IPO first)
1. **Pre-IPO** (tab 1, the demo opener) — `/v1/stocks?issuer=prestocks`. 7 cards in the order returned (heat). Card: logo, symbol, price, **premium badge** (`premiumPct`, orange when > 5), 24h %, "N memes · $X today" (`launched24h`, `memeVol24hUsd`), king thumbnail. Tap → stock page.
2. **Stocks** (tab 2) — same cards, `/v1/stocks?issuer=xstocks,backpack`.
3. **Stock page** — header from `/v1/stocks/:mint` (price, fair value, premium, liquidity, buys/sells). **Buy the stock** button (Monday). **King of the floor** pinned with buy/sell. Then the floor list `/v1/stocks/:mint/tokens` (sort tabs volume / new / mcap, `next` paging). Subscribe `/ws/stock:<mint>` for live trades and launches on this floor; flash cards, bump numbers.
4. **Token** — `/v1/tokens/:mint` header; candles from `/candles` (1m default, tf picker), live tape from `/ws/:mint` prepended to `/trades`. Append live trades into the current candle client-side. Ape button, disabled until Monday's wallet work. "Launched against $OPENAI" links back to the stock page.

Read-only. No wallet, no login, no settings. Get these three feeling live and fast before anything else.

## Design language
Feel = dex.fun / pump.fun terminal on a phone: dense, live, numbers first, big Ape button. Palette used across all artifacts: bg `#0b0e12`, surface `#12161c`, line `#232a33`, ink `#eef2f5`, muted `#a7b1bc`, faint `#6b7682`, green `#5fe39a`, amber `#f5b640`, blue `#6db3ff`, red `#ff5c5c`. Type in the artifacts: Bricolage Grotesque (display), IBM Plex Sans (body), IBM Plex Mono (numbers); on iOS use SF Pro Rounded / SF Mono with tabular numbers unless bundling fonts is trivial. Tiny prices need smart formatting (e.g. `0.0₅308` subscript-zero style, or `$3.08e-7` → `$0.000000308`); mcap/vol as `$69.3K`, `$1.2M`.

## Artifacts (open in a browser, `docs/artifacts/`)
- `apeme-sofar.html` — where everything stands today, start here.
- `apeme-be.html` — backend design: endpoints, why each exists, security, build order.
- `apeme-day1.html` — real rows of data, what each screen shows.
- `apeme-indexing.html` — what indexing gives us, with real examples; chart history explained.
- `apeme-phase0.html` — the phase 0 spec (indexer), with status.
- `apeme-recovery.html` — how the indexer survives crashes, tested cases.
- `apeme-plan.html`, `apeme-system.html` — the earlier overall plan and system design (some track choices there are stale; the tables above win).

## Things learned the hard way
- Trades reach the phone ~1s after confirmation; the chain's own block clock runs 1–4s behind wall time, so never compute "age" from `ts` against `Date()` without expecting that skew.
- Older DBC tokens have no chart history; show "live from now" rather than an empty chart error.
- The backend is on a shared, overloaded VPS right now; uncached reads jitter 100–600ms. A dedicated VPS is planned. Cache hits are 50–100ms. Design the UI to render from cache/last state immediately and update, never to block on a request.

## Still owed by Joey
Paid Apple Developer account (by Sunday, for TestFlight). apeme.fun on the Cloudflare account. Dedicated VPS (later). Ask PreStocks on X whether xStocks' SPCXx counts for their bounty.
