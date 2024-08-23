//
//  MappedApp.swift
//  Mapped
//
//  Created by Noval, Cam on 8/23/24.
//

import SwiftUI

@main
struct MappedApp: App {
    @StateObject private var fileImportHandler = FileImportHandler()
    
    init() {
        //NotificationManager.shared.requestNotificationPermission() //Called now in NotificationManager when they actually need notifications for the collage completion
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(fileImportHandler)
                .onOpenURL { url in
                    print("🎯 onOpenURL triggered!")
                    print("🎯 URL: \(url)")
                    
                    if url.scheme == "mapped" && url.host == "import" {
                        // File was imported via Quick Look preview button
                        fileImportHandler.handleSharedExtensionImport()
                    } else {
                        // Direct file opening
                        fileImportHandler.handleIncomingFile(url)
                    }
                }
                .onAppear {
                    NotificationManager.shared.clearBadge()
                    print("App launched and ready to receive files")
                }
        }
    }
}

// MARK: - File Import Handler

class FileImportHandler: ObservableObject {
    @Published var pendingImport: (name: String, data: Data)?
    @Published var showImportAlert = false
    private func presentImportAlert(name: String, data: Data) {  // RENAMED
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Add Friend? 🎉",
                message: "📍 \(name) wants to share their 2025 journey with you!",
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            alert.addAction(UIAlertAction(title: "Add Friend", style: .default) { _ in
                print("User confirmed import for: \(name)")
                NotificationCenter.default.post(
                    name: NSNotification.Name("ImportFriend"),
                    object: nil,
                    userInfo: ["name": name, "data": data]
                )
            })
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                var topController = rootVC
                while let presented = topController.presentedViewController {
                    topController = presented
                }
                topController.present(alert, animated: true)
                print("Presented import alert")
            } else {
                print("Failed to find root view controller")
            }
        }
    }
    
    func handleIncomingFile(_ url: URL) {
        print("📥 Received file: \(url.lastPathComponent)")
        print("📂 Path extension: \(url.pathExtension)")
        
        // Accept BOTH .mapped AND .json files (for iOS 16 Messages compatibility)
        let ext = url.pathExtension.lowercased()
        guard ext == "mapped" || (ext == "json" && url.lastPathComponent.contains(".mapped.json")) else {
            print("❌ Not a mapped file, got: .\(url.pathExtension)")
            return
        }
        
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        print("🔓 Security access granted: \(didStartAccessing)")
        
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        var coordinatorError: NSError?
        let coordinator = NSFileCoordinator()
        var fileData: Data?
        
        coordinator.coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinatorError) { newURL in
            do {
                fileData = try Data(contentsOf: newURL)
                print("✅ Successfully read file (\(fileData?.count ?? 0) bytes)")
            } catch {
                print("❌ Failed to read file: \(error)")
            }
        }
        
        if let error = coordinatorError {
            print("❌ File coordinator error: \(error)")
            return
        }
        
        guard var data = fileData else {
            print("❌ No data read from file")
            return
        }
        
        // Strip magic header if present
        let magicHeaders = [
            "MAPPED_JOURNEY_FILE\n".data(using: .utf8)!,
            "MAPPED_JOURNEY_V1\n".data(using: .utf8)!
        ]
        
        for header in magicHeaders {
            if data.starts(with: header) {
                data = data.dropFirst(header.count)
                print("✅ Stripped magic header")
                break
            }
        }
        
        // If it's a .json file, extract the _data field
        if ext == "json" {
            do {
                if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let isWrapped = jsonObject["_mapped_file"] as? Bool,
                   isWrapped == true {
                    print("✅ Detected wrapped Mapped JSON file")
                    
                    // Extract the actual data from the _data field
                    if let dataObject = jsonObject["_data"] {
                        let reEncodedData = try JSONSerialization.data(withJSONObject: dataObject)
                        data = reEncodedData
                        print("✅ Extracted data from JSON wrapper")
                    }
                }
            } catch {
                print("⚠️ Failed to parse JSON wrapper: \(error)")
            }
        }
        
        // Now decode normally
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        if let journeyData = try? decoder.decode(ShareableJourneyData.self, from: data) {
            print("✅ Decoded journey from: \(journeyData.senderName)")
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            if let reEncodedData = try? encoder.encode(journeyData.exportData) {
                presentImportAlert(name: journeyData.senderName, data: reEncodedData)
            }
        } else if let legacyData = try? decoder.decode(ExportableLocationData.self, from: data) {
            print("✅ Decoded legacy journey data")
            
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            
            if let reEncodedData = try? encoder.encode(legacyData) {
                presentImportAlert(name: "Friend", data: reEncodedData)
            }
        } else {
            print("❌ Failed to decode journey data")
        }
    }
    
    func handleSharedExtensionImport() {
        print("📥 Handling shared extension import")
        
        guard let sharedDefaults = UserDefaults(suiteName: "group.com.novalco.mapped") else {
            print("Failed to get shared UserDefaults")
            return
        }
        
        guard let base64String = sharedDefaults.string(forKey: "pendingImportData"),
              let data = Data(base64Encoded: base64String) else {
            print("No pending import data found")
            return
        }
        
        let filename = sharedDefaults.string(forKey: "pendingImportFilename") ?? "import.mapped"
        print("Found pending import: \(filename) (\(data.count) bytes)")
        
        // Create a temporary file URL for processing
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        
        do {
            try data.write(to: tempURL)
            print("Wrote temp file: \(tempURL.path)")
            
            // Process the file
            handleIncomingFile(tempURL)
            
            // Clean up
            try? FileManager.default.removeItem(at: tempURL)
            sharedDefaults.removeObject(forKey: "pendingImportData")
            sharedDefaults.removeObject(forKey: "pendingImportFilename")
            sharedDefaults.synchronize()
            
            print("Cleaned up temp file and shared defaults")
        } catch {
            print("Failed to process temp file: \(error)")
        }
    }

}
