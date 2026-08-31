import Foundation

enum AttachmentType: String, Codable {
    case photo
    case video
    case videoNote
    case document
    case audio
}

struct Attachment: Identifiable, Codable {

    let id: UUID
    let type: AttachmentType
    var fileName: String
    var localPath: String?
    var remoteURL: String?
    var width: Double?
    var height: Double?
    var duration: Double?
    var waveform: [Double]?
    var size: Int64

    init(
        id: UUID = UUID(),
        type: AttachmentType,
        fileName: String,
        localPath: String? = nil,
        remoteURL: String? = nil,
        width: Double? = nil,
        height: Double? = nil,
        duration: Double? = nil,
        waveform: [Double]? = nil,
        size: Int64 = 0
    ) {
        self.id = id
        self.type = type
        self.fileName = fileName
        self.localPath = localPath
        self.remoteURL = remoteURL
        self.width = width
        self.height = height
        self.duration = duration
        self.waveform = waveform
        self.size = size
    }
}
