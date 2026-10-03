import Foundation
import IOKit
import IOKit.hid

/// Main run loop serializes discovery, lifecycle callbacks and physical control.
/// IndependentDevices prevents the inspector from opening every matched keyboard.
public final class HIDDeviceManager: PhysicalKeyboardControlling {
    private let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOHIDManagerOptions.independentDevices.rawValue)
    private var handles: [UInt64: IOHIDDevice] = [:]
    private var seized: [UInt64: IOHIDDevice] = [:]
    public private(set) var devices: [UInt64: KeyboardDevice] = [:]
    public var changed: (String, KeyboardDevice) -> Void = { _, _ in }
    public var failed: (Int32) -> Void = { _ in }
    private var started = false

    public init() {}

    @discardableResult public func start() -> Int32 {
        precondition(Thread.isMainThread)
        guard !started else { return 0 }
        started = true
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDDeviceUsagePageKey: 1, kIOHIDDeviceUsageKey: 6] as CFDictionary)
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, { context, result, _, device in
            guard let context else { return }
            let owner = Unmanaged<HIDDeviceManager>.fromOpaque(context).takeUnretainedValue()
            guard result == kIOReturnSuccess else { owner.failed(result); return }
            owner.add(device)
        }, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, { context, result, _, device in
            guard let context else { return }
            let owner = Unmanaged<HIDDeviceManager>.fromOpaque(context).takeUnretainedValue()
            if result != kIOReturnSuccess { owner.failed(result) }
            let id = HIDDeviceManager.registryID(device)
            if let metadata = owner.devices.removeValue(forKey: id) {
                owner.handles.removeValue(forKey: id)
                // Retain seized handle until controller release, including device removal.
                owner.changed("removed", metadata)
            }
        }, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if result == kIOReturnSuccess, let all = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> {
            for device in all { add(device) }
        }
        return result
    }

    public func stop() {
        precondition(Thread.isMainThread)
        guard started else { return }
        for id in Array(seized.keys) { _ = release(id) }
        IOHIDManagerRegisterDeviceMatchingCallback(manager, nil, nil)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, nil, nil)
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        handles.removeAll(); devices.removeAll(); started = false
    }

    public func seize(_ registryID: UInt64) -> Int32 {
        precondition(Thread.isMainThread)
        guard let device = handles[registryID], seized.isEmpty,
              Self.metadata(device).classification.role == .builtIn else { return kIOReturnBadArgument }
        let code = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeSeizeDevice))
        if code == kIOReturnSuccess { seized[registryID] = device }
        return code
    }

    public func release(_ registryID: UInt64) -> Int32 {
        precondition(Thread.isMainThread)
        guard let device = seized[registryID] else { return kIOReturnNotOpen }
        let code = IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        if code == kIOReturnSuccess { seized.removeValue(forKey: registryID) }
        return code
    }

    private func add(_ device: IOHIDDevice) {
        let metadata = Self.metadata(device)
        guard metadata.registryID != 0 else { return }
        let wasKnown = devices[metadata.registryID] != nil
        handles[metadata.registryID] = device
        devices[metadata.registryID] = metadata
        if !wasKnown { changed("connected", metadata) }
    }

    private static func registryID(_ device: IOHIDDevice) -> UInt64 {
        var id: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(device), &id)
        return id
    }

    private static func metadata(_ device: IOHIDDevice) -> KeyboardDevice {
        func property(_ key: String) -> Any? { IOHIDDeviceGetProperty(device, key as CFString) }
        func number(_ key: String) -> Int? { (property(key) as? NSNumber)?.intValue }
        let primary = HIDUsage(number(kIOHIDPrimaryUsagePageKey) ?? 0, number(kIOHIDPrimaryUsageKey) ?? 0)
        let usages = (property(kIOHIDDeviceUsagePairsKey) as? [[String: Any]] ?? []).compactMap { pair -> HIDUsage? in
            guard let page = pair[kIOHIDDeviceUsagePageKey] as? Int,
                  let usage = pair[kIOHIDDeviceUsageKey] as? Int else { return nil }
            return HIDUsage(page, usage)
        }
        // Missing collection metadata is not evidence that a device is safe to seize.
        let service = IOHIDDeviceGetService(device)
        var ancestry: [String] = []
        var current = service
        IOObjectRetain(current)
        for _ in 0..<12 {
            if let name = IOObjectCopyClass(current)?.takeRetainedValue() { ancestry.append(name as String) }
            var parent: io_registry_entry_t = 0
            let result = IORegistryEntryGetParentEntry(current, kIOServicePlane, &parent)
            IOObjectRelease(current)
            guard result == KERN_SUCCESS else { current = 0; break }
            current = parent
        }
        if current != 0 { IOObjectRelease(current) }
        return KeyboardDevice(registryID: registryID(device), product: property(kIOHIDProductKey) as? String ?? "Unknown",
            manufacturer: property(kIOHIDManufacturerKey) as? String,
            vendorID: number(kIOHIDVendorIDKey), productID: number(kIOHIDProductIDKey),
            locationID: number(kIOHIDLocationIDKey), transport: property(kIOHIDTransportKey) as? String ?? "Unknown",
            builtIn: (property("Built-In") as? NSNumber)?.boolValue,
            primary: primary, usages: usages, ancestry: ancestry,
            virtualProperty: (property("VirtualHIDDevice") as? NSNumber)?.boolValue == true ||
                (property("IsVirtual") as? NSNumber)?.boolValue == true)
    }
}
