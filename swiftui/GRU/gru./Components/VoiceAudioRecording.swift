import Foundation

struct VoiceAudioRecording: Sendable {
    let url: URL
    let duration: Double
    let waveform: [Double]
}
