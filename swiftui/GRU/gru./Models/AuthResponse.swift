
import Foundation

struct AuthResponse: Codable {

    let token: String

    let userId: String

    let nickname: String?
}
