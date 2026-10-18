import SwiftUI

struct GeneralSettingsPage: View {
    @ObservedObject var loginItem: LoginItemModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("开机自启").fontWeight(.medium)
                    Text(loginItem.detail).font(.system(size: 11)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("开机自启", isOn: Binding(
                    get: { loginItem.isEnabled }, set: { loginItem.setEnabled($0) }
                ))
                .labelsHidden().toggleStyle(.switch).controlSize(.small)
            }
            if loginItem.needsApproval {
                Button("前往系统登录项设置") { loginItem.openSettings() }
                    .buttonStyle(.link)
            }
            if let error = loginItem.error {
                Text(error).font(.system(size: 11)).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                Button("检查系统登录项") { loginItem.openSettings() }.buttonStyle(.link)
            }
        }
        .font(.system(size: 13))
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.06)))
        .onAppear { loginItem.refresh() }
    }
}
