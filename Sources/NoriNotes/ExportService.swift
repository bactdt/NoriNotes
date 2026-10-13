import Foundation
import AppKit
import CoreText
import UniformTypeIdentifiers

struct ExportFormat: Identifiable {
    let id: String
    let title: String
    let fileExtension: String

    static let allCases: [ExportFormat] = [
        ExportFormat(id: "markdown", title: "Markdown", fileExtension: "md"),
        ExportFormat(id: "html", title: "HTML 网页", fileExtension: "html"),
        ExportFormat(id: "docx", title: "Word 文档", fileExtension: "docx"),
        ExportFormat(id: "pdf", title: "PDF 文档", fileExtension: "pdf"),
        ExportFormat(id: "jpg", title: "JPG 图片", fileExtension: "jpg"),
        ExportFormat(id: "epub", title: "EPUB 电子书", fileExtension: "epub")
    ]

    var contentType: UTType {
        switch id {
        case "html": return .html
        case "docx": return UTType("org.openxmlformats.wordprocessingml.document") ?? .zip
        case "pdf": return .pdf
        case "jpg": return .jpeg
        case "epub": return UTType("org.idpf.epub-container") ?? .zip
        default: return .plainText
        }
    }
}

enum ExportService {
    static func export(note: Note, format: ExportFormat, to url: URL) throws {
        let text = note.title + "\n\n" + note.body
        switch format.id {
        case "markdown": try text.write(to: url, atomically: true, encoding: .utf8)
        case "html": try htmlDocument(note).write(to: url, atomically: true, encoding: .utf8)
        case "docx": try writeDOCX(note, to: url)
        case "pdf": try writePDF(text, to: url)
        case "jpg": try writeJPG(note, to: url)
        case "epub": try writeEPUB(note, to: url)
        default: throw ExportError.unsupportedFormat
        }
    }

    // MARK: - HTML

    private static func htmlDocument(_ note: Note) -> String {
        let paragraphs = note.body.components(separatedBy: "\n").map { line in
            line.isEmpty ? "<p>&nbsp;</p>" : "<p>\(escapeHTML(line))</p>"
        }.joined(separator: "\n")
        let tags = note.tags.isEmpty ? "" : "<p class=\"tags\">\(note.tags.map(escapeHTML).joined(separator: " · "))</p>"
        return """
        <!doctype html><html lang="zh-CN"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>\(escapeHTML(note.title))</title><style>body{max-width:720px;margin:64px auto;padding:0 24px;font:17px/1.8 -apple-system,BlinkMacSystemFont,"PingFang SC",sans-serif;color:#26302d}h1{font-size:32px;line-height:1.25}.tags{color:#78817b;font-size:13px}p{white-space:pre-wrap}</style></head><body><article><h1>\(escapeHTML(note.title.isEmpty ? "无标题笔记" : note.title))</h1>\(tags)\(paragraphs)</article></body></html>
        """
    }

    // MARK: - DOCX

    private static func writeDOCX(_ note: Note, to url: URL) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("NoriDOCX-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("_rels"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("word"), withIntermediateDirectories: true)
        let paragraphs = ([note.title.isEmpty ? "无标题笔记" : note.title, ""] + note.body.components(separatedBy: "\n")).map { line in
            line.isEmpty ? "<w:p/>" : "<w:p><w:r><w:t xml:space=\"preserve\">\(escapeXML(line))</w:t></w:r></w:p>"
        }.joined()
        let contentTypes = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>
        """
        let relationships = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>
        """
        let document = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body>\(paragraphs)<w:sectPr/></w:body></w:document>
        """
        try contentTypes.write(to: root.appendingPathComponent("[Content_Types].xml"), atomically: true, encoding: .utf8)
        try relationships.write(to: root.appendingPathComponent("_rels/.rels"), atomically: true, encoding: .utf8)
        try document.write(to: root.appendingPathComponent("word/document.xml"), atomically: true, encoding: .utf8)
        try zip(root: root, output: url, arguments: ["-qr"])
    }

    // MARK: - EPUB

    private static func writeEPUB(_ note: Note, to url: URL) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("NoriEPUB-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("META-INF"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root.appendingPathComponent("OEBPS"), withIntermediateDirectories: true)
        try "application/epub+zip".write(to: root.appendingPathComponent("mimetype"), atomically: true, encoding: .utf8)
        let title = escapeXML(note.title.isEmpty ? "无标题笔记" : note.title)
        let paragraphs = note.body.components(separatedBy: "\n").map { "<p>\(escapeXML($0).isEmpty ? "&#160;" : escapeXML($0))</p>" }.joined()
        let container = "<?xml version=\"1.0\"?><container version=\"1.0\" xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\"><rootfiles><rootfile full-path=\"OEBPS/content.opf\" media-type=\"application/oebps-package+xml\"/></rootfiles></container>"
        let package = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><package xmlns=\"http://www.idpf.org/2007/opf\" version=\"3.0\" unique-identifier=\"bookid\" xml:lang=\"zh-CN\"><metadata xmlns:dc=\"http://purl.org/dc/elements/1.1/\"><dc:identifier id=\"bookid\">\(note.id.uuidString)</dc:identifier><dc:title>\(title)</dc:title><dc:language>zh-CN</dc:language></metadata><manifest><item id=\"chapter\" href=\"chapter.xhtml\" media-type=\"application/xhtml+xml\"/><item id=\"nav\" href=\"nav.xhtml\" media-type=\"application/xhtml+xml\" properties=\"nav\"/></manifest><spine><itemref idref=\"chapter\"/></spine></package>"
        let chapter = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><html xmlns=\"http://www.w3.org/1999/xhtml\" xml:lang=\"zh-CN\"><head><title>\(title)</title><meta charset=\"utf-8\"/></head><body><h1>\(title)</h1>\(paragraphs)</body></html>"
        let nav = "<?xml version=\"1.0\" encoding=\"UTF-8\"?><html xmlns=\"http://www.w3.org/1999/xhtml\" xmlns:epub=\"http://www.idpf.org/2007/ops\"><head><title>目录</title></head><body><nav epub:type=\"toc\"><h1>目录</h1><ol><li><a href=\"chapter.xhtml\">\(title)</a></li></ol></nav></body></html>"
        try container.write(to: root.appendingPathComponent("META-INF/container.xml"), atomically: true, encoding: .utf8)
        try package.write(to: root.appendingPathComponent("OEBPS/content.opf"), atomically: true, encoding: .utf8)
        try chapter.write(to: root.appendingPathComponent("OEBPS/chapter.xhtml"), atomically: true, encoding: .utf8)
        try nav.write(to: root.appendingPathComponent("OEBPS/nav.xhtml"), atomically: true, encoding: .utf8)
        try zip(root: root, output: url, arguments: ["-X0"], files: ["mimetype"])
        try zip(root: root, output: url, arguments: ["-Xr9D"], files: ["META-INF", "OEBPS"], append: true)
    }

    private static func zip(root: URL, output: URL, arguments: [String], files: [String] = ["."], append: Bool = false) throws {
        if !append { try? FileManager.default.removeItem(at: output) }
        var args = arguments
        if append { args.append("-g") }
        args.append(output.path)
        args.append(contentsOf: files)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = root
        process.arguments = args
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw ExportError.archiveCreationFailed }
    }

    // MARK: - PDF

    private static func writePDF(_ text: String, to url: URL) throws {
        var mediaBox = CGRect(x: 0, y: 0, width: 595, height: 842)
        guard let consumer = CGDataConsumer(url: url as CFURL),
              let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { throw ExportError.pdfCreationFailed }
        let font = CTFontCreateWithName("PingFangSC-Regular" as CFString, 12, nil)
        let attributed = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.black])
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        var offset = 0
        repeat {
            context.beginPDFPage(nil)
            let path = CGPath(rect: CGRect(x: 48, y: 48, width: 499, height: 746), transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: offset, length: 0), path, nil)
            CTFrameDraw(frame, context)
            let visible = CTFrameGetVisibleStringRange(frame).length
            context.endPDFPage()
            if visible <= 0 { break }
            offset += visible
        } while offset < attributed.length
        context.closePDF()
    }

    // MARK: - JPG

    private static func writeJPG(_ note: Note, to url: URL) throws {
        let width = 1200
        let height = 1600
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let graphics = NSGraphicsContext(bitmapImageRep: bitmap) else { throw ExportError.imageCreationFailed }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = graphics
        NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.94, alpha: 1).setFill()
        NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
        let title = note.title.isEmpty ? "无标题笔记" : note.title
        title.draw(in: NSRect(x: 86, y: height - 220, width: width - 172, height: 120), withAttributes: [.font: NSFont.systemFont(ofSize: 42, weight: .semibold), .foregroundColor: NSColor(calibratedWhite: 0.15, alpha: 1)])
        note.body.draw(in: NSRect(x: 86, y: 130, width: width - 172, height: height - 420), withAttributes: [.font: NSFont.systemFont(ofSize: 25), .foregroundColor: NSColor(calibratedWhite: 0.22, alpha: 1)])
        graphics.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else { throw ExportError.imageCreationFailed }
        try data.write(to: url, options: .atomic)
    }

    // MARK: - 转义

    private static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&#39;")
    }

    private static func escapeXML(_ text: String) -> String { escapeHTML(text) }

    enum ExportError: LocalizedError {
        case unsupportedFormat, archiveCreationFailed, pdfCreationFailed, imageCreationFailed
        var errorDescription: String? {
            switch self {
            case .unsupportedFormat: return "不支持的导出格式。"
            case .archiveCreationFailed: return "无法创建文档压缩包。"
            case .pdfCreationFailed: return "无法生成 PDF。"
            case .imageCreationFailed: return "无法生成 JPG 图片。"
            }
        }
    }
}
