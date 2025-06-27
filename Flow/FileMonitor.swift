// Copyright © 2025 Michi Hoffmann. All rights reserved.

import Foundation
import Combine

class FileMonitor: ObservableObject {
    private var monitors: [String: DispatchSourceFileSystemObject] = [:]
    private var fileDescriptors: [String: Int32] = [:]
    @Published var fileChanges: [String: Date] = [:]
    
    func startMonitoring(filePath: String) {
        stopMonitoring(filePath: filePath)
        
        let fileDescriptor = open(filePath, O_EVTONLY)
        guard fileDescriptor != -1 else {
            print("Failed to open file for monitoring: \(filePath)")
            return
        }
        
        fileDescriptors[filePath] = fileDescriptor
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .rename, .delete],
            queue: DispatchQueue.main
        )
        
        source.setEventHandler { [weak self] in
            self?.handleFileChange(filePath: filePath)
        }
        
        source.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptors[filePath] {
                close(fd)
                self?.fileDescriptors.removeValue(forKey: filePath)
            }
        }
        
        monitors[filePath] = source
        source.resume()
    }
    
    func stopMonitoring(filePath: String) {
        monitors[filePath]?.cancel()
        monitors.removeValue(forKey: filePath)
    }
    
    func stopAllMonitoring() {
        monitors.values.forEach { $0.cancel() }
        monitors.removeAll()
        fileDescriptors.removeAll()
    }
    
    private func handleFileChange(filePath: String) {
        DispatchQueue.main.async { [weak self] in
            self?.fileChanges[filePath] = Date()
        }
    }
    
    deinit {
        stopAllMonitoring()
    }
}
