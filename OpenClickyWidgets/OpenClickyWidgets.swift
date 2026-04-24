import SwiftUI
import WidgetKit

struct OpenClickyWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: OpenClickyWidgetSnapshot
}

struct OpenClickyWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> OpenClickyWidgetEntry {
        OpenClickyWidgetEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (OpenClickyWidgetEntry) -> Void) {
        completion(OpenClickyWidgetEntry(date: Date(), snapshot: OpenClickyWidgetSnapshotReader.readSnapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OpenClickyWidgetEntry>) -> Void) {
        let entry = OpenClickyWidgetEntry(date: Date(), snapshot: OpenClickyWidgetSnapshotReader.readSnapshot())
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

@main
struct OpenClickyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        OpenClickyActiveAgentsWidget()
        OpenClickyTodayStatsWidget()
        OpenClickyNeedsAttentionWidget()
    }
}

struct OpenClickyActiveAgentsWidget: Widget {
    let kind = "OpenClickyActiveAgentsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OpenClickyWidgetProvider()) { entry in
            OpenClickyWidgetContainer(title: "Active Agents", deepLink: OpenClickyWidgetDeepLink.agents) {
                OpenClickyActiveAgentsWidgetView(snapshot: entry.snapshot)
            }
        }
        .configurationDisplayName("OpenClicky Agents")
        .description("Shows active OpenClicky agent tasks and statuses.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct OpenClickyTodayStatsWidget: Widget {
    let kind = "OpenClickyTodayStatsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OpenClickyWidgetProvider()) { entry in
            OpenClickyWidgetContainer(title: "Today", deepLink: OpenClickyWidgetDeepLink.agents) {
                OpenClickyTodayStatsWidgetView(stats: entry.snapshot.todayStats)
            }
        }
        .configurationDisplayName("OpenClicky Today")
        .description("Shows today's OpenClicky voice and agent stats.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct OpenClickyNeedsAttentionWidget: Widget {
    let kind = "OpenClickyNeedsAttentionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: OpenClickyWidgetProvider()) { entry in
            OpenClickyWidgetContainer(title: "Needs Attention", deepLink: OpenClickyWidgetDeepLink.logs) {
                OpenClickyNeedsAttentionWidgetView(snapshot: entry.snapshot)
            }
        }
        .configurationDisplayName("OpenClicky Attention")
        .description("Shows failed agents, permissions, and flagged logs.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct OpenClickyWidgetContainer<Content: View>: View {
    let title: String
    let deepLink: URL
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Circle()
                    .fill(Color.green)
                    .frame(width: 7, height: 7)
            }

            content

            Spacer(minLength: 0)
        }
        .padding(14)
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.07, blue: 0.07),
                    Color(red: 0.09, green: 0.11, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .widgetURL(deepLink)
    }
}

private struct OpenClickyActiveAgentsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: OpenClickyWidgetSnapshot

    var body: some View {
        if snapshot.activeAgents.isEmpty {
            EmptyWidgetMessage(text: "No active agents")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(snapshot.activeAgents.prefix(maxRows))) { agent in
                    Link(destination: URL(string: "openclicky://agent/\(agent.id.uuidString)") ?? OpenClickyWidgetDeepLink.agents) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                statusDot(for: agent.status)
                                Text(agent.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .lineLimit(1)
                            }
                            if family != .systemSmall, let caption = agent.caption {
                                Text(caption)
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    private var maxRows: Int {
        switch family {
        case .systemSmall:
            return 2
        case .systemMedium:
            return 3
        default:
            return 5
        }
    }

    private func statusDot(for status: String) -> some View {
        Circle()
            .fill(statusColor(for: status))
            .frame(width: 7, height: 7)
    }

    private func statusColor(for status: String) -> Color {
        switch status {
        case "Done":
            return .green
        case "Needs attention":
            return .red
        case "Running":
            return .cyan
        default:
            return .yellow
        }
    }
}

private struct OpenClickyTodayStatsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let stats: OpenClickyWidgetTodayStats

    var body: some View {
        if family == .systemSmall {
            VStack(alignment: .leading, spacing: 8) {
                statLine(value: stats.agentTasksCreated, label: "Agents")
                statLine(value: stats.voiceInteractions, label: "Voice")
                statLine(value: stats.agentFailures + stats.logReviewComments, label: "Review")
            }
        } else {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 10) {
                statTile(value: stats.agentTasksCreated, label: "Agent tasks")
                statTile(value: stats.agentCompletions, label: "Completed")
                statTile(value: stats.voiceInteractions, label: "Voice")
                statTile(value: stats.agentFailures + stats.logReviewComments, label: "Needs review")
            }
        }
    }

    private func statLine(value: Int, label: String) -> some View {
        HStack {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private func statTile(value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("\(value)")
                .font(.system(size: 22, weight: .bold))
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct OpenClickyNeedsAttentionWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let snapshot: OpenClickyWidgetSnapshot

    var body: some View {
        if snapshot.needsAttention.isEmpty {
            EmptyWidgetMessage(text: "Nothing needs attention")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(snapshot.needsAttention.prefix(maxRows))) { item in
                    Link(destination: item.deepLink ?? OpenClickyWidgetDeepLink.logs) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                                .font(.system(size: 12, weight: .semibold))
                                .lineLimit(1)
                            if family != .systemSmall, let detail = item.detail {
                                Text(detail)
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    private var maxRows: Int {
        family == .systemLarge ? 5 : 3
    }
}

private struct EmptyWidgetMessage: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
            Text("Open OpenClicky to update this widget.")
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}
