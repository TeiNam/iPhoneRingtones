import Foundation

/// 벨소리로 잘라낼 구간(초 단위) 입력을 검증한다.
enum RingtoneRange {
    /// iPhone 벨소리 최대 길이
    static let maxLength: TimeInterval = 40
    /// 0.1초 단위 입력을 빼고 더할 때 생기는 부동소수점 오차 허용치
    private static let tolerance: TimeInterval = 0.001

    enum Problem: Error, Equatable {
        case notANumber
        case endNotAfterStart
        case tooLong

        var message: String {
            switch self {
            case .notANumber: "시작·끝 시간은 초 단위 숫자로 입력하세요."
            case .endNotAfterStart: "끝 시간은 시작 시간보다 뒤여야 합니다."
            case .tooLong: "벨소리는 최대 \(Int(RingtoneRange.maxLength))초까지 만들 수 있습니다."
            }
        }
    }

    /// 입력값을 곡 길이 안으로 맞춘 뒤 내보낼 구간을 돌려준다.
    static func validate(
        start: String, end: String, duration: TimeInterval
    ) -> Result<ClosedRange<TimeInterval>, Problem> {
        guard let start = seconds(from: start), let end = seconds(from: end) else {
            return .failure(.notANumber)
        }
        // 표시 반올림 때문에 곡 길이보다 살짝 큰 끝 시간을 적어도 곡 끝까지로 본다
        let lower = max(start, 0)
        let upper = min(end, duration)
        guard upper > lower else { return .failure(.endNotAfterStart) }
        guard upper - lower <= maxLength + tolerance else { return .failure(.tooLong) }
        return .success(lower...upper)
    }

    /// 화면과 입력창에 쓰는 초 표기 (소수 첫째 자리, 항상 '.' 소수점)
    static func format(_ seconds: TimeInterval) -> String {
        String(format: "%.1f", seconds)
    }

    private static func seconds(from text: String) -> TimeInterval? {
        // 소수점으로 쉼표를 쓰는 지역 설정 입력도 받아 준다
        let normalized = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value.isFinite else { return nil }
        return value
    }
}
