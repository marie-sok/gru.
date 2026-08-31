
import Foundation
import Observation

@MainActor
@Observable
final class ChatListViewModel {

    var search = ""

    private let service = ChatService.shared

    var chats: [Chat] {
        service.chats
    }

    var filteredChats: [Chat] {

        if search.isEmpty {
            return chats
        }

        return chats.filter { chat in

            chat.users.contains { user in

                user.displayName.localizedCaseInsensitiveContains(search)
            }
        }
    }

    func createChat(username: String) {

        service.createChat(username: username)
    }

    func delete(chat: Chat) {

        service.deleteChat(chat.id)
    }
}
