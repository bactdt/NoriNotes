# 架构

## 分层与依赖方向

```text
Types → Store → UI
```

- **Types**（`Sources/NoriNotes/Models.swift`）：纯数据结构 + 纯函数（加密、主题调色板）。禁止 import SwiftUI 以外框架、禁止依赖 Store/UI。
- **Store**（`Sources/NoriNotes/NotebookStore.swift`）：`@MainActor` 状态容器，持久化、过滤、业务动作。可依赖 Types，禁止依赖 UI。
- **UI**（`ContentView.swift`、`NoriNotesApp.swift`、`MarkdownEditor.swift`）：视图层。可依赖 Store 与 Types。
- 依赖方向严格单向，由结构测试机械校验（`Tests/NoriNotesTests/ArchitectureTests.swift`）。

## 目录

```text
Sources/NoriNotes/
├── Models.swift          # Types 层
├── NotebookStore.swift   # Store 层
├── MarkdownEditor.swift  # UI 层：WYSIWYG 编辑器（NSViewRepresentable）
├── ContentView.swift     # UI 层：主界面
└── NoriNotesApp.swift    # UI 层：入口
```

未来模块（OCR/导出/保护）进入 Store 层配套的 Service 类型，位置与依赖规则在加入时更新本文件。

## 数据流

- UI 通过 `@EnvironmentObject` 观察 Store 的 `@Published` 状态。
- 编辑路径：`NSTextView` 文本变化 → Store 增量更新对应笔记字段 → 防抖 0.3s 后原子写盘。**禁止**在每次按键时重建视图数据或全文重新解析 Markdown。
- 持久化：`notebook.json`（ISO8601 日期，原子写入）；损坏时备份为 `.corrupt` 后重建。

## 关键决策

| 决策 | 理由 |
|---|---|
| WYSIWYG 用 NSTextView 而非 SwiftUI TextEditor | 需要按段落增量重样式；TextEditor 无法访问底层存储做增量操作，性能不达标 |
| 零第三方依赖 | 可完全内化推理；Markdown 渲染用 AttributedString(markdown:)（系统库） |
| iCloud 同步缺席 | 用户排除（2026-10-13）；数据层与 UI 已解耦，未来以 Service 形式加入 |
