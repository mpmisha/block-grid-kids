import AVFoundation
import Foundation

/// The short musical cues the game plays.
enum GameSound: CaseIterable {
    case pickUp
    case place
    case invalid
    case clearSingle
    case clearCombo
    case button
    case gameOver
    case levelUp

    /// Each cue is a tiny melody of `(frequency in Hz, duration in seconds)`.
    var notes: [(frequency: Double, duration: Double)] {
        switch self {
        case .pickUp:
            return [(660, 0.07)]
        case .place:
            return [(523.25, 0.06), (659.25, 0.07)]
        case .invalid:
            return [(200, 0.09)]
        case .clearSingle:
            return [(659.25, 0.07), (783.99, 0.07), (1046.50, 0.12)]
        case .clearCombo:
            return [(659.25, 0.06), (830.61, 0.06), (987.77, 0.06), (1318.51, 0.16)]
        case .button:
            return [(880, 0.05)]
        case .gameOver:
            return [(587.33, 0.14), (493.88, 0.14), (392.00, 0.26)]
        case .levelUp:
            return [(523.25, 0.09), (659.25, 0.09), (783.99, 0.09),
                    (1046.50, 0.10), (1318.51, 0.24)]
        }
    }

    var volume: Float {
        switch self {
        case .invalid: return 0.25
        case .pickUp, .button: return 0.35
        default: return 0.5
        }
    }
}

/// Plays short synthesized tones. Nothing is loaded from disk, so the app ships
/// with no audio assets and no third-party sound libraries.
final class SoundPlayer {

    static let shared = SoundPlayer()

    private var players: [GameSound: [AVAudioPlayer]] = [:]
    private var didConfigureSession = false

    private init() {}

    /// Pre-renders every cue so the first play has no hitch.
    func prepare() {
        configureSessionIfNeeded()
        for sound in GameSound.allCases where players[sound] == nil {
            // Two players per cue lets overlapping effects play together.
            let pool = (0..<2).compactMap { _ in makePlayer(for: sound) }
            players[sound] = pool
        }
    }

    func play(_ sound: GameSound) {
        guard SettingsStore.shared.isSoundEnabled else { return }
        configureSessionIfNeeded()

        if players[sound] == nil {
            players[sound] = (0..<2).compactMap { _ in makePlayer(for: sound) }
        }
        guard let pool = players[sound], !pool.isEmpty else { return }

        let player = pool.first { !$0.isPlaying } ?? pool[0]
        player.currentTime = 0
        player.play()
    }

    // MARK: - Session

    private func configureSessionIfNeeded() {
        guard !didConfigureSession else { return }
        didConfigureSession = true
        // `.ambient` keeps other apps' music playing and honours the ring switch.
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func makePlayer(for sound: GameSound) -> AVAudioPlayer? {
        guard let data = ToneSynthesizer.makeWAVData(notes: sound.notes) else { return nil }
        let player = try? AVAudioPlayer(data: data)
        player?.volume = sound.volume
        player?.prepareToPlay()
        return player
    }
}

/// Renders simple melodies into in-memory 16-bit PCM WAV data.
enum ToneSynthesizer {

    private static let sampleRate = 44_100.0

    static func makeWAVData(notes: [(frequency: Double, duration: Double)]) -> Data? {
        guard !notes.isEmpty else { return nil }

        var samples: [Int16] = []
        for note in notes {
            samples.append(contentsOf: renderNote(frequency: note.frequency, duration: note.duration))
        }
        guard !samples.isEmpty else { return nil }
        return wrapInWAVContainer(samples: samples)
    }

    /// A sine plus a quiet octave, shaped by a short attack and a long decay so
    /// the cue sounds soft rather than clicky.
    private static func renderNote(frequency: Double, duration: Double) -> [Int16] {
        let frameCount = max(1, Int(duration * sampleRate))
        let attackFrames = max(1, Int(0.006 * sampleRate))
        var output: [Int16] = []
        output.reserveCapacity(frameCount)

        for frame in 0..<frameCount {
            let time = Double(frame) / sampleRate
            let angle = 2.0 * Double.pi * frequency * time

            var value = sin(angle)
            value += 0.28 * sin(2.0 * angle)
            value /= 1.28

            let attack = min(1.0, Double(frame) / Double(attackFrames))
            let progress = Double(frame) / Double(frameCount)
            let decay = pow(1.0 - progress, 1.6)
            let envelope = attack * decay

            let scaled = value * envelope * 0.85 * Double(Int16.max)
            output.append(Int16(max(Double(Int16.min), min(Double(Int16.max), scaled))))
        }
        return output
    }

    private static func wrapInWAVContainer(samples: [Int16]) -> Data {
        let channelCount: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = UInt32(sampleRate) * UInt32(channelCount) * UInt32(bitsPerSample / 8)
        let blockAlign = channelCount * (bitsPerSample / 8)
        let dataSize = UInt32(samples.count * MemoryLayout<Int16>.size)

        var data = Data()
        data.append(contentsOf: Array("RIFF".utf8))
        data.appendLittleEndian(UInt32(36) + dataSize)
        data.append(contentsOf: Array("WAVE".utf8))

        data.append(contentsOf: Array("fmt ".utf8))
        data.appendLittleEndian(UInt32(16))          // PCM chunk size
        data.appendLittleEndian(UInt16(1))           // PCM format
        data.appendLittleEndian(channelCount)
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(byteRate)
        data.appendLittleEndian(blockAlign)
        data.appendLittleEndian(bitsPerSample)

        data.append(contentsOf: Array("data".utf8))
        data.appendLittleEndian(dataSize)
        for sample in samples {
            data.appendLittleEndian(UInt16(bitPattern: sample))
        }
        return data
    }
}

private extension Data {
    mutating func appendLittleEndian(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    mutating func appendLittleEndian(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }
}
