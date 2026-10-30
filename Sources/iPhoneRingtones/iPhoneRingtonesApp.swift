import SwiftUI

/// macOS 27 SDK 의 `@State` 는 매크로인데 Command Line Tools 에는 그 플러그인(SwiftUIMacros)이 없다.
/// 같은 이름의 프로퍼티 래퍼 타입을 별칭으로 불러 매크로를 거치지 않는다.
typealias ViewState = SwiftUI.State

@main
struct iPhoneRingtonesApp: App {
    var body: some Scene {
        // 제목을 비워 두면 창 제목이 번들 이름(build.sh 의 APP_NAME)을 따른다
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
