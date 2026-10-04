import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: WritingStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("glassTintStrengthV2") private var glassStrength = 0.18
    @AppStorage("glassTint") private var glassTint = "warm"
    @State private var sidebarVisible = true
    @State private var historyVisible = false
    @State private var focusMode = false
    @State private var appearanceVisible = false
    @State private var storySwitcherVisible = false
    @State private var toolbarHovered = false
    @State private var hoveredChapter: UUID?
    @FocusState private var novelTitleFocused: Bool
    @StateObject private var todoPanelModel = TodoPanelModel()

    private let accent = Color(red: 0.43, green: 0.39, blue: 0.33)

    var body: some View {
        ZStack {
            glassBackground.ignoresSafeArea()

            HStack(spacing: 0) {
                if sidebarVisible && !focusMode {
                    sidebar
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }

                editor

                if historyVisible && !focusMode {
                    historyPanel
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        }
        .frame(minWidth: 840, minHeight: 600)
        .background {
            ZStack {
                WindowGlassConfigurator()
                TodoPanelAttacher(store: store, model: todoPanelModel)
            }
        }
        .overlay(alignment: .trailing) {
            if !historyVisible {
                todoOverlay
            }
        }
        .tint(accent)
        .animation(.easeInOut(duration: 0.22), value: sidebarVisible)
        .animation(.easeInOut(duration: 0.22), value: historyVisible)
        .animation(.easeInOut(duration: 0.22), value: focusMode)
        .onReceive(NotificationCenter.default.publisher(for: .newChapter)) { _ in
            store.addChapter()
        }
        .onReceive(NotificationCenter.default.publisher(for: .newNovel)) { _ in
            createStory()
        }
        .onReceive(NotificationCenter.default.publisher(for: .saveVersion)) { _ in
            store.createSnapshot(label: "手动保存")
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            sidebarVisible.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleHistory)) { _ in
            historyVisible.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleFocus)) { _ in
            focusMode.toggle()
            if focusMode {
                historyVisible = false
                sidebarVisible = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAppearance)) { _ in
            appearanceVisible = true
        }
        .onChange(of: historyVisible) { _, visible in
            if visible {
                todoPanelModel.hideImmediately()
            }
        }
        .onChange(of: store.selectedNovelID) { _, _ in
            historyVisible = false
            todoPanelModel.hideImmediately()
        }
        .onOpenURL { url in
            guard url.scheme == "liubai", url.host == "todo",
                  let idText = url.pathComponents.dropFirst().first,
                  let id = UUID(uuidString: idText),
                  store.selectNovel(containingTodoGroup: id) else { return }
            todoPanelModel.selectedGroupID = id
            todoPanelModel.show()
        }
    }

    @ViewBuilder
    private var glassBackground: some View {
        if #available(macOS 26.0, *) {
            Rectangle()
                .fill(.clear)
                .glassEffect(
                    .regular.tint(glassColor.opacity(glassStrength)),
                    in: Rectangle()
                )
        } else {
            ZStack {
                NativeVisualEffectView(
                    material: .popover,
                    blendingMode: .behindWindow
                )
                glassColor.opacity(glassStrength * 0.55)
            }
        }
    }

    private var glassColor: Color {
        let dark = colorScheme == .dark
        switch glassTint {
        case "blue":
            return dark ? Color(red: 0.08, green: 0.12, blue: 0.16) : Color(red: 0.86, green: 0.92, blue: 0.97)
        case "sage":
            return dark ? Color(red: 0.08, green: 0.13, blue: 0.12) : Color(red: 0.87, green: 0.93, blue: 0.90)
        case "rose":
            return dark ? Color(red: 0.16, green: 0.10, blue: 0.11) : Color(red: 0.97, green: 0.89, blue: 0.89)
        case "graphite":
            return dark ? Color(red: 0.07, green: 0.07, blue: 0.075) : Color(red: 0.88, green: 0.88, blue: 0.89)
        default:
            return dark ? Color(red: 0.075, green: 0.07, blue: 0.06) : Color(red: 0.98, green: 0.96, blue: 0.91)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Button {
                    storySwitcherVisible.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 7, weight: .bold))
                    }
                    .foregroundStyle(accent)
                    .frame(height: 24)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("切换故事")
                .popover(isPresented: $storySwitcherVisible, arrowEdge: .bottom) {
                    storySwitcherPanel
                }

                TextField("小说名", text: Binding(
                    get: { store.selectedNovel?.title ?? "" },
                    set: store.updateNovelTitle
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .semibold))
                .focused($novelTitleFocused)

                Button(action: createStory) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(width: 22, height: 22)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("新建故事")
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 20)

            Text("章节")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(1.2)
                .padding(.horizontal, 18)
                .padding(.bottom, 8)

            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(store.selectedNovel?.chapters ?? []) { chapter in
                        chapterRow(chapter)
                    }
                }
                .padding(.horizontal, 10)
            }

            Spacer(minLength: 10)

            Button(action: store.addChapter) {
                Label("新建章节", systemImage: "plus")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(12)
            .foregroundStyle(.secondary)
        }
        .frame(width: 236)
        .background {
            NativeVisualEffectView(material: .sidebar, blendingMode: .withinWindow)
        }
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color.primary.opacity(0.07)).frame(width: 1)
        }
    }

    private var storySwitcherPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("故事")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("\(store.novels.count) 本")
                    .font(.system(size: 10.5, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(store.novels) { novel in
                        storyRow(novel)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 280)

            Divider().opacity(0.55)

            Button(action: createStory) {
                Label("新建故事", systemImage: "plus")
                    .font(.system(size: 12.5, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(accent)
            .padding(12)
        }
        .frame(width: 260)
    }

    private func storyRow(_ novel: Novel) -> some View {
        let selected = novel.id == store.selectedNovelID
        return Button {
            store.selectNovel(novel.id)
            storySwitcherVisible = false
        } label: {
            HStack(spacing: 10) {
                Image(systemName: selected ? "book.closed.fill" : "book.closed")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(selected ? accent : Color.secondary)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 3) {
                    Text(novel.title.isEmpty ? "未命名故事" : novel.title)
                        .font(.system(size: 12.5, weight: selected ? .semibold : .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("\(novel.chapters.count) 章 · \(novelCharacterCount(novel)) 字")
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 6)

                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(accent)
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .background(selected ? accent.opacity(0.11) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func createStory() {
        store.addNovel()
        storySwitcherVisible = false
        DispatchQueue.main.async {
            novelTitleFocused = true
        }
    }

    private func novelCharacterCount(_ novel: Novel) -> Int {
        novel.chapters
            .map(\.text)
            .joined()
            .filter { !$0.isWhitespace && !$0.isNewline }
            .count
    }

    private func chapterRow(_ chapter: Chapter) -> some View {
        let selected = chapter.id == store.selectedChapterID
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(chapter.title.isEmpty ? "未命名章节" : chapter.title)
                    .font(.system(size: 13.5, weight: selected ? .semibold : .regular))
                    .lineLimit(1)
                Text(chapterPreview(chapter))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            if hoveredChapter == chapter.id, (store.selectedNovel?.chapters.count ?? 0) > 1 {
                Button {
                    store.deleteChapter(chapter.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(selected ? accent.opacity(0.13) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onTapGesture { store.selectChapter(chapter.id) }
        .onHover { hovering in hoveredChapter = hovering ? chapter.id : nil }
    }

    private var editor: some View {
        VStack(spacing: 0) {
            editorToolbar

            Rectangle()
                .fill(Color.primary.opacity(0.055))
                .frame(height: 1)

            if store.selectedChapter != nil {
                ComfortableTextEditor(
                    text: Binding(
                        get: { store.selectedChapter?.text ?? "" },
                        set: store.updateChapterText
                    ),
                    focusMode: focusMode
                )
                .frame(maxWidth: 820)
                .frame(maxWidth: .infinity)
            } else {
                ContentUnavailableView("还没有章节", systemImage: "doc.text")
            }

            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var editorToolbar: some View {
        HStack(spacing: 12) {
            quietButton(sidebarVisible ? "sidebar.left" : "sidebar.right") {
                sidebarVisible.toggle()
            }
            .help("显示或隐藏章节")
            .opacity(toolbarHovered ? 1 : 0)
            .allowsHitTesting(toolbarHovered)

            Spacer()

            TextField("章节标题", text: Binding(
                get: { store.selectedChapter?.title ?? "" },
                set: store.updateChapterTitle
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 14, weight: .medium))
            .multilineTextAlignment(.center)
            .frame(maxWidth: 320)

            Spacer()

            quietButton(focusMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right") {
                focusMode.toggle()
                if focusMode {
                    historyVisible = false
                    sidebarVisible = false
                }
            }
            .help("专注模式")
            .opacity(toolbarHovered ? 1 : 0)
            .allowsHitTesting(toolbarHovered)

            quietButton("circle.lefthalf.filled") {
                appearanceVisible.toggle()
            }
            .help("玻璃外观")
            .popover(isPresented: $appearanceVisible, arrowEdge: .top) {
                appearancePanel
            }
            .opacity(toolbarHovered || appearanceVisible ? 1 : 0)
            .allowsHitTesting(toolbarHovered || appearanceVisible)

            quietButton("clock.arrow.circlepath") {
                historyVisible.toggle()
            }
            .help("版本历史")
            .opacity(toolbarHovered ? 1 : 0)
            .allowsHitTesting(toolbarHovered)
        }
        .padding(.horizontal, 16)
        .frame(height: 46)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
                toolbarHovered = hovering
            }
        }
    }

    private var appearancePanel: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("玻璃外观")
                    .font(.system(size: 15, weight: .semibold))
                Text("只改变背景，文字始终保持清晰")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("透明度")
                    Spacer()
                    Text("\(Int((1 - glassStrength) * 100))%")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 12.5))

                Slider(value: $glassStrength, in: 0.04...0.48)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("色调")
                    .font(.system(size: 12.5))
                HStack(spacing: 13) {
                    tintButton("warm", color: Color(red: 0.91, green: 0.84, blue: 0.70), name: "暖白")
                    tintButton("blue", color: Color(red: 0.62, green: 0.76, blue: 0.88), name: "雾蓝")
                    tintButton("sage", color: Color(red: 0.58, green: 0.74, blue: 0.66), name: "青灰")
                    tintButton("rose", color: Color(red: 0.86, green: 0.65, blue: 0.66), name: "玫瑰")
                    tintButton("graphite", color: Color(red: 0.40, green: 0.41, blue: 0.43), name: "石墨")
                }
            }
        }
        .padding(18)
        .frame(width: 292)
    }

    private func tintButton(_ id: String, color: Color, name: String) -> some View {
        Button {
            glassTint = id
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.gradient)
                        .frame(width: 28, height: 28)
                    if glassTint == id {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                Text(name)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        HStack {
            Circle()
                .fill(store.saveState == .saved ? Color.green.opacity(0.82) : accent.opacity(0.65))
                .frame(width: 6, height: 6)
                .shadow(
                    color: store.saveState == .saved ? Color.green.opacity(0.28) : .clear,
                    radius: 3
                )
            Spacer()
            Text("\(characterCount) 字")
        }
        .font(.system(size: 11.5))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 22)
        .frame(height: 34)
    }

    private var todoOverlay: some View {
        ZStack(alignment: .trailing) {
            Color.clear
                .frame(width: 11)
                .contentShape(Rectangle())
                .onHover { hovering in
                    if hovering {
                        todoPanelModel.show()
                    } else {
                        todoPanelModel.edgeExited()
                    }
                }

            if let selectedTodoGroupID = todoPanelModel.selectedGroupID,
               let group = store.currentTodoGroups.first(where: { $0.id == selectedTodoGroupID }) {
                todoGroupDetail(group)
                    .padding(.trailing, 16)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private func todoGroupDetail(_ group: TodoGroup) -> some View {
        let groupColor = TodoPalette.color(for: group.colorKey)
        return glassCard(cornerRadius: 20) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    TextField("清单名称", text: Binding(
                        get: { store.currentTodoGroups.first(where: { $0.id == group.id })?.title ?? "" },
                        set: { store.updateTodoGroupTitle(group.id, title: $0) }
                    ))
                    .textFieldStyle(.plain)
                    .font(.system(size: 15, weight: .semibold))

                    Text("\(group.items.filter { $0.isDone }.count)/\(group.items.count)")
                        .font(.system(size: 10.5, design: .rounded))
                        .foregroundStyle(.tertiary)

                    Button {
                        withAnimation(.easeOut(duration: 0.18)) {
                            todoPanelModel.closeSelection()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                Rectangle()
                    .fill(Color.primary.opacity(0.07))
                    .frame(height: 1)

                Capsule()
                    .fill(groupColor.gradient)
                    .frame(width: 38, height: 4)
                    .shadow(color: groupColor.opacity(0.28), radius: 3)

                HStack(spacing: 9) {
                    ForEach(TodoPalette.options) { option in
                        Button {
                            store.updateTodoGroupColor(group.id, colorKey: option.id)
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(option.color.gradient)
                                    .frame(width: 19, height: 19)
                                    .shadow(color: option.color.opacity(0.25), radius: 3)

                                if group.colorKey == option.id {
                                    Circle()
                                        .stroke(Color.primary.opacity(0.72), lineWidth: 1.5)
                                        .frame(width: 25, height: 25)
                                }
                            }
                            .frame(width: 25, height: 25)
                        }
                        .buttonStyle(.plain)
                        .help("更改清单颜色")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView {
                    LazyVStack(spacing: 5) {
                        if group.items.isEmpty {
                            Text("这张清单还是空的")
                                .font(.system(size: 12))
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 18)
                        } else {
                            ForEach(group.items) { todo in
                                todoRow(groupID: group.id, todo: todo)
                            }
                        }
                    }
                }
                .frame(minHeight: 120, maxHeight: 300)

                HStack {
                    Button {
                        store.addTodo(to: group.id)
                    } label: {
                        Label("添加待办", systemImage: "plus")
                            .font(.system(size: 11.5, weight: .medium))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(groupColor)

                    Spacer()

                    Button {
                        todoPanelModel.closeSelection()
                        store.deleteTodoGroup(group.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .frame(width: 330)
        }
    }

    private func todoRow(groupID: UUID, todo: TodoItem) -> some View {
        let groupColor = TodoPalette.color(
            for: store.currentTodoGroups.first(where: { $0.id == groupID })?.colorKey ?? "mango"
        )
        return HStack(spacing: 9) {
            Button {
                store.toggleTodo(groupID: groupID, todoID: todo.id)
            } label: {
                Image(systemName: todo.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(todo.isDone ? groupColor : Color.secondary)
            }
            .buttonStyle(.plain)

            TextField("待办事项", text: Binding(
                get: {
                    store.currentTodoGroups
                        .first(where: { $0.id == groupID })?
                        .items.first(where: { $0.id == todo.id })?.title ?? ""
                },
                set: { store.updateTodoTitle(groupID: groupID, todoID: todo.id, title: $0) }
            ))
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .strikethrough(todo.isDone)
            .foregroundStyle(todo.isDone ? .secondary : .primary)

            Button {
                store.deleteTodo(groupID: groupID, todoID: todo.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
    }

    @ViewBuilder
    private func glassCard<Content: View>(
        cornerRadius: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        if #available(macOS 26.0, *) {
            content()
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            content()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                }
        }
    }

    private var historyPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("版本历史")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button {
                    historyVisible = false
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(18)

            Button {
                store.createSnapshot(label: "手动保存")
            } label: {
                Label("保存当前版本", systemImage: "bookmark")
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider().opacity(0.5)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(store.selectedChapter?.snapshots ?? []) { snapshot in
                        snapshotRow(snapshot)
                    }

                    if store.selectedChapter?.snapshots.isEmpty != false {
                        VStack(spacing: 8) {
                            Image(systemName: "clock")
                                .font(.system(size: 22, weight: .light))
                            Text("保存版本后会出现在这里")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(.tertiary)
                        .padding(.top, 50)
                    }
                }
            }
        }
        .frame(width: 290)
        .background {
            NativeVisualEffectView(material: .sidebar, blendingMode: .withinWindow)
        }
        .overlay(alignment: .leading) {
            Rectangle().fill(Color.primary.opacity(0.07)).frame(width: 1)
        }
    }

    private func snapshotRow(_ snapshot: ChapterSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(snapshot.label ?? "自动版本")
                        .font(.system(size: 12.5, weight: .medium))
                    Text(snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Button("恢复") { store.restore(snapshot) }
                    .buttonStyle(.plain)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(accent)
            }
            Text(snapshot.text.replacingOccurrences(of: "\n", with: " "))
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .lineSpacing(3)
        }
        .padding(16)
        .overlay(alignment: .bottom) {
            Divider().opacity(0.35)
        }
    }

    private func quietButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private var characterCount: Int {
        (store.selectedChapter?.text ?? "")
            .filter { !$0.isWhitespace && !$0.isNewline }
            .count
    }

    private func chapterPreview(_ chapter: Chapter) -> String {
        let text = chapter.text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? "空白章节" : text
    }
}

extension Notification.Name {
    static let newNovel = Notification.Name("LiuBai.newNovel")
    static let newChapter = Notification.Name("LiuBai.newChapter")
    static let saveVersion = Notification.Name("LiuBai.saveVersion")
    static let toggleSidebar = Notification.Name("LiuBai.toggleSidebar")
    static let toggleHistory = Notification.Name("LiuBai.toggleHistory")
    static let toggleFocus = Notification.Name("LiuBai.toggleFocus")
    static let showAppearance = Notification.Name("LiuBai.showAppearance")
}
