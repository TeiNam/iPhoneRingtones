import AVFoundation

/// 원본 오디오의 구간을 AAC 로 인코딩해 iPhone 벨소리(.m4r)로 저장한다.
enum RingtoneExporter {
    struct UnsupportedSource: LocalizedError {
        var errorDescription: String? { "이 파일은 벨소리로 변환할 수 없습니다." }
    }

    /// 페이드 인·아웃 길이
    static let maxFadeDuration: TimeInterval = 2
    private static let timescale: CMTimeScale = 600

    /// 결과는 임시 폴더에 '원본 이름.m4r' 로 만들어진다.
    static func export(
        source: URL, range: ClosedRange<TimeInterval>, fadeIn: Bool, fadeOut: Bool
    ) async throws -> URL {
        let asset = AVURLAsset(url: source)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw UnsupportedSource()
        }
        session.timeRange = CMTimeRange(start: time(range.lowerBound), end: time(range.upperBound))
        if fadeIn || fadeOut {
            session.audioMix = try await fadeMix(for: asset, range: range, fadeIn: fadeIn, fadeOut: fadeOut)
        }
        let output = try makeOutputURL(for: source)
        // .m4r 은 확장자만 다른 AAC(.m4a) 파일이다
        try await session.export(to: output, as: .m4a)
        return output
    }

    /// 구간이 짧으면 페이드 인·아웃이 겹치지 않도록 구간의 절반까지만 쓴다.
    static func fadeDuration(for length: TimeInterval) -> TimeInterval {
        min(maxFadeDuration, length / 2)
    }

    /// 볼륨 램프는 원본 트랙의 시간축 기준이므로 구간의 시작·끝 시각에 건다.
    private static func fadeMix(
        for asset: AVURLAsset, range: ClosedRange<TimeInterval>, fadeIn: Bool, fadeOut: Bool
    ) async throws -> AVAudioMix {
        let fade = time(fadeDuration(for: range.upperBound - range.lowerBound))
        let start = time(range.lowerBound)
        let end = time(range.upperBound)
        let mix = AVMutableAudioMix()
        mix.inputParameters = try await asset.loadTracks(withMediaType: .audio).map { track in
            let parameters = AVMutableAudioMixInputParameters(track: track)
            if fadeIn {
                parameters.setVolumeRamp(
                    fromStartVolume: 0, toEndVolume: 1, timeRange: CMTimeRange(start: start, duration: fade)
                )
            }
            if fadeOut {
                parameters.setVolumeRamp(
                    fromStartVolume: 1, toEndVolume: 0, timeRange: CMTimeRange(start: end - fade, duration: fade)
                )
            }
            return parameters
        }
        return mix
    }

    private static func time(_ seconds: TimeInterval) -> CMTime {
        CMTime(seconds: seconds, preferredTimescale: timescale)
    }

    private static func makeOutputURL(for source: URL) throws -> URL {
        // 내보낼 때마다 새 폴더를 써서 같은 이름의 이전 결과(끌어 놓는 중일 수도 있는)를 건드리지 않는다
        let folder = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
            .appending(path: source.deletingPathExtension().lastPathComponent)
            .appendingPathExtension("m4r")
    }
}
