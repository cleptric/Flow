// Copyright © 2025 Michi Hoffmann. All rights reserved.

import SwiftUI

struct LogDetailView: View {
  let logFile: LogFile
  @State private var logContent: String = ""
  @State private var hasError: Bool = false
  @State private var errorMessage: String = ""
  @State private var isCleared: Bool = false
  @State private var isLoading: Bool = false
  @State private var lastLoadedPath: String = ""
  @State private var isLoadingMore: Bool = false
  @StateObject private var fileManager = LogFileManager.shared
  @StateObject private var fileMonitor = FileMonitor()

  @Binding var isAutoScrollEnabled: Bool
  @Binding var searchText: String
  @Binding var refreshTrigger: Bool
  @Binding var clearTrigger: Bool

  var displayedContent: String {
    if isCleared {
      return ""
    }

    guard !searchText.isEmpty else { return logContent }
    let lines = logContent.components(separatedBy: .newlines)
    let filteredLines = lines.filter { $0.localizedCaseInsensitiveContains(searchText) }

    // Limit search results to prevent UI lag
    let maxSearchResults = 500
    if filteredLines.count > maxSearchResults {
      let limitedLines = Array(filteredLines.suffix(maxSearchResults))
      return limitedLines.joined(separator: "\n")
    }

    return filteredLines.joined(separator: "\n")
  }

  var isSearching: Bool {
    !searchText.isEmpty
  }

  var hasSearchResults: Bool {
    guard isSearching else { return true }
    return !displayedContent.isEmpty
  }

  var body: some View {
    // Log content area
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          if hasError {
            VStack(alignment: .leading, spacing: 12) {
              HStack {
                Image(systemName: "exclamationmark.triangle")
                  .foregroundColor(.orange)
                Text("Error reading log file")
                  .font(.headline)
                  .foregroundColor(.orange)
              }
              Text(errorMessage)
                .font(.body)
                .foregroundColor(.secondary)
              Button("Retry") {
                retryLoadContent()
              }
              .buttonStyle(.bordered)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
          } else {
            if logContent.isEmpty {
              Text("Log file is empty...")
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .id("logContent")
            } else if isSearching && !hasSearchResults {
              Text("No matches found for \"\(searchText)\"")
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .id("logContent")
            } else {
              Text(displayedContent)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .id("logContent")
            }
          }
        }
      }
      .onAppear {
        // Start at bottom when view appears
        DispatchQueue.main.async {
          proxy.scrollTo("logContent", anchor: .bottom)
        }
      }
      .onChange(of: logContent) {
        if isAutoScrollEnabled && !hasError && !isCleared && !isSearching {
          DispatchQueue.main.async {
            proxy.scrollTo("logContent", anchor: .bottom)
          }
        }
      }
      .onChange(of: refreshTrigger) {
        refreshLogContent()
        // Scroll to bottom after refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          proxy.scrollTo("logContent", anchor: .bottom)
        }
      }
      .onChange(of: clearTrigger) {
        clearLogDisplay()
      }
    }
    .onAppear {
      // Only load if we haven't loaded this file yet or if it's a different file
      if lastLoadedPath != logFile.filePath {
        if logFile.accessSecurityScopedResource() {
          loadLogContent()
          fileMonitor.startMonitoring(filePath: logFile.filePath)
          lastLoadedPath = logFile.filePath
        } else {
          hasError = true
          errorMessage = "Permission denied. Please re-add this log file to grant access."
        }
      }
    }
    .onDisappear {
      fileMonitor.stopMonitoring(filePath: logFile.filePath)
      logFile.stopAccessingSecurityScopedResource()
    }
    .onReceive(fileMonitor.$fileChanges) { changes in
      if changes[logFile.filePath] != nil {
        isCleared = false
        loadLogContent()
      }
    }
  }

  private func loadLogContent() {
    guard !isLoading else { return }

    isLoading = true

    Task {
      do {
        let url = URL(fileURLWithPath: logFile.filePath)
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { fileHandle.closeFile() }

        // Get file size
        let fileSize =
          try FileManager.default.attributesOfItem(atPath: logFile.filePath)[.size] as? Int64 ?? 0

        // First, read just the last few lines for immediate display
        let quickBytes: Int64 = 8192  // 8KB for quick preview
        let quickBytesToRead = min(fileSize, quickBytes)

        if fileSize > quickBytes {
          try fileHandle.seek(toOffset: UInt64(fileSize - quickBytesToRead))
        }

        let quickData = fileHandle.readData(ofLength: Int(quickBytesToRead))
        var quickContent = String(data: quickData, encoding: .utf8) ?? ""

        // If we started mid-line, remove the first incomplete line
        if fileSize > quickBytes {
          if let firstNewline = quickContent.firstIndex(of: "\n") {
            quickContent = String(quickContent[quickContent.index(after: firstNewline)...])
          }
        }

        // Show just the last few lines immediately
        let quickLines = quickContent.components(separatedBy: .newlines)
        let previewLines = Array(quickLines.suffix(50))  // Show last 50 lines immediately
        let previewContent = previewLines.joined(separator: "\n")

        await MainActor.run {
          logContent = previewContent
          hasError = false
          errorMessage = ""
          isLoading = false
        }

        // Now load more content in the background if the file is larger
        if fileSize > quickBytes {
          loadMoreContent()
        }

      } catch {
        await MainActor.run {
          hasError = true
          errorMessage = error.localizedDescription
          logContent = ""
          isLoading = false
        }
      }
    }
  }

  private func loadMoreContent() {
    guard !isLoadingMore else { return }

    isLoadingMore = true

    Task {
      do {
        let url = URL(fileURLWithPath: logFile.filePath)
        let fileHandle = try FileHandle(forReadingFrom: url)
        defer { fileHandle.closeFile() }

        // Get file size
        let fileSize =
          try FileManager.default.attributesOfItem(atPath: logFile.filePath)[.size] as? Int64 ?? 0

        // Read more content (up to 256KB)
        let maxBytes: Int64 = 256 * 1024
        let bytesToRead = min(fileSize, maxBytes)

        if fileSize > maxBytes {
          try fileHandle.seek(toOffset: UInt64(fileSize - bytesToRead))
        }

        let data = fileHandle.readData(ofLength: Int(bytesToRead))
        var content = String(data: data, encoding: .utf8) ?? ""

        // If we started mid-line, remove the first incomplete line
        if fileSize > maxBytes {
          if let firstNewline = content.firstIndex(of: "\n") {
            content = String(content[content.index(after: firstNewline)...])
          }
        }

        // Limit to manageable number of lines
        let lines = content.components(separatedBy: .newlines)
        let maxDisplayLines = 300
        if lines.count > maxDisplayLines {
          let startIndex = lines.count - maxDisplayLines
          content = lines[startIndex...].joined(separator: "\n")
        }

        await MainActor.run {
          logContent = content
          isLoadingMore = false
        }

      } catch {
        await MainActor.run {
          isLoadingMore = false
        }
      }
    }
  }

  func clearLogDisplay() {
    isCleared = true
    hasError = false
    errorMessage = ""
  }

  func refreshLogContent() {
    if logFile.accessSecurityScopedResource() {
      isCleared = false
      loadLogContent()
    }
  }

  private func retryLoadContent() {
    if logFile.accessSecurityScopedResource() {
      isCleared = false
      loadLogContent()
    }
  }

  private func revealInFinder() {
    let url = URL(fileURLWithPath: logFile.filePath)
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }

}

struct CheckboxToggleStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    HStack {
      Image(systemName: configuration.isOn ? "checkmark.square" : "square")
        .foregroundColor(configuration.isOn ? .accentColor : .secondary)
        .onTapGesture {
          configuration.isOn.toggle()
        }
      configuration.label
    }
  }
}

#Preview {
  LogDetailView(
    logFile: LogFile(filePath: "/tmp/test.log"),
    isAutoScrollEnabled: .constant(true),
    searchText: .constant(""),
    refreshTrigger: .constant(false),
    clearTrigger: .constant(false)
  )
}
