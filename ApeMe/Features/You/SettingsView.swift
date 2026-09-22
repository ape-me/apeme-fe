import SwiftUI

/// Trading settings. Saves on change, optimistic; server copy replaces on success.
struct SettingsView: View {
    @Environment(AppState.self) private var app
    @State private var s: Me.Settings = Auth.shared.settings
    @State private var error: String?
    @State private var customSlippage = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) { BackButton(); Text("Settings").h2Text(); Spacer() }.padding(.horizontal, 12).padding(.top, 6).frame(height: 56)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    section("Slippage") {
                        chips([(10, "0.1%"), (50, "0.5%"), (100, "1%"), (300, "3%")], selected: s.slippageBps ?? 100) { s.slippageBps = $0; save(["slippageBps": $0]) }
                    }
                    section("Quick buy amounts") {
                        editableChips(values: s.quickBuyUsd ?? [], prefix: "$", max: 4) { s.quickBuyUsd = $0; save(["quickBuyUsd": $0]) }
                    }
                    section("Quick sell %") {
                        editableChips(values: s.quickSellPct ?? [], suffix: "%", max: 4) { s.quickSellPct = $0; save(["quickSellPct": $0]) }
                    }
                    section("Priority fee", note: "ApeMe pays the gas.") {
                        chips([("normal", "Normal"), ("fast", "Fast"), ("turbo", "Turbo")], selected: s.priority ?? "normal") { s.priority = $0; save(["priority": $0]) }
                    }
                    KCard {
                        toggle("Hide dust (< $0.01)", s.hideDust ?? false) { s.hideDust = $0; save(["hideDust": $0]) }
                    }
                    if let error { Text(error).font(.sub).foregroundStyle(Theme.red) }
                }
                .padding(.horizontal, 20).padding(.top, 8).padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.ground)
        .task { if let r = try? await API.shared.settings() { s = r; app.auth.applySettings(r) } }
    }

    private func save(_ patch: [String: Any]) {
        error = nil
        app.auth.applySettings(s)
        Task {
            do { let r = try await API.shared.patchSettings(patch); s = r; app.auth.applySettings(r) }
            catch { self.error = TradeStore.message(error) }
        }
    }

    private func section<C: View>(_ title: String, note: String? = nil, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 16, weight: .semibold)).tracking(-0.3)
            content()
            if let note { Text(note).font(.sub).foregroundStyle(Theme.muted) }
        }
    }

    private func chips<T: Hashable>(_ items: [(T, String)], selected: T, pick: @escaping (T) -> Void) -> some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.0) { v, label in
                Pill(label: label, on: v == selected) { pick(v) }
            }
        }
    }

    private func editableChips(values: [Double], prefix: String = "", suffix: String = "", max: Int, set: @escaping ([Double]) -> Void) -> some View {
        HStack(spacing: 8) {
            ForEach(values, id: \.self) { v in
                Pill(label: prefix + Fmt.n(v) + suffix, icon: values.count > 1 ? "xmark" : nil) { set(values.count > 1 ? values.filter { $0 != v } : values) }
            }
            if values.count < max {
                Menu {
                    ForEach(prefix == "$" ? [5.0, 10, 20, 25, 50, 100, 250, 500] : [10.0, 25, 50, 75, 100], id: \.self) { v in
                        if !values.contains(v) { Button(prefix + Fmt.n(v) + suffix) { set((values + [v]).sorted()) } }
                    }
                } label: { Pill(label: "+", size: .regular) {} }
            }
        }
    }

    private func toggle(_ title: String, _ on: Bool, set: @escaping (Bool) -> Void) -> some View {
        Button { Haptic.light(); set(!on) } label: {
            HStack { Text(title).font(.system(size: 15, weight: .medium)); Spacer(); SwitchShape(on: on, tint: Skin(mode: app.mode ?? .invest).accent) }
                .frame(minHeight: 52).contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
