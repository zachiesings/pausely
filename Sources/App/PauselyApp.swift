import SwiftUI

@main
struct PauselyApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        MenuBarExtra {
            MenuView()
                .environmentObject(model)
        } label: {
            // Show the minutes to the next break alongside the icon when active.
            if let mins = model.store.nextBreakMinutes {
                Image(systemName: "pause.circle.fill")
                Text("\(mins)m")
            } else {
                Image(systemName: "pause.circle.fill")
            }
        }
        .menuBarExtraStyle(.window)
    }
}
