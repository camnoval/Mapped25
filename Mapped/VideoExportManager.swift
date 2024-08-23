// VideoExportManager.swift

import Foundation
import Combine
import UIKit
import CoreLocation
class VideoExportManager: ObservableObject {
    static let shared = VideoExportManager()
    
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    
    private var currentExporter: VideoExporter?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    func startExport(
        exporter: VideoExporter,
        locations: [CLLocationCoordinate2D],
        timestamps: [Date],
        statistics: [String: String],
        friends: [FriendData],
        loadPhotosFromCache: Bool = true  // ← Changed: simple boolean flag
    ) {
        cancelExport()
        
        currentExporter = exporter
        isExporting = true
        
        exporter.$isExporting
            .receive(on: DispatchQueue.main)
            .sink { [weak self] exporting in
                self?.isExporting = exporting
            }
            .store(in: &cancellables)
        
        exporter.$exportProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.exportProgress = progress
            }
            .store(in: &cancellables)
        
        // Subscribe to exportedVideoURL changes
        exporter.$exportedVideoURL
            .receive(on: DispatchQueue.main)
            .sink { url in
                // This ensures the URL updates in the console
                print("Video URL updated: \(url?.absoluteString ?? "nil")")
            }
            .store(in: &cancellables)
        
        exporter.exportVideo(
            locations: locations,
            timestamps: timestamps,
            statistics: statistics,
            friends: friends,
            loadPhotosFromCache: loadPhotosFromCache
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isExporting = false
                self?.currentExporter = nil
                
                switch result {
                case .success(let url):
                    print("Background export completed: \(url)")
                    NotificationManager.shared.scheduleVideoExportNotification()
                    
                    // CRITICAL: Make sure the exporter's URL is set
                    exporter.exportedVideoURL = url
                    
                case .failure(let error):
                    print("Background export failed: \(error)")
                }
            }
        }
    }
    
    func cancelExport() {
        currentExporter?.cancelExport()
        currentExporter = nil
        isExporting = false
        exportProgress = 0.0
        cancellables.removeAll()

        print("Export cancelled by user")
    }
}
