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
        textView.insertionPointColor = palette.accent
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
        textView.insertionPointColor = palette.accent
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
        if let headingMatch = paragraph.firstMatch(of: /^(#{1,6})\s+(.*)$/), range.length > 0 {
            let level = headingMatch.1.count
            let size = CGFloat([22, 19, 17, 15.5, 15, 15][min(level, 6) - 1])
            let weight: NSFont.Weight = level <= 2 ? .semibold : .medium
            let titleLength = min(paragraph.count, range.length)
            storage.addAttributes([
                .font: NSFont.systemFont(ofSize: size, weight: weight, design: .rounded),
                .foregroundColor: palette.ink,
            ], range: NSRange(location: range.location, length: titleLength))
            let markerLength = min(headingMatch.1.count + 1, titleLength)
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
            var searchStart = content.startIndex
            while let matchRange = content.range(of: marker + "[^" + marker.first! + "]*" + marker, options: .regularExpression, range: searchStart..<content.endIndex) {
                let inner = content[matchRange].dropFirst(marker.count).dropLast(marker.count)
                let nsInner = String(inner) as NSString
                let offset = content.distance(from: content.startIndex, to: matchRange.lowerBound)
                let fullRange = NSRange(location: contentRange.location + offset, length: content.distance(from: matchRange.lowerBound, to: matchRange.upperBound))
                let innerRange = NSRange(location: contentRange.location + offset + marker.count, length: nsInner.length)
                storage.addAttributes(attributes, range: innerRange)
                storage.addAttribute(.foregroundColor, value: palette.muted, range: NSRange(location: fullRange.location, length: marker.count))
                storage.addAttribute(.foregroundColor, value: palette.muted, range: NSRange(location: fullRange.location + fullRange.length - marker.count, length: marker.count))
                searchStart = matchRange.upperBound
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
    /// 行内 Markdown 规则（顺序即优先级）。独立函数便于单测。
    static func inlineRules(palette: ThemePalette) -> [(String, [NSAttributedString.Key: Any])] {
        [
            ("**", [.font: NSFont.boldSystemFont(ofSize: 15)]),
            ("*", [.font: NSFont.systemFont(ofSize: 15, weight: .regular).withSlant()]),
            ("`", [
                .font: NSFont.monospacedSystemFont(ofSize: 13.5, weight: .regular),
                .backgroundColor: palette.accent.opacity(0.10),
            ]),
        ]
    }
}

private extension NSFont {
    func withSlant() -> NSFont {
        NSFontManager.shared.convert(self, toHaveTrait: [.italicFontMask])
    }
}

private extension String {
    func firstMatch(of pattern: Regex<Substring>) -> Regex<Substring>.Match? {
        self.firstMatch(of: pattern)
    }
}

private extension String {
    subscript(range: some RangeExpression) -> Substring {
        self[range]
    }
}

private extension NSAttributedString {
    var attributedSubstringSupported: Bool { true }
}

extension NSTextView {
    /// 兼容访问（macOS 14 可直接用 attributedSubstring）。
    var attributedText: () -> NSAttributedString {
        { self.attributedString() }
    }
}
