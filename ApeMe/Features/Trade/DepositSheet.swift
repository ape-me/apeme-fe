import SwiftUI
import CoreImage.CIFilterBuiltins

/// Deposit: the active account's USDC address as QR + full address + copy / share. Polls quietly; toasts on arrival.
struct DepositSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var baseline: Double?
    /// The content's own height, so the sheet opens to exactly that and no further.
    @State private var height: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { Text("Deposit").h2Text(); Spacer(); IconButton(symbol: "xmark", label: "Close") { dismiss() } }
            if let addr = app.walletAddress {
                HStack(spacing: 6) {
                    Image(systemName: "network").font(.system(size: 12, weight: .semibold))
                    Text("Solana network").font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Theme.ink).padding(.horizontal, 11).frame(height: 30).background(Theme.surface2, in: .capsule)
                .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                .frame(maxWidth: .infinity)

                ZStack {
                    qr(addr).interpolation(.none).resizable().scaledToFit().frame(width: 196, height: 196)
                    Image("usdc").resizable().frame(width: 40, height: 40).clipShape(.circle).padding(6).background(Color.white, in: .circle)
                }
                .padding(16).background(Theme.surface, in: .rect(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1))
                .frame(maxWidth: .infinity)

                Text("Your USDC address").font(.sub).foregroundStyle(Theme.muted).frame(maxWidth: .infinity)
                Button { app.copy(addr) } label: {
                    HStack(spacing: 10) {
                        Text(addr).font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(Theme.ink).multilineTextAlignment(.leading)
                        Spacer()
                        Image(systemName: "doc.on.doc").font(.system(size: 15, weight: .medium)).foregroundStyle(Theme.muted)
                    }
                    .padding(14).background(Theme.surface, in: .rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                Text("Send USDC on the Solana network to this address. Other networks or tokens may be lost.")
                    .font(.sub).foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: .infinity)
                HStack(spacing: 10) {
                    BigButton(label: "Copy address", style: .ghost) { app.copy(addr) }
                    ShareLink(item: addr) {
                        HStack(spacing: 8) { Image(systemName: "square.and.arrow.up").font(.system(size: 15, weight: .semibold)); Text("Share").font(.instrument(16, 600)) }
                            .foregroundStyle(Theme.ink).frame(maxWidth: .infinity).frame(height: 52)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1.5))
                    }
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 18)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .frame(maxWidth: .infinity, alignment: .top)
        // No empty sheet below the buttons: the detent is the content's height, and only a
        // phone too short for it gets the full sheet with a scroll.
        .presentationDetents(height > 0 ? [.height(height + 10)] : [.large])
        .presentationBackground(Theme.ground)
        .presentationDragIndicator(.visible)
        .task {
            await app.loadWallet(fresh: true)
            baseline = app.cashUsd
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                await app.loadWallet(fresh: true)
                if let b = baseline, app.cashUsd > b + 0.005 { Haptic.success(); app.show("Received \(Fmt.usd(app.cashUsd - b))"); dismiss(); return }
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
