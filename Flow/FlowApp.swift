// Copyright © 2025 Michi Hoffmann. All rights reserved.

import SwiftData
import SwiftUI

extension Notification.Name {
  static let openLogFile = Notification.Name("openLogFile")
  static let revealInFinder = Notification.Name("revealInFinder")
}

@main
struct FlowApp: App {
  @StateObject private var recentFilesManager = RecentFilesManager.shared

  var sharedModelContainer: ModelContainer = {
    let schema = Schema([
      LogFile.self
    ])
    let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

    do {
      return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
    .modelContainer(sharedModelContainer)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button("Open...") {
          NotificationCenter.default.post(name: .openLogFile, object: nil)
        }
        .keyboardShortcut("O", modifiers: .command)

        Divider()

        Menu("Open Recent") {
          ForEach(recentFilesManager.recentFiles) { recentFile in
            Button(recentFile.name) {
              NotificationCenter.default.post(
                name: .openLogFile,
                object: recentFile.path
              )
            }
          }

          if !recentFilesManager.recentFiles.isEmpty {
            Divider()
          }

          Button("Clear Menu") {
            recentFilesManager.clearRecentFiles()
          }
          .disabled(recentFilesManager.recentFiles.isEmpty)
        }

        Divider()

        Button("Reveal in Finder") {
          NotificationCenter.default.post(name: .revealInFinder, object: nil)
        }
        .keyboardShortcut("R", modifiers: .command)
      }
    }
  }
}
