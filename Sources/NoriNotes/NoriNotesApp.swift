import SwiftUI

@main
struct NoriNotesApp: App {
    @StateObject private var store = NotebookStore()

    var body: some Scene {
        WindowGroup("Nori Notes") {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 920, minHeight: 620)
                .frame(idealWidth: 1160, idealHeight: 780)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建笔记") { store.createNote() }
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
