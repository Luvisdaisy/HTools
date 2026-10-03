import Foundation

struct DisplayArea: Equatable {
    let frame: CGRect
    let visibleFrame: CGRect
}

enum WindowSizePolicy {
    // AX uses top-left origin on the primary display; AppKit uses bottom-left.
    static func axRect(from cocoa: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: cocoa.minX, y: primaryHeight - cocoa.maxY, width: cocoa.width, height: cocoa.height)
    }

    static func display(for window: CGRect, among displays: [DisplayArea]) -> DisplayArea? {
        displays.enumerated().max { lhs, rhs in
            let l = area(window.intersection(lhs.element.frame))
            let r = area(window.intersection(rhs.element.frame))
            if l != r { return l < r }
            let ld = distance(window, lhs.element.frame), rd = distance(window, rhs.element.frame)
            if ld != rd { return ld > rd }
            return lhs.offset > rhs.offset
        }?.element
    }

    static func fit(_ size: WindowSize, origin: CGPoint, into visible: CGRect) -> CGRect {
        let width = min(size.width, max(1, visible.width))
        let height = min(size.height, max(1, visible.height))
        return CGRect(x: min(max(origin.x, visible.minX), visible.maxX - width),
                      y: min(max(origin.y, visible.minY), visible.maxY - height), width: width, height: height)
    }

    private static func area(_ rect: CGRect) -> CGFloat { rect.isNull ? 0 : rect.width * rect.height }
    private static func distance(_ a: CGRect, _ b: CGRect) -> CGFloat {
        let dx = a.midX - b.midX, dy = a.midY - b.midY
        return dx * dx + dy * dy
    }
}
