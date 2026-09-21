import Foundation
import PrivySDK

/// Enough Solana to co-sign a v0 transaction the backend built: the user's slot is filled, the fee payer's stays empty.
enum SolanaTx {
    enum Error: Swift.Error { case badTransaction, signerNotFound }

    /// Preferred path: Privy signs the serialized transaction and returns it base64, other slots untouched.
    static func sign(_ base64: String, with wallet: any EmbeddedSolanaWallet) async throws -> String {
        guard let data = Data(base64Encoded: base64) else { throw Error.badTransaction }
        do {
            return try await wallet.provider.signTransaction(transaction: data)
        } catch {
            // Fall back to signing the message bytes and placing the signature ourselves.
            return try await signManually(data, with: wallet)
        }
    }

    static func signManually(_ tx: Data, with wallet: any EmbeddedSolanaWallet) async throws -> String {
        let bytes = [UInt8](tx)
        var i = 0
        let (sigCount, n) = compactU16(bytes, at: i); i += n
        let sigStart = i
        i += sigCount * 64
        let message = Array(bytes[i...])
        // message: [0x80 | version] header(3) compact-u16 keys … — keys are 32 bytes each, first `numRequired` are signers.
        var m = 0
        if message[m] & 0x80 != 0 { m += 1 }                // version prefix
        let numRequired = Int(message[m]); m += 3
        let (keyCount, kn) = compactU16(message, at: m); m += kn
        let me = base58Decode(wallet.address)
        var slot: Int?
        for k in 0..<min(keyCount, numRequired) {
            if Array(message[m + k*32 ..< m + k*32 + 32]) == me { slot = k; break }
        }
        guard let slot else { throw Error.signerNotFound }
        let sigB64 = try await wallet.provider.signMessage(message: Data(message).base64EncodedString())
        guard let sig = Data(base64Encoded: sigB64), sig.count == 64 else { throw Error.badTransaction }
        var out = bytes
        out.replaceSubrange(sigStart + slot*64 ..< sigStart + slot*64 + 64, with: [UInt8](sig))
        return Data(out).base64EncodedString()
    }

    private static func compactU16(_ b: [UInt8], at start: Int) -> (Int, Int) {
        var v = 0, shift = 0, i = start
        while i < b.count {
            let byte = Int(b[i]); v |= (byte & 0x7f) << shift; i += 1
            if byte & 0x80 == 0 { break }
            shift += 7
        }
        return (v, i - start)
    }

    static func base58Decode(_ s: String) -> [UInt8] {
        let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
        var map = [Character: Int](); for (i, c) in alphabet.enumerated() { map[c] = i }
        var bytes: [UInt8] = []
        for c in s {
            guard var carry = map[c] else { return [] }
            for j in 0..<bytes.count { carry += Int(bytes[j]) * 58; bytes[j] = UInt8(carry & 0xff); carry >>= 8 }
            while carry > 0 { bytes.append(UInt8(carry & 0xff)); carry >>= 8 }
        }
        for c in s { if c == "1" { bytes.append(0) } else { break } }
        return bytes.reversed()
    }
}
