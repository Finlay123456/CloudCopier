import Foundation
import SwiftUI
import UserNotifications

class ClipboardManager: NSObject, ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var recentItems: [ClipboardItem] = []
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    
    enum ConnectionState {
        case disconnected, connecting, connected, error
    }
    
    override init() {
        super.init()
        setupNotificationActions()
    }
    
    func connect(to urlString: String) {
        guard let url = URL(string: urlString) else {
            print("Invalid URL: \(urlString)")
            return
        }
        
        connectionState = .connecting
        
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()
        
        receiveMessage()
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession = nil
        connectionState = .disconnected
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleMessage(message)
                self?.receiveMessage() // Continue listening
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                DispatchQueue.main.async {
                    self?.connectionState = .error
                }
            }
        }
    }
    
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            handleStringMessage(text)
        case .data(let data):
            if let text = String(data: data, encoding: .utf8) {
                handleStringMessage(text)
            }
        @unknown default:
            break
        }
    }
    
    private func handleStringMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String,
              type == "clipboardUpdate",
              let clipboardData = json["clipboard"] as? [String: Any],
              let formats = clipboardData["formats"] as? [String: String] else {
            return
        }
        
        let source = clipboardData["source"] as? String ?? "unknown"
        let clipboardItem = ClipboardItem(formats: formats, source: source)
        
        DispatchQueue.main.async {
            self.recentItems.insert(clipboardItem, at: 0)
            if self.recentItems.count > 10 {
                self.recentItems.removeLast()
            }
            self.showNotification(for: clipboardItem)
        }
    }
    
    private func showNotification(for item: ClipboardItem) {
        let content = UNMutableNotificationContent()
        content.title = "New Clipboard Item"
        content.body = item.previewText
        content.sound = .default
        content.categoryIdentifier = "CLIPBOARD_CATEGORY"
        content.userInfo = ["clipboardItemId": item.id.uuidString]
        
        let request = UNNotificationRequest(
            identifier: item.id.uuidString,
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to show notification: \(error)")
            }
        }
    }
    
    private func setupNotificationActions() {
        let copyAction = UNNotificationAction(
            identifier: "COPY_ACTION",
            title: "Copy",
            options: [.foreground]
        )
        
        let ignoreAction = UNNotificationAction(
            identifier: "IGNORE_ACTION",
            title: "Ignore",
            options: []
        )
        
        let category = UNNotificationCategory(
            identifier: "CLIPBOARD_CATEGORY",
            actions: [copyAction, ignoreAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
        UNUserNotificationCenter.current().delegate = self
    }
    
    func copyToClipboard(_ item: ClipboardItem) {
        let pasteboard = UIPasteboard.general
        
        // Clear the pasteboard first
        pasteboard.items = []
        
        var pasteboardItems: [String: Any] = [:]
        
        // Add text formats
        if let text = item.formats["text"] {
            pasteboardItems["public.plain-text"] = text
        }
        
        if let html = item.formats["html"] {
            pasteboardItems["public.html"] = html
        }
        
        if let rtf = item.formats["rtf"] {
            pasteboardItems["public.rtf"] = rtf.data(using: .utf8)
        }
        
        // Handle images (base64 encoded)
        if let imageData = item.formats["image"],
           imageData.hasPrefix("data:image/"),
           let base64String = imageData.components(separatedBy: ",").last,
           let data = Data(base64Encoded: base64String) {
            pasteboardItems["public.png"] = data
        }
        
        pasteboard.setItems([pasteboardItems])
        
        // Show success feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
    }
}

// MARK: - URLSessionWebSocketDelegate
extension ClipboardManager: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.connectionState = .connected
        }
        print("WebSocket connected")
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async {
            self.connectionState = .disconnected
        }
        print("WebSocket disconnected")
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension ClipboardManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        guard let itemIdString = response.notification.request.content.userInfo["clipboardItemId"] as? String,
              let itemId = UUID(uuidString: itemIdString),
              let item = recentItems.first(where: { $0.id == itemId }) else {
            completionHandler()
            return
        }
        
        switch response.actionIdentifier {
        case "COPY_ACTION":
            copyToClipboard(item)
        case "IGNORE_ACTION":
            break // Do nothing
        default:
            break
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }
}