import Foundation
import AppKit
import Combine

@MainActor
final class NotebookStore: ObservableObject {
    @Published private(set) var notes: [Note] = []
    @Published var selectedNoteID: UUID?
    @Published var searchText = ""
    @Published var statusMessage: String?

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

    var filteredNotes: [Note] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return notes.filter { note in
            guard !needle.isEmpty else { return true }
            return note.title.localizedCaseInsensitiveContains(needle)
                || note.body.localizedCaseInsensitiveContains(needle)
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    func createNote() {
        let now = Date()
        let note = Note(id: UUID(), title: "", body: "", createdAt: now, updatedAt: now)
        notes.insert(note, at: 0)
        selectedNoteID = note.id
        persist()
    }

    func updateSelected(title: String? = nil, body: String? = nil) {
        guard let id = selectedNoteID, let index = notes.firstIndex(where: { $0.id == id }) else { return }
        if let title { notes[index].title = title }
        if let body { notes[index].body = body }
        notes[index].updatedAt = Date()
        schedulePersist()
    }

    func delete(_ id: UUID) {
        notes.removeAll { $0.id == id }
        if selectedNoteID == id { selectedNoteID = nil }
        persist()
    }

    private func schedulePersist() {
        let token = UUID()
        pendingSaveToken = token
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.pendingSaveToken == token else { return }
            self.persist()
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder.pretty.encode(notes)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            statusMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else {
            createWelcomeNote()
            return
        }
        if let stored = try? JSONDecoder.iso8601.decode([Note].self, from: data) {
            notes = stored
        } else {
            let backup = fileURL.appendingPathExtension("corrupt")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            statusMessage = "原数据文件无法读取，已备份为 notebook.json.corrupt。"
            createWelcomeNote()
        }
    }

    private func createWelcomeNote() {
        let now = Date()
        notes = [Note(id: UUID(), title: "欢迎来到 Nori", body: "这里是你的安静写作角落。\n\n• 点击右上角 + 或按 ⌘N 新建笔记。\n• 输入的内容会自动保存到这台设备。\n\n试着写下今天想记住的一件小事。", createdAt: now, updatedAt: now)]
        persist()
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
