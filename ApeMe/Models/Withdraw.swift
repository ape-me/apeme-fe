import Foundation

/// A withdrawal Stonks247 pays for: our fee is zero, the network fee is the backend's, and the
/// recipient's token account rent is too. What leaves is the amount, less the issuer's own transfer
/// fee on the tokens that charge one.
struct WithdrawQuote: Codable, Hashable {
    struct Fee: Codable, Hashable { let bps: Int?; let usd: Double? }
    struct Gas: Codable, Hashable { let paidBy: String? }
    struct Rent: Codable, Hashable { let lamports: Int?; let paidBy: String? }
    struct Signers: Codable, Hashable { let feePayer: String?; let user: String? }

    let requestId: String
    let from: String
    let to: String
    let mint: String
    let symbol: String?
    let amount: String
    let decimals: Int?
    let usd: Double?
    let fee: Fee?
    /// PreStocks take 1–3% on transfer, so the recipient gets less than `amount`.
    let issuerFeeBps: Int?
    let gas: Gas?
    let rent: Rent?
    let transaction: String
    let signers: Signers?
    let expiresAt: Int?

    var issuerFeeRate: Double { Double(issuerFeeBps ?? 0) / 10_000 }
    var recipientGetsUsd: Double? { usd.map { $0 * (1 - issuerFeeRate) } }
}

struct WithdrawSubmitResponse: Codable { let signature: String?; let requestId: String?; let status: String? }
struct WithdrawStatus: Codable { let requestId: String?; let signature: String?; let status: String? }
