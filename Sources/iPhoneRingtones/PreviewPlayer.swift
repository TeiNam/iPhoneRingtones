import AVFoundation
import Observation

/// 미리듣기 재생기. 화면이 읽는 재생 상태·위치를 관찰 가능한 값으로 들고 있다.
@MainActor @Observable
final class PreviewPlayer {
    let url: URL
    let duration: TimeInterval
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0

    @ObservationIgnored private let player: AVAudioPlayer
    /// 원본·결과 미리듣기가 겹쳐 들리지 않도록 지금 재생 중인 것
    private static weak var playing: PreviewPlayer?

    /// 열 수 없거나 길이가 0인 파일이면 던진다.
    init(url: URL) throws {
        self.url = url
        player = try AVAudioPlayer(contentsOf: url)
        guard player.duration > 0 else { throw CocoaError(.fileReadCorruptFile) }
        duration = player.duration
        player.prepareToPlay()
    }

    func togglePlayback() {
        if player.isPlaying {
            player.pause()
        } else {
            if Self.playing !== self { Self.playing?.stop() }
            Self.playing = self
            player.play()
        }
        refresh()
    }

    func seek(to time: TimeInterval) {
        player.currentTime = time
        refresh()
    }

    func stop() {
        player.stop()
        refresh()
    }

    /// AVAudioPlayer 는 위치 변화나 재생 끝을 알려 주지 않으므로 재생 중에는 화면이 주기적으로 부른다.
    func refresh() {
        isPlaying = player.isPlaying
        currentTime = player.currentTime
    }
}
