import SwiftUI

struct FinderSettingsPage: View {
    @ObservedObject var model: SettingsModel
    var openPermissions: () -> Void
    private enum Dimension: Hashable { case width, height }
    @FocusState private var focusedDimension: Dimension?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.status.trusted {
                settings
            } else {
                PermissionGate(action: openPermissions)
            }
        }
        .font(.system(size: 13))
        .onChange(of: model.status.trusted) { trusted in
            if !trusted { focusedDimension = nil }
        }
        .onChange(of: model.inputError) { error in
            if error != nil && model.status.trusted {
                let width = Int(model.widthText)
                focusedDimension = width.map { (100...10000).contains($0) } == true ? .height : .width
            }
        }
        .onChange(of: model.widthText) { _ in model.inputError = nil }
        .onChange(of: model.heightText) { _ in model.inputError = nil }
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: 10) {
                dimensionField("宽度", text: $model.widthText, dimension: .width)
                dimensionField("高度", text: $model.heightText, dimension: .height)
                Button(model.dirty ? "保存" : "已保存") { model.saveDraft() }
                    .disabled(!model.dirty || !model.validDraft)
                    .buttonStyle(.borderedProminent).controlSize(.regular)
            }
            if let error = model.inputError ?? (model.dirty && !model.validDraft ? "请输入 100–10000 的整数。" : nil) {
                HStack(spacing: 6) {
                    Text(error).foregroundStyle(.red)
                    Spacer(minLength: 0)
                    Button("放弃修改") { model.resetDraft() }.buttonStyle(.link)
                }
                .font(.system(size: 11))
                .padding(.top, 8)
            }
            Divider().padding(.vertical, 16)
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("自动应用到新窗口")
                    Text("已有窗口与手动缩放不受影响")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("自动应用到新窗口", isOn: Binding(
                    get: { model.preferences.autoApplyEnabled },
                    set: { model.setAutoApply($0) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
            }
        }

    }

    private func dimensionField(_ title: String, text: Binding<String>, dimension: Dimension) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                TextField(title, text: text)
                    .textFieldStyle(.roundedBorder)
                    .monospacedDigit()
                    .controlSize(.regular)
                    .accessibilityLabel("\(title)，逻辑点")
                    .focused($focusedDimension, equals: dimension)
                    .onSubmit { model.saveDraft() }
                Text("pt").foregroundStyle(.secondary).font(.system(size: 11))
            }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    @ObservedObject var keyboard: KeyboardControlModel
    @ObservedObject var permissions: PermissionsModel
    @State private var page: SettingsPage
    var onSizeChange: (NSSize) -> Void

    init(model: SettingsModel, keyboard: KeyboardControlModel, permissions: PermissionsModel,
         initialPage: SettingsPage? = nil, onSizeChange: @escaping (NSSize) -> Void = { _ in }) {
        self.model = model; self.keyboard = keyboard; self.permissions = permissions
        self.onSizeChange = onSizeChange
        _page = State(initialValue: initialPage ?? ((!permissions.setupCompleted || !permissions.status.complete) ? .permissions : .finder))
    }

    private func navigate(to destination: SettingsPage) {
        guard page != .finder || model.prepareToClose() else { return }
        page = destination
    }

    private var panelHeight: CGFloat {
        switch page {
        case .finder: return model.status.trusted ? (model.dirty && !model.validDraft ? 218 : 196) : 156
        case .keyboard:
            return permissions.status.keyboardReady ? 176 + min(CGFloat(max(1, keyboard.devices.count)) * 64, 192) : 156
        case .permissions: return 348
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(SettingsPage.allCases, id: \.self) { item in
                    Button { navigate(to: item) } label: {
                        HStack(spacing: 5) {
                            Text(item.rawValue)
                            if item == .permissions && !permissions.status.complete {
                                Circle().fill(Color.orange).frame(width: 5, height: 5)
                                    .accessibilityLabel("需要配置")
                            }
                        }
                        .font(.system(size: 12, weight: page == item ? .semibold : .regular))
                        .foregroundStyle(page == item ? Color.primary : Color.secondary)
                        .frame(maxWidth: .infinity).frame(height: 30)
                        .background(page == item ? Color(nsColor: .controlBackgroundColor) : .clear,
                                    in: RoundedRectangle(cornerRadius: 7))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(page == item ? .isSelected : [])
                }
            }
            .padding(4)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 12).padding(.top, 12)
            Group {
                switch page {
                case .finder: FinderSettingsPage(model: model) { navigate(to: .permissions) }
                case .keyboard:
                    KeyboardControlView(model: keyboard, authorized: permissions.status.keyboardReady) {
                        navigate(to: .permissions)
                    }
                case .permissions: PermissionsView(model: permissions) { navigate(to: .finder) }
                }
            }
            .padding(16).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            keyboard.openPermissions = { navigate(to: .permissions) }
            onSizeChange(NSSize(width: 400, height: panelHeight))
        }
        .onChange(of: panelHeight) { height in onSizeChange(NSSize(width: 400, height: height)) }
        .onChange(of: permissions.status) { status in
            if !status.keyboardReady { keyboard.disable() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showHToolsPermissions)) { _ in navigate(to: .permissions) }
        .frame(width: 400, height: panelHeight)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
