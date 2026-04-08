import Foundation

let outputRoot = CommandLine.arguments.dropFirst().first.map { URL(fileURLWithPath: $0, isDirectory: true) }
    ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        .appendingPathComponent("App/BundleResources", isDirectory: true)

let soundsRoot = outputRoot.appendingPathComponent("Sounds", isDirectory: true)
let defaultPackURL = soundsRoot.appendingPathComponent("default-8bit", isDirectory: true)

let fileManager = FileManager.default
try fileManager.createDirectory(at: defaultPackURL, withIntermediateDirectories: true)

struct Tone {
    let frequency: Double
    let duration: Double
    let amplitude: Double
}

let soundDefinitions: [String: [Tone]] = [
    "session_start": [
        Tone(frequency: 523.25, duration: 0.05, amplitude: 0.42),
        Tone(frequency: 659.25, duration: 0.07, amplitude: 0.46),
        Tone(frequency: 783.99, duration: 0.10, amplitude: 0.48),
    ],
    "task_ack": [
        Tone(frequency: 659.25, duration: 0.04, amplitude: 0.40),
        Tone(frequency: 880.00, duration: 0.05, amplitude: 0.42),
    ],
    "task_complete": [
        Tone(frequency: 523.25, duration: 0.05, amplitude: 0.40),
        Tone(frequency: 659.25, duration: 0.05, amplitude: 0.42),
        Tone(frequency: 783.99, duration: 0.05, amplitude: 0.44),
        Tone(frequency: 1046.50, duration: 0.12, amplitude: 0.46),
    ],
    "task_error": [
        Tone(frequency: 392.00, duration: 0.09, amplitude: 0.46),
        Tone(frequency: 329.63, duration: 0.11, amplitude: 0.42),
        Tone(frequency: 261.63, duration: 0.15, amplitude: 0.40),
    ],
    "input_required": [
        Tone(frequency: 698.46, duration: 0.06, amplitude: 0.44),
        Tone(frequency: 698.46, duration: 0.06, amplitude: 0.44),
        Tone(frequency: 932.33, duration: 0.10, amplitude: 0.40),
    ],
    "resource_limit": [
        Tone(frequency: 587.33, duration: 0.10, amplitude: 0.38),
        Tone(frequency: 554.37, duration: 0.10, amplitude: 0.36),
        Tone(frequency: 523.25, duration: 0.12, amplitude: 0.34),
    ],
    "user_spam": [
        Tone(frequency: 932.33, duration: 0.04, amplitude: 0.38),
        Tone(frequency: 830.61, duration: 0.04, amplitude: 0.36),
        Tone(frequency: 932.33, duration: 0.04, amplitude: 0.38),
        Tone(frequency: 830.61, duration: 0.04, amplitude: 0.36),
    ],
]

let manifest = """
{
  "id": "default-8bit",
  "displayName": "Default 8-Bit"
}
"""
try manifest.write(to: defaultPackURL.appendingPathComponent("pack.json"), atomically: true, encoding: .utf8)

func renderPCM(tones: [Tone], sampleRate: Int = 22_050) -> [Int16] {
    var samples: [Int16] = []
    let attack = Int(Double(sampleRate) * 0.003)
    let release = Int(Double(sampleRate) * 0.020)

    for tone in tones {
        let frameCount = max(1, Int(tone.duration * Double(sampleRate)))
        for frame in 0..<frameCount {
            let t = Double(frame) / Double(sampleRate)
            let phase = tone.frequency * t
            let square = sin(2 * .pi * phase) >= 0 ? 1.0 : -1.0
            let triangle = asin(sin(2 * .pi * phase)) * (2 / .pi)
            var value = (square * 0.72 + triangle * 0.28) * tone.amplitude

            if frame < attack {
                value *= Double(frame) / Double(max(attack, 1))
            } else if frame >= frameCount - release {
                let tail = frameCount - frame
                value *= Double(max(tail, 0)) / Double(max(release, 1))
            }

            let scaled = max(-1.0, min(1.0, value)) * Double(Int16.max)
            samples.append(Int16(scaled))
        }

        let gap = Int(Double(sampleRate) * 0.012)
        samples.append(contentsOf: Array(repeating: 0, count: gap))
    }

    return samples
}

func wavData(from samples: [Int16], sampleRate: Int = 22_050) -> Data {
    let channels: UInt16 = 1
    let bitsPerSample: UInt16 = 16
    let byteRate = UInt32(sampleRate) * UInt32(channels) * UInt32(bitsPerSample / 8)
    let blockAlign = UInt16(channels * bitsPerSample / 8)
    let dataSize = UInt32(samples.count * MemoryLayout<Int16>.size)
    let riffSize = 36 + dataSize

    var data = Data()
    data.append("RIFF".data(using: .ascii)!)
    data.append(contentsOf: withUnsafeBytes(of: riffSize.littleEndian, Array.init))
    data.append("WAVE".data(using: .ascii)!)
    data.append("fmt ".data(using: .ascii)!)

    let fmtChunkSize: UInt32 = 16
    let audioFormat: UInt16 = 1
    data.append(contentsOf: withUnsafeBytes(of: fmtChunkSize.littleEndian, Array.init))
    data.append(contentsOf: withUnsafeBytes(of: audioFormat.littleEndian, Array.init))
    data.append(contentsOf: withUnsafeBytes(of: channels.littleEndian, Array.init))
    data.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian, Array.init))
    data.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian, Array.init))
    data.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian, Array.init))
    data.append(contentsOf: withUnsafeBytes(of: bitsPerSample.littleEndian, Array.init))

    data.append("data".data(using: .ascii)!)
    data.append(contentsOf: withUnsafeBytes(of: dataSize.littleEndian, Array.init))

    for sample in samples {
        data.append(contentsOf: withUnsafeBytes(of: sample.littleEndian, Array.init))
    }
    return data
}

for (name, tones) in soundDefinitions {
    let data = wavData(from: renderPCM(tones: tones))
    try data.write(to: defaultPackURL.appendingPathComponent("\(name).wav"), options: .atomic)
}

print("Generated default sound pack in \(defaultPackURL.path)")
