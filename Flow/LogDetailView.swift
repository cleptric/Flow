// Copyright © 2025 Michi Hoffmann. All rights reserved.

import SwiftUI

struct LogDetailView: View {
  let logFile: LogFile
  @State private var hasError: Bool = false
  @State private var errorMessage: String = ""
  @State private var isCleared: Bool = false
  @State private var isLoading: Bool = false
  @State private var lastLoadedPath: String = ""
  @State private var isLoadingMore: Bool = false
  @State private var lastReadOffset: Int64 = 0
  @State private var logLines: [String] = []
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

    let linesToDisplay = logLines
    guard !searchText.isEmpty else {
      return linesToDisplay.joined(separator: "\n")
    }

    let filteredLines = linesToDisplay.filter { $0.localizedCaseInsensitiveContains(searchText) }

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
            if logLines.isEmpty {
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
      .onChange(of: logLines) {
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

        // If this is an update and we have content, only read new content
        if lastReadOffset > 0 && lastReadOffset < fileSize {
          // Read only new content
          try fileHandle.seek(toOffset: UInt64(lastReadOffset))
          let newData = fileHandle.readData(ofLength: Int(fileSize - lastReadOffset))

          if let newContent = String(data: newData, encoding: .utf8) {
            let newLines = newContent.components(separatedBy: .newlines).filter { !$0.isEmpty }

            await MainActor.run {
              logLines.append(contentsOf: newLines)

              // Keep only the last N lines to prevent memory issues
              let maxLines = 1000
              if logLines.count > maxLines {
                logLines = Array(logLines.suffix(maxLines))
              }

              lastReadOffset = fileSize
              isLoading = false
            }
          }
        } else {
          // Initial load or reset - read from end
          let bytesToRead: Int64 = min(fileSize, 256 * 1024)  // 256KB max
          var startOffset: Int64 = 0

          if fileSize > bytesToRead {
            startOffset = fileSize - bytesToRead
            try fileHandle.seek(toOffset: UInt64(startOffset))
          }

          let data = fileHandle.readData(ofLength: Int(bytesToRead))
          var content = String(data: data, encoding: .utf8) ?? ""

          // If we started mid-line, remove the first incomplete line
          if startOffset > 0 {
            if let firstNewline = content.firstIndex(of: "\n") {
              content = String(content[content.index(after: firstNewline)...])
            }
          }

          let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

          await MainActor.run {
            logLines = Array(lines.suffix(300))  // Show last 300 lines
            lastReadOffset = fileSize
            hasError = false
            errorMessage = ""
            isLoading = false
          }
        }

      } catch {
        await MainActor.run {
          hasError = true
          errorMessage = error.localizedDescription
          logLines = []
          lastReadOffset = 0
          isLoading = false
        }
      }
    }
  }

  func clearLogDisplay() {
    isCleared = true
    hasError = false
    errorMessage = ""
    logLines = []
    lastReadOffset = 0
  }

  func refreshLogContent() {
    if logFile.accessSecurityScopedResource() {
      isCleared = false
      // Reset to reload all content
      lastReadOffset = 0
      logLines = []
      loadLogContent()
    }
  }

  private func retryLoadContent() {
    if logFile.accessSecurityScopedResource() {
      isCleared = false
      lastReadOffset = 0
      logLines = []
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
