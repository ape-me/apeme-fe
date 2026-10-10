import SwiftUI

/// Describe an idea; the AI picks the stocks and weights and hands back a basket. One ask, one
/// result: the result is an ordinary basket page.
struct BuildBasketView: View {
    var idea: String = ""
    @Environment(AppState.self) private var app
    @State private var text: String
    @State private var ideas: [String] = []
    @State private var mine: [AIBasketRef] = []
    @State private var building = false
    @State private var step = 0
    @State private var error: String?
    @State private var examples: [String] = []
    @State private var task: Task<Void, Never>?
    @FocusState private var focused: Bool

    init(idea: String = "") { self.idea = idea; _text = State(initialValue: idea) }

    private static let steps = ["Reading your idea", "Finding stocks", "Checking the news", "Setting weights"]
    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var valid: Bool { (3...200).contains(trimmed.count) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) { BackButton().disabled(building); Spacer() }
                .padding(.horizontal, 12).padding(.top, 6).frame(height: 56)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if building { progress } else { ask }
                }
                .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 24)
                .containerRelativeFrame(.horizontal, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Theme.ground)
        .task {
            ideas = (try? await API.shared.basketIdeas().ideas) ?? []
            if app.signedIn, let r = try? await API.shared.myAIBaskets() { mine = r.baskets }
        }
        .onAppear { if text.isEmpty { focused = true } }
        .onDisappear { task?.cancel() }
    }

    // MARK: The ask

    private var ask: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Build a basket").h1Text()
                Text("Say what you believe in a sentence. The AI picks the stocks and sets the mix.")
                    .font(.body15).foregroundStyle(Theme.muted).fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .trailing, spacing: 6) {
                TextField("AI needs way more power", text: $text, axis: .vertical)
                    .lineLimit(3...6)
                    .font(.system(size: 18, weight: .medium)).foregroundStyle(Theme.ink)
                    .focused($focused)
                    .padding(14)
                    .background(Theme.surface, in: .rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(focused ? Theme.accent : Theme.line, lineWidth: focused ? 1.5 : 1))
                    .onChange(of: text) { _, v in if v.count > 200 { text = String(v.prefix(200)) } }
                Text("\(trimmed.count)/200").font(.system(size: 11)).monospacedDigit().foregroundStyle(trimmed.count >= 200 ? Theme.red : Theme.faint)
            }
            if let error {
                ErrorBar(text: error).padding(.horizontal, -20)
                if !examples.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Try something like").font(.sub).foregroundStyle(Theme.muted)
                        FlowChips(items: examples) { e in Pill(label: e, size: .small) { text = e; self.error = nil; examples = [] } }
                    }
                }
            }
            BigButton(label: "Build", style: valid ? .cta : .off) { guard valid else { return }; build() }
                .disabled(!valid)
            if !ideas.isEmpty, examples.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Or start from one of these").font(.sub).foregroundStyle(Theme.muted)
                    FlowChips(items: ideas) { i in Pill(label: i, on: text == i, size: .small) { text = i; focused = false } }
                }
            }
            if !mine.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    SectionTitle("Your ideas").padding(.top, 6)
                    KCard {
                        ForEach(mine) { b in
                            Button { app.push(.basket(b.id)) } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(b.name).font(.rowTitle).lineLimit(1)
                                        Text(b.idea ?? b.tagline ?? "").font(.sub).foregroundStyle(Theme.muted).lineLimit(1)
                                    }
                                    Spacer(minLength: 8)
                                    Text("\(b.tickers?.count ?? 0) stocks").font(.sub).foregroundStyle(Theme.faint)
                                    Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.faint)
                                }
                                .padding(.vertical, 12).contentShape(.rect)
                            }
                            .buttonStyle(RowPress())
                        }
                    }
                }
            }
            Text("AI picks, not advice. Check the stocks before you buy.").font(.system(size: 11)).foregroundStyle(Theme.faint)
        }
    }

    // MARK: Building

    /// The cover's wash where the cover will be, the idea quoted, four steps that tick on a
    /// clock, and a way out. Nothing jumps when the real page replaces it.
    private var progress: some View {
        VStack(alignment: .leading, spacing: 22) {
            RoundedRectangle(cornerRadius: 16).fill(BasketTint.gradient).frame(height: 150)
                .overlay(alignment: .bottomLeading) {
                    HStack(spacing: -11) {
                        ForEach(0..<5, id: \.self) { _ in Circle().fill(Theme.surface.opacity(0.7)).frame(width: 36, height: 36).overlay(Circle().stroke(Theme.surface, lineWidth: 2)) }
                    }
                    .padding(20)
                }
            Text("“\(trimmed)”").font(.system(size: 20, weight: .semibold)).tracking(-0.4).fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 14) {
                ForEach(Array(Self.steps.enumerated()), id: \.offset) { i, s in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().stroke(i < step ? Theme.green : i == step ? Theme.accent : Theme.line, lineWidth: 1.5).frame(width: 22, height: 22)
                            if i < step { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(Theme.green) }
                            else if i == step { ProgressView().tint(Theme.accent).scaleEffect(0.6) }
                        }
                        Text(s).font(.body15).foregroundStyle(i <= step ? Theme.ink : Theme.faint)
                    }
                }
            }
            Text("Usually about ten seconds. Up to a minute when it's busy.").font(.sub).foregroundStyle(Theme.faint)
            BigButton(label: "Cancel", style: .ghost) { task?.cancel(); building = false; step = 0 }
        }
    }

    private func build() {
        error = nil; examples = []; focused = false
        building = true; step = 0
        Haptic.medium()
        let idea = trimmed
        task = Task {
            // The steps are a clock, not the backend's progress: it reports nothing until done.
            let ticker = Task {
                for d in [2.5, 3.0, 4.0] {
                    try? await Task.sleep(for: .seconds(d))
                    if Task.isCancelled { return }
                    withAnimation(.easeOut(duration: 0.2)) { step = min(step + 1, Self.steps.count - 1) }
                }
            }
            defer { ticker.cancel() }
            do {
                let d = try await API.shared.createAIBasket(idea: idea)
                guard !Task.isCancelled else { return }
                Haptic.success()
                BasketsStore.shared.remember(d)
                // The result takes this screen's place in the stack: Back from it goes home.
                app.path.removeLast()
                app.push(.basket(d.id))
            } catch is CancellationError {
            } catch {
                guard !Task.isCancelled else { return }
                Haptic.error()
                building = false; step = 0
                switch error {
                case APIError.rejected("not_an_idea", let ex, _):
                    self.error = "That doesn't read as an investing idea."; examples = ex ?? []
                case APIError.rejected("no_match", _, _):
                    self.error = "Couldn't build a basket for that. Try another idea."
                case APIError.rejected("daily_limit", _, let limit):
                    self.error = "That's \(limit ?? 20) baskets today. Back tomorrow."
                case APIError.rejected("ai_busy", _, _):
                    self.error = "The AI is busy right now. Try again in a moment."
                case APIError.http(401, _), APIError.http(403, _):
                    self.error = "Sign in to build a basket."
                default:
                    self.error = Failure.action(error)
                }
            }
        }
    }
}
