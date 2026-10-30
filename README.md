# iPhoneRingtones

![Swift](https://img.shields.io/badge/Swift-6.0-F05138.svg)
![SwiftUI](https://img.shields.io/badge/SwiftUI-macOS%2015%2B-0D96F6.svg)
![AVFoundation](https://img.shields.io/badge/AVFoundation-Audio-555555.svg)
![Universal](https://img.shields.io/badge/Universal-arm64%20%7C%20x86__64-000000.svg)

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://buymeacoffee.com/teinam)

음악 파일에서 원하는 구간을 골라 iPhone 벨소리(`.m4r`)로 만드는 macOS 앱입니다.
Xcode 없이 Command Line Tools 만으로 빌드합니다.

## 기능

- **파일 열기**: 오디오 파일을 창에 끌어다 놓거나 "파일 열기…"로 엽니다. mp3, m4a, wav, aiff 등 macOS 가 재생할 수 있는 형식이면 됩니다.
- **음량 파형**: 곡 전체의 음량을 그려 소리가 나는 구간을 한눈에 보여 줍니다. 파형을 클릭하거나 끌면 그 위치로 이동합니다.
- **미리듣기**: 재생/정지 버튼과 위치 슬라이더가 있습니다.
- **구간 지정**: 시작·끝을 초 단위로 입력하거나 "현재 위치" 버튼으로 지정합니다. 최대 60초입니다.
- **페이드 인/아웃**: 시작과 끝 2초 동안 소리를 서서히 키우거나 줄입니다. 구간이 4초보다 짧으면 구간 길이의 절반만 씁니다.
- **벨소리 만들기**: 선택한 구간을 AAC 로 인코딩해 `.m4r` 파일을 만들고, 결과를 바로 들어 볼 수 있습니다.
- **저장**: 결과 아이콘을 Finder 나 음악 앱으로 끌어다 놓거나 "저장…" 버튼으로 저장합니다.

## 요구 사항

- macOS 15 이상 (Apple Silicon 과 Intel 을 모두 지원하는 Universal 앱)
- 빌드할 때: Xcode Command Line Tools. Swift 6.4.2 / macOS 27.2 SDK 에서 확인했습니다. 설치되어 있지 않으면 `xcode-select --install` 로 설치합니다.

## 빌드와 실행

```bash
./build.sh                       # 테스트 후 build/iPhoneRingtones.app 생성
open build/iPhoneRingtones.app
```

`build.sh` 는 다음 순서로 동작합니다.

1. `swift test` 로 테스트를 실행합니다.
2. `swift build -c release --arch arm64 --arch x86_64` 로 Universal 바이너리를 빌드합니다.
3. `scripts/make-icon.swift` 가 앱 아이콘을 그리고 `iconutil` 로 `.icns` 를 만듭니다.
4. Info.plist 를 포함한 `.app` 번들을 만들고 ad-hoc 서명합니다.

앱 이름·번들 ID·버전은 `build.sh` 맨 위의 변수에서 바꿀 수 있습니다.

## 사용법

1. 오디오 파일을 창에 끌어다 놓습니다.
2. 파형에서 소리가 큰 부분을 클릭하고 재생해 들어 봅니다.
3. 원하는 위치에서 시작·끝 옆의 "현재 위치"를 누르거나 초를 직접 입력합니다.
4. 필요하면 "페이드 인"과 "페이드 아웃"을 켭니다.
5. "벨소리 만들기"를 누르고 아래 결과 플레이어로 들어 봅니다.
6. 결과 아이콘을 Finder 로 끌어다 놓거나 "저장…"으로 저장합니다.

### iPhone 에 넣기

1. iPhone 을 Mac 에 연결하고 Finder 사이드바에서 iPhone 을 선택합니다.
2. `.m4r` 파일을 그 창으로 끌어다 놓으면 벨소리로 동기화됩니다.
3. iPhone 의 설정 → 사운드 및 햅틱 → 벨소리에서 선택합니다.

> iPhone 은 전통적으로 40초까지만 벨소리로 받아 왔습니다. 40초를 넘는 벨소리는 기기에서 인식되는지 확인하세요.

## 프로젝트 구조

```text
Sources/iPhoneRingtones/
├── iPhoneRingtonesApp.swift   앱 진입점
├── ContentView.swift          메인 화면 (불러오기, 구간 지정, 내보내기, 결과)
├── WaveformView.swift         음량 파형 표시, 클릭해서 이동
├── Waveform.swift             파형용 음량(RMS) 계산
├── PlayerControls.swift       재생/정지 버튼, 위치 슬라이더
├── PreviewPlayer.swift        미리듣기 재생기 (AVAudioPlayer)
├── RingtoneRange.swift        구간 입력 검증 (최대 60초)
├── RingtoneExporter.swift     .m4r 내보내기, 페이드 (AVAssetExportSession)
└── FileDragSource.swift       결과 아이콘 끌어 내기 (AppKit)
Tests/iPhoneRingtonesTests/    Swift Testing 테스트
scripts/make-icon.swift        앱 아이콘 생성
build.sh                       .app 번들 빌드 스크립트
```

## Command Line Tools 빌드 메모

Xcode 없이 빌드하기 위해 우회한 부분입니다.

- macOS 27 SDK 에서 SwiftUI 의 `@State` 는 매크로인데, Command Line Tools 에는 그 플러그인(SwiftUIMacros)이 없습니다. 그래서 같은 이름의 프로퍼티 래퍼 타입을 `ViewState` 라는 별칭으로 씁니다 (`iPhoneRingtonesApp.swift`).
- Command Line Tools 의 `swift test` 는 Swift Testing 매크로 플러그인 경로를 넘기지 않습니다. 그래서 `build.sh` 가 `-plugin-path` 를 직접 넘깁니다.
- asset catalog 를 만드는 `actool` 이 없어서, 앱 아이콘은 코드로 그린 PNG 를 `iconutil` 로 묶어 만듭니다.
