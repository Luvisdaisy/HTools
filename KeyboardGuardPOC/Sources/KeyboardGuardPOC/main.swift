import AppKit

let args = Array(CommandLine.arguments.dropFirst())
func value(_ key: String) -> String? {
    guard let index = args.firstIndex(of: key), index + 1 < args.count else { return nil }
    return args[index + 1]
}

if args.contains("--list") || args.contains("--watch") {
    Worker(runID: UUID().uuidString).run(target: nil, external: nil, seconds: 0, watch: args.contains("--watch"))
} else if args.contains("--seize") {
    guard let target = value("--seize").flatMap(UInt64.init),
          let external = value("--external").flatMap(UInt64.init),
          let seconds = value("--seconds").flatMap(Int.init), (1...30).contains(seconds) else {
        fputs("Usage: --seize <decimal registry ID> --external <decimal registry ID> --seconds <1...30>\n", stderr)
        exit(64)
    }
    Worker(runID: value("--run-id") ?? UUID().uuidString).run(target: target, external: external, seconds: seconds)
} else if args.contains("--help") {
    print("KeyboardGuardPOC: GUI (default), --list, --watch, --seize ID --external ID --seconds 1...30. No key contents recorded.")
} else {
    let app = NSApplication.shared
    let delegate = InspectorApp(evidenceDirectory: value("--evidence-dir"))
    app.delegate = delegate
    app.setActivationPolicy(.regular)
    app.run()
}
