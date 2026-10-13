import Foundation
import AppKit
import Combine

@MainActor
final class NotebookStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published var selectedNoteID: UUID?
    @Published var activeFilter: NotebookFilter = .all
    @Published var searchText = ""
    @Published var statusMessage: String?

    private var unlockedKeys: [UUID: Data] = [:]
    private var pendingSaveToken = UUID()
    private let fileURL: URL

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("NoriNotes", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        fileURL = support.appendingPathComponent("notebook.json")
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.persist() }
        }
        load()
    }

    var selectedNote: Note? {
        guard let selectedNoteID else { return nil }
        return notes.first(where: { $0.id == selectedNoteID })
    }

    var availableTags: [String] {
        Array(Set(notes.filter { !$0.isLocked && !$0.isArchived }.flatMap(\.tags)))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    var filteredNotes: [Note] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return notes.filter { note in
            let matchesFilter: Bool
            switch activeFilter {
            case .all: matchesFilter = !note.isArchived
            case .pinned: matchesFilter = note.isPinned && !note.isArchived
            case .archive: matchesFilter = note.isArchived
            case .tag(let tag): matchesFilter = !note.isArchived && note.tags.contains(tag)
            }
            guard matchesFilter else { return false }
            guard !needle.isEmpty else { return true }
            if note.isLocked { return "受保护笔记".localizedCaseInsensitiveContains(needle) }
            return note.title.localizedCaseInsensitiveContains(needle)
                || note.body.localizedCaseInsensitiveContains(needle)
                || note.tags.contains(where: { $0.localizedCaseInsensitiveContains(needle) })
        }.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    func createNote() {
        activeFilter = .all
        let now = Date()
        let note = Note(id: UUID(), title: "", body: "", tags: [], createdAt: now, updatedAt: now, isPinned: false, isArchived: false, isLocked: false, protection: nil)
        notes.insert(note, at: 0)
        selectedNoteID = note.id
        persist()
    }

    func select(_ id: UUID?) { selectedNoteID = id }

    func updateSelected(title: String? = nil, body: String? = nil, tags: [String]? = nil) {
        guard let id = selectedNoteID, let index = notes.firstIndex(where: { $0.id == id }), !notes[index].isLocked else { return }
        if let title { notes[index].title = title }
        if let body { notes[index].body = body }
        if let tags { notes[index].tags = Self.normalizedTags(tags) }
        notes[index].updatedAt = Date()
        schedulePersist()
    }

    func updateTags(_ tags: [String], for id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }), !notes[index].isLocked else { return }
        notes[index].tags = Self.normalizedTags(tags)
        notes[index].updatedAt = Date()
        schedulePersist()
    }

    func setPinned(_ id: UUID, pinned: Bool) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].isPinned = pinned
        notes[index].updatedAt = Date()
        persist()
    }

    func setArchived(_ id: UUID, archived: Bool) {
        guard let index = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[index].isArchived = archived
        notes[index].updatedAt = Date()
        if archived, selectedNoteID == id { selectedNoteID = nil }
        persist()
    }

    func delete(_ id: UUID) {
        notes.removeAll { $0.id == id }
        unlockedKeys.removeValue(forKey: id)
        if selectedNoteID == id { selectedNoteID = nil }
        persist()
    }

    func insertOCRText(_ text: String, sourceName: String, into noteID: UUID?) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else {
            statusMessage = "没有识别到可搜索的文字。"
            return
        }
        if let noteID, let index = notes.firstIndex(where: { $0.id == noteID }), !notes[index].isLocked {
            notes[index].body += "\n\n--- \(sourceName) 的文字识别 ---\n" + cleaned
            notes[index].updatedAt = Date()
            schedulePersist()
            selectedNoteID = noteID
        } else {
            createNote()
            updateSelected(title: sourceName, body: cleaned, tags: ["OCR"])
        }
        statusMessage = "已将识别文字加入笔记，现在可在搜索中查找。"
    }

    // MARK: - 密码保护

    func protect(_ id: UUID, password: String) throws {
        guard let index = notes.firstIndex(where: { $0.id == id }), !notes[index].isLocked else { return }
        let content = SecureNoteContent(title: notes[index].title, body: notes[index].body, tags: notes[index].tags)
        let (envelope, key) = try NoteCrypto.protect(content, password: password)
        unlockedKeys[id] = key
        notes[index].protection = envelope
        notes[index].isLocked = false
        persist()
    }

    func unlock(_ id: UUID, password: String) -> Bool {
        guard let index = notes.firstIndex(where: { $0.id == id }), let envelope = notes[index].protection else { return false }
        do {
            let (content, key) = try NoteCrypto.unlock(envelope, password: password)
            unlockedKeys[id] = key
            notes[index].title = content.title
            notes[index].body = content.body
            notes[index].tags = content.tags
            notes[index].isLocked = false
            selectedNoteID = id
            return true
        } catch {
            return false
        }
    }

    func relock(_ id: UUID) {
        guard let index = notes.firstIndex(where: { $0.id == id }), notes[index].isProtected else { return }
        guard sealCurrentContent(at: index) else {
            // 重封失败时不清除内存明文、不解锁密钥，否则唯一明文副本会丢失。
            statusMessage = "加密失败，笔记保持解锁状态，请重试。"
            return
        }
        notes[index].title = "受保护笔记"
        notes[index].body = ""
        notes[index].tags = []
        notes[index].isLocked = true
        unlockedKeys.removeValue(forKey: id)
        persist()
    }

    // MARK: - 持久化

    private func schedulePersist() {
        let token = UUID()
        pendingSaveToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.pendingSaveToken == token else { return }
            self.persist()
        }
    }

    private func persist() {
        for index in notes.indices {
            guard sealCurrentContent(at: index) else {
                // 重封失败意味着加密数据与内存明文不一致；此时落盘会保存过期密文。
                // 中止本次持久化，保留内存中的编辑，等下次成功再写。
                statusMessage = "加密笔记更新失败，更改尚未写入磁盘，请重试。"
                return
            }
        }
        do {
            let data = try JSONEncoder.pretty.encode(Self.redactedForDisk(notes))
            try data.write(to: fileURL, options: .atomic)
        } catch {
            statusMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    /// 已解锁的保护笔记明文只存在于内存；落盘前替换为脱敏副本，密文在 protection 里。
    private static func redactedForDisk(_ notes: [Note]) -> [Note] {
        notes.map { note in
            guard note.isProtected, !note.isLocked else { return note }
            var redacted = note
            redacted.title = "受保护笔记"
            redacted.body = ""
            redacted.tags = []
            redacted.isLocked = true
            return redacted
        }
    }

    /// 持久化前把已解锁保护笔记的明文重新封存（密钥仍在内存中，不影响继续编辑）。
    /// 返回 false 表示重封失败，调用方必须中止持久化/锁定，避免编辑内容丢失。
    private func sealCurrentContent(at index: Int) -> Bool {
        let note = notes[index]
        guard note.isProtected, !note.isLocked, let key = unlockedKeys[note.id] else { return true }
        do {
            let content = SecureNoteContent(title: note.title, body: note.body, tags: note.tags)
            let combined = try NoteCrypto.reseal(content, using: key)
            notes[index].protection?.combined = combined
            return true
        } catch {
            statusMessage = "加密笔记更新失败：\(error.localizedDescription)"
            return false
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            createWelcomeNote()
            return
        }
        if let stored = try? JSONDecoder.iso8601.decode([Note].self, from: data) {
            notes = stored.map(Self.materialize)
        } else {
            let backup = fileURL.appendingPathExtension("corrupt")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            statusMessage = "原数据文件无法读取，已备份为 notebook.json.corrupt。"
            createWelcomeNote()
        }
    }

    private static func materialize(_ item: Note) -> Note {
        var note = item
        if note.protection != nil {
            note.isLocked = true
            note.title = "受保护笔记"
            note.body = ""
            note.tags = []
        }
        return note
    }

    private func createWelcomeNote() {
        let now = Date()
        notes = [Note(id: UUID(), title: "欢迎来到 Nori", body: "这里是你的安静写作角落。\n\n• 用左侧筛选笔记，或按 ⌘N 创建新笔记。\n• 正文支持 Markdown：# 标题、**加粗**、*斜体*、`代码`、- 列表、> 引用。\n• 将图片或 PDF 拖入或导入，应用会在本机识别文字并加入搜索索引。\n• 可为单篇笔记设置独立密码；密码不会上传或保存。\n\n试着写下今天想记住的一件小事。", tags: ["开始使用"], createdAt: now, updatedAt: now, isPinned: true, isArchived: false, isLocked: false, protection: nil)]
        persist()
    }

    private static func normalizedTags(_ tags: [String]) -> [String] {
        Array(Set(tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })).sorted()
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
