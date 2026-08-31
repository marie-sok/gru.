
import Foundation

struct TypingEventDTO: Codable {

    let chatId: String

    let userId: String

    let typing: Bool
}
