import Foundation
import CoreLocation
import UIKit

// MARK: - Friend Data Model

struct FriendData: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    let locations: [ExportableLocationData.ExportableLocation]
    let dateImported: Date
    let dateRange: ExportableLocationData.DateRange?
    var isVisible: Bool
    var color: String
    var emoji: String
    var profileImageData: Data?
    
    init(id: UUID = UUID(), name: String, locations: [ExportableLocationData.ExportableLocation], dateImported: Date = Date(), dateRange: ExportableLocationData.DateRange?, isVisible: Bool = true, color: String = "#FF0000", emoji: String = "⭐", profileImageData: Data? = nil) {
        self.id = id
        self.name = name
        self.locations = locations
        self.dateImported = dateImported
        self.dateRange = dateRange
        self.isVisible = isVisible
        self.color = color
        self.emoji = emoji
        self.profileImageData = profileImageData
    }
    static func == (lhs: FriendData, rhs: FriendData) -> Bool {
           return lhs.id == rhs.id &&
                  lhs.name == rhs.name &&
                  lhs.isVisible == rhs.isVisible &&
                  lhs.color == rhs.color &&
                  lhs.emoji == rhs.emoji &&
                  lhs.profileImageData == rhs.profileImageData
           // Note: We skip locations/dateRange for performance since ID should be unique
       }
    
    var coordinates: [CLLocationCoordinate2D] {
        return locations.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }
    
    var timestamps: [Date] {
        return locations.map { $0.timestamp }
    }
}

// MARK: - Persistence Manager

class PersistenceManager {
    static let shared = PersistenceManager()
    
    private let friendsKey = "SavedFriends"
    private let userDataKey = "UserLocationData"
    private let thumbnailsCacheKey = "ThumbnailsCache"
    private let allPhotosAtLocationKey = "AllPhotosAtLocation"
    private let lastVideoExportKey = "LastVideoExport"
    private let lastShareImageKey = "LastShareImage"
    
    private init() {}
    
    // MARK: - File Manager Helpers
    
    private func getCacheDirectory() -> URL {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("MappedCache", isDirectory: true)
    }
    
    private func ensureCacheDirectoryExists() {
        let cacheDir = getCacheDirectory()
        if !FileManager.default.fileExists(atPath: cacheDir.path) {
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            print("Created cache directory: \(cacheDir.path)")
        }
    }
    
    // MARK: - Friend Data Management
    
    func saveFriends(_ friends: [FriendData]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(friends)
            UserDefaults.standard.set(data, forKey: friendsKey)
            print("Saved \(friends.count) friends to storage")
        } catch {
            print("❌ Failed to save friends: \(error)")
        }
    }
    
    func loadFriends() -> [FriendData] {
        guard let data = UserDefaults.standard.data(forKey: friendsKey) else {
            print("ℹ️ No saved friends found")
            return []
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let friends = try decoder.decode([FriendData].self, from: data)
            print("Loaded \(friends.count) friends from storage")
            return friends
        } catch {
            print("❌ Failed to load friends: \(error)")
            return []
        }
    }
    
    func addFriend(_ friend: FriendData) {
        var friends = loadFriends()
        friends.append(friend)
        saveFriends(friends)
    }
    
    func updateFriend(_ friend: FriendData) {
        var friends = loadFriends()
        if let index = friends.firstIndex(where: { $0.id == friend.id }) {
            friends[index] = friend
            saveFriends(friends)
            print("Updated friend: \(friend.name)")
        }
    }
    
    func deleteFriend(id: UUID) {
        var friends = loadFriends()
        friends.removeAll(where: { $0.id == id })
        saveFriends(friends)
        print("Deleted friend with id: \(id)")
    }
    
    func toggleFriendVisibility(id: UUID) {
        var friends = loadFriends()
        if let index = friends.firstIndex(where: { $0.id == id }) {
            friends[index].isVisible.toggle()
            saveFriends(friends)
            print("Toggled visibility for: \(friends[index].name)")
        }
    }
    
    func clearAllFriends() {
        UserDefaults.standard.removeObject(forKey: friendsKey)
        print("Cleared all friends")
    }
    
    // MARK: - User Data Management
    
    func saveUserData(locations: [CLLocationCoordinate2D], timestamps: [Date]) {
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
        
        do {
            let data = try encoder.encode(exportData)
            UserDefaults.standard.set(data, forKey: userDataKey)
            print("Saved user data (\(locations.count) locations)")
        } catch {
            print("❌ Failed to save user data: \(error)")
        }
    }
    
    func loadUserData() -> (locations: [CLLocationCoordinate2D], timestamps: [Date])? {
        guard let data = UserDefaults.standard.data(forKey: userDataKey) else {
            print("ℹ️ No saved user data found")
            return nil
        }
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            let exportData = try decoder.decode(ExportableLocationData.self, from: data)
            
            let locations = exportData.locations.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
            let timestamps = exportData.locations.map { $0.timestamp }
            
            print("Loaded user data (\(locations.count) locations)")
            return (locations, timestamps)
        } catch {
            print("❌ Failed to load user data: \(error)")
            return nil
        }
    }
    
    func clearUserData() {
        UserDefaults.standard.removeObject(forKey: userDataKey)
        print("Cleared user data")
    }
    
    // MARK: - Image Caching
    
    func cacheThumbnails(_ thumbnails: [UIImage]) {
        ensureCacheDirectoryExists()
        let cacheDir = getCacheDirectory()
        let thumbnailsDir = cacheDir.appendingPathComponent("thumbnails", isDirectory: true)
        
        try? FileManager.default.removeItem(at: thumbnailsDir)
        try? FileManager.default.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)
        
        for (index, thumbnail) in thumbnails.enumerated() {
            autoreleasepool {
                if let data = thumbnail.jpegData(compressionQuality: 0.7) {
                    let fileURL = thumbnailsDir.appendingPathComponent("\(index).jpg")
                    try? data.write(to: fileURL)
                }
            }
            
            // Log progress
            if index % 50 == 0 {
                print("📦 Cached \(index)/\(thumbnails.count) thumbnails...")
            }
        }
        
        UserDefaults.standard.set(thumbnails.count, forKey: thumbnailsCacheKey)
        print("✅ Cached \(thumbnails.count) thumbnails")
    }
    func loadCachedThumbnails() -> [UIImage]? {
        guard let count = UserDefaults.standard.value(forKey: thumbnailsCacheKey) as? Int else {
            print("ℹ️ No cached thumbnails found")
            return nil
        }
        
        let cacheDir = getCacheDirectory()
        let thumbnailsDir = cacheDir.appendingPathComponent("thumbnails", isDirectory: true)
        
        var thumbnails: [UIImage] = []
        for index in 0..<count {
            let fileURL = thumbnailsDir.appendingPathComponent("\(index).jpg")
            if let data = try? Data(contentsOf: fileURL),
               let image = UIImage(data: data) {
                thumbnails.append(image)
            } else {
                print("⚠️ Failed to load thumbnail at index \(index)")
                return nil
            }
        }
        
        print("Loaded \(thumbnails.count) cached thumbnails")
        return thumbnails
    }
    
    func cacheAllPhotosAtLocation(_ allPhotos: [[UIImage]]) {
        ensureCacheDirectoryExists()
        let cacheDir = getCacheDirectory()
        let photosDir = cacheDir.appendingPathComponent("allPhotos", isDirectory: true)
        
        try? FileManager.default.removeItem(at: photosDir)
        try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
        
        var structure: [Int] = []

        for (locationIndex, photosAtLocation) in allPhotos.enumerated() {
            autoreleasepool {  // ← ADD THIS LINE
                let locationDir = photosDir.appendingPathComponent("\(locationIndex)", isDirectory: true)
                try? FileManager.default.createDirectory(at: locationDir, withIntermediateDirectories: true)
                
                for (photoIndex, photo) in photosAtLocation.enumerated() {
                    autoreleasepool {  // ← ADD THIS LINE
                        if let data = photo.jpegData(compressionQuality: 0.7) {
                            let fileURL = locationDir.appendingPathComponent("\(photoIndex).jpg")
                            try? data.write(to: fileURL)
                        }
                    }  // ← Memory freed here after each photo
                }
                
                structure.append(photosAtLocation.count)
            }  // ← Memory freed here after each location
            
            // Optional: Log progress
            if locationIndex % 50 == 0 {
                print("📦 Cached \(locationIndex)/\(allPhotos.count) locations...")
            }
        }
        
        if let data = try? JSONEncoder().encode(structure) {
            UserDefaults.standard.set(data, forKey: allPhotosAtLocationKey)
        }
        
        print("✅ Cached photos at \(allPhotos.count) locations")
    }
    
    func loadCachedAllPhotosAtLocation() -> [[UIImage]]? {
        guard let structureData = UserDefaults.standard.data(forKey: allPhotosAtLocationKey),
              let structure = try? JSONDecoder().decode([Int].self, from: structureData) else {
            print("ℹ️ No cached photo structure found")
            return nil
        }
        
        let cacheDir = getCacheDirectory()
        let photosDir = cacheDir.appendingPathComponent("allPhotos", isDirectory: true)
        
        var allPhotos: [[UIImage]] = []
        
        for (locationIndex, photoCount) in structure.enumerated() {
            let locationDir = photosDir.appendingPathComponent("\(locationIndex)", isDirectory: true)
            var photosAtLocation: [UIImage] = []
            
            for photoIndex in 0..<photoCount {
                let fileURL = locationDir.appendingPathComponent("\(photoIndex).jpg")
                if let data = try? Data(contentsOf: fileURL),
                   let image = UIImage(data: data) {
                    photosAtLocation.append(image)
                } else {
                    print("⚠️ Failed to load photo at location \(locationIndex), photo \(photoIndex)")
                    return nil
                }
            }
            
            allPhotos.append(photosAtLocation)
        }
        
        print("Loaded cached photos at \(allPhotos.count) locations")
        return allPhotos
    }
    
    // MARK: - Video Export Caching
    
    func cacheLastVideoExport(url: URL, statistics: [String: String]) {
        ensureCacheDirectoryExists()
        let cacheDir = getCacheDirectory()
        let videoURL = cacheDir.appendingPathComponent("last_export.mp4")
        
        try? FileManager.default.removeItem(at: videoURL)
        try? FileManager.default.copyItem(at: url, to: videoURL)
        
        let metadata: [String: Any] = [
            "url": videoURL.path,
            "timestamp": Date().timeIntervalSince1970,
            "statistics": statistics
        ]
        UserDefaults.standard.set(metadata, forKey: lastVideoExportKey)
        
        print("Cached last video export")
    }
    
    func loadLastVideoExport() -> (url: URL, statistics: [String: String], timestamp: Date)? {
        guard let metadata = UserDefaults.standard.dictionary(forKey: lastVideoExportKey),
              let urlPath = metadata["url"] as? String,
              let timestamp = metadata["timestamp"] as? TimeInterval,
              let statistics = metadata["statistics"] as? [String: String] else {
            print("ℹ️ No cached video export found")
            return nil
        }
        
        let url = URL(fileURLWithPath: urlPath)
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("⚠️ Cached video file not found")
            return nil
        }
        
        print("Loaded cached video export")
        return (url, statistics, Date(timeIntervalSince1970: timestamp))
    }
    
    // MARK: - Share Image Caching
    
    func cacheLastShareImage(_ image: UIImage, theme: String, statistics: [String: String]) {
        ensureCacheDirectoryExists()
        let cacheDir = getCacheDirectory()
        let imageURL = cacheDir.appendingPathComponent("last_share_image.jpg")
        
        if let data = image.jpegData(compressionQuality: 0.9) {
            try? data.write(to: imageURL)
            
            let metadata: [String: Any] = [
                "url": imageURL.path,
                "timestamp": Date().timeIntervalSince1970,
                "theme": theme,
                "statistics": statistics
            ]
            UserDefaults.standard.set(metadata, forKey: lastShareImageKey)
            
            print("Cached last share image")
        }
    }
    
    func loadLastShareImage() -> (image: UIImage, theme: String, statistics: [String: String], timestamp: Date)? {
        guard let metadata = UserDefaults.standard.dictionary(forKey: lastShareImageKey),
              let urlPath = metadata["url"] as? String,
              let timestamp = metadata["timestamp"] as? TimeInterval,
              let theme = metadata["theme"] as? String,
              let statistics = metadata["statistics"] as? [String: String] else {
            print("ℹ️ No cached share image found")
            return nil
        }
        
        let url = URL(fileURLWithPath: urlPath)
        guard let data = try? Data(contentsOf: url),
              let image = UIImage(data: data) else {
            print("⚠️ Cached share image file not found")
            return nil
        }
        
        print("Loaded cached share image")
        return (image, theme, statistics, Date(timeIntervalSince1970: timestamp))
    }
    
    // MARK: - Cache Clearing
    
    func clearImageCache() {
        let cacheDir = getCacheDirectory()
        try? FileManager.default.removeItem(at: cacheDir.appendingPathComponent("thumbnails", isDirectory: true))
        try? FileManager.default.removeItem(at: cacheDir.appendingPathComponent("allPhotos", isDirectory: true))
        UserDefaults.standard.removeObject(forKey: thumbnailsCacheKey)
        UserDefaults.standard.removeObject(forKey: allPhotosAtLocationKey)
        print("Cleared image cache")
    }
    
    func clearVideoCache() {
        let cacheDir = getCacheDirectory()
        try? FileManager.default.removeItem(at: cacheDir.appendingPathComponent("last_export.mp4"))
        UserDefaults.standard.removeObject(forKey: lastVideoExportKey)
        print("Cleared video cache")
    }
    
    func clearShareImageCache() {
        let cacheDir = getCacheDirectory()
        try? FileManager.default.removeItem(at: cacheDir.appendingPathComponent("last_share_image.jpg"))
        UserDefaults.standard.removeObject(forKey: lastShareImageKey)
        print("Cleared share image cache")
    }
    
    func clearAllCaches() {
        let cacheDir = getCacheDirectory()
        try? FileManager.default.removeItem(at: cacheDir)
        UserDefaults.standard.removeObject(forKey: thumbnailsCacheKey)
        UserDefaults.standard.removeObject(forKey: allPhotosAtLocationKey)
        UserDefaults.standard.removeObject(forKey: lastVideoExportKey)
        UserDefaults.standard.removeObject(forKey: lastShareImageKey)
        UserDefaults.standard.removeObject(forKey: "VideoPhotosCache") 
        print("Cleared all caches")
    }
    
    // MARK: - Helper Methods
    
    static func getEmojiForIndex(_ index: Int) -> String {
        let emojis = [
            "⭐", "✨", "🌟", "💫", "🔥", "💥", "⚡", "🌈", "☀️", "🌙",
            "🎨", "🎭", "🎪", "🎯", "🎲", "🎮", "🎸", "🎺", "🎻", "🎹",
            "⚽", "🏀", "🏈", "⚾", "🎾", "🏐", "🏓", "🏸", "🏒", "🏑",
            "🌸", "🌺", "🌻", "🌷", "🌹", "🌴", "🌲", "🌵", "🍀", "🌿",
            "🐶", "🐱", "🐭", "🐹", "🐰", "🦊", "🐻", "🐼", "🐨", "🐯",
            "🦁", "🐮", "🐷", "🐸", "🐵", "🦆", "🦉", "🦋", "🐛", "🐞",
            "🍎", "🍊", "🍋", "🍌", "🍉", "🍇", "🍓", "🍑", "🍒", "🥥",
            "🚀", "✈️", "🚁", "🛸", "🚂", "🚗", "🚙", "🏎️", "🚕", "🚌",
            "🏠", "🏰", "🗽", "🗼", "⛺", "🏖️", "🏔️", "⛰️", "🌋", "🗻",
            "💎", "👑", "🏆", "🎖️", "🏅", "⚔️", "🛡️", "🔮", "💰", "🎓"
        ]
        return emojis[index % emojis.count]
    }

    static func getColorForIndex(_ index: Int) -> String {
        let colors = [
            "#FF0000", "#00FF00", "#0000FF", "#FFFF00", "#FF00FF",
            "#00FFFF", "#FF8800", "#8800FF", "#FF0088", "#00FF88",
            "#CC0000", "#00CC00", "#0000CC", "#CCCC00", "#CC00CC",
            "#00CCCC", "#CC6600", "#6600CC", "#CC0066", "#00CC66",
            "#FF6666", "#66FF66", "#6666FF", "#FFFF66", "#FF66FF",
            "#66FFFF", "#FFAA66", "#AA66FF", "#FF66AA", "#66FFAA",
            "#FFB3BA", "#BAFFC9", "#BAE1FF", "#FFFFBA", "#FFD4BA",
            "#E0BBE4", "#FFDAB9", "#B4E7CE", "#FFC8DD", "#C8FFD4",
            "#8B0000", "#006400", "#00008B", "#8B8B00", "#8B008B",
            "#008B8B", "#8B4500", "#4B0082", "#8B0045", "#008B45"
        ]
        return colors[index % colors.count]
    }
    
    func importFriendFromJSON(_ data: Data, name: String) -> FriendData? {
        guard let result = LocationDataExporter.importLocations(from: data) else {
            return nil
        }
        
        let exportableLocations = zip(result.locations, result.timestamps).map { location, timestamp in
            ExportableLocationData.ExportableLocation(
                latitude: location.latitude,
                longitude: location.longitude,
                timestamp: timestamp
            )
        }
        
        let dateRange: ExportableLocationData.DateRange?
        if let earliest = result.timestamps.min(), let latest = result.timestamps.max() {
            dateRange = ExportableLocationData.DateRange(earliest: earliest, latest: latest)
        } else {
            dateRange = nil
        }
        
        let currentFriendCount = loadFriends().count
        let color = PersistenceManager.getColorForIndex(currentFriendCount)
        let emoji = PersistenceManager.getEmojiForIndex(currentFriendCount)
        
        return FriendData(
            name: name,
            locations: exportableLocations,
            dateRange: dateRange,
            color: color,
            emoji: emoji,
            profileImageData: nil
        )
    }
    
    // MARK: - Video Photo Caching

    /// Cache photos prepared for video export
    func cacheVideoPhotos(_ photos: [(image: UIImage, date: Date, location: CLLocation?)]) {
        ensureCacheDirectoryExists()
        let cacheDir = getCacheDirectory()
        let videoPhotosDir = cacheDir.appendingPathComponent("videoPhotos", isDirectory: true)
        
        try? FileManager.default.removeItem(at: videoPhotosDir)
        try? FileManager.default.createDirectory(at: videoPhotosDir, withIntermediateDirectories: true)
        
        // Save images with autoreleasepool
        for (index, photoItem) in photos.enumerated() {
            autoreleasepool {  // ← ADD THIS
                if let data = photoItem.image.jpegData(compressionQuality: 0.7) {
                    let fileURL = videoPhotosDir.appendingPathComponent("\(index).jpg")
                    try? data.write(to: fileURL)
                }
            }
        }
        
        // Save metadata (dates and locations)
        let metadata = photos.map { photo -> [String: Any] in
            var dict: [String: Any] = [
                "timestamp": photo.date.timeIntervalSince1970
            ]
            if let location = photo.location {
                dict["latitude"] = location.coordinate.latitude
                dict["longitude"] = location.coordinate.longitude
            }
            return dict
        }
        
        if let metadataData = try? JSONSerialization.data(withJSONObject: metadata) {
            let metadataURL = videoPhotosDir.appendingPathComponent("metadata.json")
            try? metadataData.write(to: metadataURL)
        }
        
        UserDefaults.standard.set(photos.count, forKey: "VideoPhotosCache")
        print("Cached \(photos.count) photos for video export")
    }

    /// Load cached photos for video export
    func loadCachedVideoPhotos() -> [(image: UIImage, date: Date, location: CLLocation?)]? {
        guard let count = UserDefaults.standard.value(forKey: "VideoPhotosCache") as? Int else {
            print("ℹ️ No cached video photos found")
            return nil
        }
        
        let cacheDir = getCacheDirectory()
        let videoPhotosDir = cacheDir.appendingPathComponent("videoPhotos", isDirectory: true)
        let metadataURL = videoPhotosDir.appendingPathComponent("metadata.json")
        
        // Load metadata
        guard let metadataData = try? Data(contentsOf: metadataURL),
              let metadataArray = try? JSONSerialization.jsonObject(with: metadataData) as? [[String: Any]] else {
            print("⚠️ Failed to load video photos metadata")
            return nil
        }
        
        var photos: [(image: UIImage, date: Date, location: CLLocation?)] = []
        
        for index in 0..<count {
            let fileURL = videoPhotosDir.appendingPathComponent("\(index).jpg")
            
            guard let imageData = try? Data(contentsOf: fileURL),
                  let image = UIImage(data: imageData),
                  index < metadataArray.count else {
                print("⚠️ Failed to load video photo at index \(index)")
                return nil
            }
            
            let metadata = metadataArray[index]
            guard let timestamp = metadata["timestamp"] as? TimeInterval else {
                print("⚠️ Invalid metadata at index \(index)")
                return nil
            }
            
            let date = Date(timeIntervalSince1970: timestamp)
            
            var location: CLLocation?
            if let lat = metadata["latitude"] as? Double,
               let lon = metadata["longitude"] as? Double {
                location = CLLocation(latitude: lat, longitude: lon)
            }
            
            photos.append((image, date, location))
        }
        
        print("Loaded \(photos.count) cached video photos")
        return photos
    }
    
    // MARK: - Batch Image Caching (Memory-Efficient)

    func prepareForBatchImageCaching() {
        ensureCacheDirectoryExists()
        let cacheDir = getCacheDirectory()
        let thumbnailsDir = cacheDir.appendingPathComponent("thumbnails", isDirectory: true)
        let photosDir = cacheDir.appendingPathComponent("allPhotos", isDirectory: true)
        
        // Clear existing caches
        try? FileManager.default.removeItem(at: thumbnailsDir)
        try? FileManager.default.removeItem(at: photosDir)
        
        // Create fresh directories
        try? FileManager.default.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)
        
        print("📦 Prepared batch caching directories")
    }

    func saveThumbnailBatch(_ batch: [(index: Int, image: UIImage)]) {
        let cacheDir = getCacheDirectory()
        let thumbnailsDir = cacheDir.appendingPathComponent("thumbnails", isDirectory: true)
        
        for item in batch {
            autoreleasepool {
                if let data = item.image.jpegData(compressionQuality: 0.7) {
                    let fileURL = thumbnailsDir.appendingPathComponent("\(item.index).jpg")
                    try? data.write(to: fileURL)
                }
            }
        }
        
        print("💾 Saved batch of \(batch.count) thumbnails to disk")
    }

    func saveLocationPhotosBatch(locationIndex: Int, photos: [(photoIndex: Int, image: UIImage)]) {
        let cacheDir = getCacheDirectory()
        let photosDir = cacheDir.appendingPathComponent("allPhotos", isDirectory: true)
        let locationDir = photosDir.appendingPathComponent("\(locationIndex)", isDirectory: true)
        
        try? FileManager.default.createDirectory(at: locationDir, withIntermediateDirectories: true)
        
        for item in photos {
            autoreleasepool {
                if let data = item.image.jpegData(compressionQuality: 0.7) {
                    let fileURL = locationDir.appendingPathComponent("\(item.photoIndex).jpg")
                    try? data.write(to: fileURL)
                }
            }
        }
        
        print("💾 Saved location \(locationIndex) with \(photos.count) photos to disk")
    }

    // Update metadata after all batches complete
    func finalizeBatchCaching(thumbnailCount: Int, locationStructure: [Int]) {
        UserDefaults.standard.set(thumbnailCount, forKey: thumbnailsCacheKey)
        
        if let data = try? JSONEncoder().encode(locationStructure) {
            UserDefaults.standard.set(data, forKey: allPhotosAtLocationKey)
        }
        
        print("✅ Finalized batch caching: \(thumbnailCount) thumbnails, \(locationStructure.count) locations")
    }
    
    // MARK: - On-Demand Image Loading

    /// Load a single thumbnail from disk
    func loadThumbnail(at index: Int) -> UIImage? {
        let cacheDir = getCacheDirectory()
        let thumbnailsDir = cacheDir.appendingPathComponent("thumbnails", isDirectory: true)
        let fileURL = thumbnailsDir.appendingPathComponent("\(index).jpg")
        
        guard let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }
        
        return image
    }

    /// Load all photos at a specific location from disk
    func loadPhotosAtLocation(at locationIndex: Int) -> [UIImage]? {
        guard let structureData = UserDefaults.standard.data(forKey: allPhotosAtLocationKey),
              let structure = try? JSONDecoder().decode([Int].self, from: structureData),
              locationIndex < structure.count else {
            return nil
        }
        
        let photoCount = structure[locationIndex]
        let cacheDir = getCacheDirectory()
        let photosDir = cacheDir.appendingPathComponent("allPhotos", isDirectory: true)
        let locationDir = photosDir.appendingPathComponent("\(locationIndex)", isDirectory: true)
        
        var images: [UIImage] = []
        
        for photoIndex in 0..<photoCount {
            let fileURL = locationDir.appendingPathComponent("\(photoIndex).jpg")
            if let data = try? Data(contentsOf: fileURL),
               let image = UIImage(data: data) {
                images.append(image)
            } else {
                return nil // If any image fails, return nil
            }
        }
        
        return images
    }
}
