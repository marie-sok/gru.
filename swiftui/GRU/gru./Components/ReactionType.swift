
import Foundation

enum ReactionType: String, Codable, CaseIterable, Identifiable {

    case heart = "❤️"
    case like = "👍"
    case dislike = "👎"
    case laugh = "😂"
    case wow = "😮"
    case cry = "😢"
    case fire = "🔥"

    var id: String {
        rawValue
    }

    var emoji: String {
        rawValue
    }
}
