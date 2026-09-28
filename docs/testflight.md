# TestFlight

Team `PYU86V9YNF`, bundle `fun.apeme.app`, display name Stonks247, iOS 17+, iPhone only.

## Ship a build (Mac)
1. Bump `CURRENT_PROJECT_VERSION` (build number) on every upload; `MARKETING_VERSION` stays 0.1 until launch.
2. Product → Archive on the Release scheme, Distribute → App Store Connect → Upload. Automatic signing handles the profile.
3. Export compliance is answered by `ITSAppUsesNonExemptEncryption = NO` in Info.plist (HTTPS only, no custom crypto).

## Internal
None. Everyone, us included, installs through the external public link.

## External (public link, everyone)
1. TestFlight → External Testing → group "Public", enable public link, cap 10,000. Add the team's emails to the same group so we get builds the moment review clears.
2. Fill Test Information (below) and submit the first build for Beta App Review. Expect 1–2 days the first time, hours after.
3. Every later build on the same version goes out without a new review unless it changes materially.

## Test Information
**Beta App Description**
Stonks247 lets you buy tokenized US stocks, ETFs and pre-IPO names on Solana, 24/7, from your phone. Sign in with email or Apple, fund the built-in wallet with USDC, and buy Apple, Nvidia, OpenAI or Anthropic in one tap. Live prices, order book depth, limit orders and a portfolio that shows real P&L.

**What to Test**
- Sign in (email code or Apple), wallet creation.
- Home: collections, movers, ticker. Stock page: chart ranges, insights, news.
- Buy and sell a stock with a small amount (USDC). Limit order placement and cancel.
- Portfolio: holdings, activity, the SOL refund line after a cancelled limit order.
- Crypto and Earn tabs.

**Beta App Review notes**
Sign in with any email — the 6-digit code arrives immediately. The app is invite-only, so at the
invite screen after sign-in enter code APPLEREVIEW. Everything is reachable from there; without the
code the app stops at that screen. Trading uses the tester's own funds on Solana mainnet; a buy can be tested with $1 USDC. The app talks only to https://apme-be.iamjoey.workers.dev. Contact: darushyam143@gmail.com.

## Before the first external submission
- Privacy Policy URL: `https://stonks247.fun/privacy` — live. Terms: `https://stonks247.fun/terms`.
  Source is `docs/legal/`; the app links to both from the welcome screen and from You.
- App Privacy answers: email address (account), wallet address and purchase history (app functionality), no tracking.
- 1024px icon is in the asset catalog already.
- Account deletion is in You → Delete account (`DELETE /v1/me`), which covers 5.1.1(v).

## Outstanding
- `support@stonks247.fun` has to receive mail before submission — both legal pages route data and
  deletion requests there.
