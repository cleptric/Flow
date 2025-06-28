// Copyright © 2025 Michi Hoffmann. All rights reserved.

import AppKit
import Foundation

class LogFileManager: ObservableObject {
  static let shared = LogFileManager()

  private init() {}

  func selectLogFile() -> String? {
    let openPanel = NSOpenPanel()
    openPanel.title = "Select Log File"
    openPanel.showsHiddenFiles = false
    openPanel.canChooseDirectories = false
    openPanel.canCreateDirectories = false
    openPanel.allowsMultipleSelection = false
    openPanel.allowedContentTypes = [.plainText, .log]

    if openPanel.runModal() == .OK {
      return openPanel.url?.path
    }

    return nil
  }

  func readLogFile(at path: String) -> String {
    do {
      return try String(contentsOfFile: path, encoding: .utf8)
    } catch {
      return "Error reading file: \(error.localizedDescription)"
    }
  }

  func getFileSize(at path: String) -> Int64 {
    do {
      let attributes = try FileManager.default.attributesOfItem(atPath: path)
      return attributes[.size] as? Int64 ?? 0
    } catch {
      return 0
    }
  }

  func getLastModified(at path: String) -> Date? {
    do {
      let attributes = try FileManager.default.attributesOfItem(atPath: path)
      return attributes[.modificationDate] as? Date
    } catch {
      return nil
    }
  }
}
