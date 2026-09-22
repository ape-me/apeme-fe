import SwiftUI

struct MarketsView: View {
    @Environment(AppState.self) private var app
    @State private var store = MarketsStore()
    @State private var showSort = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 14) {
                Text(app.isApe ? "Floors" : "Markets").h1Text()
                search
            }
            .padding(.horizontal, 20).padding(.top, 16)
            chips.padding(.top, 12).padding(.bottom, 4)
            ScrollView {
                list.padding(.horizontal, 20).padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .background(Theme.ground)
        .task(id: app.mode) { store.sort = app.isApe ? .heat : .change; await store.load(app: app) }
        .sheet(isPresented: $showSort) { sortSheet }
    }

    private var search: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.muted)
            TextField(app.isApe ? "Search floors" : "Search stocks", text: $store.query)
                .font(.body15).foregroundStyle(Theme.ink)
                .autocorrectionDisabled().textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 16).frame(height: 46)
        .background(Theme.surface, in: .capsule)
    }

    private var chips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Pill(label: store.sort.label(ape: app.isApe), size: .small, icon: "line.3.horizontal.decrease") { showSort = true }
                Pill(label: "All", on: store.tag == nil, size: .small) { store.tag = nil }
                ForEach(store.collections) { c in
                    Pill(label: store.chipTitle(c, ape: app.isApe), on: store.tag == c.id, size: .small) { store.tag = c.id }
                }
            }
            .padding(.horizontal, 20)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder private var list: some View {
        if let err = store.error, store.stocks.isEmpty {
            ErrorBar(text: err)
        } else if store.stocks.isEmpty {
            Skeleton(height: 64)
        } else {
            let rows = store.filtered(ape: app.isApe)
            if rows.isEmpty {
                EmptyState(title: "No matches", subtitle: "Try another symbol or clear the filters.")
            } else {
                VStack(spacing: 0) { ForEach(rows) { StockRow(stock: $0) } }
            }
        }
    }

    private var sortSheet: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Sort by").h2Text()
                Spacer()
                IconButton(symbol: "xmark", label: "Close") { showSort = false }
            }
            VStack(spacing: 0) {
                ForEach(MarketsStore.Sort.options(ape: app.isApe)) { s in
                    Button { store.sort = s; showSort = false } label: {
                        HStack {
                            Text(s.label(ape: app.isApe)).font(.system(size: 15, weight: .medium))
                            Spacer()
                            if store.sort == s { Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold)) }
                        }
                        .frame(height: 52).contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 20).padding(.top, 10)
        .presentationDetents([.height(320)])
        .presentationBackground(Theme.surface)
        .presentationDragIndicator(.visible)
    }
}
