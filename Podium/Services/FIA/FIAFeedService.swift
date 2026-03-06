import Foundation

enum FIAFeedError: Error {
    case invalidURL
    case noData
    case parseError
}

final class FIAFeedService {
    static let shared = FIAFeedService()
    private let newsURL = URL(string: "https://www.fia.com/rss/news")!
    private let session: URLSession

    private init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchNews() async throws -> [FIANewsItem] {
        let (data, _) = try await session.data(from: newsURL)
        let all = try parseRSS(data: data)
        return all.filter { isF1Related($0) }
    }

    /// Оставляет только новости, связанные с Формулой 1 (FIA feed содержит и WRC, и др.).
    private func isF1Related(_ item: FIANewsItem) -> Bool {
        let text = [item.title, item.description, item.link].joined(separator: " ").lowercased()
        let f1Keywords = [
            "formula 1", "formula one", "formula 1 ", " f1 ", "f1.", "f1,", "f1:", "f1'",
            "grand prix", "grand-prix", "fia formula 1", "f1 world championship",
            "f1 race", "f1 qualifying", "f1 sprint", "f1 championship"
        ]
        return f1Keywords.contains { text.contains($0) }
    }

    private func parseRSS(data: Data) throws -> [FIANewsItem] {
        let parser = FIAFeedParser(data: data)
        return try parser.parse()
    }
}

private final class FIAFeedParser: NSObject, XMLParserDelegate {
    private let data: Data
    private var items: [FIANewsItem] = []
    private var currentElement = ""
    private var currentTitle = ""
    private var currentLink = ""
    private var currentDescription = ""
    private var currentPubDate = ""

    init(data: Data) {
        self.data = data
    }

    func parse() throws -> [FIANewsItem] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw FIAFeedError.parseError
        }
        return items
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "item" {
            currentTitle = ""
            currentLink = ""
            currentDescription = ""
            currentPubDate = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        switch currentElement {
        case "title": currentTitle += string
        case "link": currentLink += string
        case "description": currentDescription += string
        case "pubDate": currentPubDate += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard elementName == "item" else { return }
        let imageURL = extractFirstImageURL(from: currentDescription)
        let plainDescription = stripHTML(currentDescription)
        let date = parsePubDate(currentPubDate) ?? Date()
        let item = FIANewsItem(
            title: currentTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            link: currentLink.trimmingCharacters(in: .whitespacesAndNewlines),
            pubDate: date,
            description: plainDescription,
            imageURL: imageURL
        )
        if !item.title.isEmpty && !item.link.isEmpty {
            items.append(item)
        }
    }

    private func extractFirstImageURL(from html: String) -> String? {
        let pattern = #"src="(https?://[^"]+\.(?:jpg|jpeg|png|webp)[^"]*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[range])
    }

    private func stripHTML(_ html: String) -> String {
        var s = html
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#039;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
        if let regex = try? NSRegularExpression(pattern: "<[^>]+>") {
            s = regex.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: "")
        }
        return s
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
    }

    private func parsePubDate(_ s: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        if let d = formatter.date(from: s.trimmingCharacters(in: .whitespacesAndNewlines)) { return d }
        formatter.dateFormat = "EEE, d MMM yyyy HH:mm:ss Z"
        return formatter.date(from: s.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
