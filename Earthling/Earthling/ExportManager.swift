//
//  ExportManager.swift
//  Earthling
//
//  Created on 3/13/26.
//
//  Handles all data export formats: JSON, CSV, and PDF.
//
//  JSON and CSV are straightforward serialisations of the Entry model.
//  PDF export uses CoreGraphics directly — no PDFKit — because it needs
//  precise control over layout, inline photo placement, and page breaks.
//  Markdown in the body is parsed and rendered manually into
//  NSAttributedString for the PDF context.
//
//  Page size is A4 (595×842pt) with 54pt (0.75in) margins.
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

class ExportManager {

    // MARK: - JSON

    /// Exports entries as a pretty-printed JSON array, sorted oldest first.
    /// Photos are included as an `images` array within each entry object.
    static func exportJSON(entries: [Entry], entryStore: EntryStore) -> Data? {
        let sorted = entries.sorted { $0.date < $1.date }
        let dicts  = sorted.map { entry -> [String: Any] in
            var dict: [String: Any] = [
                "id":        entry.id.uuidString,
                "date":      ISO8601DateFormatter().string(from: entry.date),
                "city":      entry.city,
                "region":    entry.region,
                "country":   entry.country,
                "continent": entry.continent,
                "body":      entry.body,
                "createdAt": ISO8601DateFormatter().string(from: entry.createdAt),
                "images":    entry.photos.map { [
                    "id":        $0.id.uuidString,
                    "filename":  $0.filename,
                    "alignment": $0.alignment.rawValue,
                    "size":      $0.size.rawValue,
                    "caption":   $0.caption ?? ""
                ]}
            ]
            if let sub = entry.sublocation, !sub.isEmpty { dict["sublocation"] = sub }
            if let lat = entry.latitude  { dict["latitude"]  = lat }
            if let lon = entry.longitude { dict["longitude"] = lon }
            return dict
        }
        return try? JSONSerialization.data(
            withJSONObject: dicts,
            options: [.prettyPrinted, .sortedKeys]
        )
    }

    // MARK: - CSV

    /// Exports entries as a CSV string, sorted oldest first.
    /// Newlines in body text are collapsed to spaces; quotes are escaped.
    /// Photo metadata is not included — use JSON for full fidelity.
    static func exportCSV(entries: [Entry]) -> String {
        let sorted = entries.sorted { $0.date < $1.date }
        var lines  = ["id,date,city,region,country,continent,sublocation,latitude,longitude,createdAt,body"]
        let fmt    = ISO8601DateFormatter()

        for entry in sorted {
            let fields: [String] = [
                entry.id.uuidString,
                fmt.string(from: entry.date),
                entry.city,
                entry.region,
                entry.country,
                entry.continent,
                entry.sublocation ?? "",
                entry.latitude.map  { String($0) } ?? "",
                entry.longitude.map { String($0) } ?? "",
                fmt.string(from: entry.createdAt),
                entry.body
                    .replacingOccurrences(of: "\"", with: "\"\"")
                    .replacingOccurrences(of: "\n", with: " ")
            ]
            lines.append(fields.map { "\"\($0)\"" }.joined(separator: ","))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - PDF filename

    /// Generates a filename for a single-entry PDF export.
    /// Format: `yyyy-MM-dd-City-Sublocation.pdf` or `yyyy-MM-dd-City-HHmm.pdf`
    /// when no sublocation is set.
    static func pdfFilename(for entry: Entry) -> String {
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFmt.string(from: entry.date)

        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "HHmm"
        let timeStr = timeFmt.string(from: entry.createdAt)

        let cityClean = entry.city
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")

        if let sub = entry.sublocation, !sub.isEmpty {
            let subClean = sub
                .replacingOccurrences(of: "/", with: "-")
                .replacingOccurrences(of: ":", with: "-")
            return "\(dateStr)-\(cityClean)-\(subClean).pdf"
        }
        return "\(dateStr)-\(cityClean)-\(timeStr).pdf"
    }

    // MARK: - Markdown → NSAttributedString

    /// Converts a Markdown string to an NSAttributedString for PDF rendering.
    /// Handles headings (H1–H3), blockquotes, unordered and ordered lists,
    /// horizontal rules, and inline styles (bold, italic, code, strikethrough).
    private static func attributedString(
        from markdown: String,
        baseFont: NSFont,
        color: NSColor
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let para   = NSMutableParagraphStyle()
        para.lineBreakMode = .byWordWrapping
        para.lineSpacing   = 2

        for (index, line) in markdown.components(separatedBy: "\n").enumerated() {
            if index > 0 { result.append(NSAttributedString(string: "\n")) }

            if line.hasPrefix("### ") {
                let font = NSFont.systemFont(ofSize: baseFont.pointSize + 2, weight: .semibold)
                result.append(styled(String(line.dropFirst(4)), font: font, color: color, para: para))
            } else if line.hasPrefix("## ") {
                let font = NSFont.systemFont(ofSize: baseFont.pointSize + 4, weight: .semibold)
                result.append(styled(String(line.dropFirst(3)), font: font, color: color, para: para))
            } else if line.hasPrefix("# ") {
                let font = NSFont.systemFont(ofSize: baseFont.pointSize + 7, weight: .bold)
                result.append(styled(String(line.dropFirst(2)), font: font, color: color, para: para))
            } else if line.hasPrefix("> ") {
                let quotePara = NSMutableParagraphStyle()
                quotePara.lineBreakMode       = .byWordWrapping
                quotePara.headIndent          = 16
                quotePara.firstLineHeadIndent = 16
                result.append(inlineStyled(String(line.dropFirst(2)), baseFont: baseFont,
                                           color: NSColor(white: 0.5, alpha: 1), para: quotePara))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                let listPara = NSMutableParagraphStyle()
                listPara.lineBreakMode       = .byWordWrapping
                listPara.headIndent          = 16
                listPara.firstLineHeadIndent = 0
                result.append(inlineStyled("•  " + String(line.dropFirst(2)),
                                           baseFont: baseFont, color: color, para: listPara))
            } else if let match = line.range(of: "^\\d+\\. ", options: .regularExpression) {
                let listPara = NSMutableParagraphStyle()
                listPara.lineBreakMode       = .byWordWrapping
                listPara.headIndent          = 20
                listPara.firstLineHeadIndent = 0
                result.append(inlineStyled(String(line[match]) + String(line[match.upperBound...]),
                                           baseFont: baseFont, color: color, para: listPara))
            } else if line.hasPrefix("---") || line.hasPrefix("***") || line.hasPrefix("___") {
                // Horizontal rule — rendered as a drawn line in drawBody, placeholder here.
                result.append(NSAttributedString(string: " "))
            } else {
                result.append(inlineStyled(line, baseFont: baseFont, color: color, para: para))
            }
        }
        return result
    }

    /// Applies bold, italic, bold-italic, inline code, and strikethrough
    /// formatting within a single line of text.
    private static func inlineStyled(
        _ text: String,
        baseFont: NSFont,
        color: NSColor,
        para: NSParagraphStyle
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()

        let boldItalic = NSFontManager.shared.font(
            withFamily: baseFont.familyName ?? "Helvetica",
            traits: [.boldFontMask, .italicFontMask], weight: 9,
            size: baseFont.pointSize) ?? baseFont
        let bold   = NSFont.systemFont(ofSize: baseFont.pointSize, weight: .semibold)
        let italic = NSFontManager.shared.font(
            withFamily: baseFont.familyName ?? "Helvetica",
            traits: .italicFontMask, weight: 5,
            size: baseFont.pointSize) ?? baseFont
        let code = NSFont.monospacedSystemFont(ofSize: baseFont.pointSize - 1, weight: .regular)

        var remaining = text
        while !remaining.isEmpty {
            if let r = inlineRange(in: remaining, delimiter: "***") {
                let before  = String(remaining[remaining.startIndex..<r.0])
                let content = String(remaining[r.1..<r.2])
                if !before.isEmpty { result.append(plain(before, font: baseFont, color: color, para: para)) }
                result.append(plain(content, font: boldItalic, color: color, para: para))
                remaining = String(remaining[r.3...])
            } else if let r = inlineRange(in: remaining, delimiter: "**") {
                let before  = String(remaining[remaining.startIndex..<r.0])
                let content = String(remaining[r.1..<r.2])
                if !before.isEmpty { result.append(plain(before, font: baseFont, color: color, para: para)) }
                result.append(plain(content, font: bold, color: color, para: para))
                remaining = String(remaining[r.3...])
            } else if let r = inlineRange(in: remaining, delimiter: "*") ??
                              inlineRange(in: remaining, delimiter: "_") {
                let before  = String(remaining[remaining.startIndex..<r.0])
                let content = String(remaining[r.1..<r.2])
                if !before.isEmpty { result.append(plain(before, font: baseFont, color: color, para: para)) }
                result.append(plain(content, font: italic, color: color, para: para))
                remaining = String(remaining[r.3...])
            } else if let r = inlineRange(in: remaining, delimiter: "`") {
                let before  = String(remaining[remaining.startIndex..<r.0])
                let content = String(remaining[r.1..<r.2])
                if !before.isEmpty { result.append(plain(before, font: baseFont, color: color, para: para)) }
                result.append(plain(content, font: code,
                                    color: NSColor(white: 0.4, alpha: 1), para: para))
                remaining = String(remaining[r.3...])
            } else if let r = inlineRange(in: remaining, delimiter: "~~") {
                let before  = String(remaining[remaining.startIndex..<r.0])
                let content = String(remaining[r.1..<r.2])
                if !before.isEmpty { result.append(plain(before, font: baseFont, color: color, para: para)) }
                result.append(NSMutableAttributedString(
                    string: content,
                    attributes: [
                        .font: baseFont,
                        .foregroundColor: color,
                        .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                        .paragraphStyle: para
                    ]))
                remaining = String(remaining[r.3...])
            } else {
                result.append(plain(remaining, font: baseFont, color: color, para: para))
                break
            }
        }
        return result
    }

    /// Finds a matching delimiter pair in a string.
    /// Returns (beforeStart, contentStart, contentEnd, afterEnd) indices.
    private static func inlineRange(
        in text: String,
        delimiter: String
    ) -> (String.Index, String.Index, String.Index, String.Index)? {
        guard let open = text.range(of: delimiter) else { return nil }
        let afterOpen = open.upperBound
        guard afterOpen < text.endIndex else { return nil }
        guard let close = text.range(of: delimiter, range: afterOpen..<text.endIndex) else { return nil }
        guard open.upperBound < close.lowerBound else { return nil }
        return (open.lowerBound, open.upperBound, close.lowerBound, close.upperBound)
    }

    private static func plain(
        _ text: String, font: NSFont, color: NSColor, para: NSParagraphStyle
    ) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: para
        ])
    }

    /// Applies inline styles to heading text (which has its own font already set).
    private static func styled(
        _ text: String, font: NSFont, color: NSColor, para: NSParagraphStyle
    ) -> NSAttributedString {
        inlineStyled(text, baseFont: font, color: color,
                     para: para as! NSMutableParagraphStyle)
    }

    // MARK: - PDF drawing helpers

    /// Draws an NSAttributedString into the PDF context and returns the new Y position.
    @discardableResult
    private static func drawAttributedString(
        ctx: CGContext, attrStr: NSAttributedString,
        x: CGFloat, y: CGFloat, width: CGFloat, pageHeight: CGFloat
    ) -> CGFloat {
        let bounds   = attrStr.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading])
        let height   = ceil(bounds.height)
        let drawRect = CGRect(x: x, y: pageHeight - y - height, width: width, height: height)

        let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsCtx
        attrStr.draw(with: drawRect, options: [.usesLineFragmentOrigin, .usesFontLeading])
        NSGraphicsContext.restoreGraphicsState()
        return y + height
    }

    @discardableResult
    private static func drawText(
        ctx: CGContext, text: String, x: CGFloat, y: CGFloat,
        width: CGFloat, pageHeight: CGFloat, font: NSFont, color: NSColor
    ) -> CGFloat {
        let para = NSMutableParagraphStyle()
        para.lineBreakMode = .byWordWrapping
        let attrStr = NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: para
        ])
        return drawAttributedString(ctx: ctx, attrStr: attrStr,
                                    x: x, y: y, width: width, pageHeight: pageHeight)
    }

    private static func drawDivider(
        ctx: CGContext, x: CGFloat, y: CGFloat, width: CGFloat, pageHeight: CGFloat
    ) {
        ctx.setStrokeColor(NSColor.lightGray.cgColor)
        ctx.setLineWidth(0.5)
        ctx.move(to: CGPoint(x: x, y: pageHeight - y))
        ctx.addLine(to: CGPoint(x: x + width, y: pageHeight - y))
        ctx.strokePath()
    }

    // MARK: - Photo drawing

    /// Draws a single photo into the PDF context, respecting alignment and size.
    /// Inserts a page break if the image would overflow the current page.
    @discardableResult
    private static func drawPhoto(
        ctx: CGContext, photo: EntryPhoto, entry: Entry, entryStore: EntryStore,
        x: CGFloat, y: CGFloat, contentWidth: CGFloat,
        pageHeight: CGFloat, margin: CGFloat
    ) -> CGFloat {
        let url = entryStore.photoURL(for: entry, filename: photo.filename)
        guard let nsImage = NSImage(contentsOf: url),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil),
              cgImage.width > 0, cgImage.height > 0
        else { return y }

        let imgW       = CGFloat(cgImage.width)
        let imgH       = CGFloat(cgImage.height)
        let drawWidth  = min(contentWidth * photo.size.widthFraction, contentWidth)
        let drawHeight = drawWidth * (imgH / imgW)

        var currentY = y
        if currentY + drawHeight > pageHeight - margin - 40 {
            ctx.endPDFPage()
            ctx.beginPDFPage(nil)
            currentY = margin
        }

        let drawX: CGFloat
        switch photo.alignment {
        case .left:   drawX = x
        case .center: drawX = x + (contentWidth - drawWidth) / 2
        case .right:  drawX = x + contentWidth - drawWidth
        }

        ctx.draw(cgImage, in: CGRect(
            x: drawX, y: pageHeight - currentY - drawHeight,
            width: drawWidth, height: drawHeight))
        return currentY + drawHeight
    }

    // MARK: - Body drawing

    /// Renders the entry body into the PDF context, handling both text paragraphs
    /// and inline `![photo:filename]` tags. Gallery tags are not yet supported
    /// in PDF export — gallery photos are skipped silently.
    private static func drawBody(
        ctx: CGContext, body: String, photos: [EntryPhoto],
        entry: Entry, entryStore: EntryStore,
        x: CGFloat, startY: CGFloat, width: CGFloat,
        pageHeight: CGFloat, margin: CGFloat
    ) -> CGFloat {
        var y = startY
        let baseFont         = NSFont.systemFont(ofSize: 13)
        let photosByFilename = Dictionary(uniqueKeysWithValues: photos.map { ($0.filename, $0) })

        // Split body on ![photo:...] tags into alternating text/photo segments.
        var segments: [(isPhoto: Bool, content: String)] = []
        var remaining = body
        while !remaining.isEmpty {
            if let tagRange = remaining.range(of: #"\!\[photo:[^\]]+\]"#, options: .regularExpression) {
                let before   = String(remaining[remaining.startIndex..<tagRange.lowerBound])
                if !before.isEmpty { segments.append((false, before)) }
                let filename = String(remaining[tagRange])
                    .replacingOccurrences(of: "![photo:", with: "")
                    .replacingOccurrences(of: "]", with: "")
                segments.append((true, filename))
                remaining = String(remaining[tagRange.upperBound...])
            } else {
                segments.append((false, remaining))
                break
            }
        }

        for segment in segments {
            if segment.isPhoto {
                if let photo = photosByFilename[segment.content] {
                    y += 8
                    y  = drawPhoto(ctx: ctx, photo: photo, entry: entry,
                                   entryStore: entryStore, x: x, y: y,
                                   contentWidth: width, pageHeight: pageHeight, margin: margin)
                    y += 8
                }
            } else {
                for paragraph in segment.content.components(separatedBy: "\n") {
                    let trimmed = paragraph.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty { y += 8; continue }

                    if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                        y += 8
                        drawDivider(ctx: ctx, x: x, y: y, width: width, pageHeight: pageHeight)
                        y += 8
                        continue
                    }

                    let attrStr = attributedString(from: trimmed, baseFont: baseFont, color: .black)
                    let height  = ceil(attrStr.boundingRect(
                        with: CGSize(width: width, height: .greatestFiniteMagnitude),
                        options: [.usesLineFragmentOrigin, .usesFontLeading]).height)

                    if y + height > pageHeight - margin - 40 {
                        ctx.endPDFPage()
                        ctx.beginPDFPage(nil)
                        y = margin
                    }

                    y  = drawAttributedString(ctx: ctx, attrStr: attrStr,
                                              x: x, y: y, width: width, pageHeight: pageHeight)
                    y += 4
                }
            }
        }
        return y
    }

    // MARK: - PDF export (single entry)

    static func exportPDF(entry: Entry, entryStore: EntryStore) -> Data {
        let pageWidth: CGFloat  = 595
        let pageHeight: CGFloat = 842
        let margin: CGFloat     = 54
        let contentWidth        = pageWidth - margin * 2

        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx      = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { return data as Data }

        let dateFmt = DateFormatter()
        dateFmt.dateStyle = .long
        dateFmt.timeStyle = .none

        ctx.beginPDFPage(nil)
        var y: CGFloat = margin

        y = drawText(ctx: ctx, text: dateFmt.string(from: entry.date),
                     x: margin, y: y, width: contentWidth, pageHeight: pageHeight,
                     font: .systemFont(ofSize: 11), color: .gray)
        y += 4

        let locationParts = [entry.city, entry.region, entry.country].filter { !$0.isEmpty }
        y = drawText(ctx: ctx, text: locationParts.joined(separator: ", "),
                     x: margin, y: y, width: contentWidth, pageHeight: pageHeight,
                     font: .systemFont(ofSize: 20, weight: .light), color: .black)

        if let sub = entry.sublocation, !sub.isEmpty {
            y += 2
            y  = drawText(ctx: ctx, text: sub, x: margin, y: y, width: contentWidth,
                          pageHeight: pageHeight, font: .systemFont(ofSize: 13), color: .gray)
        }

        y += 12
        drawDivider(ctx: ctx, x: margin, y: y, width: contentWidth, pageHeight: pageHeight)
        y += 16

        y = drawBody(ctx: ctx, body: entry.body, photos: entry.photos,
                     entry: entry, entryStore: entryStore,
                     x: margin, startY: y, width: contentWidth,
                     pageHeight: pageHeight, margin: margin)

        ctx.endPDFPage()
        ctx.closePDF()
        return data as Data
    }

    // MARK: - PDF export (folder — one file per entry)

    static func exportPDFsToFolder(
        entries: [Entry], folderURL: URL, entryStore: EntryStore
    ) throws {
        for entry in entries.sorted(by: { $0.date < $1.date }) {
            let data    = exportPDF(entry: entry, entryStore: entryStore)
            let fileURL = folderURL.appendingPathComponent(pdfFilename(for: entry))
            try data.write(to: fileURL)
        }
    }

    // MARK: - PDF export (combined — all entries in one file)

    static func exportPDFCombined(
        entries: [Entry], pageBreakPerEntry: Bool, entryStore: EntryStore
    ) -> Data {
        let sorted          = entries.sorted { $0.date < $1.date }
        let pageWidth: CGFloat  = 595
        let pageHeight: CGFloat = 842
        let margin: CGFloat     = 54
        let contentWidth        = pageWidth - margin * 2

        let data = NSMutableData()
        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx      = CGContext(consumer: consumer, mediaBox: &mediaBox, nil)
        else { return data as Data }

        let dateFmt = DateFormatter()
        dateFmt.dateStyle = .long
        dateFmt.timeStyle = .none

        ctx.beginPDFPage(nil)
        var y: CGFloat = margin
        var isFirst    = true

        for entry in sorted {
            if !isFirst {
                if pageBreakPerEntry {
                    ctx.endPDFPage()
                    ctx.beginPDFPage(nil)
                    y = margin
                } else {
                    y += 48
                    if y > pageHeight - margin - 120 {
                        ctx.endPDFPage()
                        ctx.beginPDFPage(nil)
                        y = margin
                    }
                }
            }
            isFirst = false

            y = drawText(ctx: ctx, text: dateFmt.string(from: entry.date),
                         x: margin, y: y, width: contentWidth, pageHeight: pageHeight,
                         font: .systemFont(ofSize: 11), color: .gray)
            y += 4

            let locationParts = [entry.city, entry.region, entry.country].filter { !$0.isEmpty }
            y = drawText(ctx: ctx, text: locationParts.joined(separator: ", "),
                         x: margin, y: y, width: contentWidth, pageHeight: pageHeight,
                         font: .systemFont(ofSize: 20, weight: .light), color: .black)

            if let sub = entry.sublocation, !sub.isEmpty {
                y += 2
                y  = drawText(ctx: ctx, text: sub, x: margin, y: y, width: contentWidth,
                              pageHeight: pageHeight, font: .systemFont(ofSize: 13), color: .gray)
            }

            y += 12
            drawDivider(ctx: ctx, x: margin, y: y, width: contentWidth, pageHeight: pageHeight)
            y += 16

            y = drawBody(ctx: ctx, body: entry.body, photos: entry.photos,
                         entry: entry, entryStore: entryStore,
                         x: margin, startY: y, width: contentWidth,
                         pageHeight: pageHeight, margin: margin)
        }

        ctx.endPDFPage()
        ctx.closePDF()
        return data as Data
    }

    // MARK: - Folder picker for multi-PDF export

    static func pickFolderAndExportPDFs(
        entries: [Entry], entryStore: EntryStore, completion: @escaping (Bool) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.canChooseFiles       = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt  = "Export Here"
        panel.message = "Choose a folder to save \(entries.count) PDF\(entries.count == 1 ? "" : "s")"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { completion(false); return }
            do {
                try exportPDFsToFolder(entries: entries, folderURL: url, entryStore: entryStore)
                completion(true)
            } catch {
                completion(false)
            }
        }
    }
}
