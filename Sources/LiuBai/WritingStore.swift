import Combine
import Foundation
import WidgetKit

@MainActor
final class WritingStore: ObservableObject {
    @Published private(set) var novels: [Novel] = []
    @Published var selectedNovelID: UUID?
    @Published var selectedChapterID: UUID?
    @Published var saveState: SaveState = .saved

    enum SaveState: Equatable {
        case saving
        case saved
    }

    private var saveTask: Task<Void, Never>?
    private let fileURL: URL

    init() {
        SharedDataLocation.migrateLegacyLibraryIfNeeded()
        fileURL = SharedDataLocation.libraryURL()
        load()
    }

    var selectedNovel: Novel? {
        guard let selectedNovelID else { return nil }
        return novels.first { $0.id == selectedNovelID }
    }

    var selectedChapter: Chapter? {
        guard let selectedNovelID, let selectedChapterID,
              let novel = novels.first(where: { $0.id == selectedNovelID }) else { return nil }
        return novel.chapters.first { $0.id == selectedChapterID }
    }

    var currentTodoGroups: [TodoGroup] {
        selectedNovel?.todoGroups ?? []
    }

    func selectChapter(_ id: UUID) {
        selectedChapterID = id
    }

    func updateNovelTitle(_ title: String) {
        guard let index = selectedNovelIndex else { return }
        novels[index].title = title
        scheduleSave()
    }

    func updateChapterTitle(_ title: String) {
        guard let indices = selectedIndices else { return }
        novels[indices.novel].chapters[indices.chapter].title = title
        novels[indices.novel].chapters[indices.chapter].updatedAt = Date()
        scheduleSave()
    }

    func updateChapterText(_ text: String) {
        guard let indices = selectedIndices,
              novels[indices.novel].chapters[indices.chapter].text != text else { return }
        novels[indices.novel].chapters[indices.chapter].text = text
        novels[indices.novel].chapters[indices.chapter].updatedAt = Date()
        scheduleSave()
    }

    func addChapter() {
        guard let novelIndex = selectedNovelIndex else { return }
        let next = novels[novelIndex].chapters.count + 1
        let chapter = Chapter(title: "第\(chineseNumber(next))章", text: "")
        novels[novelIndex].chapters.append(chapter)
        selectedChapterID = chapter.id
        scheduleSave(immediately: true)
    }

    func deleteChapter(_ id: UUID) {
        guard let novelIndex = selectedNovelIndex,
              novels[novelIndex].chapters.count > 1,
              let chapterIndex = novels[novelIndex].chapters.firstIndex(where: { $0.id == id }) else { return }
        novels[novelIndex].chapters.remove(at: chapterIndex)
        if selectedChapterID == id {
            selectedChapterID = novels[novelIndex].chapters[min(chapterIndex, novels[novelIndex].chapters.count - 1)].id
        }
        scheduleSave(immediately: true)
    }

    func createSnapshot(label: String? = nil) {
        guard let indices = selectedIndices else { return }
        let chapter = novels[indices.novel].chapters[indices.chapter]
        guard !chapter.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if chapter.snapshots.first?.text == chapter.text { return }
        let snapshot = ChapterSnapshot(text: chapter.text, label: label)
        novels[indices.novel].chapters[indices.chapter].snapshots.insert(snapshot, at: 0)
        if novels[indices.novel].chapters[indices.chapter].snapshots.count > 60 {
            novels[indices.novel].chapters[indices.chapter].snapshots.removeLast()
        }
        scheduleSave(immediately: true)
    }

    func restore(_ snapshot: ChapterSnapshot) {
        guard let indices = selectedIndices else { return }
        let current = novels[indices.novel].chapters[indices.chapter].text
        if !current.isEmpty, current != snapshot.text {
            novels[indices.novel].chapters[indices.chapter].snapshots.insert(
                ChapterSnapshot(text: current, label: "恢复前自动备份"), at: 0
            )
        }
        novels[indices.novel].chapters[indices.chapter].text = snapshot.text
        novels[indices.novel].chapters[indices.chapter].updatedAt = Date()
        scheduleSave(immediately: true)
    }

    @discardableResult
    func addTodoGroup() -> UUID? {
        guard let novelIndex = selectedNovelIndex else { return nil }
        let colorIndex = novels[novelIndex].todoGroups.count % TodoGroup.paletteKeys.count
        let group = TodoGroup(
            title: "新清单",
            items: [TodoItem(title: "新待办", details: "")],
            colorKey: TodoGroup.paletteKeys[colorIndex]
        )
        novels[novelIndex].todoGroups.append(group)
        scheduleSave(immediately: true)
        return group.id
    }

    func updateTodoGroupTitle(_ id: UUID, title: String) {
        guard let indices = todoGroupIndices(id) else { return }
        novels[indices.novel].todoGroups[indices.group].title = title
        novels[indices.novel].todoGroups[indices.group].updatedAt = Date()
        scheduleSave()
    }

    func updateTodoGroupColor(_ id: UUID, colorKey: String) {
        guard let indices = todoGroupIndices(id) else { return }
        novels[indices.novel].todoGroups[indices.group].colorKey = colorKey
        novels[indices.novel].todoGroups[indices.group].updatedAt = Date()
        scheduleSave(immediately: true)
    }

    @discardableResult
    func addTodo(to groupID: UUID) -> UUID? {
        guard let indices = todoGroupIndices(groupID) else { return nil }
        let todo = TodoItem(title: "新待办", details: "")
        novels[indices.novel].todoGroups[indices.group].items.append(todo)
        novels[indices.novel].todoGroups[indices.group].updatedAt = Date()
        scheduleSave(immediately: true)
        return todo.id
    }

    func updateTodoTitle(groupID: UUID, todoID: UUID, title: String) {
        guard let indices = todoIndices(groupID: groupID, todoID: todoID) else { return }
        novels[indices.novel].todoGroups[indices.group].items[indices.todo].title = title
        novels[indices.novel].todoGroups[indices.group].items[indices.todo].updatedAt = Date()
        novels[indices.novel].todoGroups[indices.group].updatedAt = Date()
        scheduleSave()
    }

    func toggleTodo(groupID: UUID, todoID: UUID) {
        guard let indices = todoIndices(groupID: groupID, todoID: todoID) else { return }
        novels[indices.novel].todoGroups[indices.group].items[indices.todo].isDone.toggle()
        novels[indices.novel].todoGroups[indices.group].items[indices.todo].updatedAt = Date()
        novels[indices.novel].todoGroups[indices.group].updatedAt = Date()
        scheduleSave(immediately: true)
    }

    func deleteTodo(groupID: UUID, todoID: UUID) {
        guard let indices = todoIndices(groupID: groupID, todoID: todoID) else { return }
        novels[indices.novel].todoGroups[indices.group].items.remove(at: indices.todo)
        novels[indices.novel].todoGroups[indices.group].updatedAt = Date()
        scheduleSave(immediately: true)
    }

    func deleteTodoGroup(_ id: UUID) {
        guard let indices = todoGroupIndices(id) else { return }
        novels[indices.novel].todoGroups.remove(at: indices.group)
        scheduleSave(immediately: true)
    }

    func flush() {
        saveTask?.cancel()
        saveNow()
    }

    func reloadFromDisk() {
        saveTask?.cancel()

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([Novel].self, from: data),
              !decoded.isEmpty else { return }

        let previousNovelID = selectedNovelID
        let previousChapterID = selectedChapterID
        novels = decoded

        if let previousNovelID, novels.contains(where: { $0.id == previousNovelID }) {
            selectedNovelID = previousNovelID
        } else {
            selectedNovelID = novels.first?.id
        }

        if let novel = selectedNovel,
           let previousChapterID,
           novel.chapters.contains(where: { $0.id == previousChapterID }) {
            selectedChapterID = previousChapterID
        } else {
            selectedChapterID = selectedNovel?.chapters.first?.id
        }
        saveState = .saved
    }

    private var selectedNovelIndex: Int? {
        guard let selectedNovelID else { return nil }
        return novels.firstIndex { $0.id == selectedNovelID }
    }

    private var selectedIndices: (novel: Int, chapter: Int)? {
        guard let novel = selectedNovelIndex, let selectedChapterID,
              let chapter = novels[novel].chapters.firstIndex(where: { $0.id == selectedChapterID }) else { return nil }
        return (novel, chapter)
    }

    private func todoGroupIndices(_ id: UUID) -> (novel: Int, group: Int)? {
        guard let novel = selectedNovelIndex,
              let group = novels[novel].todoGroups.firstIndex(where: { $0.id == id }) else { return nil }
        return (novel, group)
    }

    private func todoIndices(groupID: UUID, todoID: UUID) -> (novel: Int, group: Int, todo: Int)? {
        guard let groupIndices = todoGroupIndices(groupID),
              let todo = novels[groupIndices.novel].todoGroups[groupIndices.group].items.firstIndex(where: { $0.id == todoID }) else { return nil }
        return (groupIndices.novel, groupIndices.group, todo)
    }

    private func load() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? decoder.decode([Novel].self, from: data),
           !decoded.isEmpty {
            novels = decoded
        } else {
            novels = [.welcome]
        }
        selectedNovelID = novels.first?.id
        selectedChapterID = novels.first?.chapters.first?.id
    }

    private func scheduleSave(immediately: Bool = false) {
        saveTask?.cancel()
        saveState = .saving
        if immediately {
            saveNow()
            return
        }
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            self?.saveNow()
        }
    }

    private func saveNow() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(novels)
            try data.write(to: fileURL, options: .atomic)
            saveState = .saved
            WidgetCenter.shared.reloadAllTimelines()
        } catch {
            saveState = .saving
        }
    }

    private func chineseNumber(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "zh_Hans")
        formatter.numberStyle = .spellOut
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}
