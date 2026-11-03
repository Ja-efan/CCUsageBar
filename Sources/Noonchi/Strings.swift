import Foundation
import UsageCore

/// UI text in the selected language.
struct Strings {
    let language: AppLanguage
    private func t(_ ko: String, _ en: String) -> String { language == .korean ? ko : en }

    // Panel
    var session: String { t("5시간 세션", "5-hour session") }
    var weekAll: String { t("주간 (전체 모델)", "Weekly (all models)") }
    func weekModel(_ name: String) -> String { t("주간 (\(name))", "Weekly (\(name))") }
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
    var languageLabel: String { t("언어", "Language") }
    var menuBar: String { t("상단 바 표시", "Menu bar") }
    var menuBarHint: String { t("상단 바에 보여줄 항목을 고르세요.", "Choose what to show in the menu bar.") }
    var modelsHint: String { t("모델별 한도는 한 번 조회된 뒤 여기에 나타나요.", "Model limits appear here after the first refresh.") }
    var labelStyle: String { t("표시 형식", "Format") }
    var styleLabeled: String { t("라벨 포함 (5h 42%)", "With labels (5h 42%)") }
    var styleCompact: String { t("숫자만 (42%)", "Numbers only (42%)") }
    var preview: String { t("미리보기", "Preview") }
    var barColor: String { t("막대 색상", "Bar color") }
    var colorMode: String { t("색상 방식", "Color mode") }
    var modeByUsage: String { t("사용률에 따라 (초록·주황·빨강)", "By usage (green · orange · red)") }
    var modeFixed: String { t("단색", "Single color") }
    var customColor: String { t("직접 선택", "Custom") }
    var warnHigh: String { t("90% 이상이면 빨간색으로 경고", "Turn red at 90% or more") }
    var done: String { t("완료", "Done") }

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
