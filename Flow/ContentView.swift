// Copyright © 2025 Michi Hoffmann. All rights reserved.

import SwiftData
import SwiftUI

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Query private var logFiles: [LogFile]
  @StateObject private var fileManager = LogFileManager.shared
  @State private var selectedLogFile: LogFile?
  @State private var isAutoScrollEnabled: Bool = true
  @State private var searchText: String = ""
  @State private var refreshTrigger: Bool = false
  @State private var clearTrigger: Bool = false

  var body: some View {
    NavigationSplitView {
      List {
        ForEach(logFiles) { logFile in
          HStack(spacing: 8) {
            Image(systemName: "doc.text")
              .foregroundColor(.blue)
              .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
              HStack {
                Text(logFile.fileName)
                  .font(.system(size: 13))
                Spacer()
                if logFile.bookmarkData == nil {
                  Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(.orange)
                    .help("Permission required - click to re-add file")
                }
              }
              Text(logFile.filePath)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            }
          }
          .contentShape(Rectangle())
          .onTapGesture {
            selectedLogFile = logFile
          }
          .listRowBackground(
            selectedLogFile == logFile ? Color.accentColor.opacity(0.2) : Color.clear
          )
          .contextMenu {
            if logFile.bookmarkData == nil {
              Button(action: {
                refreshFileAccess(for: logFile)
              }) {
                Text("Grant Access")
              }
              Divider()
            }
            Button(action: {
              deleteLogFiles(offsets: .init([logFiles.firstIndex(of: logFile)!]))
            }) {
              Text("Remove")
            }
          }
        }
        .onDelete(perform: deleteLogFiles)
      }
      .navigationSplitViewColumnWidth(min: 180, ideal: 200)
    } detail: {
      if let selectedLogFile = selectedLogFile {
        LogDetailView(
          logFile: selectedLogFile,
          isAutoScrollEnabled: $isAutoScrollEnabled,
          searchText: $searchText,
          refreshTrigger: $refreshTrigger,
          clearTrigger: $clearTrigger
        )
        .id(selectedLogFile.filePath)
      } else {
        Text("Select a log file to view its contents")
      }
    }
    .toolbar {
      ToolbarItemGroup(placement: .navigation) {
        if let selectedLogFile = selectedLogFile {
          VStack(alignment: .leading, spacing: 2) {
            Text(selectedLogFile.fileName)
              .font(.headline)
            Text(selectedLogFile.filePath)
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }

      ToolbarItemGroup(placement: .automatic) {
        if selectedLogFile != nil {
          Toggle("Auto-scroll", isOn: $isAutoScrollEnabled)
            .toggleStyle(CheckboxToggleStyle())

          Button(action: refreshCurrentLog) {
            Image(systemName: "arrow.clockwise")
          }
          .help("Refresh log content")

          Button(action: clearCurrentLog) {
            Image(systemName: "trash")
          }
          .help("Clear displayed content")
        }
      }

      ToolbarItemGroup(placement: .primaryAction) {
        HStack {
          if selectedLogFile != nil {
            TextField("Search logs...", text: $searchText)
              .textFieldStyle(.roundedBorder)
              .frame(width: 200)
          }

          Button(action: addLogFile) {
            Image(systemName: "plus")
          }
          .help("Add Log File")
        }
      }
    }
    .onChange(of: logFiles) {
      if let selected = selectedLogFile, !logFiles.contains(selected) {
        selectedLogFile = nil
      }
    }
    .navigationTitle("")
    .onReceive(NotificationCenter.default.publisher(for: .openLogFile)) { notification in
      if let filePath = notification.object as? String {
        openLogFile(at: filePath)
      } else {
        addLogFile()
      }
    }
    .onReceive(NotificationCenter.default.publisher(for: .revealInFinder)) { _ in
      revealInFinder()
    }
  }

  private func addLogFile() {
    if let filePath = fileManager.selectLogFile() {
      let newLogFile = LogFile(filePath: filePath)
      modelContext.insert(newLogFile)
      selectedLogFile = newLogFile
      RecentFilesManager.shared.addRecentFile(filePath)
    }
  }

  private func openLogFile(at filePath: String) {
    // Check if file already exists in the list
    if let existingFile = logFiles.first(where: { $0.filePath == filePath }) {
      selectedLogFile = existingFile
      return
    }

    // Add new log file
    let newLogFile = LogFile(filePath: filePath)
    modelContext.insert(newLogFile)
    selectedLogFile = newLogFile
    RecentFilesManager.shared.addRecentFile(filePath)
  }

  private func deleteLogFiles(offsets: IndexSet) {
    for index in offsets {
      let logFileToDelete = logFiles[index]
      if selectedLogFile == logFileToDelete {
        selectedLogFile = nil
      }
      modelContext.delete(logFileToDelete)
    }
  }

  private func refreshFileAccess(for logFile: LogFile) {
    if let newFilePath = fileManager.selectLogFile() {
      // Update the existing LogFile with new bookmark data
      let url = URL(fileURLWithPath: newFilePath)
      do {
        logFile.bookmarkData = try url.bookmarkData(options: [
          .withSecurityScope, .securityScopeAllowOnlyReadAccess,
        ])
        logFile.filePath = newFilePath
        logFile.fileName = url.lastPathComponent

        if let attributes = try? FileManager.default.attributesOfItem(atPath: newFilePath),
          let modificationDate = attributes[.modificationDate] as? Date
        {
          logFile.lastModified = modificationDate
        }
      } catch {
        print("Failed to create new bookmark for \(newFilePath): \(error)")
      }
    }
  }

  private func refreshCurrentLog() {
    refreshTrigger.toggle()
  }

  private func clearCurrentLog() {
    clearTrigger.toggle()
  }

  private func revealInFinder() {
    guard let selectedLogFile = selectedLogFile else { return }

    let url = URL(fileURLWithPath: selectedLogFile.filePath)
    NSWorkspace.shared.activateFileViewerSelecting([url])
  }
}

#Preview {
  ContentView()
    .modelContainer(for: LogFile.self, inMemory: true)
}
