import Foundation

struct Candle: Codable, Hashable, Identifiable {
    var id: Int { t }
    let t: Int
    var o: Double
    var h: Double
    var l: Double
    var c: Double
    var v: Double
    var n: Int
}
