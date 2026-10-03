import Foundation

enum SharedTodoRepository {
    static func loadNovels() -> [Novel] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: SharedDataLocation.libraryURL()),
              let novels = try? decoder.decode([Novel].self, from: data) else { return [] }
        return novels
    }

    static func allGroups() -> [TodoGroup] {
        loadNovels().flatMap(\.todoGroups)
    }

    static func group(id: UUID?) -> TodoGroup? {
        let groups = allGroups()
        guard let id else { return groups.first }
        return groups.first { $0.id == id } ?? groups.first
    }

    static func toggleTodo(groupID: UUID, todoID: UUID) throws {
        var novels = loadNovels()
        guard let novelIndex = novels.firstIndex(where: { novel in
            novel.todoGroups.contains(where: { $0.id == groupID })
        }),
        let groupIndex = novels[novelIndex].todoGroups.firstIndex(where: { $0.id == groupID }),
        let todoIndex = novels[novelIndex].todoGroups[groupIndex].items.firstIndex(where: { $0.id == todoID }) else {
            return
        }

        novels[novelIndex].todoGroups[groupIndex].items[todoIndex].isDone.toggle()
        novels[novelIndex].todoGroups[groupIndex].items[todoIndex].updatedAt = Date()
        novels[novelIndex].todoGroups[groupIndex].updatedAt = Date()

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(novels)
        try data.write(to: SharedDataLocation.libraryURL(), options: .atomic)
    }
}
