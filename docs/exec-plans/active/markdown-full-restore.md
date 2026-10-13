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
- [ ] 步骤 1：Types 层扩展——Note 加 markdown 标记、恢复 ProtectedNotePayload/NoteCrypto、AppTheme 与 ThemePalette
- [ ] 步骤 2：Store 层恢复——标签/置顶/归档/保护/搜索过滤；保持防抖与原子写盘
- [ ] 步骤 3：WYSIWYG 编辑器——NSTextView 封装，按段落增量重样式（性能关键路径）
- [ ] 步骤 4：UI 恢复——三栏、主题菜单、标志切换、密码 sheet、删除确认
- [ ] 步骤 5：OCR 服务（Vision/PDFKit）
- [ ] 步骤 6：导出服务（六格式）
- [ ] 步骤 7：CI 加 swift test job；文档同步更新

## 决策日志

| 日期 | 决策 | 理由 |
|---|---|---|
| 2026-10-13 | WYSIWYG 用 NSTextView 增量段落重样式 | 性能优先；SwiftUI TextEditor 无底层存储访问能力 |
| 2026-10-13 | Markdown 渲染用系统 AttributedString(markdown:) | 零依赖，可内化推理 |

## 进度日志

| 日期 | 进展 | 阻塞 |
|---|---|---|
| 2026-10-13 | Day 0 骨架完成 | 无 |

## 关联

- 需求：`docs/requirements.md`
- 架构：`ARCHITECTURE.md`
- 技术债：`docs/exec-plans/tech-debt-tracker.md`
