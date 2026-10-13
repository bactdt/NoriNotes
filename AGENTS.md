# AGENTS.md

> 本文件是**内容目录**，不是百科全书。需要细节时，按下方指引跳转。

## 这是什么项目

Nori Notes：macOS 桌面 Markdown 笔记应用（Swift/SwiftUI），WYSIWYG 编辑，安静写作气质，性能优先。

## 如何开始

- 架构与分层：见 `ARCHITECTURE.md`
- 需求与功能范围：见 `docs/requirements.md`
- 设计理念：见 `docs/design-docs/core-beliefs.md`
- CI 与框架判定：见 `docs/CI.md`
- 当前执行计划：见 `docs/exec-plans/active/`
- 技术债：见 `docs/exec-plans/tech-debt-tracker.md`

## 硬性约束（不可违反）

- 分层依赖：Types → Store → UI，只能单向；结构测试会拦截违规
- 编辑器输入路径禁止全文重排（增量重样式，见 ARCHITECTURE 数据流节）
- 持久化必须原子写入；损坏文件先备份再重建
- 文件不超过 400 行（lint 检查）；结构化更新状态，禁止视图侧直接改模型
- 密码学实现（Models.swift 的 PBKDF2/AES）改动前必须征得用户确认

## 会话纪律

- 提交按单一职责拆分，Conventional Commits（feat/fix/chore/docs/refactor/test）
- 会话最后一次提交通过全部本地门禁，并注明 `[已测试]` / `[未测试]`（本地无 macOS 环境时标 `[未测试-CI]`，以 CI 运行为准）
- 交互式决策（技术栈、功能范围等）确认后必须写入 `docs/requirements.md` 或 `docs/CI.md`
- 计划写在 `docs/exec-plans/active/`，完成后移入 `completed/`

## 规范索引

- 质量评分：`docs/QUALITY_SCORE.md`
- 可靠性：`docs/RELIABILITY.md`
- 安全：`docs/SECURITY.md`
- 产品规格：`docs/product-specs/index.md`
- 设计文档：`docs/design-docs/index.md`

## 工作方式

- 提交前运行：`swiftlint`（若可用）与 `swift test`（需 macOS；Linux 环境仅做结构 lint，见 `scripts/lint.sh`）
- 变更前先读相关 `docs/`，变更后同步更新文档
- 版本单点声明在 `VERSION`，bump 用 `scripts/bump_version.py`
