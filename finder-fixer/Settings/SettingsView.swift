import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SettingsModel
    private enum Dimension: Hashable { case width, height }
    @FocusState private var focusedDimension: Dimension?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Finder Fixer")
                .font(.system(size: 20, weight: .semibold))
                .accessibilityAddTraits(.isHeader)
            if model.status.trusted {
                settings
                    .padding(.top, 28)
                Spacer(minLength: 0)
            } else {
                Button("前往设置辅助功能权限") { model.openPermissionSettings() }
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .font(.system(size: 13))
        .padding(24)
        .frame(width: 432, height: 280)
        .background(Color(nsColor: .windowBackgroundColor))
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
                Button("保存") { model.saveDraft() }
                    .disabled(!model.dirty || !model.validDraft)
                    .controlSize(.large)
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
            HStack {
                Text("自动应用到新窗口")
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
