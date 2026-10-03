import Foundation

struct Novel: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var chapters: [Chapter]
    var todoGroups: [TodoGroup] = []

    init(id: UUID = UUID(), title: String, chapters: [Chapter], todoGroups: [TodoGroup] = []) {
        self.id = id
        self.title = title
        self.chapters = chapters
        self.todoGroups = todoGroups
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, chapters, todoGroups, todos
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        chapters = try container.decode([Chapter].self, forKey: .chapters)
        if let groups = try container.decodeIfPresent([TodoGroup].self, forKey: .todoGroups) {
            todoGroups = groups
        } else if let legacyTodos = try container.decodeIfPresent([TodoItem].self, forKey: .todos), !legacyTodos.isEmpty {
            todoGroups = [TodoGroup(title: "待办", items: legacyTodos)]
        } else {
            todoGroups = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(chapters, forKey: .chapters)
        try container.encode(todoGroups, forKey: .todoGroups)
    }
}

struct TodoGroup: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var items: [TodoItem] = []
    var colorKey: String = "mango"
    var createdAt = Date()
    var updatedAt = Date()

    static let paletteKeys = ["coral", "mango", "lemon", "mint", "aqua", "sky", "lavender", "berry"]

    init(
        id: UUID = UUID(),
        title: String,
        items: [TodoItem] = [],
        colorKey: String = "mango",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.items = items
        self.colorKey = colorKey
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, items, colorKey, createdAt, updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try container.decode(String.self, forKey: .title)
        items = try container.decodeIfPresent([TodoItem].self, forKey: .items) ?? []
        colorKey = try container.decodeIfPresent(String.self, forKey: .colorKey) ?? "mango"
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}

struct TodoItem: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var details: String
    var isDone = false
    var createdAt = Date()
    var updatedAt = Date()
}

struct Chapter: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var text: String
    var createdAt = Date()
    var updatedAt = Date()
    var snapshots: [ChapterSnapshot] = []
}

struct ChapterSnapshot: Codable, Identifiable, Equatable {
    var id = UUID()
    var createdAt = Date()
    var text: String
    var label: String?
}

extension Novel {
    static let welcome = Novel(
        title: "未完的故事",
        chapters: [
            Chapter(
                title: "第一章  雨夜",
                text: "雨从傍晚开始下，一直没有停。\n\n林默站在便利店门口，看着街对面那扇已经熄灯的窗户。玻璃上的倒影很淡，像另一个迟迟没有离开的人。\n\n他把信重新折好，放回大衣口袋。",
                snapshots: [
                    ChapterSnapshot(
                        createdAt: Date().addingTimeInterval(-3600),
                        text: "雨从傍晚开始下，一直没有停。\n\n林默站在便利店门口，看着街对面那扇已经熄灯的窗户。",
                        label: "开始写作"
                    )
                ]
            ),
            Chapter(title: "第二章", text: "")
        ],
        todoGroups: [
            TodoGroup(title: "小说", items: [
                TodoItem(title: "补充林默的来信动机", details: ""),
                TodoItem(title: "检查雨夜时间线", details: "")
            ], colorKey: "coral"),
            TodoGroup(title: "论文", items: [
                TodoItem(title: "修改摘要", details: ""),
                TodoItem(title: "补充参考文献", details: "")
            ], colorKey: "sky")
        ]
    )
}
