import Accelerate
import AVFoundation

/// 오디오 파일 전체를 같은 길이의 칸으로 나눠 칸마다 음량(RMS)을 구한다.
/// 요즘 음악은 순간 최댓값이 거의 늘 꽉 차 있어 RMS 를 써야 조용한 절·큰 후렴이 구분된다.
enum Waveform {
    /// 가장 큰 칸이 1 이 되도록 맞춘 0...1 값들. 곡 전체를 디코딩하므로 메인 스레드 밖에서 돈다.
    @concurrent
    static func levels(of url: URL, count: Int) async throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let framesPerBucket = AVAudioFrameCount(max(1, file.length / AVAudioFramePosition(count)))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: framesPerBucket) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        var levels: [Float] = []
        levels.reserveCapacity(count)
        while levels.count < count, file.framePosition < file.length {
            // 계산 중 다른 파일을 열면 화면이 작업을 취소한다
            try Task.checkCancellation()
            try file.read(into: buffer, frameCount: framesPerBucket)
            guard buffer.frameLength > 0 else { break }
            levels.append(loudestChannelRMS(of: buffer))
        }
        let loudest = levels.max() ?? 0
        return loudest > 0 ? levels.map { $0 / loudest } : levels
    }

    private static func loudestChannelRMS(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channels = buffer.floatChannelData else { return 0 }
        return (0..<Int(buffer.format.channelCount)).map { channel in
            var rms: Float = 0
            vDSP_rmsqv(channels[channel], 1, &rms, vDSP_Length(buffer.frameLength))
            return rms
        }.max() ?? 0
    }
}
