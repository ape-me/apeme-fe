import SwiftUI
import CoreImage.CIFilterBuiltins

/// Deposit: the active account's address as QR + copy. Polls the wallet every 5 s and closes on arrival.
struct DepositSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var baseline: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Deposit USDC").h2Text()
                Spacer()
                IconButton(symbol: "xmark", label: "Close") { dismiss() }
            }
            if let addr = app.walletAddress {
                qr(addr).frame(width: 200, height: 200).frame(maxWidth: .infinity)
                    .padding(16).background(Color.white, in: .rect(cornerRadius: 20)).frame(maxWidth: .infinity)
                Button { app.copy(addr) } label: {
                    HStack(spacing: 10) {
                        Text(addr).font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(Theme.ink).lineLimit(2).multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "doc.on.doc").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.ink)
                    }
                    .padding(14).background(Theme.surface2, in: .rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                BigButton(label: "Copy address", style: .white) { app.copy(addr) }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Send USDC on the Solana network to this address. Other networks or tokens may be lost.").font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.ink)
                Text("Works from Phantom, Coinbase, Binance, any Solana wallet.").font(.sub).foregroundStyle(Theme.muted)
            }
            HStack(spacing: 8) { ProgressView().tint(Theme.muted); Text("Watching for your deposit…").font(.sub).foregroundStyle(Theme.muted) }
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 18)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.large])
        .presentationBackground(Theme.surface)
        .presentationDragIndicator(.visible)
        .task {
            await app.loadWallet(fresh: true)
            baseline = app.cashUsd
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                await app.loadWallet(fresh: true)
                if let b = baseline, app.cashUsd > b + 0.005 {
                    app.show("Received \(Fmt.usd(app.cashUsd - b))")
                    dismiss(); return
                }
            }
        }
    }

    private func qr(_ text: String) -> Image {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(text.utf8); f.correctionLevel = "M"
        let ctx = CIContext()
        if let out = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)), let cg = ctx.createCGImage(out, from: out.extent) {
            return Image(decorative: cg, scale: 1).interpolation(.none)
        }
        return Image(systemName: "qrcode")
    }
}
