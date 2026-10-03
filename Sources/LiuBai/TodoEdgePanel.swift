import AppKit
import SwiftUI

@MainActor
final class TodoPanelModel: ObservableObject {
    @Published var isVisible = false
    @Published var selectedGroupID: UUID?

    private var panelHovered = false
    private var hideTask: Task<Void, Never>?

    func show() {
        hideTask?.cancel()
        isVisible = true
    }

    func edgeExited() {
        scheduleHide()
    }

    func panelHoverChanged(_ hovering: Bool) {
        panelHovered = hovering
        hovering ? show() : scheduleHide()
    }

    func toggle(_ id: UUID) {
        hideTask?.cancel()
        selectedGroupID = selectedGroupID == id ? nil : id
        isVisible = true
    }

    func closeSelection() {
        selectedGroupID = nil
    }

    func hideImmediately() {
        hideTask?.cancel()
        selectedGroupID = nil
        isVisible = false
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(240))
            guard !Task.isCancelled, let self,
                  !self.panelHovered, self.selectedGroupID == nil else { return }
            self.isVisible = false
        }
    }
}

struct TodoPanelAttacher: NSViewRepresentable {
    let store: WritingStore
    let model: TodoPanelModel

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store, model: model)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.attach(to: view.window)
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.attach(to: view.window)
            context.coordinator.updateVisibility()
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator: NSObject {
        private let store: WritingStore
        private let model: TodoPanelModel
        private weak var parentWindow: NSWindow?
        private var panel: NSPanel?

        init(store: WritingStore, model: TodoPanelModel) {
            self.store = store
            self.model = model
        }

        func attach(to window: NSWindow?) {
            guard let window else { return }
            if parentWindow !== window {
                detach()
                parentWindow = window
                createPanel(parent: window)
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(parentFrameChanged),
                    name: NSWindow.didResizeNotification,
                    object: window
                )
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(parentFrameChanged),
                    name: NSWindow.didMoveNotification,
                    object: window
                )
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(parentMiniaturized),
                    name: NSWindow.didMiniaturizeNotification,
                    object: window
                )
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(parentDeminiaturized),
                    name: NSWindow.didDeminiaturizeNotification,
                    object: window
                )
            }
            updateVisibility()
        }

        func detach() {
            NotificationCenter.default.removeObserver(self)
            if let panel, let parentWindow {
                parentWindow.removeChildWindow(panel)
                panel.orderOut(nil)
            }
            panel = nil
            parentWindow = nil
        }

        func updateVisibility() {
            guard let panel, let parentWindow else { return }
            position(panel, beside: parentWindow)
            if !parentWindow.isMiniaturized {
                panel.order(.below, relativeTo: parentWindow.windowNumber)
            } else {
                panel.orderOut(nil)
            }
        }

        private func createPanel(parent: NSWindow) {
            let panel = NSPanel(
                contentRect: .zero,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.hidesOnDeactivate = false
            panel.isMovable = false
            panel.becomesKeyOnlyIfNeeded = true
            panel.collectionBehavior = [.fullScreenAuxiliary, .moveToActiveSpace]
            panel.contentView = NSHostingView(rootView: TodoTabsPanel(store: store, model: model))
            parent.addChildWindow(panel, ordered: .below)
            self.panel = panel
            position(panel, beside: parent)
            panel.order(.below, relativeTo: parent.windowNumber)
        }

        private func position(_ panel: NSPanel, beside parent: NSWindow) {
            let expanded = model.isVisible || model.selectedGroupID != nil
            let width: CGFloat = expanded ? expandedPanelWidth() : 38
            let height: CGFloat = expanded ? min(max(parent.frame.height - 150, 300), 620) : 70
            let frame = NSRect(
                x: parent.frame.maxX - 14,
                y: parent.frame.midY - height / 2,
                width: width,
                height: height
            )
            panel.setFrame(frame, display: false)
        }

        private func expandedPanelWidth() -> CGFloat {
            let titleFont = NSFont.systemFont(ofSize: 12.5, weight: .medium)
            let countFont = NSFont.systemFont(ofSize: 10, weight: .medium)
            let widestTag = store.currentTodoGroups.map { group in
                let title = group.title.isEmpty ? "未命名" : group.title
                let remaining = "\(group.items.filter { !$0.isDone }.count)"
                let titleWidth = (title as NSString).size(withAttributes: [.font: titleFont]).width
                let countWidth = (remaining as NSString).size(withAttributes: [.font: countFont]).width
                return titleWidth + countWidth + 43
            }.max() ?? 48
            return ceil(max(widestTag + 12, 62))
        }

        @objc private func parentFrameChanged() {
            guard let panel, let parentWindow else { return }
            position(panel, beside: parentWindow)
        }

        @objc private func parentMiniaturized() {
            panel?.orderOut(nil)
        }

        @objc private func parentDeminiaturized() {
            updateVisibility()
        }
    }
}

private struct TodoTabsPanel: View {
    @ObservedObject var store: WritingStore
    @ObservedObject var model: TodoPanelModel

    var body: some View {
        Group {
            if model.isVisible || model.selectedGroupID != nil {
                expandedTabs
                    .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                collapsedHandle
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .animation(.spring(response: 0.28, dampingFraction: 0.88), value: model.isVisible)
    }

    private var expandedTabs: some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(store.currentTodoGroups.enumerated()), id: \.element.id) { index, group in
                tab(group, index: index)
            }

            Button {
                if let id = store.addTodoGroup() {
                    model.toggle(id)
                }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.primary.opacity(0.52))
                    .frame(width: 48, height: 28)
            }
            .buttonStyle(.plain)
            .glassEffectIfAvailable(cornerRadius: 9)
        }
        .padding(.leading, 1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .onHover(perform: model.panelHoverChanged)
    }

    private var collapsedHandle: some View {
        Button {
            model.show()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 36, height: 56)
        }
        .buttonStyle(.plain)
        .glassEffectIfAvailable(cornerRadius: 11)
        .shadow(color: Color.black.opacity(0.14), radius: 5, x: 2, y: 2)
        .onHover { hovering in
            if hovering {
                model.show()
            }
        }
    }

    private func tab(_ group: TodoGroup, index: Int) -> some View {
        Button {
            model.toggle(group.id)
        } label: {
            HStack(spacing: 10) {
                Text(group.title.isEmpty ? "未命名" : group.title)
                    .font(.system(size: 12.5, weight: model.selectedGroupID == group.id ? .semibold : .medium))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                Text("\(group.items.filter { !$0.isDone }.count)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 17)
            .padding(.trailing, 10)
            .frame(minWidth: 62, alignment: .leading)
            .frame(height: 36)
            .fixedSize(horizontal: true, vertical: false)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffectIfAvailable(
            cornerRadius: 10,
            selected: model.selectedGroupID == group.id,
            tint: TodoPalette.color(for: group.colorKey)
        )
        .offset(x: model.selectedGroupID == group.id ? -4 : 0)
        .shadow(color: Color.black.opacity(0.16), radius: 5, x: 2, y: 2)
    }
}

private extension View {
    @ViewBuilder
    func glassEffectIfAvailable(
        cornerRadius: CGFloat,
        selected: Bool = false,
        tint: Color? = nil
    ) -> some View {
        if #available(macOS 26.0, *) {
            self
                .background(
                    tint?.opacity(selected ? 0.42 : 0.30) ?? .clear,
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
                .glassEffect(
                    .regular.tint(tint?.opacity(selected ? 0.80 : 0.66)),
                    in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                )
        } else {
            self.background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint?.opacity(selected ? 0.46 : 0.34) ?? .clear)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                    }
            }
        }
    }
}
