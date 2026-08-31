
import Foundation

struct SendMessageDTO: Codable {

    let chatId: String

    let text: String

    let replyToMessageId: String?
}
