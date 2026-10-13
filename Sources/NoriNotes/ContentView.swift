import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: NotebookStore
    @AppStorage("nori.theme") private var themeName = AppTheme.parchment.rawValue
    @State private var deleteConfirmation = false
    @State private var pendingDeleteID: UUID?

    private var theme: ThemePalette { (AppTheme(rawValue: themeName) ?? .parchment).palette }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 175, ideal: 205, max: 255)
        } content: {
            noteList
                .navigationSplitViewColumnWidth(min: 250, ideal: 300, max: 360)
        } detail: {
            editor
        }
        .navigationSplitViewStyle(.balanced)
        .tint(theme.accent)
        .background(theme.canvas)
        .preferredColorScheme(theme.dark ? .dark : .light)
        .toolbar {
            ToolbarItemGroup(placement: .automatic) {
                Button { store.createNote() } label: { Label("新建笔记", systemImage: "square.and.pencil") }
                    .keyboardShortcut("n", modifiers: .command)
                    .help("新建笔记（⌘N）")
                Menu {
                    ForEach(AppTheme.allCases) { option in
                        Button {
                            themeName = option.rawValue
                        } label: {
                            if themeName == option.rawValue {
                                Label(option.rawValue, systemImage: "checkmark")
                            } else {
                                Text(option.rawValue)
                            }
                        }
                    }
                } label: { Label("主题", systemImage: "paintpalette") }
                    .help("切换主题")
            }
        }
        .searchable(text: $store.searchText, placement: .toolbar, prompt: "搜索标题与正文")
        .confirmationDialog("永久删除这篇笔记？", isPresented: $deleteConfirmation, titleVisibility: .visible) {
            Button("删除笔记", role: .destructive) {
                if let pendingDeleteID { store.delete(pendingDeleteID) }
                pendingDeleteID = nil
            }
            Button("取消", role: .cancel) { pendingDeleteID = nil }
        } message: {
            Text("删除后无法从应用内恢复。")
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: "leaf")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(theme.accent)
                    .frame(width: 36, height: 36)
                    .background(theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Nori Notes").font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(theme.ink)
                    Text("留一处安静给想法").font(.system(size: 10)).foregroundStyle(theme.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 15).padding(.vertical, 16)

            List {
                Section("笔记库") {
                    HStack {
                        Label("全部笔记", systemImage: "tray.full")
                            .lineLimit(1)
                        Spacer()
                        Text("\(store.notes.count)").font(.system(size: 10, design: .rounded)).foregroundStyle(theme.muted)
                    }
                    .foregroundStyle(theme.accent)
                    .listRowBackground(theme.accent.opacity(0.11))
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(theme.canvas)
            .padding(.horizontal, 5)

            HStack(spacing: 8) {
                Image(systemName: "internaldrive").foregroundStyle(theme.muted)
                Text("笔记自动保存在这台设备上").lineLimit(2)
                Spacer(minLength: 0)
            }
            .font(.system(size: 10))
            .foregroundStyle(theme.muted)
            .padding(.horizontal, 15).padding(.vertical, 12)
        }
        .background(theme.canvas)
    }

    private var noteList: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("全部笔记").font(.system(size: 19, weight: .semibold, design: .rounded)).foregroundStyle(theme.ink)
                    Text("\(store.filteredNotes.count) 篇笔记").font(.system(size: 11)).foregroundStyle(theme.muted)
                }
                Spacer()
                Button { store.createNote() } label: {
                    Image(systemName: "plus").font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.accent)
                        .frame(width: 29, height: 29).background(theme.accent.opacity(0.11), in: Circle())
                }
                .buttonStyle(.plain).help("新建笔记")
            }
            .padding(.horizontal, 17).padding(.vertical, 15)

            List(selection: $store.selectedNoteID) {
                ForEach(store.filteredNotes) { note in
                    NoteRow(note: note, theme: theme)
                        .tag(note.id)
                        .contextMenu {
                            Button("删除笔记", role: .destructive) {
                                pendingDeleteID = note.id
                                deleteConfirmation = true
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(theme.panel)
            .overlay {
                if store.filteredNotes.isEmpty {
                    ContentUnavailableView(searchEmpty ? "没有匹配的笔记" : "这里还很安静", systemImage: searchEmpty ? "magnifyingglass" : "note.text", description: Text(searchEmpty ? "试试其他关键词。" : "创建一篇新笔记，收集灵感。"))
                        .foregroundStyle(theme.muted)
                }
            }
        }
        .background(theme.panel)
    }

    private var editor: some View {
        Group {
            if let note = store.selectedNote {
                editableEditor(note)
            } else {
                VStack(spacing: 13) {
                    Image(systemName: "leaf").font(.system(size: 38, weight: .light)).foregroundStyle(theme.accent.opacity(0.75))
                    Text("让想法慢慢展开").font(.system(size: 22, weight: .medium, design: .rounded)).foregroundStyle(theme.ink)
                    Text("选择一篇笔记，或新建一个空白页。\n你的文字会自动保存在这台设备上。")
                        .font(.system(size: 13)).multilineTextAlignment(.center).lineSpacing(5).foregroundStyle(theme.muted)
                    Button("新建笔记") { store.createNote() }.buttonStyle(.borderedProminent).tint(theme.accent).padding(.top, 5)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.panel)
            }
        }
    }

    private func editableEditor(_ note: Note) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("无标题笔记", text: Binding(get: { store.selectedNote?.title ?? "" }, set: { store.updateSelected(title: $0) }))
                    .font(.system(size: 29, weight: .semibold, design: .rounded))
                    .textFieldStyle(.plain)
                    .foregroundStyle(theme.ink)
            }
            .padding(.top, 32).padding(.horizontal, 56)

            HStack {
                Text(note.createdAt.formatted(date: .abbreviated, time: .omitted)).font(.system(size: 10)).foregroundStyle(theme.muted)
                Spacer()
                Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 10)).foregroundStyle(theme.muted)
            }
            .padding(.horizontal, 57).padding(.top, 12).padding(.bottom, 18)

            Rectangle().fill(theme.border.opacity(0.65)).frame(height: 1).padding(.horizontal, 56)

            TextEditor(text: Binding(get: { store.selectedNote?.body ?? "" }, set: { store.updateSelected(body: $0) }))
                .font(.system(size: 15, weight: .regular, design: .serif))
                .lineSpacing(6)
                .foregroundStyle(theme.ink)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(.horizontal, 46).padding(.top, 18).padding(.bottom, 22)

            HStack {
                if let status = store.statusMessage {
                    Text(status).lineLimit(1).truncationMode(.middle).foregroundStyle(theme.muted)
                } else {
                    Text("自动保存 · 本机存储").foregroundStyle(theme.muted)
                }
                Spacer()
                Text("\(note.body.count) 字").foregroundStyle(theme.muted)
            }
            .font(.system(size: 10)).padding(.horizontal, 24).padding(.vertical, 10)
            .background(theme.canvas.opacity(0.6))
        }
        .background(theme.panel)
    }

    private var searchEmpty: Bool { !store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

private struct NoteRow: View {
    let note: Note
    let theme: ThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(note.title.isEmpty ? "无标题笔记" : note.title)
                .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(theme.ink).lineLimit(1)
            Text(note.body.isEmpty ? "还没有正文" : note.body.replacingOccurrences(of: "\n", with: " "))
                .font(.system(size: 11)).foregroundStyle(theme.muted).lineLimit(2)
            Text(note.updatedAt.formatted(date: .abbreviated, time: .omitted))
                .font(.system(size: 9)).foregroundStyle(theme.muted)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}
