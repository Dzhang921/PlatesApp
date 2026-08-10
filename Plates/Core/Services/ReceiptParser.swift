import Foundation
import UIKit
import Vision

/// OCR + heuristics that turn photographed receipt pages into a `ParsedReceipt`.
///
/// The OCR pass runs Vision's accurate recognizer per page, orders the recognized
/// fragments top-to-bottom (fragments sharing a visual row are merged into one
/// line, left to right), and concatenates multi-page receipts. Every heuristic
/// below is a small pure function over `[String]` so it can be unit-tested
/// without images.
enum ReceiptParser {

    // MARK: - Entry point

    static func parse(images: [UIImage]) async -> ParsedReceipt {
        await Task.detached(priority: .userInitiated) {
            var lines: [String] = []
            for image in images {
                lines.append(contentsOf: recognizeLines(in: image))
            }
            guard !lines.isEmpty else { return ParsedReceipt() }
            return parse(lines: lines)
        }.value
    }

    // MARK: - OCR

    private struct TextFragment {
        var text: String
        var box: CGRect
        var midY: CGFloat { box.midY }
        var minX: CGFloat { box.minX }
        var height: CGFloat { box.height }
    }

    private static func recognizeLines(in image: UIImage) -> [String] {
        guard let (cgImage, orientation) = normalizedCGImage(from: image) else { return [] }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US", "fr-FR", "es-ES", "it-IT", "de-DE",
                                        "ja-JP", "zh-Hans", "ko-KR"]
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation)
        do {
            try handler.perform([request])
        } catch {
            return []
        }
        let fragments: [TextFragment] = (request.results ?? []).compactMap { observation in
            guard let candidate = observation.topCandidates(1).first,
                  !candidate.string.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return TextFragment(text: candidate.string, box: observation.boundingBox)
        }
        // Vision's normalized coordinates put y=1 at the top of the image, so
        // top-to-bottom means descending midY. Fragments whose vertical centers
        // are close (relative to their heights) sit on the same printed row and
        // are joined left-to-right, which reunites "item ..... price" columns.
        let sorted = fragments.sorted {
            $0.midY == $1.midY ? $0.minX < $1.minX : $0.midY > $1.midY
        }
        var rows: [[TextFragment]] = []
        for fragment in sorted {
            if let anchor = rows.last?.first,
               abs(anchor.midY - fragment.midY) < 0.5 * max(anchor.height, fragment.height) {
                rows[rows.count - 1].append(fragment)
            } else {
                rows.append([fragment])
            }
        }
        return rows.map { row in
            row.sorted { $0.minX < $1.minX }.map(\.text).joined(separator: " ")
        }
    }

    /// Returns a CGImage plus the orientation Vision should apply. UIImages
    /// backed by CIImage (or with no bitmap at all) are re-rendered first.
    private static func normalizedCGImage(from image: UIImage) -> (CGImage, CGImagePropertyOrientation)? {
        if let cg = image.cgImage {
            return (cg, CGImagePropertyOrientation(image.imageOrientation))
        }
        let size = image.size
        guard size.width >= 1, size.height >= 1 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = max(1, image.scale)
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let cg = rendered.cgImage else { return nil }
        return (cg, .up)
    }

    // MARK: - Heuristics over recognized lines

    static func parse(lines: [String]) -> ParsedReceipt {
        let cleaned = lines
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        var receipt = ParsedReceipt()
        receipt.rawLines = cleaned
        receipt.merchantName = merchantName(from: cleaned)
        receipt.date = purchaseDate(from: cleaned)
        receipt.currencyCode = currencyCode(from: cleaned)
        receipt.total = total(from: cleaned)
        receipt.lineItems = lineItems(from: cleaned)
        return receipt
    }

    // MARK: Merchant name

    private static let merchantSkipWords = ["WELCOME", "ORDER", "TABLE", "SERVER",
                                            "RECEIPT", "INVOICE", "CASHIER", "GUEST"]

    static func merchantName(from lines: [String]) -> String? {
        for line in lines.prefix(6) {
            let upper = line.uppercased()
            if containsAny(upper, merchantSkipWords) { continue }
            if looksLikeAddress(line) || looksLikePhoneNumber(line) || looksLikeURL(line) { continue }
            if !dateCandidates(in: line).isEmpty { continue }
            guard line.rangeOfCharacter(from: .letters) != nil else { continue }
            var name = replacingMatches(in: line, #"\s*(?:#\s*\d+|(?i:store|no|nr)\.?\s*\d+)\s*$"#, with: "")
            name = name.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, name.rangeOfCharacter(from: .letters) != nil else { continue }
            if isAllCaps(name) { name = titleCased(name) }
            return name
        }
        return nil
    }

    static func looksLikeAddress(_ line: String) -> Bool {
        let suffixes = #"(st|street|ave|avenue|rd|road|blvd|boulevard|dr|drive|ln|lane|hwy|highway|suite|ste|floor|plaza|piso)"#
        return matches(line, "(?i)\\b\\d{1,6}\\b[^\\n]*\\b" + suffixes + "\\b")
            || matches(line, "(?i)\\b" + suffixes + "\\b[^\\n]*\\b\\d{1,6}\\b")
    }

    static func looksLikePhoneNumber(_ line: String) -> Bool {
        if matches(line, #"(?i)\b(tel|phone|fax)\b"#) { return true }
        guard line.filter({ $0.isNumber }).count >= 7 else { return false }
        return matches(line, #"\+?\(?\d[\d\s().\-]{6,}\d"#)
    }

    static func looksLikeURL(_ line: String) -> Bool {
        matches(line, #"(?i)(https?://|www\.|\.(com|net|org|co|io|shop|menu)\b)"#)
    }

    static func isAllCaps(_ text: String) -> Bool {
        text.rangeOfCharacter(from: .lowercaseLetters) == nil
            && text.rangeOfCharacter(from: .uppercaseLetters) != nil
    }

    static func titleCased(_ text: String) -> String {
        text.split(separator: " ", omittingEmptySubsequences: true)
            .map { word -> String in
                var characters = Array(word.lowercased())
                if let index = characters.firstIndex(where: { $0.isLetter }) {
                    characters[index] = Character(String(characters[index]).uppercased())
                }
                return String(characters)
            }
            .joined(separator: " ")
    }

    // MARK: Date

    static func purchaseDate(from lines: [String]) -> Date? {
        var candidates: [Date] = []
        for line in lines {
            candidates.append(contentsOf: dateCandidates(in: line))
        }
        let calendar = Calendar.current
        let now = Date()
        guard let earliest = calendar.date(byAdding: .year, value: -3, to: now),
              let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
        else { return nil }
        // Ambiguous strings (03/04/25) produce several candidates; the most
        // recent plausible one wins.
        return candidates.filter { $0 >= earliest && $0 < endOfToday }.max()
    }

    private static let dateDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)

    private static let numericDateFormatters: [DateFormatter] = {
        ["M/d/yy", "M/d/yyyy", "d/M/yy", "d/M/yyyy", "yyyy/M/d"].map(makeFormatter)
    }()

    private static let monthNameFormatters: [DateFormatter] = {
        ["d MMM yyyy", "d MMMM yyyy", "MMM d yyyy", "MMMM d yyyy"].map(makeFormatter)
    }()

    private static func makeFormatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.isLenient = false
        formatter.dateFormat = format
        return formatter
    }

    /// Every date interpretation found in a line, unfiltered for plausibility.
    static func dateCandidates(in line: String) -> [Date] {
        var found: [Date] = []
        if let detector = dateDetector {
            let ns = line as NSString
            detector.enumerateMatches(in: line, range: NSRange(location: 0, length: ns.length)) { match, _, _ in
                if let date = match?.date { found.append(date) }
            }
        }
        // Numeric forms: MM/dd/yy, dd/MM/yyyy, yyyy-MM-dd, dd.MM.yyyy...
        for token in matchStrings(in: line, #"\b\d{1,4}[/\-.]\d{1,2}[/\-.]\d{2,4}\b"#) {
            let normalized = token
                .replacingOccurrences(of: "-", with: "/")
                .replacingOccurrences(of: ".", with: "/")
            for formatter in numericDateFormatters {
                if let date = formatter.date(from: normalized) { found.append(date) }
            }
        }
        // "12 Mar 2026", "Mar 12, 2026"
        for token in matchStrings(in: line, #"\b\d{1,2}\s+\p{L}{3,9}\.?\s+\d{4}\b|\b\p{L}{3,9}\.?\s+\d{1,2},?\s+\d{4}\b"#) {
            let cleanedToken = token
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: "")
            for formatter in monthNameFormatters {
                if let date = formatter.date(from: cleanedToken) { found.append(date) }
            }
        }
        // Japanese 2026年8月9日
        for groups in matchGroups(in: line, #"(\d{4})年\s*(\d{1,2})月\s*(\d{1,2})日"#) {
            if groups.count >= 4,
               let year = Int(groups[1]), let month = Int(groups[2]), let day = Int(groups[3]) {
                var components = DateComponents()
                components.year = year
                components.month = month
                components.day = day
                if let date = Calendar(identifier: .gregorian).date(from: components) {
                    found.append(date)
                }
            }
        }
        return found
    }

    // MARK: Total

    private static let totalKeywords = ["GRAND TOTAL", "AMOUNT DUE", "BALANCE DUE",
                                        "TOTAL DUE", "TO PAY", "TOTAL",
                                        "合計", "合计", "총액", "MONTANT", "IMPORTE", "TOTALE"]

    static func total(from lines: [String]) -> Decimal? {
        var keywordBest: Decimal?
        var fallbackBest: Decimal?
        for line in lines {
            let upper = line.uppercased()
            if matches(upper, #"\bCASH\b|\bCHANGE\b"#) { continue }
            guard let lineMax = amounts(in: line).max() else { continue }
            if containsAny(upper, totalKeywords) {
                keywordBest = max(keywordBest ?? lineMax, lineMax)
            }
            fallbackBest = max(fallbackBest ?? lineMax, lineMax)
        }
        // Totals sit below subtotals and are >= them, so the largest keyword
        // hit is the amount actually owed.
        return keywordBest ?? fallbackBest
    }

    private static let currencySymbols = Set("$€£¥￥₩฿₫₹＄")

    /// Currency-ish amounts in a line. Dates, times, percentages, phone-number
    /// chunks and bare year-like integers are filtered out.
    static func amounts(in line: String) -> [Decimal] {
        var text = replacingMatches(in: line, #"\b\d{1,4}[/\-]\d{1,2}[/\-]\d{2,4}\b"#, with: " ")
        text = replacingMatches(in: text, #"\b\d{1,2}\.\d{1,2}\.\d{2}(?:\d{2})?\b"#, with: " ")
        text = replacingMatches(in: text, #"\b\d{1,2}:\d{2}(?::\d{2})?\b"#, with: " ")
        text = replacingMatches(in: text, #"\d+(?:[.,]\d+)?\s*%"#, with: " ")
        guard let expression = regex(#"\d{1,3}(?:[.,]\d{3})+(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?"#) else { return [] }
        let ns = text as NSString
        var result: [Decimal] = []
        for match in expression.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            let range = match.range
            let token = ns.substring(with: range)
            let before = range.location > 0
                ? ns.substring(with: NSRange(location: range.location - 1, length: 1))
                : ""
            let afterIndex = range.location + range.length
            let after = afterIndex < ns.length
                ? ns.substring(with: NSRange(location: afterIndex, length: 1))
                : ""
            let beforeChar = before.first
            let afterChar = after.first
            // "250g", "4pc" — a unit glued on the right disqualifies it.
            if let afterChar, afterChar.isLetter, afterChar.isASCII { continue }
            // "A1234", "#2044" — reference numbers, not money.
            if let beforeChar, (beforeChar.isLetter && beforeChar.isASCII) || beforeChar == "#" { continue }
            let symbolAdjacent = (beforeChar.map { currencySymbols.contains($0) } ?? false)
                || (afterChar.map { currencySymbols.contains($0) || $0 == "円" || $0 == "원" } ?? false)
            let hasSeparator = token.contains(".") || token.contains(",")
            let digitCount = token.filter { $0.isNumber }.count
            if !hasSeparator && !symbolAdjacent {
                if digitCount >= 5 { continue }                       // phone/zip chunks
                if digitCount == 4, let value = Int(token),
                   (1900...2099).contains(value) { continue }         // year-like
            }
            guard let value = decimal(from: token), value <= 100_000_000 else { continue }
            result.append(value)
        }
        return result
    }

    /// Parses "1,234.56", European "1.234,56", "¥3,500", "12.50" — never crashes.
    static func decimal(from raw: String) -> Decimal? {
        let kept = raw.filter { $0.isNumber || $0 == "." || $0 == "," }
        let digitCount = kept.filter { $0.isNumber }.count
        guard digitCount > 0, digitCount <= 12 else { return nil }
        let lastDot = kept.lastIndex(of: ".")
        let lastComma = kept.lastIndex(of: ",")
        var separator: Character?
        if let dot = lastDot, let comma = lastComma {
            separator = dot > comma ? "." : ","
        } else if lastDot != nil {
            separator = "."
        } else if lastComma != nil {
            separator = ","
        }
        // The last separator is the decimal point only if it is followed by one
        // or two digits; three digits means it was a thousands separator.
        if let sep = separator, let sepIndex = kept.lastIndex(of: sep) {
            let fraction = String(kept[kept.index(after: sepIndex)...].filter { $0.isNumber })
            if (1...2).contains(fraction.count) {
                let integerPart = String(kept[..<sepIndex].filter { $0.isNumber })
                let composed = (integerPart.isEmpty ? "0" : integerPart) + "." + fraction
                return Decimal(string: composed, locale: Locale(identifier: "en_US_POSIX"))
            }
        }
        let digits = String(kept.filter { $0.isNumber })
        return digits.isEmpty ? nil : Decimal(string: digits, locale: Locale(identifier: "en_US_POSIX"))
    }

    // MARK: Currency

    static func currencyCode(from lines: [String]) -> String? {
        let text = lines.joined(separator: "\n")
        let upper = text.uppercased()
        if upper.contains("US$") { return "USD" }
        if upper.contains("CA$") || upper.contains("C$") { return "CAD" }
        if upper.contains("HK$") { return "HKD" }
        if upper.contains("NT$") { return "TWD" }
        if upper.contains("MX$") { return "MXN" }
        if upper.contains("S$") { return "SGD" }
        if upper.contains("A$") { return "AUD" }
        if text.contains("€") { return "EUR" }
        if text.contains("£") { return "GBP" }
        if text.contains("₩") || text.contains("원") { return "KRW" }
        if text.contains("฿") { return "THB" }
        if text.contains("₫") { return "VND" }
        if text.contains("₹") { return "INR" }
        if text.contains("¥") || text.contains("￥") || text.contains("円") {
            return containsKana(text) || text.contains("円") ? "JPY" : "CNY"
        }
        if text.contains("$") || text.contains("＄") { return "USD" }
        for (word, code) in isoCodeMap where matches(upper, "\\b\(word)\\b") {
            return code
        }
        if matches(text, #"(?i)(?<!\p{L})kr\.?(?!\p{L})"#) { return "SEK" }
        return nil
    }

    private static let isoCodeMap: [(String, String)] = [
        ("USD", "USD"), ("EUR", "EUR"), ("GBP", "GBP"), ("JPY", "JPY"),
        ("CNY", "CNY"), ("RMB", "CNY"), ("KRW", "KRW"), ("CAD", "CAD"),
        ("AUD", "AUD"), ("NZD", "NZD"), ("HKD", "HKD"), ("SGD", "SGD"),
        ("TWD", "TWD"), ("MXN", "MXN"), ("THB", "THB"), ("VND", "VND"),
        ("INR", "INR"), ("CHF", "CHF"), ("SEK", "SEK"), ("NOK", "NOK"),
        ("DKK", "DKK"), ("PLN", "PLN"), ("CZK", "CZK"), ("HUF", "HUF"),
        ("ILS", "ILS"), ("AED", "AED"), ("BRL", "BRL"), ("MYR", "MYR"),
        ("IDR", "IDR"), ("PHP", "PHP")
    ]

    static func containsKana(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x3040...0x30FF).contains($0.value) }
    }

    // MARK: Line items

    private static let summaryKeywords = ["SUBTOTAL", "SUB-TOTAL", "SUB TOTAL", "TOTAL",
                                          "AMOUNT DUE", "BALANCE", "TO PAY",
                                          "合計", "合计", "총액", "MONTANT", "IMPORTE"]

    private static let itemExclusionKeywords = ["TAX", "VAT", "TVA", "IVA", "GST", "HST",
                                                "MWST", "TIP", "SUBTOTAL", "TOTAL",
                                                "SERVICE", "GRATUITY", "DISCOUNT",
                                                "PAYMENT", "CARD", "CASH", "CHANGE",
                                                "BALANCE", "消費税", "服务费", "合計",
                                                "合计", "총액", "VISA", "MASTERCARD",
                                                "AMEX", "CREDIT", "DEBIT", "TENDER",
                                                "TABLE", "GUEST", "SERVER", "CASHIER",
                                                "ORDER", "CHECK", "INVOICE", "RECEIPT",
                                                "TERMINAL", "AUTH", "APPROVAL"]

    static func lineItems(from lines: [String]) -> [ParsedLineItem] {
        let boundary = lines.firstIndex { containsAny($0.uppercased(), summaryKeywords) } ?? lines.count
        return lines.prefix(boundary).compactMap(lineItem(from:))
    }

    static func lineItem(from line: String) -> ParsedLineItem? {
        let upper = line.uppercased()
        if containsAny(upper, itemExclusionKeywords) { return nil }
        if looksLikeAddress(line) || looksLikePhoneNumber(line) || looksLikeURL(line) { return nil }
        let pattern = #"^(.*?\p{L}.*?)[\s.…·]+((?:US\$|CA\$|C\$|HK\$|NT\$|S\$|A\$|MX\$|[$€£¥￥₩฿₫₹＄])?\s?\d[\d.,]*(?:\s?(?:[$€£¥￥₩฿₫₹＄]|kr|円|원))?)\s*$"#
        guard let groups = matchGroups(in: line, pattern).first, groups.count >= 3 else { return nil }
        let priceToken = groups[2]
        // Integer prices are fine (¥950 ramen) but long bare integers are
        // order numbers, not prices.
        let priceDigits = priceToken.filter { $0.isNumber }.count
        let priceHasSeparator = priceToken.contains(".") || priceToken.contains(",")
        if !priceHasSeparator && priceDigits > 4 { return nil }
        guard let price = decimal(from: priceToken), price < 100_000 else { return nil }

        var name = groups[1]
        name = replacingMatches(in: name, #"^\s*\d{1,3}\s*[xX×]\s*"#, with: "")
        name = replacingMatches(in: name, #"^\s*\d{1,3}\s+"#, with: "")
        name = replacingMatches(in: name, #"\s*@\s*[\d.,]+.*$"#, with: "")
        name = replacingMatches(in: name, #"(?i)\s*[\d.,]+\s*(lb|lbs|kg|g|oz|ea|pc)\.?\s*$"#, with: "")
        name = name.trimmingCharacters(in: CharacterSet(charactersIn: " \t-–—•*:;,._"))
        let letterCount = name.unicodeScalars.filter { CharacterSet.letters.contains($0) }.count
        guard letterCount >= 2 else { return nil }
        return ParsedLineItem(name: titleCased(name), price: price)
    }

    // MARK: - Small shared helpers

    private static func containsAny(_ text: String, _ keywords: [String]) -> Bool {
        keywords.contains { text.contains($0) }
    }

    private static func regex(_ pattern: String) -> NSRegularExpression? {
        try? NSRegularExpression(pattern: pattern, options: [])
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        guard let expression = regex(pattern) else { return false }
        let ns = text as NSString
        return expression.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)) != nil
    }

    private static func matchStrings(in text: String, _ pattern: String) -> [String] {
        guard let expression = regex(pattern) else { return [] }
        let ns = text as NSString
        return expression.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { ns.substring(with: $0.range) }
    }

    /// Full match plus capture groups for every match; empty string for
    /// unmatched optional groups.
    private static func matchGroups(in text: String, _ pattern: String) -> [[String]] {
        guard let expression = regex(pattern) else { return [] }
        let ns = text as NSString
        return expression.matches(in: text, range: NSRange(location: 0, length: ns.length)).map { match in
            (0..<match.numberOfRanges).map { index in
                let range = match.range(at: index)
                return range.location == NSNotFound ? "" : ns.substring(with: range)
            }
        }
    }

    private static func replacingMatches(in text: String, _ pattern: String, with template: String) -> String {
        guard let expression = regex(pattern) else { return text }
        let ns = text as NSString
        return expression.stringByReplacingMatches(in: text,
                                                   range: NSRange(location: 0, length: ns.length),
                                                   withTemplate: template)
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
