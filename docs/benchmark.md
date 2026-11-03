# 측정 기록 (2026-11-03)

README "특징" 섹션의 근거다. 환경: Apple Silicon MacBook Pro, macOS 26, Claude Code 2.1.310, Noonchi 기본 설정(5분 간격).

## 자원 사용 (60분)

방법: [`scripts/bench/sample_process_tree.py`](../scripts/bench/sample_process_tree.py)로 1초마다 앱과 그 하위 프로세스 전체의 누적 CPU 시간과 메모리를 기록했다. 1초보다 짧게 사는 하위 프로세스는 빠질 수 있다. 메모리는 `footprint` 값(Activity Monitor의 "메모리"와 같은 기준)이다.

```
python3 scripts/bench/sample_process_tree.py Noonchi 3600 result.json
```

| 항목 | 값 |
|---|---|
| 조회 횟수 | 약 12회 (`claude` 실행) |
| 앱 CPU | 2.2초 |
| 하위 프로세스 CPU (`claude`와 그 자식) | 39.5초 |
| CPU 합계 | 41.7초 / 시간 (조회 1회당 약 3.5초) |
| 앱 메모리 시작 → 끝 | 23MB → 24MB |
| 앱 RSS 최대 | 48.5MB |

CPU 대부분은 조회 때마다 실행하는 Claude Code가 쓴다. 조회 간격을 늘리면 그만큼 줄어든다.

## 정확성 (30회)

방법: 2분마다 실제 `claude`의 `/usage`를 캡처해, 같은 원본을 (a) 이전 방식(ANSI를 지우고 문자열에서 숫자 찾기)과 (b) 지금 방식(가상 터미널 화면에 다시 그린 뒤 읽기)으로 읽었다.

| | 결과 |
|---|---|
| 이전 방식이 화면과 다른 값을 읽은 횟수 | 30회 중 23회 (77%). 모두 갱신 전 캐시 값(1%p 낮음) |
| 지금 방식이 Claude Code 최종 화면과 일치한 횟수 | 30회 중 30회 |

- `/usage`는 캐시 값을 먼저 그리고 "Refreshing…"을 띄운 뒤, 새 값이 오면 바뀐 숫자 칸만 덮어쓴다. 이전 방식은 덮어쓰기 전 숫자를 읽었다.
- 기준은 Claude Code 화면이다. claude.ai 웹 값과 같은 시각에 대조하지는 않았다.
- 5회는 Claude Code가 "Per-model breakdown unavailable (rate limited)"를 표시해 모델별(Fable) 줄이 없었다. 측정 때문에 평소보다 자주 조회한 영향으로 보인다.
- 원본 캡처에는 개인 사용 통계가 들어 있어 저장소에 넣지 않았다.
