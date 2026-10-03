import SwiftUI

enum SettingsPage: String, CaseIterable {
    case finder = "访达窗口"
    case keyboard = "键盘控制"
    case permissions = "权限设置"
    var icon: String {
        switch self {
        case .finder: return "macwindow"
        case .keyboard: return "keyboard"
        case .permissions: return "lock.shield"
        }
    }
}

enum AppVersion {
    static var display: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.0" }
}

struct PageHeading: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 24, weight: .semibold, design: .rounded)).accessibilityAddTraits(.isHeader)
            if let subtitle { Text(subtitle).font(.system(size: 12)).foregroundStyle(.secondary) }
        }
    }
}

struct PermissionGate: View {
    var action: () -> Void
    var body: some View {
        Button("前往权限设置", action: action)
            .controlSize(.large).buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    func settingsCard() -> some View {
        self.padding(20)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(0.06)))
    }
}
