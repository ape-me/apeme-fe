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
Stonks247 lets you buy tokenized US stocks, ETFs and pre-IPO names on Solana, 24/7, from your phone. Sign in with email or Apple, fund the built-in wallet with USDC, and buy Apple, Nvidia, SpaceX or OpenAI in one tap. Live prices, order book depth, limit orders and a portfolio that shows real P&L.

**What to Test**
- Sign in (email code or Apple), wallet creation.
- Home: collections, movers, ticker. Stock page: chart ranges, insights, news.
- Buy and sell a stock with a small amount (USDC). Limit order placement and cancel.
- Portfolio: holdings, activity, the SOL refund line after a cancelled limit order.
- Crypto and Earn tabs.

**Beta App Review notes**
No demo account needed: sign in with any email, the 6-digit code arrives immediately. Trading uses the tester's own funds on Solana mainnet; a buy can be tested with $1 USDC. The app talks only to https://apme-be.iamjoey.workers.dev. Contact: darushyam143@gmail.com.

## Before the first external submission
- Privacy policy URL on the App Store Connect app record (a page on stonks247.fun).
- App Privacy answers: email address (account), wallet address and purchase history (app functionality), no tracking.
- 1024px icon is in the asset catalog already.
