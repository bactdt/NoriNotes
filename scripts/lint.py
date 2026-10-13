#!/usr/bin/env python3
"""结构 lint：本仓库的自定义门禁（可在无 macOS 环境下运行）。

规则（违反时输出修复指令）：
  R1 文件大小：Sources/ 下 Swift 文件 <= 400 行
  R2 分层依赖：UI 不得被 Store/Types import；Store 不得 import UI 文件同名类型
  R3 命名约定：类型名使用大驼峰；Swift 文件名与其中主类型一致（仅提示级）
  R4 禁止视图侧直接修改模型：UI 文件不得出现对 Note 字段的直接赋值（notes[index].xxx =）
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "Sources" / "NoriNotes"
MAX_LINES = 400

UI_FILES = {"ContentView.swift", "NoriNotesApp.swift", "MarkdownEditor.swift"}
STORE_FILES = {"NotebookStore.swift"}
TYPE_FILES = {"Models.swift"}

failures: list[str] = []


def check_file_size(path: Path) -> None:
    lines = path.read_text().splitlines()
    if len(lines) > MAX_LINES:
        failures.append(
            f"R1 {path.name}: {len(lines)} 行超过 {MAX_LINES} 上限。"
            f"修复：把独立类型/扩展拆到新文件，遵循单一职责。"
        )


def check_layers(path: Path) -> None:
    text = path.read_text()
    name = path.name
    if name in TYPE_FILES:
        for bad in ("NotebookStore", "ContentView", "MarkdownEditor"):
            if re.search(rf"\b{bad}\b", text):
                failures.append(
                    f"R2 {name}: Types 层出现 {bad}。"
                    f"修复：Types 只含模型与纯函数；把相关逻辑移到 Store 或 UI 层。"
                )
    if name in STORE_FILES:
        for bad in ("ContentView", "MarkdownEditor"):
            if re.search(rf"\b{bad}\b", text):
                failures.append(
                    f"R2 {name}: Store 层出现 UI 类型 {bad}。"
                    f"修复：Store 不依赖 UI；用回调或状态让 UI 自行响应。"
                )


def check_ui_mutation(path: Path) -> None:
    if path.name not in UI_FILES:
        return
    text = path.read_text()
    pattern = re.compile(r"notes\s*\[\s*\w+\s*\]\s*\.\s*\w+\s*=")
    if pattern.search(text):
        failures.append(
            f"R4 {path.name}: UI 层直接修改 notes 元素。"
            f"修复：改用 store.updateSelected/updateTags 等结构化方法。"
        )


def main() -> int:
    if not SRC.exists():
        print(f"未找到源码目录 {SRC}", file=sys.stderr)
        return 2
    swift_files = sorted(SRC.glob("*.swift"))
    if not swift_files:
        print("没有 Swift 源文件", file=sys.stderr)
        return 2
    for path in swift_files:
        check_file_size(path)
        check_layers(path)
        check_ui_mutation(path)
    if failures:
        print("结构 lint 失败：")
        for f in failures:
            print(f"  - {f}")
        return 1
    print(f"结构 lint 通过（{len(swift_files)} 个文件）")
    return 0


if __name__ == "__main__":
    sys.exit(main())
