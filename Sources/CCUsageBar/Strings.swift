import Foundation
import UsageCore

/// UI text in the selected language.
struct Strings {
    let language: AppLanguage
    private func t(_ ko: String, _ en: String) -> String { language == .korean ? ko : en }

    // Panel
    var title: String { t("Claude Code 사용량", "Claude Code Usage") }
    var session: String { t("5시간 세션", "5-hour session") }
    var weekAll: String { t("주간 (전체 모델)", "Weekly (all models)") }
    func weekModel(_ name: String) -> String { t("주간 (\(name))", "Weekly (\(name))") }
    func resets(_ when: String) -> String { t("초기화: \(when)", "Resets \(when)") }
    func updated(_ time: String) -> String { t("업데이트: \(time)", "Updated \(time)") }
    var loading: String { t("불러오는 중…", "Loading…") }
    var refresh: String { t("새로고침", "Refresh") }
    var quit: String { t("종료", "Quit") }
    var settings: String { t("설정", "Settings") }
    var showRawOutput: String { t("원본 출력 보기", "Show raw output") }

    // Raw output window
    var rawOutputTitle: String { t("CC Usage Bar · 원본 출력", "CC Usage Bar · Raw output") }
    var notYet: String { t("(아직 없음)", "(nothing yet)") }
    var copy: String { t("복사", "Copy") }
    var showInFinder: String { t("Finder에서 보기", "Show in Finder") }

    // Settings window
    var settingsTitle: String { t("CC Usage Bar 설정", "CC Usage Bar Settings") }
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

    func error(_ e: UsageError) -> String {
        switch e {
        case .claudeNotFound: return t("claude 실행 파일을 찾지 못했어요", "Couldn't find the claude executable")
        case .launchFailed:   return t("Claude Code를 실행하지 못했어요", "Couldn't launch Claude Code")
        case .noResponse:     return t("Claude Code가 응답하지 않았어요", "Claude Code didn't respond")
        case .notLoggedIn:    return t("Claude Code에 로그인되어 있지 않아요", "Claude Code is not logged in")
        case .apiBilling:     return t("API 과금 계정이라 구독 한도가 없어요", "API billing account has no plan limits")
        case .unparsable:     return t("사용률을 찾지 못했어요 (원본 출력 확인)", "Couldn't read usage (see raw output)")
        }
    }
}
