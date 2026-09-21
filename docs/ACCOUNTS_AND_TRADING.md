# ApeMe iOS — Accounts, Wallet, Trading, Invites (BE brief, Tue 22 Sep 2026)

Everything below is live on `https://apme-be.iamjoey.workers.dev`. All shapes are real responses. Build these screens in this order; each one is verifiable against prod before moving on.

Base rules
- Reads (`/v1/floor`, `/v1/stocks`, `/v1/tokens`, `/v1/wallet/:address`, WS) stay public.
- Everything under `/v1/me/*`, `/v1/swap/*` needs header `privy-id-token: <user.getIdentityToken()>`. 401 = token missing/invalid → re-login.
- `/v1/swap/*` also needs an activated account. 403 `{ "error": "invite_required" }` → show the Invite screen.
- Error body is always `{ "error": "<code or message>", "requestId": "<cf-ray>" }`. Send `requestId` to Joey when something looks wrong.
- Money is always shown in $ first; token amounts second, smaller. Dust (< $0.01) hidden when `settings.hideDust`.
- Dark UI only.

---

## 1. Sign in

Privy Swift SDK, headless. No Privy UI anywhere.

| Control | Call |
|---|---|
| Continue with Apple (`ASAuthorizationAppleIDButton`) | `privy.oAuth.login(with: .apple)` |
| Email → Send code | `privy.email.sendCode(to:)` |
| 6-digit code → Continue | `privy.email.loginWithCode(_:sentTo:)` |
| after either | `user.createSolanaWallet()` (no-op if exists) → `GET /v1/me` |

Config: App ID `cmubdpllu01d00cl2p2q2n6h6`, Client ID `client-WY6dwtnFJ1tfTakEeB1yNpEKTvshPSvbYa6DP2h7Cohay`, bundle `fun.apeme.app`, URL scheme `apeme`.
States: idle · sending code · wrong code · creating wallet (2–3 s; show "Creating your wallet…") · done → route on `/v1/me.status`.
Apple login occasionally fails with Privy `invalid_data "Failed to fetch JWKS"`: retry once silently.

`GET /v1/me` (creates the user on first call)
```json
{ "userId": "did:privy:cmuc0…", "handle": null, "avatarUrl": null, "status": "invite_required",
  "wallets": [ { "address": "7ov6…8oEh", "chain": "solana", "hdIndex": 0, "label": "Main", "isDefault": true, "createdAt": 1790010000 } ],
  "settings": { "slippageBps": 100, "quickBuyUsd": [10,25,50,100], "quickSellPct": [25,50,100], "priority": "normal", "confirmBeforeTrade": true, "hideDust": false },
  "referral": { "code": "K7X2P9", "invitesLeft": 5, "earnedUsd": 0 }, "createdAt": 1790010000 }
```
Route: `status == "invite_required"` → Invite screen (browsing the floor still allowed). `"active"` → app.

---

## 2. Invite gate

One screen: "ApeMe is invite-only. Enter your code." Input (uppercase, 6–8 chars), paste-from-clipboard prefill, Continue.

`POST /v1/me/invite` `{ "code": "XNX5KWW6" }` → `{ "ok": true, "status": "active" }`
Errors: 404 `invite code not found` · 410 `invite code used up or expired` · 409 `already activated` · 400 `you cannot use your own code`.
After success: re-fetch `/v1/me`, proceed. Codes are case-insensitive.

---

## 3. Wallet tab

Top: **cash balance** `cashUsd` big ("$969.35"), under it `totalUsd` ("Portfolio $970.95") and `pnlUsd` (green/red). Buttons: **Deposit**, **Withdraw** (disabled, "soon"). Account switcher in the header (section 8).
Then **Positions** (holdings with `kind` stock|meme, sorted by value) and **Activity** (section 7).

`GET /v1/wallet/:address?activity=30` (public; `:address` = active account)
```json
{ "address": "BaJV…99eS", "totalUsd": 970.95, "cashUsd": 969.35, "solUsd": 0.7, "stocksUsd": 0.9, "memesUsd": 0,
  "costUsd": 0, "pnlUsd": 0, "realizedUsd": 0, "pendingSwaps": 0,
  "holdings": [
    { "mint": "EPjF…Dt1v", "kind": "cash", "symbol": "USDC", "name": "Cash", "image": "…/logo.png", "amount": 969.346606, "raw": "969346606", "decimals": 6, "priceUsd": 1, "valueUsd": 969.35, "change24h": null, "costUsd": null, "pnlUsd": null, "pnlPct": null },
    { "mint": "Xspz…dRMX", "kind": "stock", "symbol": "MSFTX", "name": "MSFT", "image": "https://www.stonkfun.xyz/api/asset/quote-logo/Xspz…", "amount": 0.0018038, "raw": "178271", "decimals": 8, "priceUsd": 500.19, "valueUsd": 0.9, "change24h": 1.02, "costUsd": null, "pnlUsd": null, "pnlPct": null }
  ],
  "activity": [ … see section 7 … ], "asOf": 1790019400 }
```
- `holdings[0]` is always the cash row (`kind: "cash"`); render it as the balance, not as a position.
- `kind: "sol"` appears only if the wallet has SOL; show it as a small row, not a position.
- `raw` + `decimals` are what you send to `/v1/swap/quote` when selling. Never compute raw from `amount` (stocks have a multiplier).
- `costUsd`/`pnlUsd` are null until the wallet has bought through ApeMe.
- Empty state: `cashUsd == 0 && holdings.length <= 1` → "Deposit USDC to start" with the Deposit button as hero.

Freshness: fetch on tab open, pull-to-refresh, every 5 s while the Deposit sheet is open, once after a confirmed swap. If `pendingSwaps > 0`, poll every 3 s until 0.

---

## 4. Deposit sheet

Shows the active account's address, QR, Copy button. Text: **"Send USDC on the Solana network to this address. Other networks or tokens may be lost."** Sub-line: "Works from Phantom, Coinbase, Binance, any Solana wallet."
While open: poll `/v1/wallet/:address` every 5 s; when `cashUsd` rises show a toast "Received $20.00" and close. No BE call to create anything: the address is the Privy wallet.

---

## 5. Buy sheet (from a stock page or meme page)

Layout: amount in **$** with quick chips from `settings.quickBuyUsd` ($10 / $25 / $50 / $100) + custom. Under it "You get ≈ 0.4346 NVDAx". Line: **"Nasdaq $224.05 · here +0.09%"** (from quote `markUsd`, `premiumPct`; for memes hide the line). Row: "Fee $0.01 · Gas free". ⚡ priority chip (default from settings; turbo only offered when amount ≥ $50). Warning band if `premiumPct > 5`: "You're paying X% over the Nasdaq price." Primary button "Buy $25 of NVDAx". If `settings.confirmBeforeTrade`, a confirm step.

`POST /v1/swap/quote` — call on every amount change, debounced 300 ms. `amount` is raw USDC (× 1,000,000).
```json
{ "inputMint": "usdc", "outputMint": "Xsc9qvGR1efVDFGLrVsmkzv3qi45LTBjeUKSPmx9qEh", "amount": "25000000", "taker": "<active account address>", "priority": "normal" }
```
Response
```json
{ "requestId": "8f0c3a2e-…", "side": "buy", "inputMint": "EPjF…Dt1v", "outputMint": "Xsc9…9qEh", "symbol": "NVDAX",
  "inAmount": "25000000", "outAmount": "10864675", "minOut": "10756028",
  "inUsd": 25.0, "outUsd": 24.75, "priceImpactPct": 0.0, "slippageBps": 100,
  "fee": { "bps": 100, "amountRaw": "250000", "mint": "EPjF…Dt1v", "usd": 0.25 },
  "gas": { "paidBy": "apeme", "priority": "normal", "lamports": 10469, "rentLamports": 2039280 },
  "premiumPct": 0.09, "markUsd": 224.05,
  "transaction": "<base64 unsigned v0 tx>", "signers": { "feePayer": "95VX…XjYu", "user": "<taker>" }, "expiresAt": 1790010060 }
```
"You get" = `outAmount / 10^decimals × multiplier` for stocks (decimals + multiplier from `/v1/stocks/:mint`), `outAmount / 10^decimals` for memes.
Errors (422 unless noted): `usdc_only` · `no_route` · `amount_too_small` · 404 `token not found` · 403 `taker is not one of your wallets` · 503 `gas_wallet_not_configured` (should never happen; tell Joey).
Insufficient cash is a client check: `inUsd > cashUsd` → disable Buy, show "Deposit".

Sign (user is a signer, not the fee payer; two signature slots):
```swift
var tx = try VersionedTransaction.deserialize(Data(base64Encoded: q.transaction)!)
let msg = tx.message.serialize()
let sigB64 = try await wallet.provider.signMessage(message: msg.base64EncodedString())
try tx.addSignature(publicKey: userPubkey, signature: Data(base64Encoded: sigB64)!)
let signed = tx.serialize().base64EncodedString()
```

`POST /v1/swap/submit` `{ "requestId": "8f0c3a2e-…", "signedTransaction": "<base64>" }` → `{ "signature": "5Kd…", "status": "submitted", "requestId": "8f0c3a2e-…" }`
Errors: 410 `quote_expired` (re-quote silently and retry once) · 422 `slippage` ("Price moved. Try again.") · 422 `insufficient_funds` (show Deposit) · 422 `transaction does not match the quote` (bug, report) · 429 `too many trades this hour` · 409 `quote already submitted`.

Then poll `GET /v1/tx/<signature>` every 1 s (public):
`{ "signature": "5Kd…", "status": "pending" }` → `{ "status": "confirmed", "slot": 372114201, "confirmations": "confirmed" }` or `{ "status": "failed", "error": "expired" | "<program error>" }`.
Confirmed: success state ("You own 0.4346 NVDAx"), refresh the wallet. Failed `expired`: re-quote and retry once. Other failure: show error, keep the sheet.
States: quoting · ready · insufficient · signing · submitting · confirming (spinner ≤ 5 s) · confirmed · failed.

---

## 6. Sell sheet

Same as Buy, reversed. Amount as % chips from `settings.quickSellPct` (25 / 50 / 100) of the holding, or custom token amount. `amount` = `floor(holding.raw × pct / 100)` as a string. `inputMint` = stock/meme mint, `outputMint: "usdc"`. "You get ≈ $24.60" from `outUsd` (already net of fee). Everything else identical.

---

## 7. Activity

Rows from `/v1/wallet/:address.activity`, newest first, switch on `type`:
```json
{ "sig": "4B27…Z2fK", "ts": 1790019028, "type": "sell", "status": "confirmed", "source": "chain", "side": "sell",
  "mint": "DEW9…8WDP", "symbol": "SI", "image": "…webp", "stockSymbol": "NVDAX", "amount": 230603.33, "quote": 1.9967, "usd": 454.93, "feeUsd": null, "from": null, "error": null }
```
| `type` | Row |
|---|---|
| `buy` | "Bought 0.4346 NVDAx · $25.00" (+ "fee $0.25" when `feeUsd`) |
| `sell` | "Sold 0.30 NVDAx · $0.68" |
| `deposit` | "Received $20.00 USDC" (`from` = sender, short) |
| `withdraw` | "Sent $20.00 USDC" |

`status`: `pending` → grey pill + spinner; `failed` → red pill, `error` text under it; `confirmed` → nothing. `source: "apeme"` rows are ours (have `feeUsd`); `"chain"` rows are seen on chain. Tap → `https://solscan.io/tx/<sig>` when `sig` is non-null. Empty: "Nothing yet."

---

## 8. Accounts (Phantom-style multi-wallet)

Header of the Wallet tab shows the active account label; tap → list.
`GET /v1/me/wallets` → `{ "wallets": [ { "address", "chain", "hdIndex", "label", "isDefault", "createdAt" } ] }`
Row: label, short address, $ balance (fetch `/v1/wallet/:address` per row, `totalUsd`), default tick. Tap → becomes active for the whole app (store locally; every `taker` and every `/v1/wallet/:address` uses it).
"+ New account": Privy `createSolanaWallet` with the additional-wallet flag (confirm the Swift param name; if the SDK doesn't expose it for Solana, tell Joey and BE will create it server-side) → then `GET /v1/me` (BE syncs new wallets from the token automatically).
`PATCH /v1/me/wallets/:address` `{ "label": "Degen" }` or `{ "isDefault": true }` → `{ wallets: […] }`.

---

## 9. Settings (gear)

`GET /v1/me/settings` → `{ "slippageBps": 100, "quickBuyUsd": [10,25,50,100], "quickSellPct": [25,50,100], "priority": "normal", "confirmBeforeTrade": true, "hideDust": false }`
`PATCH /v1/me/settings` with any subset. Validation: slippageBps 10–500; 1–4 presets each; priority normal|fast|turbo.
Rows: Slippage (0.1 / 0.5 / 1 / custom %) · Quick buy amounts (editable chips) · Quick sell % (editable chips) · Priority fee (Normal / Fast / Turbo, note "ApeMe pays the gas") · Confirm before trade (toggle) · Hide dust (toggle). Save on change, optimistic.

---

## 10. Profile

Who you are, nothing about trading. Handle (editable, `[a-z0-9_]{3,20}`), avatar, member since, **Invite & earn** card (code, Share, invites left, earned $), Sign out.
`PATCH /v1/me` `{ "handle": "joey" }` → full `/v1/me` shape. 409 `handle taken`.

---

## 11. Invite & earn

`GET /v1/me/referrals`
```json
{ "code": "K7X2P9", "link": "https://apeme.fun/i/K7X2P9", "invitesLeft": 5,
  "referred": [ { "userId": "did:privy:…", "handle": "sam", "joinedAt": 1790012000, "volumeUsd": 120.5 } ],
  "earnedUsd": 0.24, "claimableUsd": 0.24, "payouts": [ { "signature": "3x…", "amountUsd": 1.1, "paidAt": 1790013000 } ] }
```
Big code + Share sheet with `link`. "5 invites left". List of referred users with volume. Earnings: earned / claimable, **Claim $X** button (disabled under $1), payout history with Solscan links. Copy: "You earn 20% of ApeMe's fee on every trade they make, forever."
`POST /v1/me/referrals/claim` → `{ "signature": "…", "amountUsd": 1.1, "to": "<default wallet>" }`. 422 `claimable $0.24 is under the $1 minimum` · 503 `payout wallet is being topped up, try again later`.

---

## 12. Watchlist (star on stock pages)

`PUT /v1/me/watchlist/:mint` / `DELETE /v1/me/watchlist/:mint` → `{ ok: true }`. `GET /v1/me/watchlist` → `{ "stocks": [ Stock… ] }` (same Stock shape as `/v1/stocks`). Use for a "Starred" filter on the stocks list.

---

## 13. Live data (unchanged, still public)

`wss://apme-be.iamjoey.workers.dev/ws/floor`, `/ws/stock:<mint>`, `/ws/<mint>`. Frames arrive as JSON arrays; types `trade`, `token`, `price` (stock rooms, every 5 s). No auth on WS.

---

## Test data

Invite codes (5 uses each): `XNX5KWW6`, `NYRP2X2Y`, `6AWUE2K8`. First real buy: deposit $1.50 USDC to your Privy wallet, buy $1 NVDAx, send Joey the `requestId` + `signature`.
