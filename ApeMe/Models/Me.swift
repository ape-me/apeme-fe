import Foundation

/// `GET /v1/me`. Created on the first call after login.
struct Me: Codable, Hashable {
    struct WalletRef: Codable, Hashable, Identifiable {
        var id: String { address }
        let address: String
        let chain: String?
        let label: String?
        let isDefault: Bool?
        let hdIndex: Int?
        let createdAt: Int?
    }
    struct Settings: Codable, Hashable {
        var slippageBps: Int?
        var quickBuyUsd: [Double]?
        var quickSellPct: [Double]?
        var priority: String?
        var confirmBeforeTrade: Bool?
        var hideDust: Bool?

        static let defaults = Settings(slippageBps: 100, quickBuyUsd: [10, 25, 50, 100], quickSellPct: [25, 50, 100], priority: "normal", confirmBeforeTrade: true, hideDust: false)
    }
    struct Referral: Codable, Hashable {
        let code: String?
        let invitesLeft: Int?
        let earnedUsd: Double?
    }

    let userId: String
    let handle: String?
    let avatarUrl: String?
    let status: String            // "invite_required" | "active"
    let wallets: [WalletRef]?
    let settings: Settings?
    let referral: Referral?
    let createdAt: Int?            // unix seconds

    var needsInvite: Bool { status == "invite_required" }
}

struct InviteResponse: Codable { let ok: Bool?; let status: String? }
