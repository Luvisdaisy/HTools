// Run with Swift from a trusted desktop host. --resize temporarily changes one
// standard window, then restores its original frame. No titles or paths logged.
import AppKit
import ApplicationServices
func value(_ e: AXUIElement, _ key: String) -> CFTypeRef? {
    var v: CFTypeRef?
    return AXUIElementCopyAttributeValue(e, key as CFString, &v) == .success ? v : nil
}
func size(_ e: AXUIElement) -> CGSize? {
    guard let raw = value(e, kAXSizeAttribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
    var s = CGSize.zero
    return AXValueGetValue(raw as! AXValue, .cgSize, &s) ? s : nil
}
func point(_ e: AXUIElement) -> CGPoint? {
    guard let raw = value(e, kAXPositionAttribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
    var p = CGPoint.zero
    return AXValueGetValue(raw as! AXValue, .cgPoint, &p) ? p : nil
}
func setSize(_ e: AXUIElement, _ s: CGSize) { var s=s; print("write=\(AXUIElementSetAttributeValue(e, kAXSizeAttribute as CFString, AXValueCreate(.cgSize, &s)!).rawValue)") }
print("trusted=\(AXIsProcessTrusted())")
for s in NSScreen.screens { print("screen=\(s.frame) visible=\(s.visibleFrame) scale=\(s.backingScaleFactor)") }
guard AXIsProcessTrusted(), let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first else { exit(2) }
let app = AXUIElementCreateApplication(finder.processIdentifier)
AXUIElementSetMessagingTimeout(app, 0.5)
let windows = value(app, kAXWindowsAttribute) as? [AXUIElement] ?? []
let standard = windows.filter { value($0,kAXRoleAttribute) as? String == kAXWindowRole && value($0,kAXSubroleAttribute) as? String == kAXStandardWindowSubrole }
print("elements=\(windows.count) standard=\(standard.count)")
print("finder-pid=\(finder.processIdentifier)")
for (index, window) in standard.enumerated() {
    print("window[\(index)] size=\(String(describing: size(window))) minimized=\(String(describing: value(window, kAXMinimizedAttribute))) fullscreen=\(String(describing: value(window, "AXFullScreen")))")
}
var observer: AXObserver?
let created = AXObserverCreate(finder.processIdentifier, { _,_,notification,_ in print("event=\(notification)") }, &observer)
print("observer=\(created.rawValue)")
if let o=observer {
    CFRunLoopAddSource(CFRunLoopGetCurrent(), AXObserverGetRunLoopSource(o), .defaultMode)
    for n in [kAXWindowCreatedNotification,kAXFocusedWindowChangedNotification] {
        print("app-notification \(n)=\(AXObserverAddNotification(o,app,n as CFString,nil).rawValue)")
    }
    if let w=standard.first {
        print("original size=\(String(describing:size(w))) position=\(String(describing:point(w)))")
        var names: CFArray?; AXUIElementCopyAttributeNames(w, &names)
        print("attributes=\(names ?? [] as CFArray)")
        for n in [kAXWindowResizedNotification,kAXWindowMovedNotification,kAXUIElementDestroyedNotification,kAXWindowMiniaturizedNotification,kAXWindowDeminiaturizedNotification] {
            print("window-notification \(n)=\(AXObserverAddNotification(o,w,n as CFString,nil).rawValue)")
        }
        if CommandLine.arguments.contains("--resize"), value(w,"AXFullScreen") as? Bool != true, value(w,kAXMinimizedAttribute) as? Bool != true, let original=size(w), var origin=point(w) {
            defer {
                setSize(w, original)
                print("restore-position=\(AXUIElementSetAttributeValue(w,kAXPositionAttribute as CFString,AXValueCreate(.cgPoint,&origin)!).rawValue)")
                RunLoop.current.run(until: Date().addingTimeInterval(0.3))
                print("restored=\(String(describing:size(w)))")
            }
            setSize(w, CGSize(width:original.width+16,height:original.height+16))
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
            print("readback=\(String(describing:size(w)))")
            setSize(w, CGSize(width:100,height:100))
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
            print("minimum-observed=\(String(describing:size(w)))")
        }
    }
    if let idx=CommandLine.arguments.firstIndex(of:"--observe"), CommandLine.arguments.count > idx+1, let seconds=Double(CommandLine.arguments[idx+1]) {
        RunLoop.current.run(until:Date().addingTimeInterval(min(seconds,60)))
    }
}
