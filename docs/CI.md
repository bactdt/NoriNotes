# CI 配置决定

## 1. 框架判定

- 判定结果：**其他**（非 Tauri）
- 判定证据：技术栈结论（`docs/requirements.md` 用户确认记录 + `docs/design-docs/core-beliefs.md`）——语言 Swift 5.9、框架 SwiftUI + AppKit、包管理器 SPM、目标平台 macOS 桌面。无 `src-tauri/`、无 Node/Rust 工具链。
- 判定日期：2026-10-13

## 2. 交互确认记录

不适用（非 Tauri 项目，§3.5）。未执行 §3.4 三问。

## 3. 落地说明

- 按 §3.5：**跳过**多平台打包与 Release 流水线，不生成 `release.yml`。
- 基础门禁照建：`.github/workflows/build.yml`（lint → test → build → 拼 .app artifact），runner `macos-14`。
- 触发条件：push 到 main、PR、手动 dispatch。
- 版本声明点：**单点** `VERSION` 文件（无多端版本一致性问题）；CI 生成 Info.plist 时读取。bump 用 `scripts/bump_version.py`。

## 4. 变更历史

| 日期 | 变更 | 原因 |
|---|---|---|
| 2026-10-13 | 建立；判定为非 Tauri，跳过 Release 流水线 | 项目 Day 0 框架确认 |
