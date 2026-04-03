import SwiftUI

struct OrderingDetailParamsSheet: View {
    @Binding var params: OrderingDetailParams

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("用餐人数（可选）", text: $params.dinersText)
                        .keyboardType(.numberPad)
                    TextField("人均预算 CNY（可选）", text: $params.budgetText)
                        .keyboardType(.numberPad)
                } header: {
                    Text("人数与预算")
                } footer: {
                    Text("默认：人数不限制，预算不限。")
                }

                Section {
                    Picker("辣度", selection: $params.spiceLevel) {
                        Text("默认").tag("default")
                        Text("不辣").tag("none")
                        Text("微辣").tag("mild")
                        Text("中辣").tag("medium")
                        Text("重辣").tag("hot")
                    }
                } header: {
                    Text("辣度偏好")
                } footer: {
                    Text("默认：跟随你的口味画像与菜单信息自动判断。")
                }

                Section {
                    TextField("用逗号分隔，例如：花生, 海鲜", text: $params.allergiesText, axis: .vertical)
                        .lineLimit(1...3)
                } header: {
                    Text("过敏/忌口（可选）")
                } footer: {
                    Text("默认：无过敏/忌口限制。")
                }

                Section {
                    TextField("例如：想吃清淡一点，尽量少油", text: $params.notes, axis: .vertical)
                        .lineLimit(2...5)
                } header: {
                    Text("补充说明（可选）")
                } footer: {
                    Text("默认：无额外偏好说明。")
                }
            }
            .navigationTitle("详细参数")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("恢复默认") {
                        params.reset()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}
