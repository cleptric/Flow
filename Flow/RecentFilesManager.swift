// Copyright © 2025 Michi Hoffmann. All rights reserved.

import Foundation

class RecentFilesManager: ObservableObject {
  static let shared = RecentFilesManager()

  @Published private(set) var recentFiles: [RecentFile] = []

  private let userDefaults = UserDefaults.standard
  private let recentFilesKey = "recentFiles"
  private let maxRecentFiles = 5

  struct RecentFile: Codable, Identifiable {
    let id = UUID()
    let path: String
    let name: String
    let lastOpened: Date

    enum CodingKeys: String, CodingKey {
      case path, name, lastOpened
    }
  }

  init() {
    loadRecentFiles()
  }

  func addRecentFile(_ filePath: String) {
    let url = URL(fileURLWithPath: filePath)
    let recentFile = RecentFile(
      path: filePath,
      name: url.lastPathComponent,
      lastOpened: Date()
    )

    var files = recentFiles.filter { $0.path != filePath }
    files.insert(recentFile, at: 0)

    if files.count > maxRecentFiles {
      files = Array(files.prefix(maxRecentFiles))
    }

    recentFiles = files
    saveRecentFiles()
  }

  func clearRecentFiles() {
    recentFiles = []
    saveRecentFiles()
  }

  private func loadRecentFiles() {
    guard let data = userDefaults.data(forKey: recentFilesKey),
      let files = try? JSONDecoder().decode([RecentFile].self, from: data)
    else {
      return
    }
    recentFiles = files
  }

  private func saveRecentFiles() {
    guard let data = try? JSONEncoder().encode(recentFiles) else { return }
    userDefaults.set(data, forKey: recentFilesKey)
  }
}
