import Foundation

/// Switches for work that exists but is not being shown yet.
enum Feature {
    /// The meme side: floors, kings, the live tape, new launches, and anything priced in a stock
    /// rather than USDC. Hidden for the hackathon — the pitch is tokenized equities that do not
    /// feel like crypto, and a memecoin floor next to that splits the story.
    ///
    /// Nothing was removed. `FloorView`, `TokenView`, their stores and models are all still here
    /// and still compile; the backend still serves `/v1/floor`, `/v1/tokens` and the socket rooms.
    /// Set this to `true` and every one of those screens comes back.
    static let ape = false

    /// Invite & earn — the referral code, the invites left, the share sheet behind it. Out of the
    /// pitch for now; the screen and the route are untouched.
    static let referrals = false

    /// Toast previews and the raw `/v1/me` dump. They are already `#if DEBUG`, but the build on
    /// a test phone is a debug build, so they show up in demos. Flip this to get them back while
    /// working; they can never reach a release build either way.
    static let debugTools = false
}
