import Foundation
import CryptoKit

/// One explicit system authorization installs a root-owned, fixed-function helper.
/// Legacy launchd packaging also supports the project's ad-hoc distribution.
enum KeyboardServiceInstaller {
    static func installScript(bundle: String, digest: String) -> String {
        let q = KeyboardAuthorization.shellQuote
        let name = KeyboardServiceIdentity.name
        let destination = KeyboardServiceIdentity.executable
        let plist = KeyboardServiceIdentity.plist
        return """
        set -eu
        /usr/bin/install -d -o root -g wheel -m 755 /Library/PrivilegedHelperTools
        stage=$(/usr/bin/mktemp -d /Library/PrivilegedHelperTools/.HTools.XXXXXXXX)
        trap '/bin/rm -rf "$stage"' EXIT
        /usr/bin/ditto --noqtn \(q(bundle)) "$stage/HToolsKeyboard.app"
        /usr/sbin/chown -R -P root:wheel "$stage/HToolsKeyboard.app"
        /bin/chmod -R u+rwX,go+rX,go-w "$stage/HToolsKeyboard.app"
        actual=$(/usr/bin/shasum -a 256 "$stage/HToolsKeyboard.app/Contents/MacOS/HTools" | /usr/bin/awk '{print $1}')
        [ "$actual" = \(q(digest)) ]
        /usr/bin/codesign --verify --deep --strict "$stage/HToolsKeyboard.app"
        /bin/cat > "$stage/service.plist" <<'HTOOLS_PLIST'
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
        <key>Label</key><string>\(name)</string>
        <key>ProgramArguments</key><array><string>\(destination)</string><string>--keyboard-service</string></array>
        <key>MachServices</key><dict><key>\(name)</key><true/></dict>
        <key>ProcessType</key><string>Interactive</string>
        <key>ExitTimeOut</key><integer>5</integer>
        </dict></plist>
        HTOOLS_PLIST
        /usr/sbin/chown root:wheel "$stage/service.plist"
        /bin/chmod 644 "$stage/service.plist"
        /bin/launchctl bootout system/\(name) 2>/dev/null || true
        if [ -e \(q(KeyboardServiceIdentity.bundlePath)) ]; then
            /bin/mv \(q(KeyboardServiceIdentity.bundlePath)) "$stage/previous.app"
        fi
        /bin/mv "$stage/HToolsKeyboard.app" \(q(KeyboardServiceIdentity.bundlePath))
        /bin/mv -f "$stage/service.plist" \(q(plist))
        /bin/launchctl bootstrap system \(q(plist))
        """
    }

    static var uninstallScript: String {
        """
        set -eu
        /bin/launchctl bootout system/\(KeyboardServiceIdentity.name) 2>/dev/null || true
        /bin/rm -f \(KeyboardAuthorization.shellQuote(KeyboardServiceIdentity.plist))
        /bin/rm -rf \(KeyboardAuthorization.shellQuote(KeyboardServiceIdentity.bundlePath))
        """
    }

    static func run(install: Bool, completion: @escaping (String?) -> Void) throws {
        let command: String
        if install {
            guard let executable = Bundle.main.executablePath else { throw POSIXError(.ENOENT) }
            let digest = SHA256.hash(data: try Data(contentsOf: URL(fileURLWithPath: executable)))
                .map { String(format: "%02x", $0) }.joined()
            command = installScript(bundle: Bundle.main.bundlePath, digest: digest)
        } else { command = uninstallScript }
        let process = Process(); let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", authorizationScript(command: command, install: install)]
        process.standardError = errors; process.standardOutput = FileHandle.nullDevice
        process.terminationHandler = { process in
            let message = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
            DispatchQueue.main.async {
                completion(process.terminationStatus == 0 ? nil :
                    (message.contains("(-128)") ? "已取消系统授权，可稍后继续配置。" : "服务配置失败：\(message)"))
            }
        }
        try process.run()
    }

    static func authorizationScript(command: String, install: Bool) -> String {
        let literal = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "do shell script \"\(literal)\" with administrator privileges with prompt \"HTools 需要\(install ? "安装" : "移除")键盘控制服务。\""
    }
}
