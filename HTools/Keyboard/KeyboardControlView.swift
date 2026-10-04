import SwiftUI

struct KeyboardControlView: View {
    @ObservedObject var model: KeyboardControlModel
    var authorized: Bool
    var openPermissions: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if authorized {
                controls
            } else {
                PermissionGate(action: openPermissions)
            }
        }
        .font(.system(size: 13))
        .alert("键盘控制", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("好", role: .cancel) { model.error = nil }
        } message: { Text(model.error ?? "") }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            VStack(spacing: 0) {
                if model.devices.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "keyboard").font(.system(size: 18)).foregroundStyle(.secondary)
                        Text("未检测到键盘").foregroundStyle(.secondary)
                        Spacer()
                    }.padding(12)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(model.devices.enumerated()), id: \.element.registryID) { index, device in
                                if index > 0 { Divider().padding(.leading, 48) }
                                keyboardRow(device)
                            }
                        }
                    }.frame(height: min(CGFloat(model.devices.count) * 64, 192))
                }
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.06)))
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("禁用内置键盘").font(.system(size: 13, weight: .medium))
                    Text(switchDetail).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                if model.busy {
                    ProgressView().controlSize(.small).scaleEffect(0.75)
                        .accessibilityLabel(model.state == .authorizing ? "正在连接服务" : "正在恢复键盘")
                }
                Toggle("禁用内置键盘", isOn: Binding(
                    get: { model.state == .on }, set: { model.setDisabled($0) }
                ))
                .labelsHidden().toggleStyle(.switch).controlSize(.small)
                .disabled(model.busy || (model.state == .off && !model.canEnable))
                .help(model.canEnable ? "关闭开关即可恢复内置键盘" : "需要识别到唯一的内置键盘和至少一个外接键盘")
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.06)))
        }
    }

    private var switchDetail: String {
        switch model.state {
        case .authorizing: return "正在连接键盘服务…"
        case .stopping: return "正在恢复内置键盘…"
        case .on: return "已禁用 · 关闭开关即可恢复"
        case .off: return model.canEnable ? "内置键盘正常使用" : "请连接外接键盘后再开启"
        }
    }

    private func keyboardRow(_ device: KeyboardDevice) -> some View {
        let role = device.classification.role
        let label = role == .builtIn ? "内置" : role == .external ? "外接" : role == .virtual ? "虚拟" : "未识别"
        return HStack(spacing: 10) {
            Image(systemName: role == .builtIn ? "laptopcomputer" : "keyboard")
                .font(.system(size: 18, weight: .regular)).foregroundStyle(.secondary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 5) {
                Text(device.product).font(.system(size: 13, weight: .medium)).lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 64)
        .accessibilityElement(children: .combine)
    }
}
