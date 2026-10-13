import SwiftUI
import AppKit

/// 所见即所得 Markdown 编辑器。
///
/// 性能契约（RELIABILITY.md）：任何输入路径禁止全文重排。
/// 实现方式：NSViewController 持有 NSTextView，文本变化时只对**光标所在段落**
/// 重新应用 Markdown 样式，其余段落保持已渲染的 NSAttributedString 原样。
struct MarkdownEditor: NSViewRepresentable {
    let text: Binding<String>
    let palette: ThemePalette

    func makeCoordinator() -> Coordinator {
        Coordinator(text: text, palette: palette)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        let textView = MarkdownTextView()
        textView.delegate = context.coordinator
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.textContainer?.widthTracksTextView = true
        textView.drawsBackground = false
        textView.insertionPointColor = NSColor(palette.accent)
        context.coordinator.attach(textView)

        scrollView.documentView = textView
        context.coordinator.applyBaseStyle()
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.palette = palette
        let newText = text.wrappedValue
        guard let textView = context.coordinator.textView else { return }
        // 外部数据变化（切换笔记/OCR 追加）时整体替换；编辑器自身输入不会走到这里。
        if textView.string != newText {
            context.coordinator.isExternalUpdate = true
            textView.string = newText
            context.coordinator.applyBaseStyle()
            context.coordinator.isExternalUpdate = false
        }
        textView.insertionPointColor = NSColor(palette.accent)
    }
}

// MARK: - Controller

final class Coordinator: NSObject, NSTextViewDelegate {
    var textView: MarkdownTextView?
    var palette: ThemePalette {
        didSet { restyleAllParagraphs() }
    }
    let text: Binding<String>
    /// 编辑器内部输入引起的变化标记为 true，避免 updateNSView 回写造成抖动。
    var isInternalEdit = false
    var isExternalUpdate = false

    private var paragraphStyles: [Int: NSAttributedString] = [:]

    init(text: Binding<String>, palette: ThemePalette) {
        self.text = text
        self.palette = palette
    }

    func attach(_ textView: MarkdownTextView) {
        self.textView = textView
        textView.coordinator = self
    }

    // MARK: NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        guard let textView else { return }
        isInternalEdit = true
        text.wrappedValue = textView.string
        restyleVisibleChangedParagraphs()
        isInternalEdit = false
    }

    // MARK: 样式

    /// 基础样式 + 全文渲染。仅用于外部替换内容（切换笔记等），非输入路径。
    func applyBaseStyle() {
        guard let textView else { return }
        applyMarkdownStyling(in: textView, range: NSRange(location: 0, length: (textView.string as NSString).length))
        paragraphStyles.removeAll()
    }

    /// 输入路径：只重样式"内容实际发生变化的段落"。
    func restyleVisibleChangedParagraphs() {
        guard let textView else { return }
        let nsText = textView.string as NSString
        let editedRange = min(textView.selectedRange.location, nsText.length)
        let paragraphRange = nsText.paragraphRange(for: NSRange(location: editedRange, length: 0))
        let plainParagraph = nsText.substring(with: paragraphRange)
        let previous = paragraphStyles[paragraphRange.location]

        // 段落纯文本没变（只是行内样式可能变化，如补全 **），跳过重排。
        if let previous, previous.string == plainParagraph { return }

        applyMarkdownStyling(in: textView, range: paragraphRange)
        let styled = textView.attributedText().attributedSubstring(from: paragraphRange)
        paragraphStyles[paragraphRange.location] = NSAttributedString(attributedString: styled)
    }

    private func restyleAllParagraphs() {
        guard let textView, !isExternalUpdate else { return }
        applyBaseStyle()
    }

    /// 把段落内的 Markdown 标记渲染为属性文本（标题/加粗/斜体/行内代码/引用）。
    private func applyMarkdownStyling(in textView: NSTextView, range: NSRange) {
        let storage = textView.textStorage!
        let nsText = textView.string as NSString
        let paragraph = nsText.substring(with: range)
        let baseFont = NSFont.systemFont(ofSize: 15, weight: .regular)
        let body: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: palette.ink,
            .paragraphStyle: paragraphStyle(),
        ]
        storage.setAttributes(body, range: range)

        // 标题行：# ~ ######
        if let headingMatch = MarkdownEditor.headingMarker(in: paragraph), range.length > 0 {
            let level = headingMatch.markerCount
            let size = CGFloat([22.0, 19.0, 17.0, 15.5, 15.0, 15.0][min(level, 6) - 1])
            let weight: NSFont.Weight = level <= 2 ? .semibold : .medium
            let titleLength = min(paragraph.count, range.length)
            storage.addAttributes([
                .font: NSFont.systemFont(ofSize: size, weight: weight),
                .foregroundColor: palette.ink,
            ], range: NSRange(location: range.location, length: titleLength))
            let markerLength = min(headingMatch.markerCount + 1, titleLength)
            storage.addAttribute(.foregroundColor, value: palette.muted, range: NSRange(location: range.location, length: markerLength))
            return
        }

        // 引用行：> text
        if paragraph.hasPrefix(">"), range.length > 0 {
            let titleLength = min(paragraph.count, range.length)
            storage.addAttributes([
                .font: NSFont.systemFont(ofSize: 14, weight: .regular),
                .foregroundColor: palette.muted,
            ], range: NSRange(location: range.location, length: titleLength))
            return
        }

        // 行内规则：**加粗**、*斜体*、`代码`（逐段处理，不跨段）
        let contentLength = min(paragraph.count, range.length)
        let contentRange = NSRange(location: range.location, length: contentLength)
        let content = nsText.substring(with: contentRange)
        for (marker, attributes) in MarkdownEditor.inlineRules(palette: palette) {
            let matches = MarkdownEditor.inlineMatches(of: marker, in: content)
            for match in matches {
                let nsInner = match.inner as NSString
                let offset = match.offset
                let fullRange = NSRange(location: contentRange.location + offset, length: match.fullLength)
                let innerRange = NSRange(location: contentRange.location + offset + marker.count, length: nsInner.length)
                storage.addAttributes(attributes, range: innerRange)
                storage.addAttribute(.foregroundColor, value: palette.muted, range: NSRange(location: fullRange.location, length: marker.count))
                storage.addAttribute(.foregroundColor, value: palette.muted, range: NSRange(location: fullRange.location + fullRange.length - marker.count, length: marker.count))
            }
        }
    }

    private func paragraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.lineSpacing = 6
        return style
    }
}

// MARK: - TextView

final class MarkdownTextView: NSTextView {
    var coordinator: Coordinator?

    override func paste(_ sender: Any?) {
        super.paste(sender)
        coordinator?.textDidChange(Notification(name: NSText.didChangeNotification, object: self, userInfo: nil))
    }
}

// MARK: - 规则表

extension MarkdownEditor {
    struct HeadingMatch {
        let markerCount: Int
    }

    struct InlineMatch {
        let inner: String
        let offset: Int
        let fullLength: Int
    }

    /// 标题行解析：返回 # 数量。独立纯函数便于单测。
    static func headingMarker(in paragraph: String) -> HeadingMatch? {
        guard let sharpCount = paragraph.prefix(while: { $0 == "#" }).count as Int?,
              sharpCount >= 1, sharpCount <= 6,
              paragraph.count > sharpCount,
              paragraph[paragraph.index(paragraph.startIndex, offsetBy: sharpCount)] == " " else { return nil }
        return HeadingMatch(markerCount: sharpCount)
    }

    /// 行内标记匹配：找到成对包裹的内容。独立纯函数便于单测。
    static func inlineMatches(of marker: String, in content: String) -> [InlineMatch] {
        var results: [InlineMatch] = []
        let ns = content as NSString
        let pattern = NSRegularExpression.escapedPattern(for: marker) + "([^" + NSRegularExpression.escapedPattern(for: marker) + "]+)" + NSRegularExpression.escapedPattern(for: marker)
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return results }
        let full = NSRange(location: 0, length: ns.length)
        for match in regex.matches(in: content, range: full) {
            let innerRange = match.range(at: 1)
            guard innerRange.location != NSNotFound else { continue }
            results.append(InlineMatch(
                inner: ns.substring(with: innerRange),
                offset: match.range.location,
                fullLength: match.range.length
            ))
        }
        return results
    }

    /// 行内 Markdown 规则（顺序即优先级）。独立函数便于单测。
    static func inlineRules(palette: ThemePalette) -> [(String, [NSAttributedString.Key: Any])] {
        let codeBackground = palette.accent.opacity(0.10)
        return [
            ("**", [.font: NSFont.boldSystemFont(ofSize: 15)]),
            ("*", [.font: NSFont.systemFont(ofSize: 15).withSlant()]),
            ("`", [
                .font: NSFont.monospacedSystemFont(ofSize: 13.5, weight: .regular),
                .backgroundColor: NSColor(codeBackground),
            ]),
        ]
    }
}

private extension NSFont {
    func withSlant() -> NSFont {
        NSFontManager.shared.convert(self, toHaveTrait: [.italicFontMask])
    }
}

extension NSTextView {
    /// 兼容访问（macOS 14 可直接用 attributedSubstring）。
    var attributedText: () -> NSAttributedString {
        { self.attributedString() }
    }
}
