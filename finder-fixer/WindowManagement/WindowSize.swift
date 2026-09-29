import Foundation

struct WindowSize: Codable, Equatable {
    var width: Double
    var height: Double

    static let initial = WindowSize(width: 1000, height: 700)
    // Product input limits, not a claim about Finder's dynamic minimum size.
    static let inputRange = 100...10000

    var isValid: Bool {
        width.isFinite && height.isFinite && width > 0 && height > 0 && width <= 10000 && height <= 10000
    }
    var cgSize: CGSize { CGSize(width: width, height: height) }
    var label: String { "\(Int(width.rounded())) × \(Int(height.rounded())) pt" }

    init(width: Double, height: Double) { self.width = width; self.height = height }
    init(_ size: CGSize) { width = size.width; height = size.height }

    func matches(_ other: WindowSize, tolerance: Double = 1) -> Bool {
        abs(width - other.width) <= tolerance && abs(height - other.height) <= tolerance
    }

    static func parse(width: String, height: String) -> WindowSize? {
        let w = width.trimmingCharacters(in: .whitespacesAndNewlines)
        let h = height.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !w.isEmpty, !h.isEmpty, w.allSatisfy({ $0.isASCII && $0.isNumber }),
              h.allSatisfy({ $0.isASCII && $0.isNumber }), let wi = Int(w), let hi = Int(h),
              inputRange.contains(wi), inputRange.contains(hi) else { return nil }
        return WindowSize(width: Double(wi), height: Double(hi))
    }
}

struct Preferences: Codable, Equatable {
    var fixedSize: WindowSize = .initial
    var autoApplyEnabled = true
}
