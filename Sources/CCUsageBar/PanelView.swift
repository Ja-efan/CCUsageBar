import SwiftUI
import UsageCore

struct UsageRow: View {
    let title: String
    let percent: Int?
    let reset: String?

    private var color: Color {
        guard let p = percent else { return .gray }
        return p >= 90 ? .red : (p >= 70 ? .orange : .green)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Text(percent.map { "\($0)%" } ?? "–")
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(color)
            }
            ProgressView(value: Double(percent ?? 0), total: 100).tint(color)
            if let reset {
                Text("초기화: \(reset)").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct PanelView: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Claude Code 사용량").font(.title3.bold())
            UsageRow(title: "5시간 세션", percent: store.snapshot.sessionPercent, reset: store.snapshot.sessionReset)
            UsageRow(title: "주간 (전체 모델)", percent: store.snapshot.weekPercent, reset: store.snapshot.weekReset)

            if let e = store.snapshot.error {
                Label(e.message, systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }

            Divider()

            HStack {
                if store.isLoading {
                    ProgressView().controlSize(.small)
                    Text("불러오는 중…").font(.caption)
                } else if store.hasLoaded {
                    Text("업데이트: \(store.snapshot.updatedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("새로고침") { store.refresh() }.disabled(store.isLoading)
            }

            DisclosureGroup("원본 출력 (디버그)", isExpanded: $store.showRaw) {
                ScrollView {
                    Text(store.snapshot.raw)
                        .font(.system(size: 10, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 220)
            }
            .font(.caption)

            HStack {
                Button("원본 복사") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(store.snapshot.raw, forType: .string)
                }
                .disabled(store.snapshot.raw.isEmpty)
                Spacer()
                Button("종료") { NSApp.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}
