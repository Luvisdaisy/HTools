import SwiftUI

struct PermissionsView: View {
    @ObservedObject var model: PermissionsModel
    var continueToApp: () -> Void
    @State private var confirmRemoval = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top) {
                PageHeading(title: model.setupCompleted ? "权限设置" : "欢迎使用 HTools",
                            subtitle: model.status.complete ? "配置已就绪，可以开始使用。" : "完成三项配置，开启全部功能。")
                Spacer()
                Text("\(model.status.completedSteps) / 3")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(model.status.complete ? Color.green : Color.secondary)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(Color.primary.opacity(0.04), in: Capsule())
            }
            VStack(spacing: 0) {
                row("辅助功能", detail: "自动调整新建访达窗口的尺寸", icon: "macwindow",
                    ready: model.status.accessibility, action: "去授权", perform: model.requestAccessibility)
                Divider().padding(.vertical, 16)
                row("输入监控", detail: "控制内置键盘，不记录输入内容", icon: "keyboard",
                    ready: model.status.inputMonitoring, action: "去授权", perform: model.requestInputMonitoring)
                Divider().padding(.vertical, 16)
                row("键盘控制服务", detail: serviceDetail, icon: "lock.shield",
                    ready: model.status.keyboardService && model.status.workerInputMonitoring,
                    action: serviceAction) {
                    if model.status.keyboardService { model.refresh() }
                    else { model.configureService(install: true) }
                }
            }
            .settingsCard()
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: model.status.complete ? "checkmark.shield" : "info.circle")
                Text(hint).fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 11)).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            HStack {
                if model.serviceInstalled {
                    Menu("管理服务") {
                        Button("重新安装服务…") { model.configureService(install: true) }
                        Button("移除服务…", role: .destructive) { confirmRemoval = true }
                    }
                    .menuStyle(.borderlessButton).fixedSize()
                }
                if model.busy {
                    ProgressView().controlSize(.small)
                    Text("等待系统授权…").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Button(model.setupCompleted ? "返回功能" : "开始使用") {
                    model.completeSetup(); continueToApp()
                }
                .buttonStyle(.borderedProminent).controlSize(.large)
                .disabled(!model.status.complete || model.busy)
            }
        }
        .disabled(model.busy)
        .confirmationDialog("移除键盘控制服务？", isPresented: $confirmRemoval, titleVisibility: .visible) {
            Button("移除服务", role: .destructive) { model.configureService(install: false) }
        } message: { Text("内置键盘将恢复正常，访达功能和窗口偏好会保留。需要时可重新安装。") }
        .alert("权限配置", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("好") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }

    private var serviceAction: String {
        if model.status.keyboardService { return "重新检查" }
        return model.serviceInstalled ? "更新服务" : "安装服务"
    }
    private var serviceDetail: String {
        if model.status.keyboardService && !model.status.workerInputMonitoring { return "已连接，等待后台输入权限" }
        if model.serviceInstalled && !model.status.keyboardService { return "需与当前版本匹配，更新后即可使用" }
        return "安装时授权，之后切换无需密码"
    }
    private var hint: String {
        if model.status.complete { return "权限仅用于上述功能。卸载 HTools 前，请从“管理服务”移除键盘服务。" }
        if model.status.keyboardService && !model.status.workerInputMonitoring {
            return "后台输入权限尚未就绪。请确认输入监控已允许当前 HTools，按系统提示重启后重新检查。"
        }
        return "按系统提示逐项授权，返回此窗口会自动检查。升级应用后，可能需要更新服务或重新确认权限。"
    }

    private func row(_ title: String, detail: String, icon: String, ready: Bool,
                     action: String, perform: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 19)).frame(width: 28).foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if ready {
                Label("已就绪", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.green)
            } else { Button(action, action: perform).controlSize(.small) }
        }
        .frame(minHeight: 38)
    }
}
