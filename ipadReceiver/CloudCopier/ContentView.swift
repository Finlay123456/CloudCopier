import SwiftUI

struct ContentView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @State private var serverURL = "ws://localhost:3000"
    @State private var isConnected = false
    @State private var isEnabled = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("CloudCopier")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                
                // Connection Status
                HStack {
                    Circle()
                        .fill(isConnected ? .green : .red)
                        .frame(width: 12, height: 12)
                    
                    Text(isConnected ? "Connected" : "Disconnected")
                        .font(.subheadline)
                        .foregroundColor(isConnected ? .green : .red)
                }
                
                // Server URL Input
                VStack(alignment: .leading) {
                    Text("Server URL")
                        .font(.headline)
                    
                    TextField("Enter server URL", text: $serverURL)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                // Main Toggle
                VStack {
                    Toggle("Enable Clipboard Sync", isOn: $isEnabled)
                        .font(.title2)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .onChange(of: isEnabled) { enabled in
                            if enabled {
                                clipboardManager.connect(to: serverURL)
                            } else {
                                clipboardManager.disconnect()
                            }
                        }
                    
                    Text(isEnabled ? "Listening for clipboard updates..." : "Tap to start syncing")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Recent Activity
                if !clipboardManager.recentItems.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Recent Items")
                            .font(.headline)
                        
                        List(clipboardManager.recentItems) { item in
                            ClipboardItemRow(item: item)
                        }
                        .frame(height: 200)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("CloudCopier")
            .navigationBarHidden(true)
            .onReceive(clipboardManager.$connectionState) { state in
                isConnected = (state == .connected)
                if !isConnected && isEnabled {
                    isEnabled = false
                }
            }
        }
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: iconForType(item.primaryFormat))
                    .foregroundColor(.blue)
                
                Text(item.primaryFormat.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(formatDate(item.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(item.previewText)
                .font(.subheadline)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
    
    private func iconForType(_ type: String) -> String {
        switch type {
        case "text": return "textformat"
        case "html": return "chevron.left.forwardslash.chevron.right"
        case "rtf": return "doc.richtext"
        case "image": return "photo"
        case "files": return "folder"
        default: return "doc"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    ContentView()
        .environmentObject(ClipboardManager())
}