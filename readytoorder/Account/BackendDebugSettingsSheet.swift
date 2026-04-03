import SwiftUI

struct BackendDebugSettingsSheet: View {
#if DEBUG
    @AppStorage("readytoorder.setting.backendURL") private var backendURL = "https://readytoorder-production.up.railway.app"
    @AppStorage("readytoorder.setting.backendApiKey") private var backendApiKey = ""
#endif

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
#if DEBUG
                    TextField("https://readytoorder-production.up.railway.app", text: $backendURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled(true)
                        .font(.subheadline.monospaced())

                    SecureField("可选：X-API-Key", text: $backendApiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .font(.subheadline.monospaced())
#else
                    Text("Release 构建不开放调试后端设置。")
                        .font(.subheadline)
#endif
                } header: {
                    Text("后端连接")
                } footer: {
                    Text("Debug 构建可修改后端地址与 API Key；Release 将固定使用生产地址。")
                }

                Section {
                    Text("所有请求会自动携带设备标识与客户端版本头。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("请求说明")
                }
            }
            .navigationTitle("调试设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    BackendDebugSettingsSheet()
}
