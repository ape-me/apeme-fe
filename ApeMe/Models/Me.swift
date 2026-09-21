import Foundation

/// `GET /v1/me`. Created on the first call after login.
struct Me: Codable, Hashable {
    struct WalletRef: Codable, Hashable {
        let address: String
        let chain: String?
        let label: String?
        let isDefault: Bool?
        let hdIndex: Int?
    }
    struct Settings: Codable, Hashable {
        let slippageBps: Int?
        let quickBuyUsd: [Double]?
        let quickSellPct: [Double]?
        let priority: String?
        let confirmBeforeTrade: Bool?
        let hideDust: Bool?
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
