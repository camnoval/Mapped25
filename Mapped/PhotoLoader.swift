import Foundation
import Photos
import CoreLocation
import UIKit
import Combine

class PhotoLoader: ObservableObject {
    // Published properties that views can observe
    @Published var locations: [CLLocationCoordinate2D] = []
    @Published var photoTimeStamps: [Date] = []
    @Published var thumbnails: [UIImage] = []
    @Published var allPhotosAtLocation: [[UIImage]] = []
    @Published var isLoading: Bool = false
    @Published var loadingProgress: Double = 0.0
    @Published var errorMessage: String?
    @Published var showLocationMarkers = true
    
    // MULTIPLE FRIENDS SUPPORT
    @Published var friends: [FriendData] = []
    @Published var showFriendOverlay = false
    @Published var friendAnimationIndices: [UUID: Int] = [:]
    
    // Legacy single friend support (for backwards compatibility)
    @Published var friendLocations: [CLLocationCoordinate2D] = []
    @Published var friendTimestamps: [Date] = []
    
    // Total photos count (before distance filtering)
    @Published var totalPhotosWithLocation: Int = 0
    
    // ALL timestamps for ALL photos with GPS (not filtered)
    @Published var allPhotoTimestamps: [Date] = []
    
    // ALL locations for ALL photos with GPS (not filtered, for distance calculation)
    @Published var allPhotoLocations: [CLLocationCoordinate2D] = []
    
    // Geographic data
    @Published var uniqueStates: Set<String> = []
    @Published var uniqueCountries: Set<String> = []
    
    // Computed statistics
    @Published var totalDistance: Double = 0.0
    @Published var totalActualDistance: Double = 0.0
    @Published var distancesTraveled: [Double] = []
    
    private let minimumDistance: Double = 1609.34 // 1 mile in meters
    private var cancellables = Set<AnyCancellable>()
    
    // DEBUG: Set to nil for current year, or 2024/2023/2022 for testing
    private let debugYear: Int? = nil // Change this to switch years
    
    // Adding Cache Capability - DON'T keep photos in memory, load on-demand
    var videoExporter: VideoExporter?
    
    // Helper to load video photos on-demand
    func getCachedPhotoItemsForVideo() -> [(image: UIImage, date: Date, location: CLLocation?)]? {
        return PersistenceManager.shared.loadCachedVideoPhotos()
    }
    // MARK: - Initialization
    
    init() {
        loadPersistedData()
    }
    
    // MARK: - Persistence
    
    /// Load all persisted data on app launch
    func loadPersistedData() {
        friends = PersistenceManager.shared.loadFriends()
        
        // Initialize animation indices for all friends
        for friend in friends {
            friendAnimationIndices[friend.id] = 0
        }
        
        print("Loaded \(friends.count) friends from storage")
        updateLegacyFriendProperties()
        
        if let userData = PersistenceManager.shared.loadUserData() {
            print("Found cached user data with \(userData.locations.count) locations")
        }
    }
    
    /// Save user data after fetching photos
    func saveUserData() {
        guard !locations.isEmpty else { return }
        PersistenceManager.shared.saveUserData(locations: locations, timestamps: photoTimeStamps)
    }
    
    /// Update legacy single-friend properties from friends array
    private func updateLegacyFriendProperties() {
        if let firstVisibleFriend = friends.first(where: { $0.isVisible }) {
            friendLocations = firstVisibleFriend.coordinates
            friendTimestamps = firstVisibleFriend.timestamps
        } else {
            friendLocations = []
            friendTimestamps = []
        }
    }
    
    func resetAllFriendAnimations() {
        for friend in friends {
            friendAnimationIndices[friend.id] = 0
        }
    }
    // MARK: - Permission Handling
    
    func checkPhotoLibraryPermission() {
        if let debugYear = debugYear {
            let lastDebugYear = UserDefaults.standard.integer(forKey: "LastDebugYear")
            if lastDebugYear != debugYear {
                print("Debug year changed to \(debugYear), clearing cache...")
                PersistenceManager.shared.clearAllCaches()
                PersistenceManager.shared.clearUserData()
                UserDefaults.standard.set(debugYear, forKey: "LastDebugYear")
            }
        }
        
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch status {
        case .authorized, .limited:
            fetchPhotos()
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.errorMessage = "Photo library access denied. Please enable in Settings."
            }
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
                if status == .authorized || status == .limited {
                    self?.fetchPhotos()
                } else {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Photo library access denied."
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    // MARK: - Photo Fetching
    
    func fetchPhotos() {
        // Check if we're testing a different year
        let calendar = Calendar.current
        let currentYear = debugYear ?? calendar.component(.year, from: Date())
        let actualCurrentYear = calendar.component(.year, from: Date())
        
        // If testing a different year, skip cache entirely
        if currentYear != actualCurrentYear {
            print("Testing year \(currentYear), skipping cache...")
            fetchPhotosFromLibrary()
            return
        }
        
        // Try to load cached data first (only for current year)
        if let cachedThumbnails = PersistenceManager.shared.loadCachedThumbnails(),
           let cachedAllPhotos = PersistenceManager.shared.loadCachedAllPhotosAtLocation(),
           let userData = PersistenceManager.shared.loadUserData() {
            
            DispatchQueue.main.async {
                self.thumbnails = cachedThumbnails
                self.allPhotosAtLocation = cachedAllPhotos
                self.locations = userData.locations
                self.photoTimeStamps = userData.timestamps
                
                self.recalculateStatistics()
                self.preparePhotosForVideo()
                
                print("Loaded all data from cache - no need to reload photos!")
            }
            return
        }
        
        // If cache not available, fetch from photo library
        print("Cache not found, fetching from photo library...")
        fetchPhotosFromLibrary()
    }
    
    private func fetchPhotosFromLibrary() {
        DispatchQueue.main.async {
            self.isLoading = true
            self.loadingProgress = 0.0
            self.errorMessage = nil
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let fetchOptions = PHFetchOptions()
            
            let calendar = Calendar.current
            let currentYear = debugYear ?? calendar.component(.year, from: Date())
            
            var startComponents = DateComponents()
            startComponents.year = currentYear
            startComponents.month = 1
            startComponents.day = 1
            startComponents.hour = 0
            startComponents.minute = 0
            startComponents.second = 0
            
            var endComponents = DateComponents()
            endComponents.year = currentYear
            endComponents.month = 12
            endComponents.day = 31
            endComponents.hour = 23
            endComponents.minute = 59
            endComponents.second = 59
            
            guard let startDate = calendar.date(from: startComponents),
                  let endDate = calendar.date(from: endComponents) else {
                return
            }
            
            fetchOptions.predicate = NSPredicate(
                format: "creationDate >= %@ AND creationDate <= %@",
                startDate as CVarArg,
                endDate as CVarArg
            )
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            
            let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            let totalAssets = assets.count
            
            guard totalAssets > 0 else {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.errorMessage = "No photos found from the last year."
                }
                return
            }
            
            // NEW: Initialize batch processing with PersistenceManager
            PersistenceManager.shared.prepareForBatchImageCaching()
            
            var tempLocations: [CLLocationCoordinate2D] = []
            var tempTimestamps: [Date] = []
            var tempAllTimestamps: [Date] = []
            var tempAssets: [PHAsset] = []
            var tempLocationAssets: [[PHAsset]] = []
            var tempDistances: [Double] = []
            var lastLocation: CLLocationCoordinate2D?
            var totalDistance: Double = 0.0
            var totalActualDistance: Double = 0.0
            var photosWithLocationCount = 0
            var currentLocationAssets: [PHAsset] = []
            
            var processedCount = 0
            
            assets.enumerateObjects { asset, index, _ in
                processedCount += 1
                if processedCount % 10 == 0 {
                    DispatchQueue.main.async {
                        self.loadingProgress = Double(processedCount) / Double(totalAssets) * 0.6
                    }
                }
                
                guard let location = asset.location?.coordinate,
                      let timestamp = asset.creationDate else {
                    return
                }
                
                photosWithLocationCount += 1
                tempAllTimestamps.append(timestamp)
                
                if let last = lastLocation {
                    let currentLoc = CLLocation(latitude: location.latitude, longitude: location.longitude)
                    let previousLoc = CLLocation(latitude: last.latitude, longitude: last.longitude)
                    let distance = currentLoc.distance(from: previousLoc)
                    
                    totalActualDistance += distance
                    
                    if distance > self.minimumDistance {
                        if !currentLocationAssets.isEmpty {
                            tempLocationAssets.append(currentLocationAssets)
                        }
                        
                        tempLocations.append(location)
                        tempTimestamps.append(timestamp)
                        tempAssets.append(asset)
                        tempDistances.append(distance)
                        totalDistance += distance
                        lastLocation = location
                        
                        currentLocationAssets = [asset]
                    } else {
                        currentLocationAssets.append(asset)
                    }
                    
                } else {
                    tempLocations.append(location)
                    tempTimestamps.append(timestamp)
                    tempAssets.append(asset)
                    lastLocation = location
                    currentLocationAssets = [asset]
                }
            }
            
            if !currentLocationAssets.isEmpty {
                tempLocationAssets.append(currentLocationAssets)
            }
            
            // NEW: Batch load thumbnails directly to disk (no memory accumulation)
            print("📦 Starting batch thumbnail processing for \(tempAssets.count) assets...")
            self.batchLoadThumbnailsToDisk(assets: tempAssets) { success in
                if !success {
                    DispatchQueue.main.async {
                        self.isLoading = false
                        self.errorMessage = "Failed to cache thumbnails"
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.loadingProgress = 0.8
                }
                
                print("📦 Starting batch allPhotos processing for \(tempLocationAssets.count) locations...")
                self.batchLoadAllPhotosToDisk(locationAssets: tempLocationAssets) { success in
                    if !success {
                        DispatchQueue.main.async {
                            self.isLoading = false
                            self.errorMessage = "Failed to cache photos"
                        }
                        return
                    }
                    
                    let locationStructure = tempLocationAssets.map { $0.count }
                    PersistenceManager.shared.finalizeBatchCaching(
                        thumbnailCount: tempAssets.count,
                        locationStructure: locationStructure
                    )
                    
                    DispatchQueue.main.async {
                        self.locations = tempLocations
                        self.photoTimeStamps = tempTimestamps
                        self.allPhotoTimestamps = tempAllTimestamps
                        self.distancesTraveled = tempDistances
                        self.totalDistance = totalDistance
                        self.totalActualDistance = totalActualDistance
                        self.totalPhotosWithLocation = photosWithLocationCount
                        
                        // Load placeholder arrays (we'll load images on-demand later)
                        self.thumbnails = Array(repeating: self.createPlaceholderImage(), count: tempAssets.count)
                        self.allPhotosAtLocation = tempLocationAssets.map { assets in
                            Array(repeating: self.createPlaceholderImage(), count: assets.count)
                        }
                        
                        self.loadingProgress = 1.0
                        self.isLoading = false
                        
                        // Save user data
                        self.saveUserData()
                        self.preparePhotosForVideo()
                        
                        print("✅ Completed photo loading with batch disk caching")
                    }
                }
            }
        }
    }
    
    // NEW: Batch load thumbnails directly to disk
    private func batchLoadThumbnailsToDisk(
        assets: [PHAsset],
        completion: @escaping (Bool) -> Void
    ) {
        let batchSize = 50 // Process 50 images at a time
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = false
        
        func processBatch(startIndex: Int) {
            guard startIndex < assets.count else {
                completion(true)
                return
            }
            
            let endIndex = min(startIndex + batchSize, assets.count)
            let batchAssets = Array(assets[startIndex..<endIndex])
            
            var batchImages: [(index: Int, image: UIImage)] = []
            let dispatchGroup = DispatchGroup()
            let lock = NSLock()
            
            for (localIndex, asset) in batchAssets.enumerated() {
                let globalIndex = startIndex + localIndex
                dispatchGroup.enter()
                
                imageManager.requestImage(
                    for: asset,
                    targetSize: CGSize(width: 800, height: 800),
                    contentMode: .aspectFill,
                    options: options
                ) { image, _ in
                    if let image = image {
                        lock.lock()
                        batchImages.append((globalIndex, image))
                        lock.unlock()
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .global(qos: .userInitiated)) {
                // Write this batch to disk immediately
                autoreleasepool {
                    PersistenceManager.shared.saveThumbnailBatch(batchImages)
                }
                
                // Update progress
                let progress = 0.6 + (0.2 * Double(endIndex) / Double(assets.count))
                DispatchQueue.main.async {
                    self.loadingProgress = progress
                }
                
                // Process next batch
                processBatch(startIndex: endIndex)
            }
        }
        
        processBatch(startIndex: 0)
    }
    
    // NEW: Batch load all photos at location directly to disk
    private func batchLoadAllPhotosToDisk(
        locationAssets: [[PHAsset]],
        completion: @escaping (Bool) -> Void
    ) {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = false
        
        func processLocation(locationIndex: Int) {
            guard locationIndex < locationAssets.count else {
                completion(true)
                return
            }
            
            let assetsAtLocation = locationAssets[locationIndex]
            var photosAtLocation: [(photoIndex: Int, image: UIImage)] = []
            let dispatchGroup = DispatchGroup()
            let lock = NSLock()
            
            for (photoIndex, asset) in assetsAtLocation.enumerated() {
                dispatchGroup.enter()
                
                imageManager.requestImage(
                    for: asset,
                    targetSize: CGSize(width: 800, height: 800),
                    contentMode: .aspectFill,
                    options: options
                ) { image, _ in
                    if let image = image {
                        lock.lock()
                        photosAtLocation.append((photoIndex, image))
                        lock.unlock()
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .global(qos: .userInitiated)) {
                // Write this location's photos to disk immediately
                autoreleasepool {
                    PersistenceManager.shared.saveLocationPhotosBatch(
                        locationIndex: locationIndex,
                        photos: photosAtLocation
                    )
                }
                
                // Update progress
                let progress = 0.8 + (0.2 * Double(locationIndex + 1) / Double(locationAssets.count))
                DispatchQueue.main.async {
                    self.loadingProgress = progress
                }
                
                // Process next location
                processLocation(locationIndex: locationIndex + 1)
            }
        }
        
        processLocation(locationIndex: 0)
    }
    
    // MARK: Recalculate Statistics from Cached Photos If Stats Change
    private func recalculateStatistics() {
        guard !locations.isEmpty else { return }
        
        var tempDistances: [Double] = []
        var totalDistance: Double = 0.0
        var lastLocation: CLLocationCoordinate2D?
        
        for location in locations {
            if let last = lastLocation {
                let currentLoc = CLLocation(latitude: location.latitude, longitude: location.longitude)
                let previousLoc = CLLocation(latitude: last.latitude, longitude: last.longitude)
                let distance = currentLoc.distance(from: previousLoc)
                
                if distance > minimumDistance {
                    tempDistances.append(distance)
                    totalDistance += distance
                }
            }
            lastLocation = location
        }
        
        self.distancesTraveled = tempDistances
        self.totalDistance = totalDistance
        self.totalActualDistance = totalDistance
        self.totalPhotosWithLocation = allPhotosAtLocation.reduce(0) { $0 + $1.count }
        self.allPhotoTimestamps = photoTimeStamps
    }
    // MARK: - Image Loading
    
    private func loadHighQualityThumbnail(for asset: PHAsset, completion: @escaping (UIImage?) -> Void) {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        
        imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: 800, height: 800),
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            completion(image)
        }
    }
    
    private func createPlaceholderImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            context.cgContext.setFillColor(UIColor.gray.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: size))
        }
    }
    
    // MARK: - Statistics Helpers
    
    func getMostVisitedLocation() -> CLLocationCoordinate2D? {
        guard !locations.isEmpty else { return nil }
        
        var locationClusters: [CLLocationCoordinate2D: Int] = [:]
        let clusterRadius = 5000.0
        
        for location in locations {
            var foundCluster = false
            for (clusterCenter, _) in locationClusters {
                let loc1 = CLLocation(latitude: location.latitude, longitude: location.longitude)
                let loc2 = CLLocation(latitude: clusterCenter.latitude, longitude: clusterCenter.longitude)
                
                if loc1.distance(from: loc2) < clusterRadius {
                    locationClusters[clusterCenter, default: 0] += 1
                    foundCluster = true
                    break
                }
            }
            
            if !foundCluster {
                locationClusters[location] = 1
            }
        }
        
        return locationClusters.max(by: { $0.value < $1.value })?.key
    }
    
    func getDateRange() -> String {
        guard let first = photoTimeStamps.first,
              let last = photoTimeStamps.last else {
            return "N/A"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        return "\(formatter.string(from: first)) - \(formatter.string(from: last))"
    }
    
    // MARK: - Friend Management
    
    /// Import friend from JSON data with name
    func importFriend(from data: Data, name: String) {
        if let friend = PersistenceManager.shared.importFriendFromJSON(data, name: name) {
            DispatchQueue.main.async {
                PersistenceManager.shared.addFriend(friend)
                self.friends = PersistenceManager.shared.loadFriends()
                
                // Initialize animation index for new friend
                self.friendAnimationIndices[friend.id] = 0
                
                self.updateLegacyFriendProperties()
                self.showFriendOverlay = true
                print("Imported friend: \(name) with \(friend.locations.count) locations")
            }
        }
    }
    
    /// Legacy import method for backwards compatibility
    func importFriendData(from data: Data) {
        importFriend(from: data, name: "Friend \(friends.count + 1)")
    }
    
    /// Delete a friend
    func deleteFriend(id: UUID) {
        PersistenceManager.shared.deleteFriend(id: id)
        DispatchQueue.main.async {
            self.friends = PersistenceManager.shared.loadFriends()
            self.updateLegacyFriendProperties()
        }
    }
    
    /// Toggle friend visibility
    func toggleFriendVisibility(id: UUID) {
        PersistenceManager.shared.toggleFriendVisibility(id: id)
        DispatchQueue.main.async {
            self.friends = PersistenceManager.shared.loadFriends()
            self.updateLegacyFriendProperties()
        }
    }
    
    /// Update friend name
    func updateFriendName(id: UUID, newName: String) {
        if let index = friends.firstIndex(where: { $0.id == id }) {
            var updatedFriend = friends[index]
            updatedFriend.name = newName
            PersistenceManager.shared.updateFriend(updatedFriend)
            DispatchQueue.main.async {
                self.friends = PersistenceManager.shared.loadFriends()
            }
        }
    }
    
    /// Clear all friends
    func clearAllFriends() {
        PersistenceManager.shared.clearAllFriends()
        DispatchQueue.main.async {
            self.friends = []
            self.updateLegacyFriendProperties()
        }
    }
    
    /// Get visible friends
    func getVisibleFriends() -> [FriendData] {
        return friends.filter { $0.isVisible }
    }
    
    func updateFriend(_ friend: FriendData) {
        PersistenceManager.shared.updateFriend(friend)
        DispatchQueue.main.async {
            self.friends = PersistenceManager.shared.loadFriends()
            self.updateLegacyFriendProperties()
        }
    }
    func preparePhotosForVideo() {
        guard !locations.isEmpty else { return }
        
        if let cached = PersistenceManager.shared.loadCachedVideoPhotos() {
                print("Video photos already cached (\(cached.count) photos)")
                return
            }
        // Try to load from cache first
        if let cached = PersistenceManager.shared.loadCachedVideoPhotos() {
            DispatchQueue.main.async {
                print("Loaded \(cached.count) photos from cache for video")
            }
            return
        }
        
        print("No cached video photos found, preparing fresh...")
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let fetchOptions = PHFetchOptions()
            
            let calendar = Calendar.current
            let currentYear = debugYear ?? calendar.component(.year, from: Date())
            
            var startComponents = DateComponents()
            startComponents.year = currentYear
            startComponents.month = 1
            startComponents.day = 1
            
            var endComponents = DateComponents()
            endComponents.year = currentYear
            endComponents.month = 12
            endComponents.day = 31
            
            guard let startDate = calendar.date(from: startComponents),
                  let endDate = calendar.date(from: endComponents) else {
                return
            }
            
            fetchOptions.predicate = NSPredicate(
                format: "creationDate >= %@ AND creationDate <= %@",
                startDate as CVarArg,
                endDate as CVarArg
            )
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            
            let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            
            // RESTORED OLD LOGIC: Group photos by day and limit to 5 per day
            var photosByDay: [String: [PHAsset]] = [:]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            for i in 0..<assets.count {
                let asset = assets[i]
                if let date = asset.creationDate, asset.location != nil {
                    let dayKey = dateFormatter.string(from: date)
                    if photosByDay[dayKey] == nil {
                        photosByDay[dayKey] = []
                    }
                    // Keep max 5 per day to prevent clustering
                    if photosByDay[dayKey]!.count < 5 {
                        photosByDay[dayKey]!.append(asset)
                    }
                }
            }
            
            // Flatten to get all assets (max 5 per day)
            var selectedAssets: [PHAsset] = []
            for (_, dayAssets) in photosByDay.sorted(by: { $0.key < $1.key }) {
                selectedAssets.append(contentsOf: dayAssets)
            }
            
            // RESTORED: Load up to 200 photos with stride sampling
            let maxPhotos = min(200, selectedAssets.count)
            let step = max(1, selectedAssets.count / maxPhotos)
            
            print("📸 Distributing \(maxPhotos) photos from \(selectedAssets.count) total (stride: \(step))")
            
            var tempPhotos: [(image: UIImage, date: Date, location: CLLocation?)] = []
            let imageManager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .fastFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = false
            
            let dispatchGroup = DispatchGroup()
            let lock = NSLock()
            
            // Use stride instead of complex per-day distribution
            for i in stride(from: 0, to: selectedAssets.count, by: step) {
                if tempPhotos.count >= maxPhotos { break }
                
                let asset = selectedAssets[i]
                dispatchGroup.enter()
                
                imageManager.requestImage(
                    for: asset,
                    targetSize: CGSize(width: 200, height: 200),
                    contentMode: .aspectFill,
                    options: options
                ) { image, info in
                    if let image = image, let date = asset.creationDate {
                        let opaqueImage = image.removeAlphaChannel() ?? image
                        let location = asset.location
                        lock.lock()
                        tempPhotos.append((opaqueImage, date, location))
                        lock.unlock()
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                // Sort by date to ensure chronological order
                let sortedPhotos = tempPhotos.sorted { $0.date < $1.date }
                
                // CACHE THEM for next time
                PersistenceManager.shared.cacheVideoPhotos(sortedPhotos)
                
                if let first = sortedPhotos.first, let last = sortedPhotos.last {
                    print("Prepared \(sortedPhotos.count) photos spanning from \(first.date) to \(last.date)")
                }
            }
        }
    }
    
    // MARK: - On-Demand Image Loading
    
    /// Load a specific thumbnail from disk cache
    func loadThumbnail(at index: Int, completion: @escaping (UIImage?) -> Void) {
        guard index < thumbnails.count else {
            completion(nil)
            return
        }
        
        // Check if already loaded
        if thumbnails[index].size.width > 100 { // Not a placeholder
            completion(thumbnails[index])
            return
        }
        
        // Load from disk
        DispatchQueue.global(qos: .userInitiated).async {
            if let image = PersistenceManager.shared.loadThumbnail(at: index) {
                DispatchQueue.main.async {
                    self.thumbnails[index] = image
                    completion(image)
                }
            } else {
                completion(nil)
            }
        }
    }
    
    /// Load all photos at a specific location from disk cache
    func loadPhotosAtLocation(at locationIndex: Int, completion: @escaping ([UIImage]?) -> Void) {
        guard locationIndex < allPhotosAtLocation.count else {
            completion(nil)
            return
        }
        
        // Check if already loaded (check first image)
        if !allPhotosAtLocation[locationIndex].isEmpty,
           allPhotosAtLocation[locationIndex][0].size.width > 100 {
            completion(allPhotosAtLocation[locationIndex])
            return
        }
        
        // Load from disk
        DispatchQueue.global(qos: .userInitiated).async {
            if let images = PersistenceManager.shared.loadPhotosAtLocation(at: locationIndex) {
                DispatchQueue.main.async {
                    self.allPhotosAtLocation[locationIndex] = images
                    completion(images)
                }
            } else {
                completion(nil)
            }
        }
    }
    
    /// Preload thumbnails for a range (for smooth scrolling)
    func preloadThumbnails(in range: Range<Int>) {
        for index in range where index < thumbnails.count {
            loadThumbnail(at: index) { _ in }
        }
    }
    
    // MARK: - Photo Deletion
    
    func deleteIndividualPhoto(locationIndex: Int, photoIndex: Int) {
        guard locationIndex < allPhotosAtLocation.count,
              photoIndex < allPhotosAtLocation[locationIndex].count else { return }
        
        // If this is the only photo at this location, remove the entire location
        if allPhotosAtLocation[locationIndex].count == 1 {
            locations.remove(at: locationIndex)
            photoTimeStamps.remove(at: locationIndex)
            thumbnails.remove(at: locationIndex)
            allPhotosAtLocation.remove(at: locationIndex)
        } else {
            // Just remove this specific photo
            allPhotosAtLocation[locationIndex].remove(at: photoIndex)
        }
        
        recalculateStatistics()
        saveUserData()
        
        print("✅ Deleted photo at location \(locationIndex), photo \(photoIndex)")
    }
    
    func deleteMultiplePhotos(_ photosToDelete: [(locationIndex: Int, photoIndex: Int)]) {
        // Group deletions by location and sort by photoIndex descending to avoid index shifting
        var groupedByLocation: [Int: [Int]] = [:]
        
        for (locIndex, photoIndex) in photosToDelete {
            if groupedByLocation[locIndex] == nil {
                groupedByLocation[locIndex] = []
            }
            groupedByLocation[locIndex]!.append(photoIndex)
        }
        
        // Sort photo indices in descending order for each location
        for (locIndex, _) in groupedByLocation {
            groupedByLocation[locIndex]?.sort(by: >)
        }
        
        // Track locations that will be empty after deletion
        var locationsToRemove: Set<Int> = []
        
        // Delete photos from each location
        for (locIndex, photoIndices) in groupedByLocation.sorted(by: { $0.key > $1.key }) {
            guard locIndex < allPhotosAtLocation.count else { continue }
            
            // If we're deleting all photos at this location, mark it for removal
            if photoIndices.count == allPhotosAtLocation[locIndex].count {
                locationsToRemove.insert(locIndex)
            } else {
                // Delete individual photos
                for photoIndex in photoIndices {
                    if photoIndex < allPhotosAtLocation[locIndex].count {
                        allPhotosAtLocation[locIndex].remove(at: photoIndex)
                    }
                }
            }
        }
        
        // Remove entire locations that are now empty (in descending order)
        for locIndex in locationsToRemove.sorted(by: >) {
            locations.remove(at: locIndex)
            photoTimeStamps.remove(at: locIndex)
            thumbnails.remove(at: locIndex)
            allPhotosAtLocation.remove(at: locIndex)
        }
        
        recalculateStatistics()
        saveUserData()
        
        print("✅ Deleted \(photosToDelete.count) photos")
    }
    
    func reloadAllPhotos() {
        // Clear current data
        locations.removeAll()
        photoTimeStamps.removeAll()
        thumbnails.removeAll()
        allPhotosAtLocation.removeAll()
        
        // Clear cache
        PersistenceManager.shared.clearAllCaches()
        PersistenceManager.shared.clearUserData()
        
        // Reload from library
        checkPhotoLibraryPermission()
        
        print("🔄 Reloading all photos from library")
    }
} 
// MARK: - UIImage Extension to Remove Alpha

extension UIImage {
    /// Converts an image with unnecessary alpha channel to opaque format
    func removeAlphaChannel() -> UIImage? {
        guard let cgImage = self.cgImage else { return nil }
        
        // Check if image already has no alpha
        let alphaInfo = cgImage.alphaInfo
        if alphaInfo == .none || alphaInfo == .noneSkipFirst || alphaInfo == .noneSkipLast {
            return self // Already opaque
        }
        
        // Create opaque bitmap context
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return nil
        }
        
        // Draw image into opaque context
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Create new opaque image
        guard let newCGImage = context.makeImage() else { return nil }
        return UIImage(cgImage: newCGImage, scale: self.scale, orientation: self.imageOrientation)
    }
}
