// Copyright © 2025 Michi Hoffmann. All rights reserved.

import SwiftData
import SwiftUI

@main
struct FlowApp: App {
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
  }
}
