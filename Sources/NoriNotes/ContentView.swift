import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct ContentView: View {
    @EnvironmentObject private var store: NotebookStore
    @AppStorage("nori.theme") private var themeName = AppTheme.parchment.rawValue
    @AppStorage("nori.glyph") private var appGlyph = "leaf"
    @State private var activeSheet: ActiveSheet?
    @State private var showingImporter = false
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
                if let note = store.selectedNote, !note.isLocked {
                    Button { showingImporter = true } label: { Label("识别图片或 PDF", systemImage: "text.viewfinder") }
                        .help("导入图片或 PDF，并识别可搜索文字")
                    Menu {
                        ForEach(ExportFormat.allCases) { format in
                            Button(format.title) { export(note, as: format) }
                        }
                    } label: { Label("导出", systemImage: "square.and.arrow.up") }
                        .help("导出当前笔记")
                    if let note = store.selectedNote {
                        Button {
                            if note.isPinned { store.setPinned(note.id, pinned: false) }
                            else { store.setPinned(note.id, pinned: true) }
                        } label: {
                            Label(note.isPinned ? "取消置顶" : "置顶", systemImage: note.isPinned ? "pin.fill" : "pin")
                        }
                    }
                    Button {
                        if note.isProtected { store.relock(note.id) }
                        else { activeSheet = .lock(note.id) }
                    } label: {
                        Label(note.isProtected ? "锁定笔记" : "设置笔记密码", systemImage: note.isProtected ? "lock.fill" : "lock")
                    }
                    .help(note.isProtected ? "立即锁定这篇笔记" : "为这篇笔记设置独立密码")
                } else if let note = store.selectedNote, note.isLocked {
                    Button { activeSheet = .unlock(note.id) } label: { Label("解锁笔记", systemImage: "lock.open") }
                }
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
                } label: { Label("外观与标志", systemImage: "paintpalette") }
                    .help("切换主题与标志样式")
            }
        }
        .searchable(text: $store.searchText, placement: .toolbar, prompt: "搜索标题、正文与标签")
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: true, onCompletion: handleImport)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .lock(let id):
                NotePasswordSheet(title: "为笔记加锁", noteTitle: store.notes.first(where: { $0.id == id })?.displayTitle ?? "笔记", confirmingPassword: true) { password in
                    do { try store.protect(id, password: password); return true }
                    catch { store.statusMessage = "加锁失败：\(error.localizedDescription)"; return false }
                }
                .frame(width: 390)
            case .unlock(let id):
                NotePasswordSheet(title: "解锁笔记", noteTitle: "受保护笔记", confirmingPassword: false) { password in
                    let unlocked = store.unlock(id, password: password)
                    if !unlocked { store.statusMessage = "密码不正确，或笔记数据无法验证。" }
                    return unlocked
                }
                .frame(width: 390)
            case .preferences:
                PreferencesView(theme: $themeName, glyph: $appGlyph)
                    .environmentObject(store)
                    .frame(width: 500, height: 560)
            }
        }
        .confirmationDialog("永久删除这篇笔记？", isPresented: $deleteConfirmation, titleVisibility: .visible) {
            Button("删除笔记", role: .destructive) {
                if let pendingDeleteID { store.delete(pendingDeleteID) }
                pendingDeleteID = nil
            }
            Button("取消", role: .cancel) { pendingDeleteID = nil }
        } message: {
            Text("删除后无法从应用内恢复。")
        }
        .onAppear(perform: refreshApplicationIcon)
        .onChange(of: appGlyph) { _, _ in refreshApplicationIcon() }
        .onChange(of: themeName) { _, _ in refreshApplicationIcon() }
    }

    // MARK: - 侧栏

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 11) {
                Image(systemName: appGlyph)
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
                    sidebarRow("全部笔记", symbol: "tray.full", filter: .all, count: store.notes.filter { !$0.isArchived }.count)
                    sidebarRow("已置顶", symbol: "pin", filter: .pinned, count: store.notes.filter { $0.isPinned && !$0.isArchived }.count)
                    sidebarRow("归档", symbol: "archivebox", filter: .archive, count: store.notes.filter(\.isArchived).count)
                }
                if !store.availableTags.isEmpty {
                    Section("标签") {
                        ForEach(store.availableTags, id: \.self) { tag in
                            sidebarRow(tag, symbol: "number", filter: .tag(tag))
                        }
                    }
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

    private func sidebarRow(_ title: String, symbol: String, filter: NotebookFilter, count: Int? = nil) -> some View {
        Button {
            store.activeFilter = filter
            store.select(nil)
        } label: {
            HStack {
                Label(title, systemImage: symbol)
                    .lineLimit(1)
                Spacer()
                if let count { Text("\(count)").font(.system(size: 10, design: .rounded)).foregroundStyle(theme.muted) }
            }
            .contentShape(Rectangle())
            .foregroundStyle(store.activeFilter == filter ? theme.accent : theme.ink)
        }
        .buttonStyle(.plain)
        .listRowBackground(store.activeFilter == filter ? theme.accent.opacity(0.11) : Color.clear)
    }

    // MARK: - 列表

    private var noteList: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(listTitle).font(.system(size: 19, weight: .semibold, design: .rounded)).foregroundStyle(theme.ink)
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
                            if !note.isLocked {
                                Button(note.isPinned ? "取消置顶" : "置顶") { store.setPinned(note.id, pinned: !note.isPinned) }
                            }
                            Button(note.isArchived ? "移出归档" : "归档") { store.setArchived(note.id, archived: !note.isArchived) }
                            Divider()
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

    // MARK: - 编辑器

    private var editor: some View {
        Group {
            if let note = store.selectedNote {
                if note.isLocked {
                    lockedEditor(note)
                } else {
                    editableEditor(note)
                }
            } else {
                VStack(spacing: 13) {
                    Image(systemName: appGlyph).font(.system(size: 38, weight: .light)).foregroundStyle(theme.accent.opacity(0.75))
                    Text("让想法慢慢展开").font(.system(size: 22, weight: .medium, design: .rounded)).foregroundStyle(theme.ink)
                    Text("选择一篇笔记，或新建一个空白页。\n正文支持 Markdown 所见即所得。")
                        .font(.system(size: 13)).multilineTextAlignment(.center).lineSpacing(5).foregroundStyle(theme.muted)
                    Button("新建笔记") { store.createNote() }.buttonStyle(.borderedProminent).tint(theme.accent).padding(.top, 5)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.panel)
            }
        }
    }

    private func lockedEditor(_ note: Note) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.circle.fill").font(.system(size: 48)).foregroundStyle(theme.accent)
            Text("这篇笔记已加密").font(.system(size: 22, weight: .semibold, design: .rounded)).foregroundStyle(theme.ink)
            Text("内容在本机以 AES-GCM 加密保存。输入设置时的密码即可查看。\n密码不会上传；忘记密码后无法恢复。")
                .font(.system(size: 13)).multilineTextAlignment(.center).lineSpacing(5).foregroundStyle(theme.muted)
            Button("输入密码解锁") { activeSheet = .unlock(note.id) }.buttonStyle(.borderedProminent).tint(theme.accent)
        }
        .padding(30).frame(maxWidth: .infinity, maxHeight: .infinity).background(theme.panel)
    }

    private func editableEditor(_ note: Note) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                TextField("无标题笔记", text: Binding(get: { store.selectedNote?.title ?? "" }, set: { store.updateSelected(title: $0) }))
                    .font(.system(size: 29, weight: .semibold, design: .rounded))
                    .textFieldStyle(.plain)
                    .foregroundStyle(theme.ink)
                if note.isPinned { Image(systemName: "pin.fill").foregroundStyle(theme.accent).font(.system(size: 12)) }
            }
            .padding(.top, 32).padding(.horizontal, 56)

            HStack(spacing: 7) {
                Image(systemName: "number").font(.system(size: 11)).foregroundStyle(theme.muted)
                NoteTagEditor(note: note, theme: theme) { tags in store.updateTags(tags, for: note.id) }
                    .id(note.id)
                Spacer()
                Text(note.updatedAt.formatted(date: .abbreviated, time: .shortened)).font(.system(size: 10)).foregroundStyle(theme.muted)
            }
            .padding(.horizontal, 57).padding(.top, 12).padding(.bottom, 18)

            Rectangle().fill(theme.border.opacity(0.65)).frame(height: 1).padding(.horizontal, 56)

            MarkdownEditor(
                text: Binding(get: { store.selectedNote?.body ?? "" }, set: { store.updateSelected(body: $0) }),
                palette: theme
            )
            .padding(.horizontal, 30).padding(.top, 10).padding(.bottom, 8)
            .id(note.id)

            HStack {
                if let status = store.statusMessage {
                    Text(status).lineLimit(1).truncationMode(.middle).foregroundStyle(theme.muted)
                } else {
                    Text("自动保存 · Markdown · 本机存储").foregroundStyle(theme.muted)
                }
                Spacer()
                Text("\(note.body.count) 字").foregroundStyle(theme.muted)
            }
            .font(.system(size: 10)).padding(.horizontal, 24).padding(.vertical, 10)
            .background(theme.canvas.opacity(0.6))
        }
        .background(theme.panel)
    }

    // MARK: - 动作

    private var listTitle: String {
        switch store.activeFilter {
        case .all: return "全部笔记"
        case .pinned: return "已置顶"
        case .archive: return "归档"
        case .tag(let tag): return "# \(tag)"
        }
    }

    private var searchEmpty: Bool { !store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error): store.statusMessage = "导入失败：\(error.localizedDescription)"
        case .success(let urls):
            for url in urls {
                let targetID = store.selectedNote?.id
                Task {
                    do {
                        let text = try await OCRService.recognize(fileAt: url)
                        store.insertOCRText(text, sourceName: url.deletingPathExtension().lastPathComponent, into: targetID)
                    } catch {
                        store.statusMessage = "\(url.lastPathComponent)：\(error.localizedDescription)"
                    }
                }
            }
        }
    }

    private func export(_ note: Note, as format: ExportFormat) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        let cleanTitle = note.title.replacingOccurrences(of: "/", with: "-")
        panel.nameFieldStringValue = "\(cleanTitle.isEmpty ? "Nori 笔记" : cleanTitle).\(format.fileExtension)"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try ExportService.export(note: note, format: format, to: url)
            store.statusMessage = "已导出为 \(format.title)。"
        } catch {
            store.statusMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    private func refreshApplicationIcon() {
        let symbolName = appGlyph
        let themeValue = AppTheme(rawValue: themeName) ?? .parchment
        let accent: NSColor
        switch themeValue {
        case .parchment: accent = NSColor(calibratedRed: 0.73, green: 0.36, blue: 0.22, alpha: 1)
        case .seaGlass: accent = NSColor(calibratedRed: 0.18, green: 0.48, blue: 0.52, alpha: 1)
        case .sage: accent = NSColor(calibratedRed: 0.35, green: 0.48, blue: 0.30, alpha: 1)
        case .dusk: accent = NSColor(calibratedRed: 0.92, green: 0.59, blue: 0.40, alpha: 1)
        }
        let icon = NSImage(size: NSSize(width: 512, height: 512), flipped: false) { rect in
            accent.setFill()
            NSBezierPath(roundedRect: rect.insetBy(dx: 18, dy: 18), xRadius: 112, yRadius: 112).fill()
            if let symbol = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Nori Notes")?.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 208, weight: .medium)) {
                symbol.isTemplate = true
                NSColor.white.set()
                symbol.draw(in: NSRect(x: 125, y: 125, width: 262, height: 262), from: .zero, operation: .sourceAtop, fraction: 1, respectFlipped: false, hints: nil)
            }
            return true
        }
        NSApplication.shared.applicationIconImage = icon
    }

    private enum ActiveSheet: Identifiable {
        case lock(UUID), unlock(UUID), preferences
        var id: String {
            switch self {
            case .lock(let id): return "lock-\(id)"
            case .unlock(let id): return "unlock-\(id)"
            case .preferences: return "preferences"
            }
        }
    }
}

