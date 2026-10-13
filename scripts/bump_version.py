#!/usr/bin/env python3
"""版本单点 bump：更新仓库根 VERSION 文件（语义化版本）。

用法：python3 scripts/bump_version.py [major|minor|patch] [vX.Y.Z]
"""
import re
import sys
from pathlib import Path

VERSION_FILE = Path(__file__).resolve().parent.parent / "VERSION"


def read_version() -> str:
    if not VERSION_FILE.exists():
        return "0.1.0"
    return VERSION_FILE.read_text().strip() or "0.1.0"


def bump(version: str, part: str) -> str:
    major, minor, patch = (int(x) for x in version.split("."))
    if part == "major":
        return f"{major + 1}.0.0"
    if part == "minor":
        return f"{major}.{minor + 1}.0"
    return f"{major}.{minor}.{patch + 1}"


def main() -> int:
    args = sys.argv[1:]
    version = read_version()
    if not args:
        print(version)
        return 0
    if args[0] == "set":
        if len(args) < 2 or not re.fullmatch(r"\d+\.\d+\.\d+", args[1]):
            print("用法：bump_version.py set X.Y.Z", file=sys.stderr)
            return 2
        new = args[1]
    else:
        if args[0] not in ("major", "minor", "patch"):
            print("用法：bump_version.py [major|minor|patch|set X.Y.Z]", file=sys.stderr)
            return 2
        new = bump(version, args[0])
    VERSION_FILE.write_text(new + "\n")
    print(f"{version} -> {new}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
