# Noonchi (눈치)

[English](README.md) | **한국어**

Claude Code의 **5시간 세션 사용률**과 **주간 사용률**을 macOS 메뉴 막대에 숫자로 표시하는 앱입니다. 패널에서는 Fable 같은 **모델별 주간 한도**도 함께 보여줍니다.

```
5h 42% · 7d 18%
```

클릭하면 항목별 사용률 막대와 초기화 시간이 나옵니다. 내용이 길면 스크롤되고, 설정·새로고침·종료 버튼은 아래에 고정됩니다.

## 특징

- **숫자가 상단 바에 바로 보입니다.** 아이콘을 눌러 패널을 열 필요가 없습니다.
- **인증 정보를 읽지 않습니다.** 키체인, 브라우저 쿠키, `~/.claude`의 인증 파일, 대화 로그 어디에도 접근하지 않습니다. 공식 `claude` CLI를 실행해 `/usage` 화면을 읽을 뿐입니다.
- **앱이 직접 네트워크를 쓰지 않습니다.** 서버와 통신하는 것은 Claude Code CLI이고, 앱에는 네트워크 코드나 자동 업데이트가 없습니다.
- **화면 갱신까지 반영해 읽습니다.** `/usage`는 캐시 값을 먼저 그린 뒤 바뀐 숫자만 덮어씁니다. Noonchi는 출력을 가상 터미널 화면에 다시 그려 최종 값을 읽습니다. 실측 30회 중 23회에서 이전 방식(출력 문자열만 읽기)이 갱신 전 값을 읽었고, 지금 방식은 30회 모두 Claude Code 화면과 일치했습니다.
- **작습니다.** 앱 코드는 Swift 약 1,200줄이고, 앱 메모리는 약 24MB입니다(1시간 측정, 증가 없음).

측정 방법과 원자료: [`docs/benchmark.md`](docs/benchmark.md)

알아둘 점:
- 조회할 때마다 Claude Code를 한 번 실행하므로 CPU를 1회 약 3.5초 씁니다(5분 간격이면 1시간에 약 40초).
- Claude Code가 Noonchi 작업 폴더(`~/Library/Application Support/Noonchi`)를 `~/.claude.json`의 프로젝트 목록에 기록합니다. Noonchi가 직접 쓰는 것은 아닙니다.
- 자동 업데이트가 없습니다. Claude Code 화면 형식이 바뀌면 직접 업데이트해야 합니다.

## 설정

패널 아래 톱니바퀴 버튼을 누르면 설정 창이 열립니다. 설정은 자동 저장됩니다.

| 항목 | 옵션 |
|---|---|
| 언어 | 한국어 / English (기본값은 시스템 언어) |
| 상단 바 표시 | 5시간 세션, 주간(전체 모델), 모델별 주간 한도(예: Fable)를 원하는 대로 조합. 아무것도 고르지 않으면 `CC`만 표시 |
| 표시 형식 | 라벨 포함 `5h 42% · 7d 10% · Fable 2%` / 숫자만 `42% · 10% · 2%` |
| 막대 색상 | 사용률에 따라 자동(70% 주황, 90% 빨강) 또는 단색(프리셋 7가지 + 직접 선택). 단색일 때 90% 이상 빨간색 경고는 켜고 끌 수 있음 |

## 동작 방식

- 5분마다(그리고 잠자기에서 깨어날 때) 백그라운드에서 `claude`를 가상 터미널(PTY)로 실행해 `/usage`를 보내고, 갱신이 끝난 화면을 읽은 뒤 바로 종료합니다.
- 조회에 실패하면 마지막으로 읽은 값을 그대로 두고 오류만 표시합니다.
- 모델을 호출하지 않으므로 **토큰을 쓰지 않습니다.**
- 키체인이나 Anthropic API를 직접 건드리지 않고, Claude Code가 보여주는 값을 그대로 씁니다.
- Claude Code 작업 폴더는 `~/Library/Application Support/Noonchi`를 사용합니다.

## 요구 사항

- macOS 14 이상, Apple Silicon(arm64)
- Claude Code 설치 및 로그인 (Pro/Max 구독)
- 빌드 시 Xcode 또는 Command Line Tools (Swift 5.9+)

`claude` 위치는 `~/.local/bin`, `~/.claude/local`, `/opt/homebrew/bin`, `/usr/local/bin` 순서로 찾습니다. 다른 곳에 있다면 `NOONCHI_CLAUDE_PATH` 환경 변수로 지정하세요.

## 설치

```bash
git clone https://github.com/Ja-efan/Noonchi.git
cd Noonchi
make install      # 빌드 → ~/Applications 설치 → 실행
```

로그인 시 자동 실행: 시스템 설정 > 일반 > 로그인 항목에 `Noonchi` 추가.

## 개발

| 명령 | 설명 |
|---|---|
| `make build` | 디버그 빌드 |
| `make test` | 파서 단위 테스트 |
| `make app` | `dist/Noonchi.app` 및 zip 생성 |
| `make run` | 앱 빌드 후 실행 |
| `make clean` | 빌드 결과 삭제 |

Xcode에서 열려면 `open Package.swift`.

### 구조

```
Sources/
  UsageCore/            UI 없는 핵심 로직 (테스트 대상)
    ClaudeRunner.swift    PTY로 claude 실행 및 /usage 캡처
    TerminalScreen.swift  PTY 출력을 가상 화면에 재현 (부분 갱신 반영)
    TerminalText.swift    ANSI 이스케이프 제거 (화면 재현 실패 시 대체 경로)
    UsageParser.swift     사용률·초기화 시간 파싱
    UsageSnapshot.swift   모델, 에러 정의
  Noonchi/              SwiftUI 메뉴 막대 앱 (패널, 설정 창, 다국어 문구)
Tests/UsageCoreTests/   파서 테스트와 /usage 출력 샘플(Fixtures)
Resources/Info.plist    앱 번들 정보 (버전은 빌드 시 주입)
scripts/                앱 번들 빌드·설치 스크립트
```

### Claude Code 출력이 바뀌었을 때

1. 패널의 "원본 출력 보기"를 눌러 별도 창에서 내용을 복사합니다.
2. `Tests/UsageCoreTests/Fixtures/`에 새 샘플로 저장하고 테스트를 추가합니다.
3. `UsageParser.swift`를 고쳐 테스트를 통과시킵니다.

## 릴리스

`VERSION`을 올리고 태그를 푸시하면 GitHub Actions가 테스트, 빌드 후 zip을 Release에 올립니다.

```bash
git tag v0.1.0 && git push origin v0.1.0
```

배포된 앱은 ad-hoc 서명이라 처음 실행 시 우클릭 > 열기가 필요할 수 있습니다.

## 라이선스

MIT
