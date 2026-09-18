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
GET /v1/stocks                                          → {stocks:[Stock], asOf}
GET /v1/stocks/:mint/tokens?sort=volume|new|mcap&limit=50&cursor=   → {stock, tokens:[TokenCard], next}
GET /v1/tokens/:mint                                    → TokenHeader
GET /v1/tokens/:mint/candles?tf=1m|5m|15m|1h|4h|1d&limit=300&before=   → {mint, tf, candles:[{t,o,h,l,c,v,n}]}  oldest→newest
GET /v1/tokens/:mint/trades?limit=100&before=           → {mint, trades:[Trade]}  newest first
WS  wss://…/ws/floor      every trade on every token
WS  wss://…/ws/:mint      trades for one token
```
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

## The three screens for this weekend
1. **Stocks** — `/v1/stocks`. Rows: logo, symbol, name, USD price, 24h %, meme count. Sort by meme count. Tap → floor.
2. **Floor** (per stock) — `/v1/stocks/:mint/tokens`, sort tabs volume / new / mcap, infinite scroll with `next`. Cards: image, symbol, phase pill, price USD, mcap, 24h vol, buys/sells, tax. Subscribe to `/ws/floor`, filter by the stock's memes (`quoteMint`), flash the card and bump the numbers on each trade.
3. **Token** — `/v1/tokens/:mint` header; candlestick chart from `/candles` (1m default, tf picker), live tape from `/ws/:mint` prepended to `/trades`. Append live trades into the current candle client-side. Big **Ape** button, disabled until Monday's wallet work.

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
