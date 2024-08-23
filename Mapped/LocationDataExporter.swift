//
//  LocationDataExporter.swift
//  Mapped
//
//  Created by Noval, Cameron on 10/27/25.
//

import Foundation
import CoreLocation
import UniformTypeIdentifiers
// MARK: - Shareable Journey Data (with sender name)

struct ShareableJourneyData: Codable {
    let senderName: String
    let exportData: ExportableLocationData
}

// MARK: - Exportable Location Data Structure

struct ExportableLocationData: Codable {
    let locations: [ExportableLocation]
    let exportDate: Date
    let totalLocations: Int
    let dateRange: DateRange?
    
    struct ExportableLocation: Codable {
        let latitude: Double
        let longitude: Double
        let timestamp: Date
    }
    
    struct DateRange: Codable {
        let earliest: Date
        let latest: Date
    }
}

// MARK: - Location Data Exporter

class LocationDataExporter {
    
    // Export locations to JSON data
    static func exportLocations(locations: [CLLocationCoordinate2D], timestamps: [Date]) -> Data? {
        guard locations.count == timestamps.count else {
            print("Locations and timestamps count mismatch")
            return nil
        }
        
        let exportableLocations = zip(locations, timestamps).map { location, timestamp in
            ExportableLocationData.ExportableLocation(
                latitude: location.latitude,
                longitude: location.longitude,
                timestamp: timestamp
            )
        }
        
        let dateRange: ExportableLocationData.DateRange?
        if let earliest = timestamps.min(), let latest = timestamps.max() {
            dateRange = ExportableLocationData.DateRange(earliest: earliest, latest: latest)
        } else {
            dateRange = nil
        }
        
        let exportData = ExportableLocationData(
            locations: exportableLocations,
            exportDate: Date(),
            totalLocations: locations.count,
            dateRange: dateRange
        )
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let jsonData = try encoder.encode(exportData)
            return jsonData
        } catch {
            print("Failed to encode location data: \(error)")
            return nil
        }
    }
    
    // Import locations from JSON data
    static func importLocations(from data: Data) -> (locations: [CLLocationCoordinate2D], timestamps: [Date])? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let importData = try decoder.decode(ExportableLocationData.self, from: data)
            
            let locations = importData.locations.map { exportLoc in
                CLLocationCoordinate2D(latitude: exportLoc.latitude, longitude: exportLoc.longitude)
            }
            
            let timestamps = importData.locations.map { $0.timestamp }
            
            print("Successfully imported \(locations.count) locations")
            if let dateRange = importData.dateRange {
                print("Date range: \(dateRange.earliest) to \(dateRange.latest)")
            }
            
            return (locations, timestamps)
        } catch {
            print("Failed to decode location data: \(error)")
            return nil
        }
    }
    
    static func createShareableFile(from data: Data, senderName: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MappedShares", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let sanitizedName = senderName
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "[^A-Za-z0-9_]", with: "", options: .regularExpression)
        
        let fileName = "\(sanitizedName)_Journey.mapped"
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        do {
            try? FileManager.default.removeItem(at: fileURL)
            try data.write(to: fileURL, options: [.atomic])
            
            print("Created shareable file at: \(fileURL)")
            print("Filename: \(fileName)")
            print("File size: \(data.count) bytes")
            
            return fileURL
        } catch {
            print("Failed to write file: \(error)")
            return nil
        }
    }
}

