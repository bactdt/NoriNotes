import Foundation
import Vision
import PDFKit
import ImageIO
import AppKit

struct OCRService {
    enum OCRFailure: LocalizedError {
        case unsupportedFile
        case unreadableDocument
        case noImageData

        var errorDescription: String? {
            switch self {
            case .unsupportedFile: return "只支持图片或 PDF 文件。"
            case .unreadableDocument: return "无法读取所选文件。"
            case .noImageData: return "无法从文件中取得图像内容。"
            }
        }
    }

    static func recognize(fileAt url: URL) async throws -> String {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        return try await Task.detached(priority: .userInitiated) {
            let ext = url.pathExtension.lowercased()
            if ext == "pdf" { return try recognizePDF(url) }
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { throw OCRFailure.noImageData }
            return try recognizeImage(image)
        }.value
    }

    private static func recognizePDF(_ url: URL) throws -> String {
        guard let document = PDFDocument(url: url) else { throw OCRFailure.unreadableDocument }
        var pages: [String] = []
        for index in 0..<min(document.pageCount, 250) {
            guard let page = document.page(at: index) else { continue }
            let nativeText = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !nativeText.isEmpty {
                pages.append(nativeText)
                continue
            }
            let image = page.thumbnail(of: CGSize(width: 1800, height: 2300), for: .mediaBox)
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
            let text = try recognizeImage(cgImage)
            if !text.isEmpty { pages.append(text) }
        }
        return pages.enumerated().map { "第\($0.offset + 1)页\n\($0.element)" }.joined(separator: "\n\n")
    }

    private static func recognizeImage(_ image: CGImage) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["zh-Hans", "en-US"]
        try VNImageRequestHandler(cgImage: image).perform([request])
        return (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
    }
}
