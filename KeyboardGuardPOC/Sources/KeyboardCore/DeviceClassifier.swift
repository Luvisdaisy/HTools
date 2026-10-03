import Foundation

public struct HIDUsage: Codable, Equatable {
    public let page: Int
    public let usage: Int
    public init(_ page: Int, _ usage: Int) { self.page = page; self.usage = usage }
}

public struct KeyboardDevice: Codable, Equatable {
    public let registryID: UInt64
    public var product: String
    public var manufacturer: String?
    public var vendorID: Int?
    public var productID: Int?
    public var locationID: Int?
    public var transport: String
    public var builtIn: Bool?
    public var primary: HIDUsage
    public var usages: [HIDUsage]
    public var ancestry: [String]
    public var virtualProperty: Bool

    public init(registryID: UInt64, product: String, manufacturer: String? = nil,
                vendorID: Int? = nil, productID: Int? = nil, locationID: Int? = nil,
                transport: String, builtIn: Bool?, primary: HIDUsage, usages: [HIDUsage],
                ancestry: [String] = [], virtualProperty: Bool = false) {
        self.registryID = registryID; self.product = product; self.manufacturer = manufacturer
        self.vendorID = vendorID; self.productID = productID; self.locationID = locationID
        self.transport = transport; self.builtIn = builtIn; self.primary = primary
        self.usages = usages; self.ancestry = ancestry; self.virtualProperty = virtualProperty
    }

    public var classification: Classification { DeviceClassifier.classify(self) }
}

public enum KeyboardRole: String, Codable { case builtIn, external, virtual, ignored }

public struct Classification: Codable, Equatable {
    public let role: KeyboardRole
    /// Heuristic confidence score, not a statistically calibrated probability.
    public let confidence: Double
    public let reasons: [String]
}

public enum DeviceClassifier {
    public static func classify(_ d: KeyboardDevice) -> Classification {
        func result(_ role: KeyboardRole, _ score: Double, _ reasons: [String]) -> Classification {
            Classification(role: role, confidence: min(score, 1), reasons: reasons)
        }
        guard d.registryID != 0, d.usages.contains(HIDUsage(1, 6)) else {
            return result(.ignored, 0, ["missing registry identity or Keyboard usage"])
        }
        let transport = d.transport.lowercased()
        let identity = ([d.product] + d.ancestry).joined(separator: " ").lowercased()
        if d.virtualProperty || transport.contains("virtual") ||
            ["virtualhid", "virtual keyboard", "karabiner", "keyboardguard"].contains(where: identity.contains) {
            return result(.virtual, 0, ["explicit virtual device evidence"])
        }
        let internalTransport = ["fifo", "spi", "i2c"].contains(transport)
        let internalParent = d.ancestry.contains {
            $0.contains("AppleHIDTransport") || $0.contains("AppleEmbeddedKeyboard")
        }
        if d.builtIn == true {
            // Never seize an interface exposing mouse, pointer, or digitizer collections.
            guard d.primary == HIDUsage(1, 6), !d.usages.contains(where: {
                $0.page == 13 || ($0.page == 1 && [1, 2].contains($0.usage))
            }) else { return result(.ignored, 0, ["internal composite pointing interface or non-keyboard primary"] ) }
            var score = 0.60
            var reasons = ["Built-In=true", "dedicated keyboard interface"]
            if internalTransport { score += 0.25; reasons.append("internal transport=\(d.transport)") }
            if d.vendorID == 0x05ac { score += 0.10; reasons.append("Apple vendor") }
            if internalParent { score += 0.15; reasons.append("Apple internal HID ancestry") }
            guard score >= 0.85, internalTransport || internalParent else {
                return result(.ignored, score, reasons + ["insufficient corroboration"])
            }
            // Bluetooth is inconsistent with an internal MacBook keyboard even if marked Built-In.
            guard !transport.contains("bluetooth") else {
                return result(.ignored, 0, reasons + ["conflicting Bluetooth transport"])
            }
            return result(.builtIn, score, reasons)
        }
        guard !internalTransport, !internalParent else {
            return result(.ignored, 0, ["internal topology without trustworthy Built-In property"])
        }
        let bluetooth = ["bluetooth", "bluetooth low energy"].contains(transport)
        let physicalUSB = transport == "usb" && d.ancestry.contains {
            $0.contains("IOUSBHost") || $0.contains("IOUSBHID")
        }
        if bluetooth || physicalUSB {
            return result(.external, 0.9, ["Keyboard usage", "external \(d.transport) topology",
                "no positive Built-In or virtual evidence"])
        }
        return result(.ignored, 0, ["unknown or uncorroborated transport/topology"])
    }
}
