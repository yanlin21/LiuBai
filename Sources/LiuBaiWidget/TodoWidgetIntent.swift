import AppIntents
import WidgetKit

struct TodoGroupEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "清单")
    static var defaultQuery = TodoGroupEntityQuery()

    let id: UUID
    let title: String
    let colorKey: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)")
    }

    init(group: TodoGroup) {
        id = group.id
        title = group.title
        colorKey = group.colorKey
    }

    init(requestedID: UUID, fallback group: TodoGroup) {
        id = requestedID
        title = group.title
        colorKey = group.colorKey
    }
}

struct TodoGroupEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [TodoGroupEntity] {
        let groups = SharedTodoRepository.allGroups()
        guard let fallback = groups.first else { return [] }

        return identifiers.map { identifier in
            if let group = groups.first(where: { $0.id == identifier }) {
                return TodoGroupEntity(group: group)
            }
            // WidgetKit may keep an old AppEntity identifier after its list was
            // deleted or migrated. Resolve that identifier to a live group so
            // the widget can render and its configuration can be edited again.
            return TodoGroupEntity(requestedID: identifier, fallback: fallback)
        }
    }

    func suggestedEntities() async throws -> [TodoGroupEntity] {
        SharedTodoRepository.allGroups().map(TodoGroupEntity.init)
    }

    func defaultResult() async -> TodoGroupEntity? {
        SharedTodoRepository.allGroups().first.map(TodoGroupEntity.init)
    }
}

struct SelectTodoGroupIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "选择清单"
    static var description = IntentDescription("选择要显示在桌面组件中的清单标签。")

    @Parameter(title: "清单")
    var group: TodoGroupEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("显示 \(\.$group)")
    }
}

struct ToggleTodoWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "完成待办"
    static var description = IntentDescription("切换一条留白待办的完成状态。")

    @Parameter(title: "清单 ID")
    var groupID: String

    @Parameter(title: "待办 ID")
    var todoID: String

    init() {
        groupID = ""
        todoID = ""
    }

    init(groupID: UUID, todoID: UUID) {
        self.groupID = groupID.uuidString
        self.todoID = todoID.uuidString
    }

    func perform() async throws -> some IntentResult {
        guard let groupUUID = UUID(uuidString: groupID),
              let todoUUID = UUID(uuidString: todoID) else { return .result() }
        try SharedTodoRepository.toggleTodo(groupID: groupUUID, todoID: todoUUID)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct MoveTodoWidgetItemsIntent: AppIntent {
    static var title: LocalizedStringResource = "滚动清单"
    static var description = IntentDescription("在桌面小组件中向上或向下移动一行待办。")
    static var openAppWhenRun = false

    @Parameter(title: "清单 ID")
    var groupID: String

    @Parameter(title: "方向")
    var direction: Int

    init() {
        groupID = ""
        direction = 0
    }

    init(groupID: UUID, direction: Int) {
        self.groupID = groupID.uuidString
        self.direction = direction
    }

    func perform() async throws -> some IntentResult {
        guard let groupUUID = UUID(uuidString: groupID), direction != 0 else { return .result() }
        SharedTodoRepository.moveWidgetItems(groupID: groupUUID, by: direction > 0 ? 1 : -1)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
