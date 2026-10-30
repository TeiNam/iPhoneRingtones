import AppKit
import SwiftUI

/// 파일 아이콘. Finder·음악 앱 등으로 끌어 놓으면 파일이 복사된다.
struct FileDragSource: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> DraggableFileIcon {
        let view = DraggableFileIcon()
        // 아이콘 기본 크기(32pt)보다 큰 끌기 대상이 되도록 프레임에 맞춰 키운다
        view.imageScaling = .scaleProportionallyUpOrDown
        return view
    }

    func updateNSView(_ view: DraggableFileIcon, context: Context) {
        view.fileURL = url
    }
}

final class DraggableFileIcon: NSImageView, NSDraggingSource {
    var fileURL: URL? {
        didSet { image = fileURL.map { NSWorkspace.shared.icon(forFile: $0.path) } }
    }

    // 창이 비활성 상태여도 첫 클릭부터 바로 끌 수 있게 한다
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard let fileURL else { return }
        let item = NSDraggingItem(pasteboardWriter: fileURL as NSURL)
        item.setDraggingFrame(bounds, contents: image)
        beginDraggingSession(with: [item], event: event, source: self)
    }

    // 이동을 허용하면 같은 볼륨의 Finder 가 임시 결과 파일을 옮겨 버리므로 복사만 허용한다
    func draggingSession(
        _ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }
}
