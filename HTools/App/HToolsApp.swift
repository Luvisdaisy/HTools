import AppKit

@main
enum HToolsApp {
    static func main() {
        if CommandLine.arguments.dropFirst().first == "--keyboard-access-check" {
            KeyboardWorker.checkAccess()
        }
        if CommandLine.arguments.dropFirst().first == "--keyboard-service" {
            KeyboardService.run()
        }
        if CommandLine.arguments.dropFirst().first == "--keyboard-worker" {
            KeyboardWorker.run(arguments: Array(CommandLine.arguments.dropFirst(2)))
        }
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
