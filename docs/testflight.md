# TestFlight

Team `PYU86V9YNF`, bundle `fun.apeme.app`, display name Stonks247, iOS 17+, iPhone only.

## Ship a build (Mac)
1. Bump `CURRENT_PROJECT_VERSION` (build number) on every upload; `MARKETING_VERSION` stays 0.1 until launch.
2. Product → Archive on the Release scheme, Distribute → App Store Connect → Upload. Automatic signing handles the profile.
3. Export compliance is answered by `ITSAppUsesNonExemptEncryption = NO` in Info.plist (HTTPS only, no custom crypto).

## Internal (team, no review)
App Store Connect → TestFlight → Internal Testing → group "Team". Add App Store Connect users, tick "automatic distribution". Build is installable within minutes of processing.

## External (public link, judges)
1. TestFlight → External Testing → group "Judges", enable public link, cap 1,000.
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
- **Deploy the legal pages.** `docs/legal/privacy.html` and `docs/legal/terms.html` go live at
  `stonks247.fun/privacy` and `/terms`. Both paths currently fall through to the landing page, and
  App Store Connect will not let you add external testers without a working Privacy Policy URL. The
  app links to both from the welcome screen and from You → Privacy Policy.
- **Make `support@stonks247.fun` receive mail** (Cloudflare Email Routing). Both pages route data and
  deletion requests there.
- App Privacy answers: email address (account), wallet address and purchase history (app functionality), no tracking.
- 1024px icon is in the asset catalog already.

## Known gaps
- **No in-app account deletion.** Guideline 5.1.1(v) requires it for any app that creates an account.
  Beta App Review rarely stops on it; App Store submission will. Needs a BE endpoint plus a Privy
  delete call, so it is not a front-end-only fix.
