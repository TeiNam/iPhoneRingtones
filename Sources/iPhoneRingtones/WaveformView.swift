import SwiftUI

/// 원본 전체의 음량 파형. 선택 구간·재생 위치를 겹쳐 그리고, 누르거나 끌면 그 위치로 이동한다.
struct WaveformView: View {
    let preview: PreviewPlayer
    /// 입력이 올바른 구간일 때만 강조한다
    let selection: ClosedRange<TimeInterval>?

    @ViewState private var levels: [Float] = []
    @ViewState private var failure: String?

    private static let barCount = 200
    private static let height: CGFloat = 72

    var body: some View {
        // Canvas 는 화면에 그릴 때 따로 불리므로 관찰 값은 여기(body)서 읽어 넘겨야 재생 중에 다시 그려진다
        let drawing = WaveformDrawing(
            levels: levels, selection: selection, currentTime: preview.currentTime, duration: preview.duration
        )
        GeometryReader { geometry in
            Canvas { context, size in drawing.draw(in: context, size: size) }
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { drag in
                    let ratio = min(max(drag.location.x / geometry.size.width, 0), 1)
                    preview.seek(to: ratio * preview.duration)
                })
        }
        .frame(height: Self.height)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
        .overlay {
            if let failure {
                Text(failure).foregroundStyle(.secondary)
            } else if levels.isEmpty {
                ProgressView().controlSize(.small)
            }
        }
        // 이동·구간 지정은 슬라이더와 입력칸으로도 할 수 있어 VoiceOver 에서는 건너뛴다
        .accessibilityHidden(true)
        .task(id: preview.url) { await loadLevels() }
    }

    private func loadLevels() async {
        levels = []
        failure = nil
        do {
            levels = try await Waveform.levels(of: preview.url, count: Self.barCount)
        } catch is CancellationError {
            // 다른 파일을 열어 취소됨 — 새 파일의 작업이 다시 그린다
        } catch {
            failure = "파형을 그릴 수 없습니다"
        }
    }
}

/// 한 번 그리는 데 필요한 값 묶음
private struct WaveformDrawing {
    let levels: [Float]
    let selection: ClosedRange<TimeInterval>?
    let currentTime: TimeInterval
    let duration: TimeInterval

    func draw(in context: GraphicsContext, size: CGSize) {
        if let selection {
            let start = x(selection.lowerBound, size), end = x(selection.upperBound, size)
            context.fill(
                Path(CGRect(x: start, y: 0, width: end - start, height: size.height)),
                with: .color(.accentColor.opacity(0.2))
            )
        }
        drawBars(in: context, size: size)
        context.fill(
            Path(CGRect(x: x(currentTime, size) - 1, y: 0, width: 2, height: size.height)),
            with: .color(.primary)
        )
    }

    /// 선택 구간 안 막대는 강조색, 바깥은 회색
    private func drawBars(in context: GraphicsContext, size: CGSize) {
        guard !levels.isEmpty else { return }
        let slot = size.width / CGFloat(levels.count)
        var inside = Path()
        var outside = Path()
        for (index, level) in levels.enumerated() {
            let height = max(1, CGFloat(level) * size.height * 0.9)
            let bar = CGRect(
                x: CGFloat(index) * slot, y: (size.height - height) / 2, width: max(1, slot * 0.6), height: height
            )
            let time = (Double(index) + 0.5) / Double(levels.count) * duration
            if selection?.contains(time) == true {
                inside.addRect(bar)
            } else {
                outside.addRect(bar)
            }
        }
        context.fill(outside, with: .color(.secondary))
        context.fill(inside, with: .color(.accentColor))
    }

    private func x(_ time: TimeInterval, _ size: CGSize) -> CGFloat {
        CGFloat(time / duration) * size.width
    }
}
