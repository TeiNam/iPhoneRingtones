import SwiftUI

/// 미리듣기: 재생/정지 버튼과 위치 슬라이더
struct PlayerControls: View {
    let preview: PreviewPlayer

    private static let refreshInterval = Duration.milliseconds(100)

    var body: some View {
        HStack(spacing: 12) {
            Button(
                preview.isPlaying ? "정지" : "재생",
                systemImage: preview.isPlaying ? "stop.fill" : "play.fill",
                action: preview.togglePlayback
            )
            Slider(value: position, in: 0...preview.duration)
                .accessibilityLabel("재생 위치")
            Text("\(RingtoneRange.format(preview.currentTime)) / \(RingtoneRange.format(preview.duration))초")
                .monospacedDigit()
        }
        // 원본·결과 두 플레이어를 VoiceOver 가 구분할 수 있도록 파일 이름으로 묶는다
        .accessibilityElement(children: .contain)
        .accessibilityLabel(preview.url.lastPathComponent)
        // 재생 중일 때만 위치를 다시 읽는다. 멈추거나 화면이 사라지면 SwiftUI 가 작업을 취소한다.
        .task(id: preview.isPlaying) {
            while preview.isPlaying, (try? await Task.sleep(for: Self.refreshInterval)) != nil {
                preview.refresh()
            }
        }
    }

    private var position: Binding<TimeInterval> {
        Binding { preview.currentTime } set: { preview.seek(to: $0) }
    }
}
