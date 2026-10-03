import AppKit
import SwiftUI

@main
struct LiuBaiApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var store = WritingStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(nil)
                .onDisappear { store.flush() }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        store.reloadFromDisk()
                    case .inactive, .background:
                        store.flush()
                    @unknown default:
                        break
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .defaultSize(width: 1120, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建章节") {
                    NotificationCenter.default.post(name: .newChapter, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .saveItem) {
                Button("保存当前版本") {
                    NotificationCenter.default.post(name: .saveVersion, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandMenu("写作") {
                Button("显示或隐藏章节") {
                    NotificationCenter.default.post(name: .toggleSidebar, object: nil)
                }
                .keyboardShortcut("\\", modifiers: .command)

                Button("显示或隐藏历史") {
                    NotificationCenter.default.post(name: .toggleHistory, object: nil)
                }
                .keyboardShortcut("y", modifiers: [.command, .shift])

                Button("进入或退出专注模式") {
                    NotificationCenter.default.post(name: .toggleFocus, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])

                Divider()

                Button("玻璃外观…") {
                    NotificationCenter.default.post(name: .showAppearance, object: nil)
                }
            }
        }
    }
}
