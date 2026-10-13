# Nori Notes

macOS 桌面 Markdown 笔记应用（Swift/SwiftUI），所见即所得编辑，安静写作气质，性能优先。

## 功能

- **Markdown 所见即所得**：标题/加粗/斜体/行内代码/引用实时渲染，按段落增量重样式，输入不全文重排
- 笔记管理：置顶、归档、标签、搜索（标题/正文/标签）
- 密码保护：单篇笔记 AES-GCM 加密（PBKDF2 派生密钥），密钥仅存内存，忘记密码无法恢复
- OCR 导入：图片/PDF → Vision 本机识别 → 加入笔记
- 导出：Markdown / HTML / DOCX / PDF / JPG / EPUB
- 外观：四套主题（羊皮纸/海盐蓝/鼠尾草/暮色）+ 应用标志切换
- 数据保存在 `~/Library/Application Support/NoriNotes/notebook.json`：原子写入，损坏自动备份，退出强制落盘

## 构建（需要 macOS 14+）

```bash
swift build          # 开发构建
swift test           # 单元测试（含架构结构测试）
swift run            # 直接运行
```

或用 CI：push 到 main 自动跑 lint → test → build，产出 `NoriNotes.app` zip artifact。

## 文档

- 架构与分层：`ARCHITECTURE.md`
- 需求：`docs/requirements.md`
- 设计理念：`docs/design-docs/core-beliefs.md`
- CI 决策：`docs/CI.md`
- 执行计划：`docs/exec-plans/active/`

## 版本

单点声明在 `VERSION`，bump 用 `python3 scripts/bump_version.py [major|minor|patch]`。
