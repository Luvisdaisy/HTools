import Combine
import ServiceManagement

final class LoginItemModel: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var error: String?
    private let service: LoginItemServicing

    init(service: LoginItemServicing = SystemLoginItemService()) {
        self.service = service
        status = service.status
    }

    var isEnabled: Bool { status == .enabled || status == .requiresApproval }
    var needsApproval: Bool { status == .requiresApproval }
    var detail: String {
        switch status {
        case .enabled: return "登录 Mac 后自动在菜单栏运行"
        case .requiresApproval: return "等待在系统登录项中允许 HTools"
        case .notFound: return "请将 HTools 放入应用程序后重试"
        case .notRegistered: return "登录 Mac 后自动在菜单栏运行"
        @unknown default: return "请在系统登录项中检查 HTools"
        }
    }

    func refresh() { status = service.status }

    func setEnabled(_ enabled: Bool) {
        error = nil
        refresh()
        guard enabled != isEnabled else { return }
        do {
            if enabled { try service.register() }
            else { try service.unregister() }
        } catch {
            self.error = "无法\(enabled ? "开启" : "关闭")开机自启：\(error.localizedDescription)"
        }
        refresh()
    }

    func openSettings() { service.openSettings() }
}
