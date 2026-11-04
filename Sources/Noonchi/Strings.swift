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

    // Updates
    var updateMenu: String { t("업데이트 확인…", "Check for Updates…") }
    var updateTitle: String { t("Noonchi 업데이트", "Noonchi Update") }
    var updateChecking: String { t("확인하는 중…", "Checking…") }
    var updateLatest: String { t("최신 버전입니다", "You're up to date") }
    func updateCurrent(_ version: String) -> String { t("지금 버전은 \(version)입니다.", "This is version \(version).") }
    func updateAvailable(_ version: String) -> String { t("\(version) 버전이 나왔습니다", "Version \(version) is available") }
    func updateInstallNote(_ current: String) -> String {
        t("지금 버전은 \(current)입니다. 설치하면 GitHub 릴리스에서 내려받아 교체하고 앱을 다시 엽니다. 설정은 유지됩니다.",
          "You have \(current). Installing downloads it from GitHub Releases, replaces the app, and reopens it. Your settings stay.")
    }
    var updateFromSource: String { t("이 빌드는 소스에서 설치합니다. 브랜치를 옮긴 뒤 make install을 실행하세요.", "This build installs from source. Rebase the branch and run make install.") }
    var done: String { t("확인", "OK") }
    var updateInstall: String { t("설치", "Install") }
    var updateLater: String { t("나중에", "Later") }
    var updateChanges: String { t("변경 내용", "What's New") }
    var updateDownloading: String { t("내려받는 중…", "Downloading…") }
    var updateFailed: String { t("업데이트하지 못했어요", "Couldn't update") }
    var updateOpenPage: String { t("릴리스 페이지 열기", "Open Releases") }
    func updateFailure(_ failure: UpdateFailure) -> String {
        switch failure {
        case .network: return t("GitHub에 연결하지 못했어요. 지금 앱은 그대로입니다.", "Couldn't reach GitHub. Your app hasn't changed.")
        case .unreadableRelease: return t("릴리스 정보를 읽지 못했어요. 지금 앱은 그대로입니다.", "Couldn't read the release. Your app hasn't changed.")
        case .damagedDownload: return t("받은 파일이 손상됐어요. 지금 앱은 그대로입니다.", "The download is damaged. Your app hasn't changed.")
        case .cannotWriteToApp: return t("앱 폴더에 쓸 수 없어요. 릴리스 페이지에서 받아 ~/Applications로 옮겨 주세요.", "Can't write to the app's folder. Get it from Releases and move it to ~/Applications.")
        case .invalidApp: return t("받은 앱이 올바르지 않아요. 지금 앱은 그대로입니다.", "The downloaded app isn't valid. Your app hasn't changed.")
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
    var refreshEvery: String { t("새로고침 주기", "Refresh every") }
    var minutesUnit: String { t("분", "min") }
    var refreshHint: String { t("길수록 CPU를 덜 쓰지만 한도 경고가 늦어질 수 있어요. 화면이 꺼져 있으면 조회하지 않아요.", "Longer uses less CPU, but limit warnings can come later. Skipped while the screen is off.") }
    func every(_ interval: RefreshInterval) -> String {
        t("\(interval.minutes)분마다", "every \(interval.minutes) min")
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
