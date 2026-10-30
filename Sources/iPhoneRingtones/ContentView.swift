import SwiftUI

/// 오디오 끌어 놓기 → 미리듣기 → 구간 지정 → .m4r 내보내기 → 결과 아이콘 끌어 내기
struct ContentView: View {
    /// 원본 미리듣기 (원본 파일 경로도 여기서 얻는다)
    @ViewState private var preview: PreviewPlayer?
    @ViewState private var startText = ""
    @ViewState private var endText = ""
    @ViewState private var shouldFadeIn = false
    @ViewState private var shouldFadeOut = false
    /// 만들어진 벨소리 — 결과 미리듣기와 끌어 내기에 함께 쓴다
    @ViewState private var result: PreviewPlayer?
    @ViewState private var isExporting = false
    @ViewState private var errorMessage: String?
    @ViewState private var isImporterPresented = false
    @ViewState private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            dropZone
            if let preview {
                let selection = RingtoneRange.validate(start: startText, end: endText, duration: preview.duration)
                WaveformView(preview: preview, selection: try? selection.get())
                PlayerControls(preview: preview)
                rangeEditor(preview, selection: selection)
            }
            if let result {
                Divider()
                resultSection(result)
            }
            if let errorMessage { Text(errorMessage).foregroundStyle(.red) }
        }
        .padding(20)
        .frame(width: 560)
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            load(url)
            return true
        } isTargeted: { isDropTargeted = $0 }
        .fileImporter(isPresented: $isImporterPresented, allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url): load(url)
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
    }

    private var dropZone: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text(preview?.url.lastPathComponent ?? "오디오 파일을 여기에 끌어다 놓으세요")
                .font(.headline)
            Button("파일 열기…") { isImporterPresented = true }
        }
        .frame(maxWidth: .infinity, minHeight: 130)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : .secondary,
                    style: StrokeStyle(lineWidth: 2, dash: [6])
                )
        }
    }

    private func rangeEditor(
        _ preview: PreviewPlayer, selection: Result<ClosedRange<TimeInterval>, RingtoneRange.Problem>
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 20) {
                timeField("시작", text: $startText, preview: preview)
                timeField("끝", text: $endText, preview: preview)
            }
            HStack(spacing: 16) {
                Toggle("페이드 인", isOn: $shouldFadeIn)
                    .help("시작 부분 최대 \(Int(RingtoneExporter.maxFadeDuration))초 동안 소리를 서서히 키웁니다")
                Toggle("페이드 아웃", isOn: $shouldFadeOut)
                    .help("끝 부분 최대 \(Int(RingtoneExporter.maxFadeDuration))초 동안 소리를 서서히 줄입니다")
            }
            HStack(spacing: 12) {
                Button("벨소리 만들기") {
                    if case .success(let range) = selection { export(range) }
                }
                .disabled(isExporting || (try? selection.get()) == nil)
                if isExporting { ProgressView().controlSize(.small) }
                switch selection {
                case .success(let range):
                    Text("길이 \(RingtoneRange.format(range.upperBound - range.lowerBound))초")
                case .failure(let problem):
                    Text(problem.message).foregroundStyle(.red)
                }
            }
        }
    }

    private func timeField(_ title: String, text: Binding<String>, preview: PreviewPlayer) -> some View {
        HStack(spacing: 6) {
            Text(title)
            TextField(title, text: text).frame(width: 64)
            Text("초")
            Button("현재 위치") { text.wrappedValue = RingtoneRange.format(preview.currentTime) }
                .help("미리듣기 위치를 \(title) 시간으로 씁니다")
                .accessibilityLabel("현재 위치를 \(title) 시간으로")
        }
    }

    private func resultSection(_ result: PreviewPlayer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                FileDragSource(url: result.url)
                    .frame(width: 64, height: 64)
                    .accessibilityLabel("벨소리 파일 \(result.url.lastPathComponent)")
                VStack(alignment: .leading, spacing: 4) {
                    Text(result.url.lastPathComponent).bold()
                    Text("아이콘을 Finder나 음악 앱으로 끌어다 놓아 저장하세요.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // 끌어 놓기를 못 쓰는 키보드·VoiceOver 사용자를 위한 대체 경로
                Button("저장…") { save(result.url) }
            }
            // 만들어진 파일(페이드 포함)을 그대로 들어 본다
            PlayerControls(preview: result)
        }
    }

    private func load(_ url: URL) {
        do {
            guard url.isFileURL else { throw CocoaError(.fileReadUnsupportedScheme) }
            let newPreview = try PreviewPlayer(url: url)
            preview?.stop()
            result?.stop()
            preview = newPreview
            result = nil
            startText = RingtoneRange.format(0)
            endText = RingtoneRange.format(min(newPreview.duration, RingtoneRange.maxLength))
            errorMessage = nil
        } catch {
            errorMessage = "오디오 파일을 열 수 없습니다: \(url.lastPathComponent)"
        }
    }

    private func export(_ range: ClosedRange<TimeInterval>) {
        guard let source = preview?.url else { return }
        isExporting = true
        result?.stop()
        result = nil
        errorMessage = nil
        Task {
            defer { isExporting = false }
            do {
                let output = try await RingtoneExporter.export(
                    source: source, range: range, fadeIn: shouldFadeIn, fadeOut: shouldFadeOut
                )
                // 내보내는 사이 다른 파일을 열었으면 이전 파일의 결과는 보여 주지 않는다
                guard preview?.url == source else { return }
                result = try PreviewPlayer(url: output)
            } catch {
                errorMessage = "벨소리를 만들지 못했습니다: \(error.localizedDescription)"
            }
        }
    }

    private func save(_ url: URL) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = url.lastPathComponent
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            // 원자적 쓰기: 덮어쓰기 도중 실패해도 기존 파일이 깨진 채 남지 않는다
            try Data(contentsOf: url).write(to: destination, options: .atomic)
        } catch {
            errorMessage = "저장하지 못했습니다: \(error.localizedDescription)"
        }
    }
}
