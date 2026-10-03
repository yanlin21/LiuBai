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
    let entry: TodoWidgetEntry

    var body: some View {
        Group {
            if let group = entry.group {
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
        VStack(alignment: .leading, spacing: family == .systemSmall ? 8 : 10) {
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
                VStack(alignment: .leading, spacing: family == .systemSmall ? 7 : 9) {
                    ForEach(Array(group.items.prefix(itemLimit))) { todo in
                        todoRow(group: group, todo: todo)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(family == .systemSmall ? 13 : 16)
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
        case .systemSmall: 4
        case .systemMedium: 6
        case .systemLarge: 12
        default: 5
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
