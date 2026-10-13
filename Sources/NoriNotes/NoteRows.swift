import SwiftUI

/// 笔记列表行与标签行内编辑器。
struct NoteRow: View {
    let note: Note
    let theme: ThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if note.isLocked { Image(systemName: "lock.fill").font(.system(size: 9)).foregroundStyle(theme.accent) }
                Text(note.displayTitle).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(theme.ink).lineLimit(1)
                Spacer(minLength: 0)
                if note.isPinned { Image(systemName: "pin.fill").font(.system(size: 9)).foregroundStyle(theme.accent) }
            }
            Text(note.isLocked ? "内容已加密" : (note.body.isEmpty ? "还没有正文" : note.body.replacingOccurrences(of: "\n", with: " ")))
                .font(.system(size: 11)).foregroundStyle(theme.muted).lineLimit(2)
            HStack(spacing: 5) {
                Text(note.updatedAt.formatted(date: .abbreviated, time: .omitted)).font(.system(size: 9)).foregroundStyle(theme.muted)
                if !note.isLocked {
                    ForEach(note.tags.prefix(2), id: \.self) { tag in
                        Text(tag).font(.system(size: 9)).foregroundStyle(theme.accent).padding(.horizontal, 5).padding(.vertical, 2).background(theme.accent.opacity(0.09), in: Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}

/// 标签行内编辑：逗号分隔，回车或失焦提交。
struct NoteTagEditor: View {
    let note: Note
    let theme: ThemePalette
    let onCommit: ([String]) -> Void
    @State private var draft: String
    @FocusState private var isFocused: Bool

    init(note: Note, theme: ThemePalette, onCommit: @escaping ([String]) -> Void) {
        self.note = note
        self.theme = theme
        self.onCommit = onCommit
        _draft = State(initialValue: note.tags.joined(separator: ", "))
    }

    var body: some View {
        TextField("标签（逗号分隔，回车保存）", text: $draft)
            .font(.system(size: 11)).textFieldStyle(.plain).foregroundStyle(theme.muted)
            .focused($isFocused)
            .onSubmit(commit)
            .onChange(of: isFocused) { wasFocused, focused in
                if wasFocused && !focused { commit() }
            }
            .onChange(of: note.tags) { _, tags in
                if !isFocused { draft = tags.joined(separator: ", ") }
            }
    }

    private func commit() {
        onCommit(draft.split(separator: ",").map { String($0) })
    }
}
