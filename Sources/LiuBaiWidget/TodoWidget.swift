import AppIntents
import SwiftUI
import WidgetKit

struct TodoWidgetEntry: TimelineEntry {
    let date: Date
    let group: TodoGroup?
    let configuration: SelectTodoGroupIntent
}

struct TodoWidgetProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TodoWidgetEntry {
        TodoWidgetEntry(date: Date(), group: .widgetPreview, configuration: SelectTodoGroupIntent())
    }

    func snapshot(for configuration: SelectTodoGroupIntent, in context: Context) async -> TodoWidgetEntry {
        entry(for: configuration, preview: context.isPreview)
    }

    func timeline(for configuration: SelectTodoGroupIntent, in context: Context) async -> Timeline<TodoWidgetEntry> {
        let entry = entry(for: configuration, preview: false)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60)))
    }

    private func entry(for configuration: SelectTodoGroupIntent, preview: Bool) -> TodoWidgetEntry {
        let group = preview
            ? TodoGroup.widgetPreview
            : SharedTodoRepository.group(id: configuration.group?.id)
        return TodoWidgetEntry(date: Date(), group: group, configuration: configuration)
    }
}

struct LiuBaiTodoWidget: Widget {
    static let kind = "com.liubai.writer.todo-widget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: Self.kind,
            intent: SelectTodoGroupIntent.self,
            provider: TodoWidgetProvider()
        ) { entry in
            TodoWidgetView(entry: entry)
        }
        .configurationDisplayName("留白清单")
        .description("选择一张清单，将它固定在桌面。")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

private struct TodoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.redactionReasons) private var redactionReasons
    let entry: TodoWidgetEntry

    var body: some View {
        Group {
            if redactionReasons.contains(.placeholder) {
                loadingState
                    .unredacted()
                    .containerBackground(for: .widget) {
                        LinearGradient(
                            colors: [Color.white.opacity(0.13), Color.white.opacity(0.035)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
            } else if let group = entry.group {
                content(group)
                    .widgetURL(URL(string: "liubai://todo/\(group.id.uuidString)"))
                    .containerBackground(for: .widget) {
                        background(for: group)
                    }
            } else {
                emptyState
                    .containerBackground(for: .widget) {
                        Color.black.opacity(0.12)
                    }
            }
        }
    }

    private func content(_ group: TodoGroup) -> some View {
        let maximumOffset = max(0, group.items.count - itemLimit)
        let offset = min(SharedTodoRepository.widgetItemOffset(groupID: group.id), maximumOffset)
        let visibleItems = Array(group.items.dropFirst(offset).prefix(itemLimit))

        return VStack(alignment: .leading, spacing: family == .systemSmall ? 10 : 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(group.title.isEmpty ? "未命名清单" : group.title)
                    .font(.system(size: family == .systemSmall ? 15 : 17, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Text("\(group.items.filter { !$0.isDone }.count)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if group.items.isEmpty {
                Spacer()
                Text("清单还是空的")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: rowSpacing) {
                        ForEach(visibleItems) { todo in
                            todoRow(group: group, todo: todo)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if maximumOffset > 0 {
                        itemNavigator(group: group, offset: offset, maximumOffset: maximumOffset)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, family == .systemSmall ? 14 : 18)
        .padding(.vertical, family == .systemSmall ? 13 : 16)
    }

    private func itemNavigator(group: TodoGroup, offset: Int, maximumOffset: Int) -> some View {
        VStack(spacing: 6) {
            Button(intent: MoveTodoWidgetItemsIntent(groupID: group.id, direction: -1)) {
                Image(systemName: "chevron.up")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .disabled(offset == 0)
            .opacity(offset == 0 ? 0.28 : 0.78)

            Text("\(offset + 1)/\(maximumOffset + 1)")
                .font(.system(size: 8, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Button(intent: MoveTodoWidgetItemsIntent(groupID: group.id, direction: 1)) {
                Image(systemName: "chevron.down")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .disabled(offset == maximumOffset)
            .opacity(offset == maximumOffset ? 0.28 : 0.78)
        }
        .font(.system(size: 9, weight: .semibold))
        .opacity(0.72)
    }

    private func todoRow(group: TodoGroup, todo: TodoItem) -> some View {
        HStack(spacing: 7) {
            Button(intent: ToggleTodoWidgetIntent(groupID: group.id, todoID: todo.id)) {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13, weight: .medium))
            }
            .buttonStyle(.plain)
            .tint(.primary)

            Text(todo.title.isEmpty ? "未命名待办" : todo.title)
                .font(.system(size: 12.5))
                .lineLimit(1)
                .strikethrough(todo.isDone)
                .foregroundStyle(todo.isDone ? .secondary : .primary)
                .invalidatableContent()
        }
    }

    private var itemLimit: Int {
        switch family {
        case .systemSmall: 3
        case .systemMedium: 4
        case .systemLarge: 9
        default: 4
        }
    }

    private var rowSpacing: CGFloat {
        switch family {
        case .systemSmall: 9
        case .systemMedium: 12
        case .systemLarge: 11
        default: 12
        }
    }

    private func background(for group: TodoGroup) -> some View {
        let color = TodoPalette.color(for: group.colorKey)
        return LinearGradient(
            colors: [color.opacity(0.46), color.opacity(0.18)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.system(size: 24, weight: .light))
            Text("打开留白，新建一张清单")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .padding()
    }

    private var loadingState: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("留白")
                    .font(.system(size: family == .systemSmall ? 15 : 17, weight: .semibold))
                Spacer()
                Circle()
                    .fill(.secondary.opacity(0.45))
                    .frame(width: 6, height: 6)
            }
            Spacer()
            Text("正在载入清单…")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, family == .systemSmall ? 14 : 18)
        .padding(.vertical, family == .systemSmall ? 13 : 16)
    }
}

private extension TodoGroup {
    static let widgetPreview = TodoGroup(
        title: "论文",
        items: [
            TodoItem(title: "修改摘要", details: ""),
            TodoItem(title: "补充参考文献", details: ""),
            TodoItem(title: "重画图 3", details: "", isDone: true)
        ],
        colorKey: "sky"
    )
}
