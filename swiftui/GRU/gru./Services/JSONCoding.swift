
import Foundation

enum JSONCoding {

    static let encoder: JSONEncoder = {

        let encoder = JSONEncoder()

        encoder.dateEncodingStrategy = .iso8601

        return encoder
    }()

    static let decoder: JSONDecoder = {

        let decoder = JSONDecoder()

        decoder.dateDecodingStrategy = .custom { decoder in

            let container = try decoder.singleValueContainer()

            let value = try container.decode(String.self)

            let formatterWithMilliseconds = ISO8601DateFormatter()

            formatterWithMilliseconds.formatOptions = [
                .withInternetDateTime,
                .withFractionalSeconds
            ]

            if let date = formatterWithMilliseconds.date(
                from: value
            ) {
                return date
            }

            let formatter = ISO8601DateFormatter()

            formatter.formatOptions = [
                .withInternetDateTime
            ]

            if let date = formatter.date(
                from: value
            ) {
                return date
            }

            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription:
                    "Неверная дата от сервера: \(value)"
            )
        }

        return decoder
    }()
}
