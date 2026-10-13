# Nori Notes MVP

最小可用的 macOS 笔记应用：只有文本编辑 + 自动保存，保留原版主题样式。

## 功能

- 新建 / 选择 / 删除笔记（删除有确认弹窗）
- 标题 + 正文编辑，输入后 0.3 秒自动保存
- 按标题、正文搜索
- 四套原版主题（羊皮纸 / 海盐蓝 / 鼠尾草 / 暮色），在工具栏"主题"菜单切换
- 数据保存在 `~/Library/Application Support/NoriNotes/notebook.json`，退出时强制落盘

## 构建与运行（需要 macOS 14+ 与 Xcode Command Line Tools）

```bash
# 直接运行
swift run

# 或生成 .app（复用原项目的打包脚本思路）
swiftc -swift-version 5 -parse-as-library -O \
  Sources/NoriNotes/*.swift \
  -framework SwiftUI -framework AppKit -framework Combine \
  -o NoriNotes
./NoriNotes
```

## 与原版相比移除的部分

密码保护（AES-GCM）、OCR 导入、多格式导出、iCloud 同步、标签、置顶、归档、应用图标切换。
数据模型改为单文件直接存 `[Note]`；损坏文件会先备份为 `notebook.json.corrupt` 再重建，不会覆盖丢失。
