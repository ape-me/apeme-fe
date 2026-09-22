import SwiftUI
import CoreImage.CIFilterBuiltins

/// Deposit: the active account's USDC address as QR + full address + copy / share. Polls quietly; toasts on arrival.
struct DepositSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var baseline: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Deposit").h2Text(); Spacer(); IconButton(symbol: "xmark", label: "Close") { dismiss() } }
            if let addr = app.walletAddress {
                HStack(spacing: 6) {
                    Image(systemName: "network").font(.system(size: 12, weight: .semibold))
                    Text("Solana network").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Theme.ink).padding(.horizontal, 11).frame(height: 30).background(Theme.surface2, in: .capsule)
                .frame(maxWidth: .infinity)

                ZStack {
                    qr(addr).interpolation(.none).resizable().scaledToFit().frame(width: 196, height: 196)
                    Image("usdc").resizable().frame(width: 40, height: 40).clipShape(.circle).padding(6).background(Color.white, in: .circle)
                }
                .padding(16).background(Color.white, in: .rect(cornerRadius: 20)).frame(maxWidth: .infinity)

                Text("Your USDC address").font(.sub).foregroundStyle(Theme.muted).frame(maxWidth: .infinity)
                Button { app.copy(addr) } label: {
                    HStack(spacing: 10) {
                        Text(addr).font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "doc.on.doc").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                    }
                    .padding(14).background(Theme.surface2, in: .rect(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                Text("Send USDC on the Solana network to this address. Other networks or tokens may be lost.")
                    .font(.sub).foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                HStack(spacing: 10) {
                    BigButton(label: "Copy address", style: .ghost) { app.copy(addr) }
                    ShareLink(item: addr) {
                        HStack(spacing: 8) { Image(systemName: "square.and.arrow.up").font(.system(size: 15, weight: .semibold)); Text("Share").font(.system(size: 17, weight: .semibold)) }
                            .foregroundStyle(Theme.ink).frame(maxWidth: .infinity).frame(height: 52).background(Theme.surface2, in: .capsule)
                    }
                }
            }
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
                if let b = baseline, app.cashUsd > b + 0.005 { app.show("Received \(Fmt.usd(app.cashUsd - b))"); dismiss(); return }
            }
        }
    }

    private func qr(_ text: String) -> Image {
        let f = CIFilter.qrCodeGenerator()
        f.message = Data(text.utf8); f.correctionLevel = "H"
        let ctx = CIContext()
        if let out = f.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)), let cg = ctx.createCGImage(out, from: out.extent) {
            return Image(decorative: cg, scale: 1)
        }
        return Image(systemName: "qrcode")
    }
}
