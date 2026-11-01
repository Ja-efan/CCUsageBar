# CC Usage Bar

Claude Code의 **5시간 세션 사용률**과 **주간 사용률**을 macOS 메뉴 막대에 표시하는 앱입니다.

```
5h 42% · 7d 18%
```

클릭하면 사용률 막대, 초기화 시간, 새로고침 버튼이 나옵니다. 70% 이상은 주황, 90% 이상은 빨강으로 표시됩니다.

## 동작 방식

- 5분마다 백그라운드에서 `claude`를 가상 터미널(PTY)로 실행해 `/usage`를 보내고, 출력을 읽은 뒤 바로 종료합니다.
- 모델을 호출하지 않으므로 **토큰을 쓰지 않습니다.**
- 키체인이나 Anthropic API를 직접 건드리지 않고, Claude Code가 보여주는 값을 그대로 씁니다.
- Claude Code 작업 폴더는 `~/Library/Application Support/CCUsageBar`를 사용합니다.

## 요구 사항

- macOS 14 이상
- Claude Code 설치 및 로그인 (Pro/Max 구독)
- 빌드 시 Xcode 또는 Command Line Tools (Swift 5.9+)

`claude` 위치는 `~/.local/bin`, `~/.claude/local`, `/opt/homebrew/bin`, `/usr/local/bin` 순서로 찾습니다. 다른 곳에 있다면 `CCUSAGEBAR_CLAUDE_PATH` 환경 변수로 지정하세요.

## 설치

```bash
git clone https://github.com/<you>/CCUsageBar.git
cd CCUsageBar
make install      # 빌드 → ~/Applications 설치 → 실행
```

로그인 시 자동 실행: 시스템 설정 > 일반 > 로그인 항목에 `CCUsageBar` 추가.

## 개발

| 명령 | 설명 |
|---|---|
| `make build` | 디버그 빌드 |
| `make test` | 파서 단위 테스트 |
| `make app` | `dist/CCUsageBar.app` 및 zip 생성 |
| `make run` | 앱 빌드 후 실행 |
| `make clean` | 빌드 결과 삭제 |

Xcode에서 열려면 `open Package.swift`.

### 구조

```
Sources/
  UsageCore/            UI 없는 핵심 로직 (테스트 대상)
    ClaudeRunner.swift    PTY로 claude 실행 및 /usage 캡처
    TerminalText.swift    ANSI 이스케이프 제거
    UsageParser.swift     사용률·초기화 시간 파싱
    UsageSnapshot.swift   모델, 에러 정의
  CCUsageBar/           SwiftUI 메뉴 막대 앱
Tests/UsageCoreTests/   파서 테스트와 /usage 출력 샘플(Fixtures)
Resources/Info.plist    앱 번들 정보 (버전은 빌드 시 주입)
scripts/                앱 번들 빌드·설치 스크립트
```

### Claude Code 출력이 바뀌었을 때

1. 패널의 "원본 출력 (디버그)" 내용을 복사합니다.
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
