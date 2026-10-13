# 执行计划：Markdown 所见即所得 + 完整功能恢复

- **状态**：active
- **创建日期**：2026-10-13
- **驱动**：用户需求（docs/requirements.md），性能优先

## 目标

在现有 Swift/SwiftUI 仓库上恢复原压缩包全部功能（除 iCloud 同步），新增 Markdown 所见即所得编辑；harness Day 0 骨架就位。

## 验收标准

- WYSIWYG：标题/加粗/斜体/代码/列表/引用实时渲染，输入不全文重排
- 置顶/归档/标签/搜索、密码保护、OCR 导入、六格式导出、主题+标志切换全部可用
- CI 绿：lint + 结构测试 + swift build + swift test
- 性能断言（RELIABILITY.md）在 CI 冒烟与人工测试中成立

## 拆解

- [x] Day 0：文档骨架（AGENTS/ARCHITECTURE/docs/*）、lint、结构测试、CI 更新
- [x] 步骤 1：Types 层扩展——恢复 ProtectedNotePayload/NoteCrypto、AppTheme 与 ThemePalette
- [x] 步骤 2：Store 层恢复——标签/置顶/归档/保护/搜索过滤；保持防抖与原子写盘
- [x] 步骤 3：WYSIWYG 编辑器——NSTextView 封装，按段落增量重样式（性能关键路径）
- [x] 步骤 4：UI 恢复——三栏、主题菜单、标志切换、密码 sheet、删除确认
- [x] 步骤 5：OCR 服务（Vision/PDFKit）
- [x] 步骤 6：导出服务（六格式）
- [x] 步骤 7：CI 加 swift test job；文档同步更新
- [ ] 步骤 8（待用户验收）：真机 WYSIWYG 手感与大文档性能验证

## 决策日志

| 日期 | 决策 | 理由 |
|---|---|---|
| 2026-10-13 | WYSIWYG 用 NSTextView 增量段落重样式 | 性能优先；SwiftUI TextEditor 无底层存储访问能力 |
| 2026-10-13 | Markdown 渲染自研轻量解析（headingMarker/inlineMatches 纯函数） | 系统 AttributedString(markdown:) 整块转换无法做段落级增量；自研可完全内化推理 |
| 2026-10-13 | OCR 追加目标在发起导入时固定（into: noteID） | 修复原版并发导入可能写错笔记的问题 |
| 2026-10-13 | Codex 评审后：Note 自定义 init(from:) 给旧字段默认值 | 旧版 notebook.json 升级时按损坏处理会丢数据（P1） |
| 2026-10-13 | Codex 评审后：落盘前脱敏已解锁保护笔记；重封失败中止持久化与锁定 | 防止明文写入 JSON（P1）与重封失败丢失唯一明文（P2） |
| 2026-10-13 | Codex 评审后：palette 仅在视觉值变化时全文重样式；编辑范围基于 textStorage.editedRange；NSRange 全部 UTF-16 单位 | 打字路径性能契约（P1）、跨段粘贴（P2）、emoji 长度错误（P2） |

## 进度日志

| 日期 | 进展 | 阻塞 |
|---|---|---|
| 2026-10-13 | Day 0 骨架完成 | 无 |
| 2026-10-13 | 步骤 1-6 全部完成并推送；CI 首跑抓出 4 类编译错误已修复，全绿（run 38391034001） | 无 |
| 2026-10-13 | Codex reviewer 评审：3 P1 + 4 P2 全部修复，CI 全绿（run 38399810581） | 无 |

## 关联

- 需求：`docs/requirements.md`
- 架构：`ARCHITECTURE.md`
- 技术债：`docs/exec-plans/tech-debt-tracker.md`
