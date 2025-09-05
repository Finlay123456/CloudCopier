//
//  ContentView.swift
//  CloudCopier
//
//  Created by Finlay Cooper on 2025-07-27.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @EnvironmentObject var clipboardManager: ClipboardManager
    @EnvironmentObject var serverManager: ServerManager
    @EnvironmentObject var notificationManager: NotificationManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Status Panel - matching Windows app
                VStack(spacing: 8) {
                    HStack {
                        Button(action: {
                            clipboardManager.toggleMonitoring()
                        }) {
                            Text(clipboardManager.isMonitoring ? "Pause" : "Unpause")
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                        }
                        
                        // Status indicator
                        Circle()
                            .fill(clipboardManager.isMonitoring ? Color.green : Color.red)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text("●")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(clipboardManager.isMonitoring ? .green : .red)
                            )
                        
                        Spacer()
                        
                        // Connection status
                        Text(serverManager.connectionStatus)
                            .font(.caption)
                            .foregroundColor(serverManager.connectionStatus == "Connected" ? .green : .orange)
                    }
                    
                    HStack {
                        Text("Mode: Send & Receive")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                
                // Content Panel - matching Windows app
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(clipboardManager.statusMessage)
                            .font(.body)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                        
                        // App info section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Clipboard Sync")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text("Server: \(AppConfig.serverUrl)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Polling every \(Int(AppConfig.pollingInterval))s")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        
                        // Instructions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How to use:")
                                .font(.headline)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Copy content on any device", systemImage: "doc.on.clipboard")
                                Label("Content syncs automatically", systemImage: "arrow.triangle.2.circlepath")
                                Label("Tap 'Copy' when notified", systemImage: "bell.badge")
                                Label("Paste anywhere on this device", systemImage: "doc.on.clipboard.fill")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        
                        Spacer(minLength: 50)
                    }
                    .padding()
                }
                .background(Color.gray.opacity(0.1))
            }
        }
        .navigationTitle("Clipboard Sync")
        .overlay(
            // Custom alert overlay
            ClipboardAlert()
                .environmentObject(notificationManager)
        )
        .onAppear {
            // Start services if not already started
            if !serverManager.isPolling {
                serverManager.startPolling()
            }
            if !clipboardManager.isMonitoring {
                clipboardManager.startMonitoring()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(ClipboardManager())
            .environmentObject(ServerManager())
            .environmentObject(NotificationManager())
    }
}
