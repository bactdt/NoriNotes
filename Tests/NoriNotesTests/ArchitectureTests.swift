import XCTest
@testable import NoriNotes

/// 结构测试：机械校验 ARCHITECTURE.md 声明的分层依赖与数据流约束。
final class ArchitectureTests: XCTestCase {

    private func source(_ name: String) throws -> String {
        let url = Bundle.moduleURL
            .appendingPathComponent("Sources/NoriNotes")
            .appendingPathComponent(name)
        return try String(contentsOf: url, encoding: .utf8)
    }

    // Types 层不得引用 Store/UI 层类型
    func testTypesLayerDoesNotReferenceUpperLayers() throws {
        let text = try source("Models.swift")
        for forbidden in ["NotebookStore", "ContentView", "MarkdownEditor"] {
            XCTAssertFalse(
                text.contains(forbidden),
                "Types 层不得引用 \(forbidden)：把相关逻辑移到 Store 或 UI 层"
            )
        }
    }

    // Store 层不得引用 UI 层类型
    func testStoreLayerDoesNotReferenceUILayer() throws {
        let text = try source("NotebookStore.swift")
        for forbidden in ["ContentView", "MarkdownEditor"] {
            XCTAssertFalse(
                text.contains(forbidden),
                "Store 层不得引用 UI 类型 \(forbidden)"
            )
        }
    }

    // 持久化必须原子写入
    func testPersistenceUsesAtomicWrite() throws {
        let text = try source("NotebookStore.swift")
        XCTAssertTrue(
            text.contains(".atomic"),
            "持久化必须使用 .atomic 原子写入（见 docs/RELIABILITY.md）"
        )
    }

    // 损坏文件必须先备份再重建，不得直接覆盖
    func testLoadBacksUpCorruptFile() throws {
        let text = try source("NotebookStore.swift")
        XCTAssertTrue(
            text.contains("corrupt"),
            "load() 解析失败时必须把原文件备份为 .corrupt 后再重建（见 docs/RELIABILITY.md）"
        )
    }
}

private extension Bundle {
    /// 测试 target 运行时定位包内源码目录。
    static var moduleURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()          // Tests/NoriNotesTests
            .deletingLastPathComponent()          // Tests
            .deletingLastPathComponent()          // 仓库根
    }
}
