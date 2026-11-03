import Foundation
import UsageCore

/// UI text in the selected language.
struct Strings {
    let language: AppLanguage
    private func t(_ ko: String, _ en: String) -> String { language == .korean ? ko : en }

    // Panel
    func updated(_ time: String) -> String { t("\(time) 업데이트", "Updated \(time)") }
    func valueAt(_ time: String) -> String { t("\(time) 값", "As of \(time)") }
    var retryNext: String { t("다음 조회 때 다시 시도", "will retry") }
    var loading: String { t("불러오는 중…", "Loading…") }
    var refreshing: String { t("새로고침 중…", "Refreshing…") }
    var refresh: String { t("새로고침", "Refresh") }
    var more: String { t("더 보기", "More") }
    var settingsMenu: String { t("설정…", "Settings…") }
    var quit: String { t("Noonchi 종료", "Quit Noonchi") }
    var showRawOutput: String { t("원본 출력 보기", "Show raw output") }
    var noProviders: String { t("Claude Code나 Codex를 찾지 못했어요", "Couldn't find Claude Code or Codex") }

    /// "5시간", "주간", "30일", or the model name.
    func windowLabel(_ kind: UsageWindow.Kind) -> String {
        switch kind {
        case .model(let name, _):
            return name
        case .rolling(let minutes):
            if minutes == 10080 { return t("주간", "Weekly") }
            if minutes % 1440 == 0 { return t("\(minutes / 1440)일", "\(minutes / 1440)-day") }
            return t("\(minutes / 60)시간", "\(minutes / 60)-hour")
        }
    }

    private var locale: Locale { Locale(identifier: language == .korean ? "ko_KR" : "en_US") }

    /// "3:59 PM" in both languages, as in the design.
    func clock(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm a"
        return f.string(from: date)
    }

    func reset(_ display: ResetDisplay) -> String {
        switch display {
        case .inMinutes(0): return t("곧", "soon")
        case .inMinutes(let m): return t("\(m)분 후", "in \(m) min")
        case .time(let d): return clock(d)
        case .weekdayTime(let d): return d.formatted(.dateTime.weekday(.abbreviated).locale(locale)) + " " + clock(d)
        case .date(let d): return d.formatted(.dateTime.month(.abbreviated).day().locale(locale))
        }
    }

    // Raw output window
    var rawOutputTitle: String { t("Noonchi · 원본 출력", "Noonchi · Raw output") }
    var notYet: String { t("(아직 없음)", "(nothing yet)") }
    var copy: String { t("복사", "Copy") }
    var showInFinder: String { t("Finder에서 보기", "Show in Finder") }

    // Settings window
    var settingsTitle: String { t("Noonchi 설정", "Noonchi Settings") }
    var general: String { t("일반", "General") }
    var services: String { t("서비스", "Services") }
    var languageLabel: String { t("언어", "Language") }
    var menuBar: String { t("상단 바", "Menu bar") }
    var menuBarMode: String { t("표시 방식", "Display") }
    var modeAuto: String { t("자동", "Automatic") }
    var modeCustom: String { t("직접 선택", "Custom") }
    var customHint: String { t("서비스 탭에서 항목을 고르세요.", "Pick items in the Services tab.") }
    var labels: String { t("라벨", "Labels") }
    var labelsHint: String { t("5h 19%처럼 기간 표시", "Show the period, like 5h 19%") }
    var iconStyle: String { t("아이콘", "Icon") }
    var iconSymbol: String { t("기호", "Symbol") }
    var iconMonogram: String { t("글자", "Letter") }
    var iconRing: String { t("링", "Ring") }
    var colors: String { t("색상", "Colors") }
    var highlightHigh: String { t("높을 때만 강조", "Highlight high usage") }
    var highlightHint: String { t("80% 주황 · 95% 빨강", "Orange at 80%, red at 95%") }
    var barColor: String { t("막대 색", "Bar color") }
    var systemColor: String { t("시스템", "System") }
    var launchAtLogin: String { t("로그인 시 열기", "Open at login") }
    var approveInSystemSettings: String { t("시스템 설정에서 허용하기…", "Allow in System Settings…") }
    var other: String { t("기타", "Other") }
    func used(_ percent: Int) -> String { t("\(percent)% 사용", "\(percent)% used") }
    func resetsAt(_ time: String) -> String { t("\(time) 초기화", "resets \(time)") }
    var notInstalled: String { t("설치되지 않음", "Not installed") }
    var menuBarItems: String { t("상단 바 항목", "Menu bar items") }
    var afterFirstRefresh: String { t("첫 조회 뒤에 나타나요", "Appear after the first refresh") }
    func every(_ interval: Duration) -> String {
        let m = Int(interval.components.seconds / 60)
        return t("\(m)분마다", "every \(m) min")
    }

    /// "이 속도면 3:10 PM쯤 5시간 한도에 닿아요"
    func pace(_ label: String, _ when: ResetDisplay) -> String {
        let time = reset(when)
        switch when {
        case .inMinutes(0):
            return t("이 속도면 곧 \(label) 한도에 닿아요", "On pace to hit the \(label) limit soon")
        case .inMinutes:
            return t("이 속도면 \(time)쯤 \(label) 한도에 닿아요", "On pace to hit the \(label) limit \(time)")
        case .time, .weekdayTime, .date:
            return t("이 속도면 \(time)쯤 \(label) 한도에 닿아요", "On pace to hit the \(label) limit by \(time)")
        }
    }

    /// Same wording as the panel row, for a window known only by ID.
    func windowLabel(id: String) -> String {
        UsageWindow.kind(forID: id).map(windowLabel) ?? id
    }

    func error(_ e: ProviderError) -> String {
        switch e {
        case .notInstalled:    return t("설치되지 않음", "Not installed")
        case .launchFailed:    return t("실행하지 못했어요", "Couldn't launch")
        case .timeout:         return t("응답 없음", "No response")
        case .notLoggedIn:     return t("로그인 필요", "Not logged in")
        case .unsupportedPlan: return t("API 과금 계정이라 구독 한도가 없어요", "API billing account has no plan limits")
        case .unparsable:      return t("사용률을 읽지 못했어요 (원본 출력 확인)", "Couldn't read usage (see raw output)")
        case .failed(let m):   return t("오류: \(m)", "Error: \(m)")
        }
    }
}
