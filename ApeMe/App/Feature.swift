import Foundation

/// Switches for work that exists but is not being shown yet.
enum Feature {
    /// Invite & earn — the referral code, the invites left, the share sheet behind it. Out of the
    /// pitch for now; the screen and the route are untouched.
    static let referrals = false

    /// Toast previews and the raw `/v1/me` dump. They are already `#if DEBUG`, but the build on
    /// a test phone is a debug build, so they show up in demos. Flip this to get them back while
    /// working; they can never reach a release build either way.
    static let debugTools = false
}
