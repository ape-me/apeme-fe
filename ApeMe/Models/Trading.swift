import Foundation

/// `POST /v1/swap/quote`
struct Quote: Codable, Hashable {
    struct Fee: Codable, Hashable { let bps: Int?; let amountRaw: String?; let mint: String?; let usd: Double? }
    struct Gas: Codable, Hashable { let paidBy: String?; let priority: String?; let lamports: Int?; let rentLamports: Int? }
    struct Signers: Codable, Hashable { let feePayer: String?; let user: String? }
    let requestId: String
    let side: String
    let inputMint: String
    let outputMint: String
    let symbol: String?
    let inAmount: String
    let outAmount: String
    let minOut: String?
    let inUsd: Double?
    let outUsd: Double?
    let priceImpactPct: Double?
    let slippageBps: Int?
    let fee: Fee?
    let gas: Gas?
    let premiumPct: Double?
    let markUsd: Double?
    let transaction: String
    let signers: Signers?
    let expiresAt: Int?
}

struct SubmitResponse: Codable { let signature: String; let status: String?; let requestId: String? }

/// `GET /v1/tx/:signature`
struct TxStatus: Codable { let signature: String?; let status: String; let slot: Int?; let confirmations: String?; let error: String? }

struct WalletsResponse: Codable { let wallets: [Me.WalletRef] }

/// `GET /v1/me/referrals`
struct Referrals: Codable, Hashable {
    struct Referred: Codable, Hashable, Identifiable { var id: String { userId }; let userId: String; let handle: String?; let joinedAt: Int?; let volumeUsd: Double? }
    struct Payout: Codable, Hashable, Identifiable { var id: String { signature }; let signature: String; let amountUsd: Double?; let paidAt: Int? }
    let code: String?
    let link: String?
    let invitesLeft: Int?
    let referred: [Referred]?
    let earnedUsd: Double?
    let claimableUsd: Double?
    let payouts: [Payout]?
}

struct ClaimResponse: Codable { let signature: String?; let amountUsd: Double?; let to: String? }
struct OkResponse: Codable { let ok: Bool? }
