//
//  ClipboardManager.swift
//  CloudCopier
//
//  Created by Finlay Cooper on 2025-07-27.
//

import Foundation
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

class ClipboardManager: ObservableObject {
    @Published var lastReceivedContent: String = ""
    private var lastReceivedFiles: [String] = [] // Track file names to prevent infinite loop
    @Published var statusMessage: String = "Ready to sync clipboard...\nCopy something to test!"
    @Published var isMonitoring: Bool = true
    
    weak var serverManager: ServerManager?
    private var pollingTimer: Timer?
    private var lastChangeCount: Int = 0
    
    init() {
        #if canImport(UIKit)
        lastChangeCount = UIPasteboard.general.changeCount
        #else
        lastChangeCount = NSPasteboard.general.changeCount
        #endif
    }
    
    func startMonitoring() {
        stopMonitoring()
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboardChanges()
        }
    }
    
    func stopMonitoring() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }
    
    private func checkClipboardChanges() {
        guard isMonitoring else { return }
        
        #if canImport(UIKit)
        let currentChangeCount = UIPasteboard.general.changeCount
        #else
        let currentChangeCount = NSPasteboard.general.changeCount
        #endif
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            DispatchQueue.main.async {
                self.statusMessage = "Clipboard changed detected..."
            }
            
            // Add a small delay to avoid processing clipboard changes too quickly after setting
            Task {
                try? await Task.sleep(nanoseconds: 200_000_000) // 200ms delay
                await self.handleClipboardChange()
            }
        }
    }
    
    @MainActor
    private func handleClipboardChange() async {
        do {
            statusMessage = "Capturing clipboard data..."
            
            // Small delay to ensure clipboard is ready
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
            
            if let clipboardData = await captureClipboardData() {
                statusMessage = "Sending to server..."
                await serverManager?.sendClipboardToServer(clipboardData)
            } else {
                statusMessage = "No valid clipboard data found"
            }
        } catch {
            statusMessage = "Error: \(error.localizedDescription)"
        }
    }
    
    private func captureClipboardData() async -> [String: Any]? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                #if canImport(UIKit)
                var formats: [String: Any] = [:]
                let pasteboard = UIPasteboard.general
                
                // Check for text
                if let text = pasteboard.string {
                    // Don't send if this is the same content we just received from server
                    if text == self.lastReceivedContent {
                        DispatchQueue.main.async {
                            self.statusMessage = "Skipping - same as received content"
                        }
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    formats["text"] = text
                    DispatchQueue.main.async {
                        self.statusMessage = "Found text: \(String(text.prefix(50)))..."
                    }
                }
                
                // Check for images
                if let image = pasteboard.image {
                    if let imageData = image.pngData() {
                        let base64String = imageData.base64EncodedString()
                        formats["image"] = "data:image/png;base64,\(base64String)"
                        DispatchQueue.main.async {
                            self.statusMessage = "Found image data"
                        }
                    }
                }
                
                // Check for files (URLs)
                if let urls = pasteboard.urls {
                    let fileData = self.processFileURLs(urls)
                    if !fileData.isEmpty {
                        formats["files"] = fileData
                        DispatchQueue.main.async {
                            self.statusMessage = "Found \(fileData.count) files/folders"
                        }
                    }
                }
                
                if !formats.isEmpty {
                    let result = [
                        "formats": formats,
                        "source": "ios"
                    ]
                    continuation.resume(returning: result)
                } else {
                    DispatchQueue.main.async {
                        self.statusMessage = "No supported clipboard formats found"
                    }
                    continuation.resume(returning: nil)
                }
                #else
                // macOS clipboard support
                var formats: [String: Any] = [:]
                let pasteboard = NSPasteboard.general
                
                // Check for text
                if let text = pasteboard.string(forType: .string) {
                    print("DEBUG: Clipboard text: '\(String(text.prefix(50)))...'")
                    print("DEBUG: lastReceivedContent: '\(String(self.lastReceivedContent.prefix(50)))...'")
                    // Don't send if this is the same content we just received from server
                    if text == self.lastReceivedContent {
                        print("DEBUG: SKIPPING - content matches lastReceivedContent")
                        DispatchQueue.main.async {
                            self.statusMessage = "Skipping - same as received content: '\(String(text.prefix(30)))...'"
                        }
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    print("DEBUG: SENDING - content is different")
                    formats["text"] = text
                    DispatchQueue.main.async {
                        self.statusMessage = "Found text: \(String(text.prefix(50)))..."
                    }
                }
                
                // Check for images
                if let imageData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
                    let base64String = imageData.base64EncodedString()
                    formats["image"] = "data:image/png;base64,\(base64String)"
                    DispatchQueue.main.async {
                        self.statusMessage = "Found image data"
                    }
                }
                
                // Check for file URLs
                if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] {
                    let fileNames = urls.map { $0.lastPathComponent }.sorted()
                    
                    // Don't send if these are the same files we just received from server
                    if fileNames == self.lastReceivedFiles {
                        print("DEBUG: SKIPPING FILES - same as received: \(fileNames)")
                        DispatchQueue.main.async {
                            self.statusMessage = "Skipping - same files as received: \(fileNames.joined(separator: ", "))"
                        }
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let fileData = self.processFileURLs(urls)
                    if !fileData.isEmpty {
                        print("DEBUG: SENDING FILES - different from received: \(fileNames)")
                        formats["files"] = fileData
                        DispatchQueue.main.async {
                            self.statusMessage = "Found \(fileData.count) files/folders"
                        }
                    }
                }
                
                if !formats.isEmpty {
                    let result = [
                        "formats": formats,
                        "source": "macos"
                    ]
                    continuation.resume(returning: result)
                } else {
                    DispatchQueue.main.async {
                        self.statusMessage = "No supported clipboard formats found"
                    }
                    continuation.resume(returning: nil)
                }
                #endif
            }
        }
    }
    
    private func processFileURLs(_ urls: [URL]) -> [[String: Any]] {
        var fileData: [[String: Any]] = []
        
        for url in urls {
            do {
                if url.hasDirectoryPath {
                    // Directory
                    fileData.append([
                        "name": url.lastPathComponent,
                        "content": "",
                        "size": 0,
                        "type": "directory",
                        "isDirectory": true
                    ])
                } else {
                    // File
                    let data = try Data(contentsOf: url)
                    
                    // Limit file size to 50MB
                    if data.count <= 50 * 1024 * 1024 {
                        let base64Content = data.base64EncodedString()
                        let mimeType = getMimeType(for: url)
                        
                        fileData.append([
                            "name": url.lastPathComponent,
                            "content": base64Content,
                            "size": data.count,
                            "type": mimeType
                        ])
                    } else {
                        DispatchQueue.main.async {
                            self.statusMessage = "File too large: \(url.lastPathComponent) (\(data.count / (1024 * 1024))MB)"
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = "Error reading file \(url.lastPathComponent): \(error.localizedDescription)"
                }
            }
        }
        
        return fileData
    }
    
    private func getMimeType(for url: URL) -> String {
        let pathExtension = url.pathExtension.lowercased()
        
        switch pathExtension {
        case "txt": return "text/plain"
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "xls": return "application/vnd.ms-excel"
        case "xlsx": return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "ppt": return "application/vnd.ms-powerpoint"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "bmp": return "image/bmp"
        case "svg": return "image/svg+xml"
        case "mp4": return "video/mp4"
        case "avi": return "video/x-msvideo"
        case "mov": return "video/quicktime"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "zip": return "application/zip"
        case "rar": return "application/vnd.rar"
        case "7z": return "application/x-7z-compressed"
        case "json": return "application/json"
        case "xml": return "application/xml"
        case "html": return "text/html"
        case "css": return "text/css"
        case "js": return "application/javascript"
        case "py": return "text/x-python"
        case "java": return "text/x-java-source"
        case "cpp", "cc", "cxx": return "text/x-c++src"
        case "c": return "text/x-csrc"
        case "cs": return "text/x-csharp"
        case "php": return "text/x-php"
        case "rb": return "text/x-ruby"
        case "go": return "text/x-go"
        case "rs": return "text/x-rust"
        default: return "application/octet-stream"
        }
    }
    
    @MainActor
    func setLocalClipboard(from formats: [String: Any]) async {
        #if canImport(UIKit)
        let pasteboard = UIPasteboard.general
        
        // Priority: files, then images, then text (files are more specific than text paths)
        if let filesArray = formats["files"] as? [[String: Any]] {
            await handleReceivedFiles(filesArray)
        } else if let imageString = formats["image"] as? String,
                  imageString.hasPrefix("data:image") {
            if let base64String = imageString.components(separatedBy: ",").last,
               let imageData = Data(base64Encoded: base64String),
               let image = UIImage(data: imageData) {
                pasteboard.image = image
                statusMessage = "📥 Set clipboard image"
            }
        } else if let text = formats["text"] as? String {
            lastReceivedContent = text
            pasteboard.string = text
            statusMessage = "📥 Set clipboard text: \(String(text.prefix(50)))..."
        }
        #else
        // macOS clipboard support
        let pasteboard = NSPasteboard.general
        
        // Priority: files, then images, then text (files are more specific than text paths)
        if let filesArray = formats["files"] as? [[String: Any]] {
            await handleReceivedFiles(filesArray)
        } else if let imageString = formats["image"] as? String,
                  imageString.hasPrefix("data:image") {
            if let base64String = imageString.components(separatedBy: ",").last,
               let imageData = Data(base64Encoded: base64String),
               let image = NSImage(data: imageData) {
                pasteboard.clearContents()
                pasteboard.writeObjects([image])
                statusMessage = "📥 Set clipboard image"
            }
        } else if let text = formats["text"] as? String {
            lastReceivedContent = text
            print("DEBUG: Setting lastReceivedContent to: '\(String(text.prefix(50)))...'")
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            statusMessage = "📥 Set clipboard text: \(String(text.prefix(50)))..."
        }
        #endif
    }
    
    @MainActor
    private func handleReceivedFiles(_ filesArray: [[String: Any]]) async {
        do {
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let tempDir = documentsPath.appendingPathComponent("ClipboardSync")
            
            // Create temp directory
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            
            var fileUrls: [URL] = []
            var decodedFiles: [String] = []
            
            for fileDict in filesArray {
                guard let fileName = fileDict["name"] as? String else { continue }
                
                let fileUrl = tempDir.appendingPathComponent(fileName)
                
                if let isDirectory = fileDict["isDirectory"] as? Bool, isDirectory {
                    // Create directory
                    try FileManager.default.createDirectory(at: fileUrl, withIntermediateDirectories: true)
                    fileUrls.append(fileUrl)
                    decodedFiles.append("\(fileName) (folder)")
                } else if let content = fileDict["content"] as? String, !content.isEmpty {
                    // Decode and save file
                    if let fileData = Data(base64Encoded: content) {
                        try fileData.write(to: fileUrl)
                        fileUrls.append(fileUrl)
                        decodedFiles.append(fileName)
                    }
                }
            }
            
            if !fileUrls.isEmpty {
                // Track the received file names to prevent infinite loop
                lastReceivedFiles = fileUrls.map { $0.lastPathComponent }.sorted()
                print("DEBUG: Setting lastReceivedFiles to: \(lastReceivedFiles)")
                
                #if canImport(UIKit)
                UIPasteboard.general.urls = fileUrls
                #else
                // macOS file URLs support
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.writeObjects(fileUrls as [NSURL])
                #endif
                statusMessage = "📥 Set clipboard files: \(decodedFiles.joined(separator: ", "))"
            } else {
                statusMessage = "No valid files to decode"
            }
        } catch {
            statusMessage = "Error setting files: \(error.localizedDescription)"
        }
    }
    
    func toggleMonitoring() {
        isMonitoring.toggle()
        if isMonitoring {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }
    
    func clearLastReceivedFiles() {
        lastReceivedFiles = []
        print("DEBUG: Cleared lastReceivedFiles")
    }
}
