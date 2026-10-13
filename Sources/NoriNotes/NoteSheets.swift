import SwiftUI

/// 密码输入 sheet：加锁（双输确认）与解锁（单输验证）共用。
struct NotePasswordSheet: View {
    let title: String
    let noteTitle: String
    let confirmingPassword: Bool
    let action: (String) -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmation = ""
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack {
                Image(systemName: confirmingPassword ? "lock.shield" : "lock.open")
                    .font(.system(size: 25))
                    .foregroundStyle(Color(red: 0.73, green: 0.36, blue: 0.22))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 20, weight: .semibold, design: .rounded))
                    Text(noteTitle).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            SecureField(confirmingPassword ? "设置密码（至少 8 位）" : "输入笔记密码", text: $password)
                .textFieldStyle(.roundedBorder)
            if confirmingPassword {
                SecureField("再次输入密码", text: $confirmation).textFieldStyle(.roundedBorder)
            }
            Text(confirmingPassword
                 ? "密码用于加密这篇笔记，应用不会保存或上传密码。忘记密码后无法恢复。"
                 : "密码仅在本机用于解密此笔记。")
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if let errorText { Text(errorText).font(.system(size: 11)).foregroundStyle(.red) }
            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(confirmingPassword ? "加密并保存" : "解锁") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(password.isEmpty || (confirmingPassword && confirmation.isEmpty))
            }
        }
        .padding(24)
    }

    private func submit() {
        if confirmingPassword {
            guard password.count >= 8 else { errorText = "请使用至少 8 个字符的密码。"; return }
            guard password == confirmation else { errorText = "两次输入的密码不一致。"; return }
        }
        if action(password) { dismiss() }
        else if errorText == nil { errorText = "无法验证密码，请检查后重试。" }
    }
}

/// 偏好设置：主题预览选择 + 应用标志样式。
struct PreferencesView: View {
    @Binding var theme: String
    @Binding var glyph: String
    @Environment(\.dismiss) private var dismiss

    private let glyphs = ["leaf", "scribble.variable", "bookmark", "sparkle"]

    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("偏好设置").font(.system(size: 23, weight: .semibold, design: .rounded))
                    Text("让书写空间更适合你").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button("完成") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                Text("主题").font(.system(size: 13, weight: .semibold))
                HStack(spacing: 10) {
                    ForEach(AppTheme.allCases) { option in
                        Button { theme = option.rawValue } label: {
                            VStack(spacing: 7) {
                                RoundedRectangle(cornerRadius: 9).fill(option.palette.canvas).frame(height: 46)
                                    .overlay(alignment: .bottomTrailing) { Circle().fill(option.palette.accent).frame(width: 14, height: 14).padding(7) }
                                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(theme == option.rawValue ? option.palette.accent : Color.gray.opacity(0.2), lineWidth: theme == option.rawValue ? 2 : 1))
                                Text(option.rawValue).font(.system(size: 10)).foregroundStyle(.primary)
                            }
                        }.buttonStyle(.plain)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("应用标志样式").font(.system(size: 13, weight: .semibold))
                HStack(spacing: 10) {
                    ForEach(glyphs, id: \.self) { symbol in
                        Button { glyph = symbol } label: {
                            Image(systemName: symbol).font(.system(size: 17, weight: .medium)).frame(width: 42, height: 38)
                                .background(glyph == symbol ? Color.accentColor.opacity(0.13) : Color.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(glyph == symbol ? Color.accentColor : Color.clear, lineWidth: 1.5))
                        }.buttonStyle(.plain)
                    }
                    Text("同时更改窗口与 Dock 图标").font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            Text("Nori Notes · 原创独立笔记工具 · 数据文件保存在 ~/Library/Application Support/NoriNotes/")
                .font(.system(size: 9)).foregroundStyle(.tertiary)
        }
        .padding(25)
    }
}
