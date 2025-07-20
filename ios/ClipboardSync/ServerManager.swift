import Foundation
import UIKit

class ServerManager: ObservableObject {
    @Published var isPolling: Bool = false
    @Published var connectionStatus: String = "Disconnected"
    
    weak var clipboardManager: ClipboardManager?
    weak var notificationManager: NotificationManager?
    
    private var pollingTimer: Timer?
    private var lastProcessedTimestamp: Int64 = 0
    private let session = URLSession.shared
    
    func startPolling() {
        stopPolling()
        isPolling = true
        connectionStatus = "Connecting..."
        
        pollingTimer = Timer.scheduledTimer(withTimeInterval: AppConfig.pollingInterval, repeats: true) { [weak self] _ in
            Task {
                await self?.pollClipboard()
            }
        }
        
        // Immediate first poll
        Task {
            await pollClipboard()
        }
    }
    
    func stopPolling() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        isPolling = false
        connectionStatus = "Disconnected"
    }
    
    private func pollClipboard() async {
        do {
            guard let url = URL(string: "\(AppConfig.serverUrl)/clipboard") else {
                await updateConnectionStatus("Invalid server URL")
                return
            }
            
            var request = URLRequest(url: url)
            request.addValue(AppConfig.apiKey, forHTTPHeaderField: "x-api-key")
            request.timeoutInterval = 10
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await updateConnectionStatus("Invalid response")
                return
            }
            
            if httpResponse.statusCode == 200 {
                await updateConnectionStatus("Connected")
                
                let clipboardData = try JSONDecoder().decode(ClipboardData.self, from: data)
                
                // Only process if this is newer data and not from our own app
                if clipboardData.timestamp > lastProcessedTimestamp && clipboardData.source != "ios" {
                    lastProcessedTimestamp = clipboardData.timestamp
                    
                    let formats = clipboardData.formats.mapValues { $0.value }
                    
                    // Show notification with preview and copy options
                    await notificationManager?.showClipboardNotification(with: formats)
                }
            } else {
                await updateConnectionStatus("Server error: \(httpResponse.statusCode)")
            }
            
        } catch {
            await updateConnectionStatus("Network error: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func updateConnectionStatus(_ status: String) {
        connectionStatus = status
    }
    
    func sendClipboardToServer(_ clipboardData: [String: Any]) async {
        do {
            guard let url = URL(string: "\(AppConfig.serverUrl)/clipboard") else {
                await updateClipboardStatus("Invalid server URL")
                return
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue(AppConfig.apiKey, forHTTPHeaderField: "x-api-key")
            request.timeoutInterval = 30
            
            await updateClipboardStatus("Serializing data...")
            
            let jsonData = try JSONSerialization.data(withJSONObject: clipboardData)
            request.httpBody = jsonData
            
            await updateClipboardStatus("Sending to \(AppConfig.serverUrl)/clipboard...")
            
            let (_, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                await updateClipboardStatus("✗ Invalid response")
                return
            }
            
            if httpResponse.statusCode == 204 || httpResponse.statusCode == 200 {
                await updateClipboardStatus("✓ Clipboard sent successfully")
                await clearLastReceivedContent()
            } else {
                await updateClipboardStatus("✗ Server error: \(httpResponse.statusCode)")
            }
            
        } catch {
            await updateClipboardStatus("✗ Network error: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func updateClipboardStatus(_ message: String) {
        clipboardManager?.statusMessage = message
    }
    
    @MainActor
    private func clearLastReceivedContent() {
        clipboardManager?.lastReceivedContent = ""
    }
}