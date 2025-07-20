import SwiftUI
import UserNotifications

@main
struct ClipboardSyncApp: App {
    @StateObject private var clipboardManager = ClipboardManager()
    @StateObject private var serverManager = ServerManager()
    @StateObject private var notificationManager = NotificationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(clipboardManager)
                .environmentObject(serverManager)
                .environmentObject(notificationManager)
                .onAppear {
                    setupApp()
                }
        }
    }
    
    private func setupApp() {
        // Request notification permission
        notificationManager.requestPermission()
        
        // Setup clipboard and server managers
        clipboardManager.serverManager = serverManager
        serverManager.clipboardManager = clipboardManager
        serverManager.notificationManager = notificationManager
        
        // Start polling
        serverManager.startPolling()
        
        // Start clipboard monitoring
        clipboardManager.startMonitoring()
    }
}