import SwiftUI

@main
struct CODOApp: App {
    @StateObject private var store = ProjectStore()

    var body: some Scene {
        WindowGroup {
            CODOView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .frame(minWidth: 980, minHeight: 660)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Project") { store.addSampleProject() }
                    .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
