import SwiftUI

enum SettingsPage: String, CaseIterable {
    case general = "通用设置"
    case finder = "访达窗口"
    case keyboard = "键盘控制"
    case permissions = "权限设置"
}

struct PermissionGate: View {
    var action: () -> Void
    var body: some View {
        Button("前往权限设置", action: action)
            .controlSize(.regular).buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
