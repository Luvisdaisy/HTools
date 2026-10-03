import SwiftUI

struct FinderSettingsPage: View {
    @ObservedObject var model: SettingsModel
    var openPermissions: () -> Void
    private enum Dimension: Hashable { case width, height }
    @FocusState private var focusedDimension: Dimension?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PageHeading(title: "访达窗口", subtitle: model.status.trusted ? "设置一次，让新窗口保持合适的大小。" : nil)
            if model.status.trusted {
                settings
                    .padding(.top, 28)
                Spacer(minLength: 0)
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
            HStack(alignment: .bottom, spacing: 12) {
                dimensionField("宽度", text: $model.widthText, dimension: .width)
                dimensionField("高度", text: $model.heightText, dimension: .height)
                Button(model.dirty ? "保存" : "已保存") { model.saveDraft() }
                    .disabled(!model.dirty || !model.validDraft)
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
            HStack {
                if let error = model.inputError ?? (model.dirty && !model.validDraft ? "请输入 100–10000 的整数。" : nil) {
                    HStack(spacing: 8) {
                        Text(error).foregroundStyle(.red)
                        Spacer(minLength: 0)
                        Button("放弃修改") { model.resetDraft() }.buttonStyle(.link)
                    }
                    .font(.system(size: 11))
                }
            }
            .frame(height: 36, alignment: .center)
            Divider().padding(.bottom, 20)
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
        .settingsCard()
    }

    private func dimensionField(_ title: String, text: Binding<String>, dimension: Dimension) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).foregroundStyle(.secondary)
            HStack(spacing: 4) {
                TextField(title, text: text)
                    .textFieldStyle(.roundedBorder)
                    .monospacedDigit()
                    .controlSize(.large)
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
    private let initialPage: SettingsPage?

    init(model: SettingsModel, keyboard: KeyboardControlModel, permissions: PermissionsModel,
         initialPage: SettingsPage? = nil) {
        self.model = model; self.keyboard = keyboard; self.permissions = permissions
        self.initialPage = initialPage
        _page = State(initialValue: initialPage ?? .finder)
    }

    private func navigate(to destination: SettingsPage) {
        guard page != .finder || model.prepareToClose() else { return }
        page = destination
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 9) {
                    Image(nsImage: NSApp.applicationIconImage).resizable().frame(width: 30, height: 30)
                    Text("HTools").font(.system(size: 14, weight: .semibold, design: .rounded))
                }
                .padding(.horizontal, 6).padding(.top, 8).padding(.bottom, 24)
                ForEach([SettingsPage.finder, .keyboard], id: \.self) { item in
                    Button { navigate(to: item) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: item.icon).font(.system(size: 15)).frame(width: 20)
                            Text(item.rawValue).font(.system(size: 13, weight: .medium))
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(page == item ? Color.white : Color.primary)
                        .padding(.horizontal, 12).padding(.vertical, 11)
                        .background(page == item ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(page == item ? .isSelected : [])
                }
                Spacer()
                Button { navigate(to: .permissions) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.shield").frame(width: 20)
                        Text("权限设置")
                        Spacer()
                        if !permissions.status.complete {
                            Circle().fill(Color.orange).frame(width: 6, height: 6)
                                .accessibilityLabel("需要配置")
                        }
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(page == .permissions ? Color.white : Color.primary)
                    .padding(.horizontal, 12).padding(.vertical, 11)
                    .background(page == .permissions ? Color.accentColor : .clear, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(page == .permissions ? .isSelected : [])
                Divider().padding(.vertical, 10)
                Text("HTools \(AppVersion.display)")
                    .font(.system(size: 11)).foregroundStyle(.secondary).padding(.horizontal, 12)
            }
            .padding(16).frame(width: 196)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.65))
            Divider()
            Group {
                switch page {
                case .finder: FinderSettingsPage(model: model) { navigate(to: .permissions) }
                case .keyboard:
                    KeyboardControlView(model: keyboard,
                                        authorized: permissions.status.keyboardReady) {
                        navigate(to: .permissions)
                    }
                case .permissions: PermissionsView(model: permissions) { navigate(to: .finder) }
                }
            }
            .padding(28).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .onAppear {
            if initialPage == nil && (!permissions.setupCompleted || !permissions.status.complete) { page = .permissions }
            keyboard.openPermissions = { navigate(to: .permissions) }
        }
        .onChange(of: permissions.status) { status in
            if !status.keyboardReady { keyboard.disable() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showHToolsPermissions)) { _ in navigate(to: .permissions) }
        .frame(width: 760, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
