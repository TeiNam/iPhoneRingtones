import AVFoundation
import Testing
@testable import iPhoneRingtones

struct RingtoneRangeTests {
    @Test func clampsRangeToTrack() throws {
        let range = try RingtoneRange.validate(start: "-3", end: "12.5", duration: 10).get()
        #expect(range == 0...10)
    }

    @Test func acceptsCommaDecimalSeparator() throws {
        let range = try RingtoneRange.validate(start: " 1,5 ", end: "3", duration: 10).get()
        #expect(range == 1.5...3)
    }

    @Test func allowsExactlyMaxLengthDespiteFloatingPointError() {
        // 64.4 - 24.4 는 부동소수점으로 40.00000000000001 이 된다
        #expect((try? RingtoneRange.validate(start: "24.4", end: "64.4", duration: 100).get()) != nil)
    }

    @Test(arguments: [
        ("abc", "10", RingtoneRange.Problem.notANumber),
        ("nan", "10", .notANumber),
        ("0", "inf", .notANumber),
        ("5", "5", .endNotAfterStart),
        ("120", "130", .endNotAfterStart),
        ("0", "40.2", .tooLong),
    ])
    func rejectsInvalidInput(start: String, end: String, problem: RingtoneRange.Problem) {
        #expect(RingtoneRange.validate(start: start, end: end, duration: 100) == .failure(problem))
    }
}

struct RingtoneExporterTests {
    @Test func exportsSelectedRangeAsAACRingtone() async throws {
        let source = try makeTone(seconds: 3)
        defer { try? FileManager.default.removeItem(at: source) }
        let output = try await RingtoneExporter.export(source: source, range: 1...2, fadeIn: false, fadeOut: false)
        defer { try? FileManager.default.removeItem(at: output.deletingLastPathComponent()) }

        #expect(output.pathExtension == "m4r")
        #expect(output.deletingPathExtension().lastPathComponent == source.deletingPathExtension().lastPathComponent)
        let asset = AVURLAsset(url: output)
        let duration = try await asset.load(.duration).seconds
        #expect(abs(duration - 1) < 0.1)
        let track = try #require(try await asset.loadTracks(withMediaType: .audio).first)
        let format = try #require(try await track.load(.formatDescriptions).first)
        #expect(CMFormatDescriptionGetMediaSubType(format) == kAudioFormatMPEG4AAC)
        // 결과 미리듣기도 이 파일을 열 수 있어야 한다
        let previewDuration = try await MainActor.run { try PreviewPlayer(url: output).duration }
        #expect(abs(previewDuration - 1) < 0.1)
    }

    @Test func shortensFadeForShortRanges() {
        #expect(RingtoneExporter.fadeDuration(for: 30) == RingtoneExporter.maxFadeDuration)
        #expect(RingtoneExporter.fadeDuration(for: 3) == 1.5)
    }

    @Test func fadesInAndOutAtRangeEdges() async throws {
        let source = try makeTone(seconds: 5)
        defer { try? FileManager.default.removeItem(at: source) }
        let faded = try await RingtoneExporter.export(source: source, range: 1...4, fadeIn: true, fadeOut: true)
        defer { try? FileManager.default.removeItem(at: faded.deletingLastPathComponent()) }
        let plain = try await RingtoneExporter.export(source: source, range: 1...4, fadeIn: false, fadeOut: false)
        defer { try? FileManager.default.removeItem(at: plain.deletingLastPathComponent()) }

        // 페이드를 켜면 앞뒤 0.2초가 가운데보다 훨씬 작고, 끄면 가운데와 비슷하다
        let fadedLevels = try levels(of: faded)
        #expect(fadedLevels.start < fadedLevels.middle * 0.25)
        #expect(fadedLevels.end < fadedLevels.middle * 0.25)
        let plainLevels = try levels(of: plain)
        #expect(plainLevels.start > plainLevels.middle * 0.6)
        #expect(plainLevels.end > plainLevels.middle * 0.6)
    }
}

struct WaveformTests {
    @Test func showsWhereSoundIs() async throws {
        // 앞 1초는 무음, 뒤 1초만 소리
        let source = try makeTone(seconds: 2) { time in time < 1 ? 0 : 1 }
        defer { try? FileManager.default.removeItem(at: source) }
        let levels = try await Waveform.levels(of: source, count: 10)

        #expect(levels.count == 10)
        #expect(levels.prefix(5).allSatisfy { $0 < 0.01 })
        #expect(levels.suffix(5).allSatisfy { $0 > 0.9 })
    }
}

/// 테스트용 440Hz 사인파 오디오 파일. amplitude 는 시각(초)별 음량(0...1)
private func makeTone(seconds: Double, amplitude: (Double) -> Float = { _ in 1 }) throws -> URL {
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
    let frameCount = AVAudioFrameCount(seconds * format.sampleRate)
    let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
    buffer.frameLength = frameCount
    let samples = try #require(buffer.floatChannelData?[0])
    for frame in 0..<Int(frameCount) {
        let time = Double(frame) / format.sampleRate
        samples[frame] = amplitude(time) * sin(2 * .pi * 440 * Float(time))
    }
    let url = URL.temporaryDirectory.appending(path: "\(UUID().uuidString).caf")
    // AVAudioFile 은 해제될 때 파일을 닫으므로 문장 하나로 쓰고 버린다
    try AVAudioFile(forWriting: url, settings: format.settings).write(from: buffer)
    return url
}

/// 파일 앞·가운데·끝 0.2초 구간의 RMS 음량
private func levels(of url: URL) throws -> (start: Float, middle: Float, end: Float) {
    let file = try AVAudioFile(forReading: url)
    let buffer = try #require(
        AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length))
    )
    try file.read(into: buffer)
    let channel = try #require(buffer.floatChannelData?[0])
    let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    let window = Int(file.processingFormat.sampleRate * 0.2)
    let middle = samples.count / 2 - window / 2
    return (rms(samples.prefix(window)), rms(samples[middle..<middle + window]), rms(samples.suffix(window)))
}

private func rms(_ samples: ArraySlice<Float>) -> Float {
    (samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count)).squareRoot()
}
