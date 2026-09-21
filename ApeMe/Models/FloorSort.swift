import Foundation

enum FloorSort: String, CaseIterable, Identifiable {
    case vol24h, new, mcap, progress
    var id: String { rawValue }
    var label: String {
        switch self { case .vol24h: "Volume"; case .new: "New"; case .mcap: "Mcap"; case .progress: "Graduating" }
    }
}
