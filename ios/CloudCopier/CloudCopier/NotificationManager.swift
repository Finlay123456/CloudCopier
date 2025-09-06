//
//  NotificationManager.swift
//  CloudCopier
//
//  Created by Finlay Cooper on 2025-07-27.
//
import Foundation
import UserNotifications
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var showingCopyAlert = false
    @Published var pendingClipboardData: [String: Any]?
    
    weak var clipboardManager: ClipboardManager?
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        setupNotificationCategories()
    }
    
    private func setupNotificationCategories() {
        let copyAction = UNNotificationAction(
            identifier: "COPY_ACTION",
            title: "Copy",
            options: []
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_ACTION",
            title: "Dismiss",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: "CLIPBOARD_CATEGORY",
            actions: [copyAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            } else if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied - app will work without notifications")
            }
        }
    }
    
    func showClipboardNotification(with formats: [String: Any]) async {
        #if canImport(UIKit)
        // iOS/iPadOS: Send native notification
        let content = UNMutableNotificationContent()
        content.title = "📥 Clipboard Content Received"
        content.body = getPreviewText(from: formats)
        content.sound = .default
        content.categoryIdentifier = "CLIPBOARD_CATEGORY"
        content.userInfo = formats
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Error sending notification: \(error)")
            // Fallback to in-app alert if notification fails
            await MainActor.run {
                self.pendingClipboardData = formats
                self.showingCopyAlert = true
            }
        }
        #else
        // macOS: Auto-copy to clipboard immediately (no notification needed)
        await clipboardManager?.setLocalClipboard(from: formats)
        #endif
    }
    
    func copyPendingContent() async {
        guard let data = pendingClipboardData else { return }
        
        await clipboardManager?.setLocalClipboard(from: data)
        
        await MainActor.run {
            self.pendingClipboardData = nil
            self.showingCopyAlert = false
        }
    }
    
    func cancelPendingContent() {
        pendingClipboardData = nil
        showingCopyAlert = false
    }
    
    // Helper function to get preview text for the notification
    func getPreviewText(from formats: [String: Any]) -> String {
        if let text = formats["text"] as? String {
            return String(text.prefix(100))
        } else if formats["image"] != nil {
            return "📷 Image"
        } else if let files = formats["files"] as? [[String: Any]] {
            let fileNames = files.compactMap { $0["name"] as? String }
            if fileNames.count == 1 {
                return "📁 \(fileNames[0])"
            } else {
                return "📁 \(fileNames.count) files"
            }
        }
        return "Unknown content type"
    }
    
    // Helper function to get detailed content for the alert
    func getDetailedContent(from formats: [String: Any]) -> (title: String, content: AnyView) {
        if let text = formats["text"] as? String {
            return (
                title: "Text Content",
                content: AnyView(
                    ScrollView {
                        Text(text)
                            .foregroundColor(.black)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .frame(maxHeight: 200)
                )
            )
        } else if formats["image"] != nil {
            return (
                title: "Image Content",
                content: AnyView(
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        Text("Image data received")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                )
            )
        } else if let files = formats["files"] as? [[String: Any]] {
            return (
                title: "Files Content",
                content: AnyView(
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(files.indices, id: \.self) { [self] index in
                                if let fileName = files[index]["name"] as? String,
                                   let fileSize = files[index]["size"] as? Int64 {
                                    HStack {
                                        Image(systemName: getFileIcon(for: fileName))
                                            .foregroundColor(.blue)
                                        VStack(alignment: .leading) {
                                            Text(fileName)
                                                .font(.caption)
                                                .foregroundColor(.black)
                                                .lineLimit(1)
                                            Text(formatFileSize(fileSize))
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .frame(maxHeight: 200)
                )
            )
        }
        
        return (
            title: "Unknown Content",
            content: AnyView(
                Text("Unknown content type")
                    .foregroundColor(.secondary)
                    .padding()
            )
        )
    }
    
    private func getFileIcon(for fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        
        switch ext {
        case "txt", "md": return "doc.text"
        case "pdf": return "doc.richtext"
        case "doc", "docx": return "doc.text"
        case "xls", "xlsx": return "tablecells"
        case "ppt", "pptx": return "play.rectangle"
        case "jpg", "jpeg", "png", "gif", "bmp": return "photo"
        case "mp4", "avi", "mov": return "video"
        case "mp3", "wav": return "music.note"
        case "zip", "rar", "7z": return "archivebox"
        case "exe", "msi": return "gear"
        case "json", "xml": return "curlybraces"
        case "html": return "globe"
        case "css": return "paintbrush"
        case "js", "py", "java", "cpp", "c", "cs", "php", "rb", "go", "rs": return "chevron.left.forwardslash.chevron.right"
        default: return "doc"
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        if bytes < 1024 {
            return "\(bytes) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", Double(bytes) / 1024)
        } else {
            return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "COPY_ACTION":
            Task {
                await clipboardManager?.setLocalClipboard(from: userInfo)
            }
        case "DISMISS_ACTION", UNNotificationDefaultActionIdentifier:
            // Just dismiss the notification
            break
        default:
            break
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.alert, .sound, .badge])
    }
}

// Custom alert view for clipboard content
struct ClipboardAlert: View {
    @EnvironmentObject var notificationManager: NotificationManager
    
    var body: some View {
        if notificationManager.showingCopyAlert,
           let data = notificationManager.pendingClipboardData {
            
            let content = notificationManager.getDetailedContent(from: data)
            
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    HStack {
                        Text("📥 Clipboard Content Received")
                            .font(.headline)
                            .foregroundColor(.black)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(content.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.black)
                        
                        content.content
                    }
                    
                    HStack(spacing: 12) {
                        Button("Cancel") {
                            notificationManager.cancelPendingContent()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                        
                        Button("Copy") {
                            Task {
                                await notificationManager.copyPendingContent()
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(16)
                .padding(.horizontal, 20)
                .shadow(radius: 10)
            }
        }
    }
}
