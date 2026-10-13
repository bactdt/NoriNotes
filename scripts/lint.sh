#!/bin/bash
# 本地门禁入口：结构 lint（任意平台可用）。swift build/test 需 macOS。
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$ROOT/scripts/lint.py"
