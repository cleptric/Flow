// Copyright © 2025 Michi Hoffmann. All rights reserved.

import Foundation
import SwiftData

@Model
final class LogFile {
    var filePath: String
    var fileName: String
    var lastModified: Date
    var isMonitoring: Bool
    var bookmarkData: Data?
    
    init(filePath: String) {
        self.filePath = filePath
        self.fileName = URL(fileURLWithPath: filePath).lastPathComponent
        self.lastModified = Date()
        self.isMonitoring = true
        
        if let attributes = try? FileManager.default.attributesOfItem(atPath: filePath),
           let modificationDate = attributes[.modificationDate] as? Date {
            self.lastModified = modificationDate
        }
        
        // Create security-scoped bookmark
        let url = URL(fileURLWithPath: filePath)
        do {
            self.bookmarkData = try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess])
        } catch {
            print("Failed to create bookmark for \(filePath): \(error)")
            self.bookmarkData = nil
        }
    }
    
    func accessSecurityScopedResource() -> Bool {
        guard let bookmarkData = bookmarkData else { return false }
        
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, bookmarkDataIsStale: &isStale)
            
            if isStale {
                // Bookmark is stale, need to recreate it
                print("Bookmark is stale for \(filePath)")
                return false
            }
            
            return url.startAccessingSecurityScopedResource()
        } catch {
            print("Failed to resolve bookmark for \(filePath): \(error)")
            return false
        }
    }
    
    func stopAccessingSecurityScopedResource() {
        guard let bookmarkData = bookmarkData else { return }
        
        do {
            var isStale = false
            let url = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, bookmarkDataIsStale: &isStale)
            url.stopAccessingSecurityScopedResource()
        } catch {
            print("Failed to stop accessing security scoped resource for \(filePath): \(error)")
        }
    }
}
