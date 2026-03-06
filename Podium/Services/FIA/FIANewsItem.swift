import Foundation

struct FIANewsItem: Identifiable {
    var id: String { link }
    var title: String
    var link: String
    var pubDate: Date
    var description: String
    var imageURL: String?
}
