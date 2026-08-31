
import Foundation

struct ServerChatParticipantDTO: Codable, Identifiable {

    let id: String

    let nickname: String
}

struct ServerChatDTO: Codable, Identifiable {

    let id: String

    let participants: [ServerChatParticipantDTO]

    let createdAt: Date?
}
