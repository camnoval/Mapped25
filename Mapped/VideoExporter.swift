import Foundation
import AVFoundation
import UIKit
import CoreLocation
import MapKit
import Photos
import UserNotifications
import SwiftUI

class VideoExporter: ObservableObject {
    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0
    @Published var exportError: String?
    @Published var exportedVideoURL: URL?
    
    //User emojis and customization
    private var userEmoji: String {UserDefaults.standard.string(forKey: "userEmoji") ?? "🚶"}
    private var userColor: String {UserDefaults.standard.string(forKey: "userColor") ?? "#33CCBB"}
    private var snapshotUserEmoji: String = ""
    private var snapshotUserColor: String = ""
    private var snapshotUserName: String = ""
    
    //Video variable
    private let videoSize = CGSize(width: 720, height: 1280)  // Fixed 9:16 at 720p
    private let fps: Int32 = 20
    
    // FIXED photo sizes for video (NOT device-dependent)
    private let fixedPhotoSizes: [CGFloat] = [55, 60, 65, 70, 75, 80, 85, 90, 95, 100, 110]
    
    // Fixed layout positions for consistent video
    private let collageStartY: CGFloat = 800
    private let mapHeight: CGFloat = 670
    
    // Photo cache with metadata
    private var photoItems: [(image: UIImage, date: Date, location: CLLocation?)] = []
    private var collageLayout: [(image: UIImage, rect: CGRect, rotation: CGFloat, hasBorder: Bool, appearTime: Double, size: CGFloat, shape: PhotoShape)] = []
    private var prerenderedPhotos: [UIImage] = []
    private var isCancelled = false
    private var shapePathCache: [String: CGPath] = [:]
    
    enum PhotoShape {
        case square
        case circle
        case roundedSquare
        case hexagon
        case triangle
    }
    
    func cancelExport() {
            isCancelled = true
            
            DispatchQueue.main.async {
                self.isExporting = false
                self.exportProgress = 0.0
                self.exportError = "Export cancelled by user"
            }
        
        }
    
    // MARK: - Main Export Function
    
    func exportVideo(
        locations: [CLLocationCoordinate2D],
        timestamps: [Date],
        statistics: [String: String],
        friends: [FriendData] = [],
        loadPhotosFromCache: Bool = true,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        guard !locations.isEmpty else {
            let error = NSError(domain: "VideoExporter", code: -1, userInfo: [NSLocalizedDescriptionKey: "No locations to export"])
            completion(.failure(error))
            return
        }
        
        //SNAPSHOT user preferences at export start (before anything else)
        snapshotUserEmoji = UserDefaults.standard.string(forKey: "userEmoji") ?? "🚶"
        snapshotUserColor = UserDefaults.standard.string(forKey: "userColor") ?? "#0000FF"
        snapshotUserName = UserDefaults.standard.string(forKey: "userName") ?? "You"
        
        isCancelled = false
        
        DispatchQueue.main.async {
            self.isExporting = true
            self.exportProgress = 0.0
            self.exportError = nil
            self.exportedVideoURL = nil 
        }
        
        
        var backgroundTask: UIBackgroundTaskIdentifier = .invalid
        backgroundTask = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                return
            }
            
            let finishWithError: (Error) -> Void = { error in
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.exportError = error.localizedDescription
                    
                    UIApplication.shared.endBackgroundTask(backgroundTask)
                    completion(.failure(error))
                }
            }
            
            let finishSuccessfully: (URL) -> Void = { videoURL in
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.exportProgress = 1.0
                    self.exportedVideoURL = videoURL
                    
                    NotificationManager.shared.scheduleVideoExportNotification()
                    UIApplication.shared.endBackgroundTask(backgroundTask)
                    completion(.success(videoURL))
                }
            }
            
            // Load photos from cache on background thread
            // Load photos from cache on background thread
            if loadPhotosFromCache {
                print("📸 Loading cached photos for video export...")
                
                // Load photos from disk (happens on background thread already)
                if let cached = PersistenceManager.shared.loadCachedVideoPhotos() {
                    // CRITICAL: Validate cache isn't empty
                    if cached.isEmpty {
                        print("⚠️ Cached video photos are empty, falling back to library load")
                        self.loadPhotosWithMetadata(timestamps: timestamps, locations: locations) {
                            self.generateCollageLayout(timestamps: timestamps, locations: locations)
                            self.prerenderPhotoTextures()
                            
                            if self.isCancelled {
                                DispatchQueue.main.async {
                                    self.isExporting = false
                                    UIApplication.shared.endBackgroundTask(backgroundTask)
                                }
                                return
                            }
                            
                            do {
                                let videoURL = try self.createVideo(
                                    locations: locations,
                                    timestamps: timestamps,
                                    statistics: statistics,
                                    friends: friends
                                )
                                
                                // âœ… CRITICAL: Clear photos from memory after export
                                self.photoItems = []
                                self.prerenderedPhotos = []
                                self.collageLayout = []
                                print("Cleared video photos from memory")
                                
                                finishSuccessfully(videoURL)
                            } catch {
                                // Clear memory even on error
                                self.photoItems = []
                                self.prerenderedPhotos = []
                                self.collageLayout = []
                                print("Cleared video photos from memory (after error)")
                                
                                finishWithError(error)
                            }
                        }
                        return
                    }
                    
                    // Cache is valid, use it
                    self.photoItems = cached
                    
                    DispatchQueue.main.async {
                        self.exportProgress = 0.1
                    }
                    
                    if self.isCancelled {
                        DispatchQueue.main.async {
                            self.isExporting = false
                            UIApplication.shared.endBackgroundTask(backgroundTask)
                        }
                        return
                    }
                    
                    self.generateCollageLayout(timestamps: timestamps, locations: locations)
                    self.prerenderPhotoTextures()
                    
                    if self.isCancelled {
                        DispatchQueue.main.async {
                            self.isExporting = false
                            UIApplication.shared.endBackgroundTask(backgroundTask)
                        }
                        return
                    }
                    
                    do {
                        let videoURL = try self.createVideo(
                            locations: locations,
                            timestamps: timestamps,
                            statistics: statistics,
                            friends: friends
                        )
                        
                        // âœ… CRITICAL: Clear photos from memory after export
                        self.photoItems = []
                        self.prerenderedPhotos = []
                        self.collageLayout = []
                        print("Cleared video photos from memory")
                        
                        finishSuccessfully(videoURL)
                    } catch {
                        // Clear memory even on error
                        self.photoItems = []
                        self.prerenderedPhotos = []
                        self.collageLayout = []
                        print("Cleared video photos from memory (after error)")
                        
                        finishWithError(error)
                    }
                    
                } else {
                    // Fallback: load from library if cache doesn't exist
                    print("No cached photos found, loading from library...")
                    self.loadPhotosWithMetadata(timestamps: timestamps, locations: locations) {
                        self.generateCollageLayout(timestamps: timestamps, locations: locations)
                        self.prerenderPhotoTextures()
                        
                        do {
                            let videoURL = try self.createVideo(
                                locations: locations,
                                timestamps: timestamps,
                                statistics: statistics,
                                friends: friends
                            )
                            
                            // Clear memory after fallback too
                            self.photoItems = []
                            self.prerenderedPhotos = []
                            self.collageLayout = []
                            
                            finishSuccessfully(videoURL)
                        } catch {
                            self.photoItems = []
                            self.prerenderedPhotos = []
                            self.collageLayout = []
                            
                            finishWithError(error)
                        }
                    }
                }
            } else {
                // If flag is false, load from library
                print("Loading photos from library (cache disabled)...")
                self.loadPhotosWithMetadata(timestamps: timestamps, locations: locations) {
                    self.generateCollageLayout(timestamps: timestamps, locations: locations)
                    self.prerenderPhotoTextures()
                    
                    do {
                        let videoURL = try self.createVideo(
                            locations: locations,
                            timestamps: timestamps,
                            statistics: statistics,
                            friends: friends
                        )
                        
                        self.photoItems = []
                        self.prerenderedPhotos = []
                        self.collageLayout = []
                        
                        finishSuccessfully(videoURL)
                    } catch {
                        self.photoItems = []
                        self.prerenderedPhotos = []
                        self.collageLayout = []
                        
                        finishWithError(error)
                    }
                }
            }
        }
    }
    
    // MARK: - Load Photos with Location Metadata
    
    private func loadPhotosWithMetadata(timestamps: [Date], locations: [CLLocationCoordinate2D], completion: @escaping () -> Void) {
        let fetchOptions = PHFetchOptions()
        
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        
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
            completion()
            return
        }
        
        fetchOptions.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@",
            startDate as CVarArg,
            endDate as CVarArg
        )
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        
        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        // Collect all photos with location
        var selectedAssets: [PHAsset] = []
        for i in 0..<assets.count {
            let asset = assets[i]
            if asset.location != nil {
                selectedAssets.append(asset)
            }
        }

        // UPDATED LOGIC:
        // - If 400 or fewer photos: use all of them
        // - If more than 400 photos: limit to 3 per day to spread across year
        if selectedAssets.count <= 400 {
            print("📸 Using all \(selectedAssets.count) photos for video (400 or under)")
            // Keep all photos, sorted by date
            selectedAssets.sort { ($0.creationDate ?? Date.distantPast) < ($1.creationDate ?? Date.distantPast) }
        } else {
            print("📸 Filtering \(selectedAssets.count) photos for video - limiting to 3 per day")
            // Group by day and limit to 3 per day
            var photosByDay: [String: [PHAsset]] = [:]
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            for asset in selectedAssets {
                if let date = asset.creationDate {
                    let dayKey = dateFormatter.string(from: date)
                    if photosByDay[dayKey] == nil {
                        photosByDay[dayKey] = []
                    }
                    if photosByDay[dayKey]!.count < 3 {
                        photosByDay[dayKey]!.append(asset)
                    }
                }
            }
            
            // Flatten to get filtered assets
            selectedAssets = []
            for (_, dayAssets) in photosByDay.sorted(by: { $0.key < $1.key }) {
                selectedAssets.append(contentsOf: dayAssets)
            }
        }

        // Load up to 400 photos with stride sampling
        let maxPhotos = min(400, selectedAssets.count)
        let step = max(1, selectedAssets.count / maxPhotos)
        
        var tempPhotos: [(image: UIImage, date: Date, location: CLLocation?)] = []
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = false
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false

        let dispatchGroup = DispatchGroup()
        let lock = NSLock()

        for i in stride(from: 0, to: selectedAssets.count, by: step) {
            if tempPhotos.count >= maxPhotos { break }
            
            let asset = selectedAssets[i]
            dispatchGroup.enter()
            
            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 200, height: 200),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image = image, let date = asset.creationDate {
                    let location = asset.location
                    lock.lock()
                    tempPhotos.append((image, date, location))
                    lock.unlock()
                }
                dispatchGroup.leave()
            }
        }
        
        dispatchGroup.notify(queue: .global(qos: .userInitiated)) {
            self.photoItems = tempPhotos
            
            DispatchQueue.main.async {
                self.exportProgress = 0.1
            }
            
            completion()
        }
    }
    
    // MARK: - Generate Static Collage Layout
    private func generateCollageLayout(timestamps: [Date], locations: [CLLocationCoordinate2D]) {
        guard !photoItems.isEmpty, !timestamps.isEmpty else { return }
        
        // FIXED positions for consistent 720x1280 video on all devices
        let collageHeight: CGFloat = 460  // Fixed: videoSize.height - collageStartY - 20
        let collageWidth: CGFloat = 660   // Fixed: videoSize.width - 60
        let collageX: CGFloat = 30        // Fixed: 30px from left edge
        
        // FIXED photo sizes for 720p (NOT scaled)
        let photoSizes = fixedPhotoSizes
        
        var layout: [(image: UIImage, rect: CGRect, rotation: CGFloat, hasBorder: Bool, appearTime: Double, size: CGFloat, shape: PhotoShape)] = []
        
        let appearTimes = photoItems.map { findAppearTime(for: $0.date, in: timestamps) }
        
        let bleedAmount: CGFloat = 70  // Fixed value
        let extendedHeight = collageHeight + (bleedAmount * 2)
        let extendedWidth = collageWidth + (bleedAmount * 2)
        
        var occupiedRects: [CGRect] = []
        
        for (index, photoItem) in photoItems.enumerated() {
            let photo = photoItem.image
            let appearTime = appearTimes[index]
            let photoSize = photoSizes[index % photoSizes.count]
            
            let shapeIndex = index % 20
            let shape: PhotoShape
            if shapeIndex < 9 {
                shape = .square
            } else if shapeIndex < 18 {
                shape = .roundedSquare
            } else if shapeIndex < 19 {
                shape = .circle
            } else {
                shape = .hexagon
            }
            
            let hasBorder = false
            
            var bestPosition: CGPoint?
            var minOverlap: CGFloat = .infinity
            
            for _ in 0..<5 {
                let x = (collageX - bleedAmount) + CGFloat.random(in: 0...(max(0, extendedWidth - photoSize)))
                let y = (collageStartY - bleedAmount) + CGFloat.random(in: 0...(max(0, extendedHeight - photoSize)))
                
                let testRect = CGRect(x: x, y: y, width: photoSize, height: photoSize)
                
                var totalOverlap: CGFloat = 0
                var hasCollision = false
                
                let startCheck = max(0, occupiedRects.count - 20)
                for i in startCheck..<occupiedRects.count {
                    let occupied = occupiedRects[i]
                    
                    if testRect.intersects(occupied) {
                        let intersection = testRect.intersection(occupied)
                        totalOverlap += intersection.width * intersection.height
                        hasCollision = true
                    }
                }
                
                if !hasCollision {
                    bestPosition = CGPoint(x: x, y: y)
                    break
                }
                
                if totalOverlap < minOverlap {
                    minOverlap = totalOverlap
                    bestPosition = CGPoint(x: x, y: y)
                }
            }
            
            guard let position = bestPosition else { continue }
            
            let rect = CGRect(x: position.x, y: position.y, width: photoSize, height: photoSize)
            occupiedRects.append(rect)
            
            let rotation = shape == .circle ? 0 : CGFloat.random(in: -0.2...0.2)
            
            layout.append((photo, rect, rotation, hasBorder, appearTime, photoSize, shape))
        }
        
        self.collageLayout = layout
    }
    
// MARK: Prerender Helper Function
    private func prerenderPhotoTextures() {
        guard !collageLayout.isEmpty else { return }
        
        print("Pre-rendering \(collageLayout.count) photo textures...")
        
        prerenderedPhotos = collageLayout.map { item in
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: item.size, height: item.size))
            
            return renderer.image { context in
                let ctx = context.cgContext
                let rect = CGRect(x: 0, y: 0, width: item.size, height: item.size)
                
                // Draw shadow
                if item.shape != .circle {
                    ctx.setShadow(
                        offset: CGSize(width: 0, height: 2),
                        blur: 4,
                        color: UIColor.black.withAlphaComponent(0.15).cgColor
                    )
                }
                
                // Clip to shape
                switch item.shape {
                case .square:
                    ctx.clip(to: rect)
                case .circle:
                    ctx.addEllipse(in: rect)
                    ctx.clip()
                case .roundedSquare:
                    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: 15, cornerHeight: 15, transform: nil))
                    ctx.clip()
                case .hexagon:
                    let path = createHexagonPath(in: rect)
                    ctx.addPath(path)
                    ctx.clip()
                case .triangle:
                    let path = createTrianglePath(in: rect)
                    ctx.addPath(path)
                    ctx.clip()
                }
                
                // Draw photo
                item.image.draw(in: rect)
            }
        }
        
        print("  Pre-rendered \(prerenderedPhotos.count) textures")
    }


    // MARK: - Find Appear Time for Photo

    private func findAppearTime(for photoDate: Date, in timestamps: [Date]) -> Double {
        // Find the closest timestamp to this photo
        guard !timestamps.isEmpty else { return 0 }
        
        var closestIndex = 0
        var closestDiff = abs(photoDate.timeIntervalSince(timestamps[0]))
        
        for (index, timestamp) in timestamps.enumerated() {
            let diff = abs(photoDate.timeIntervalSince(timestamp))
            if diff < closestDiff {
                closestDiff = diff
                closestIndex = index
            }
        }
        
        // Return as percentage through the journey
        return Double(closestIndex) / Double(timestamps.count)
    }
    

    // MARK: - Video Creation

    private func createVideo(
        locations: [CLLocationCoordinate2D],
        timestamps: [Date],
        statistics: [String: String],
        friends: [FriendData]
    ) throws -> URL {
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("2025mapped_\(UUID().uuidString).mp4")
        
        guard let videoWriter = try? AVAssetWriter(outputURL: outputURL, fileType: .mp4) else {
            throw NSError(domain: "VideoExporter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create video writer"])
        }
        
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoSize.width,
            AVVideoHeightKey: videoSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 2_000_000,
                AVVideoMaxKeyFrameIntervalKey: 60,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel,
                AVVideoExpectedSourceFrameRateKey: fps,
                AVVideoAllowFrameReorderingKey: false
            ]
        ]
        
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = false
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: videoSize.width,
                kCVPixelBufferHeightKey as String: videoSize.height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
        )
        
        guard videoWriter.canAdd(videoInput) else {
            throw NSError(domain: "VideoExporter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cannot add video input"])
        }
        
        videoWriter.add(videoInput)
        videoWriter.startWriting()
        videoWriter.startSession(atSourceTime: .zero)
        
        //   UPDATED TIMING: Extended map, shortened stats/outro
        let totalFrames = 300  // 15 seconds at 20fps
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
        
        let introFrames = 30           // 1.5s intro
        let mapAnimationFrames = 160   // 8s map animation (extended)
        let mapHoldFrames = 20         // 1s hold
        let statsFrames = 60           // 3s stats (no separate hold)
        let statsHoldFrames = 0        // No hold, they can pause
        let outroFrames = 30           // 1.5s outro (shortened)
        
        var frameCount = 0
        
        let mapData = generateMapSnapshot(locations: locations, friends: friends)
        
        while frameCount < totalFrames {
            autoreleasepool {
                if self.isCancelled {
                    videoInput.markAsFinished()
                    videoWriter.cancelWriting()
                    return
                }
                
                if videoInput.isReadyForMoreMediaData {
                    let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameCount))
                    
                    let currentPhase: VideoPhase
                    let phaseFrame: Int
                    
                    if frameCount < introFrames {
                        currentPhase = .intro
                        phaseFrame = frameCount
                    } else if frameCount < introFrames + mapAnimationFrames {
                        currentPhase = .mapAnimation
                        phaseFrame = frameCount - introFrames
                    } else if frameCount < introFrames + mapAnimationFrames + mapHoldFrames {
                        // Hold the final map
                        currentPhase = .mapAnimation
                        phaseFrame = mapAnimationFrames - 1
                    } else if frameCount < introFrames + mapAnimationFrames + mapHoldFrames + statsFrames {
                        currentPhase = .stats
                        phaseFrame = frameCount - introFrames - mapAnimationFrames - mapHoldFrames
                    } else {
                        currentPhase = .outro
                        phaseFrame = frameCount - introFrames - mapAnimationFrames - mapHoldFrames - statsFrames - statsHoldFrames
                    }
                    
                    if let pixelBuffer = self.createFrame(
                        phase: currentPhase,
                        phaseFrame: phaseFrame,
                        totalPhaseFrames: currentPhase.frameCount(intro: introFrames, map: mapAnimationFrames, stats: statsFrames, outro: outroFrames),
                        locations: locations,
                        statistics: statistics,
                        mapData: mapData,
                        friends: friends
                    ) {
                        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                    }
                    
                    frameCount += 1
                    
                    if frameCount % 10 == 0 {
                        let progress = 0.1 + (0.9 * Double(frameCount) / Double(totalFrames))
                        DispatchQueue.main.async {
                            self.exportProgress = progress
                        }
                    }
                }
            }
        }
        
        videoInput.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        
        videoWriter.finishWriting {
            semaphore.signal()
        }
        
        semaphore.wait()
        
        guard videoWriter.status == .completed else {
            throw videoWriter.error ?? NSError(domain: "VideoExporter", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video export failed"])
        }
        
        return outputURL
    }
    
    // Multi-region support
    private struct MapRegion {
        let locations: [CLLocationCoordinate2D]
        let name: String
        let center: CLLocationCoordinate2D
        let span: MKCoordinateSpan
    }

    // ADD: Region detection function
    private func detectRegions(from allLocations: [CLLocationCoordinate2D]) -> [MapRegion] {
        guard !allLocations.isEmpty else { return [] }
        
        // Simple clustering by distance (10,000km threshold)
        var clusters: [[CLLocationCoordinate2D]] = []
        
        for location in allLocations {
            var addedToCluster = false
            
            for i in 0..<clusters.count {
                // If location is within 10,000km of any location in cluster, add it
                if clusters[i].contains(where: { existingLoc in
                    let loc1 = CLLocation(latitude: location.latitude, longitude: location.longitude)
                    let loc2 = CLLocation(latitude: existingLoc.latitude, longitude: existingLoc.longitude)
                    let distance = loc1.distance(from: loc2)
                    return distance < 10_000_000 // 10,000km threshold
                }) {
                    clusters[i].append(location)
                    addedToCluster = true
                    break
                }
            }
            
            if !addedToCluster {
                clusters.append([location])
            }
        }
        
        // Sort clusters by size (largest first)
        clusters.sort { $0.count > $1.count }
        
        // Create regions
        return clusters.enumerated().map { index, locations in
            let minLat = locations.map(\.latitude).min()!
            let maxLat = locations.map(\.latitude).max()!
            let minLon = locations.map(\.longitude).min()!
            let maxLon = locations.map(\.longitude).max()!
            
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            
            let latPadding = (maxLat - minLat) * 0.2
            let lonPadding = (maxLon - minLon) * 0.2
            
            let span = MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) + latPadding, 0.5),
                longitudeDelta: max((maxLon - minLon) + lonPadding, 0.5)
            )
            
            let regionName = index == 0 ? "Main" : "Region \(index + 1)"
            
            return MapRegion(locations: locations, name: regionName, center: center, span: span)
        }
    }

    // ADD: Check if coordinate is in region
    private func isCoordinate(_ coord: CLLocationCoordinate2D, inRegion region: MapRegion) -> Bool {
        let minLat = region.locations.map(\.latitude).min() ?? 0
        let maxLat = region.locations.map(\.latitude).max() ?? 0
        let minLon = region.locations.map(\.longitude).min() ?? 0
        let maxLon = region.locations.map(\.longitude).max() ?? 0
        
        let latBuffer = (maxLat - minLat) * 0.05
        let lonBuffer = (maxLon - minLon) * 0.05
        
        return coord.latitude >= (minLat - latBuffer) &&
               coord.latitude <= (maxLat + latBuffer) &&
               coord.longitude >= (minLon - lonBuffer) &&
               coord.longitude <= (maxLon + lonBuffer)
    }
    
    // MARK: - Map Snapshot Generation
    
    private func generateMapSnapshot(locations: [CLLocationCoordinate2D], friends: [FriendData]) -> (image: UIImage, snapshot: MKMapSnapshotter.Snapshot, regions: [MapRegion], insetSnapshots: [(region: MapRegion, snapshot: MKMapSnapshotter.Snapshot)])? {
        var allLocations = locations
        
        for friend in friends {
            allLocations.append(contentsOf: friend.coordinates)
        }
        
        guard !allLocations.isEmpty else { return nil }
        
        let regions = detectRegions(from: allLocations)
        print("🗺️ Detected \(regions.count) region(s) for video")
        
        if regions.count == 1 {
            // Single region
            guard let result = generateSingleRegionSnapshot(region: regions[0]) else {
                return nil
            }
            return (result.image, result.snapshot, regions, [])
        } else {
            // Multiple regions
            return generateMultiRegionSnapshot(regions: regions, friends: friends, locations: locations)
        }
    }

    // ADD: Single region snapshot
    private func generateSingleRegionSnapshot(region: MapRegion) -> (image: UIImage, snapshot: MKMapSnapshotter.Snapshot)? {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: region.center, span: region.span)
        options.size = CGSize(width: 700, height: 700)
        options.scale = 1.5
        
        let snapshotter = MKMapSnapshotter(options: options)
        let semaphore = DispatchSemaphore(value: 0)
        var result: (image: UIImage, snapshot: MKMapSnapshotter.Snapshot)?
        
        snapshotter.start { snapshot, error in
            defer { semaphore.signal() }
            guard let snapshot = snapshot else { return }
            result = (snapshot.image, snapshot)
        }
        
        semaphore.wait()
        return result
    }

    // ADD: Multi-region snapshot with insets
    private func generateMultiRegionSnapshot(regions: [MapRegion], friends: [FriendData], locations: [CLLocationCoordinate2D]) -> (image: UIImage, snapshot: MKMapSnapshotter.Snapshot, regions: [MapRegion], insetSnapshots: [(region: MapRegion, snapshot: MKMapSnapshotter.Snapshot)])? {
        guard !regions.isEmpty else { return nil }
        
        let mainRegion = regions[0]
        let insetRegions = Array(regions.dropFirst())
        
        // Generate main snapshot
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: mainRegion.center, span: mainRegion.span)
        options.size = CGSize(width: 700, height: 700)
        options.scale = 1.5
        
        let snapshotter = MKMapSnapshotter(options: options)
        let semaphore = DispatchSemaphore(value: 0)
        var mainSnapshot: MKMapSnapshotter.Snapshot?
        
        snapshotter.start { snapshot, error in
            defer { semaphore.signal() }
            mainSnapshot = snapshot
        }
        semaphore.wait()
        
        guard let mainSnap = mainSnapshot else { return nil }
        
        // Generate inset snapshots
        var insetSnapshots: [(region: MapRegion, snapshot: MKMapSnapshotter.Snapshot)] = []
        
        for insetRegion in insetRegions {
            let insetOptions = MKMapSnapshotter.Options()
            insetOptions.region = MKCoordinateRegion(center: insetRegion.center, span: insetRegion.span)
            insetOptions.size = CGSize(width: 175, height: 175) // Smaller for video
            insetOptions.scale = 1.5
            
            let insetSnapshotter = MKMapSnapshotter(options: insetOptions)
            let insetSemaphore = DispatchSemaphore(value: 0)
            var insetSnap: MKMapSnapshotter.Snapshot?
            
            insetSnapshotter.start { snapshot, error in
                defer { insetSemaphore.signal() }
                insetSnap = snapshot
            }
            insetSemaphore.wait()
            
            if let snap = insetSnap {
                insetSnapshots.append((insetRegion, snap))
            }
        }
        
        // Composite the images
        let compositeImage = createCompositeMapForVideo(
            mainSnapshot: mainSnap,
            mainRegion: mainRegion,
            insetSnapshots: insetSnapshots
        )
        
        return (compositeImage, mainSnap, regions, insetSnapshots)
    }

    // REPLACE createCompositeMapForVideo:
    private func createCompositeMapForVideo(
        mainSnapshot: MKMapSnapshotter.Snapshot,
        mainRegion: MapRegion,
        insetSnapshots: [(region: MapRegion, snapshot: MKMapSnapshotter.Snapshot)]
    ) -> UIImage {
        let size: CGFloat = 700
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1.5
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        
        return renderer.image { context in
            let ctx = context.cgContext
            
            // Draw main map
            mainSnapshot.image.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
            
            // SMART INSET POSITIONING - same positions we'll use in animation
            let insetSize: CGFloat = 175
            let padding: CGFloat = 15
            let mapRect = CGRect(x: 0, y: 0, width: size, height: size)
            
            let positions = calculateSmartInsetPositions(
                mainRegion: mainRegion,
                mainSnapshot: mainSnapshot,
                insetCount: insetSnapshots.count,
                mapRect: mapRect,
                scaledInsetSize: insetSize,
                padding: padding
            )
            
            // Use calculated positions for our insets
            for (index, inset) in insetSnapshots.enumerated() {
                guard index < positions.count else { break }
                
                let position = positions[index]
                let insetRect = CGRect(x: position.x, y: position.y, width: insetSize, height: insetSize)
                
                // Shadow
                ctx.setShadow(offset: CGSize(width: 0, height: 2), blur: 5, color: UIColor.black.withAlphaComponent(0.3).cgColor)
                ctx.setFillColor(UIColor.white.cgColor)
                ctx.fill(insetRect)
                ctx.setShadow(offset: .zero, blur: 0, color: nil)
                
                // Draw inset map
                inset.snapshot.image.draw(in: insetRect)
                
                // Border
                ctx.setStrokeColor(UIColor.white.cgColor)
                ctx.setLineWidth(3)
                ctx.stroke(insetRect)
                
                // Label
                let labelAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                    .foregroundColor: UIColor.white,
                    .backgroundColor: UIColor.black.withAlphaComponent(0.7)
                ]
                let labelText = " \(inset.region.name) " as NSString
                let labelSize = labelText.size(withAttributes: labelAttrs)
                let labelRect = CGRect(
                    x: position.x + 5,
                    y: position.y + 5,
                    width: labelSize.width,
                    height: labelSize.height
                )
                labelText.draw(in: labelRect, withAttributes: labelAttrs)
            }
        }
    }
    
    //Helper function to calculate smart inset positions (add near other helper functions):
    private func calculateSmartInsetPositions(
        mainRegion: MapRegion,
        mainSnapshot: MKMapSnapshotter.Snapshot,
        insetCount: Int,
        mapRect: CGRect,
        scaledInsetSize: CGFloat,
        padding: CGFloat
    ) -> [(x: CGFloat, y: CGFloat)] {
        
        let allPositions: [(x: CGFloat, y: CGFloat)] = [
            (mapRect.maxX - scaledInsetSize - padding, mapRect.minY + padding), // top-right
            (mapRect.maxX - scaledInsetSize - padding, mapRect.maxY - scaledInsetSize - padding), // bottom-right
            (mapRect.minX + padding, mapRect.minY + padding), // top-left
            (mapRect.minX + padding, mapRect.maxY - scaledInsetSize - padding) // bottom-left
        ]
        
        var scoredPositions: [(position: (x: CGFloat, y: CGFloat), score: Int)] = []
        
        for pos in allPositions {
            let testRect = CGRect(x: pos.x, y: pos.y, width: scaledInsetSize, height: scaledInsetSize)
            
            var pointsInArea = 0
            for location in mainRegion.locations {
                let point = mainSnapshot.point(for: location)
                
                // Scale the snapshot point to map coordinates
                let snapshotSize = mainSnapshot.image.size
                let scaleX = mapRect.width / snapshotSize.width
                let scaleY = mapRect.height / snapshotSize.height
                
                let scaledPoint = CGPoint(
                    x: mapRect.minX + (point.x * scaleX),
                    y: mapRect.minY + (point.y * scaleY)
                )
                
                if testRect.contains(scaledPoint) {
                    pointsInArea += 1
                }
            }
            
            scoredPositions.append((position: pos, score: pointsInArea))
        }
        
        scoredPositions.sort { $0.score < $1.score }
        
        return scoredPositions.prefix(insetCount).map { $0.position }
    }
    
    //function to draw connector lines between regions:
    // REPLACE the drawRegionConnectors function with clipping support:
    private func drawRegionConnectors(
        context: CGContext,
        locations: [CLLocationCoordinate2D],
        mainRegion: MapRegion,
        insetSnapshots: [(region: MapRegion, snapshot: MKMapSnapshotter.Snapshot)],
        insetPositions: [(x: CGFloat, y: CGFloat)],
        mainSnapshot: MKMapSnapshotter.Snapshot,
        mapRect: CGRect,
        scaledInsetSize: CGFloat,
        visiblePoints: Int,
        userColor: UIColor
    ) {
        guard visiblePoints > 1 else { return }
        
        // Helper to get point on main map snapshot (even if off-screen)
        func coordinateToMainMapPoint(_ coord: CLLocationCoordinate2D) -> CGPoint {
            let snapshotPoint = mainSnapshot.point(for: coord)
            let snapshotSize = mainSnapshot.image.size
            let scaleX = mapRect.width / snapshotSize.width
            let scaleY = mapRect.height / snapshotSize.height
            
            return CGPoint(
                x: mapRect.minX + (snapshotPoint.x * scaleX),
                y: mapRect.minY + (snapshotPoint.y * scaleY)
            )
        }
        
        // Track region transitions
        for i in 1..<min(visiblePoints, locations.count) {
            let prevLocation = locations[i - 1]
            let currentLocation = locations[i]
            
            let prevInMain = isCoordinate(prevLocation, inRegion: mainRegion)
            let currInMain = isCoordinate(currentLocation, inRegion: mainRegion)
            
            // Case 1: Jump FROM main TO inset
            if prevInMain && !currInMain {
                // Find which inset contains current location
                for (insetIndex, insetData) in insetSnapshots.enumerated() {
                    if isCoordinate(currentLocation, inRegion: insetData.region) {
                        guard insetIndex < insetPositions.count else { break }
                        
                        // Get point in main map (where we're leaving from)
                        let mainPoint = coordinateToMainMapPoint(prevLocation)
                        
                        // Get where the DESTINATION would be on the main map (even if off-screen)
                        let destinationOnMainMap = coordinateToMainMapPoint(currentLocation)
                        
                        // Draw connector line to where it WOULD be on main map (CLIPPED to main map)
                        drawConnectorLine(
                            context: context,
                            from: mainPoint,
                            to: destinationOnMainMap,
                            color: userColor,
                            clipRect: mapRect
                        )
                        
                        // Now draw second line from that off-screen point to the inset box
                        let insetPosition = insetPositions[insetIndex]
                        let insetRect = CGRect(x: insetPosition.x, y: insetPosition.y, width: scaledInsetSize, height: scaledInsetSize)
                        let insetSnapshot = insetData.snapshot
                        let insetSnapPoint = insetSnapshot.point(for: currentLocation)
                        let insetPoint = CGPoint(
                            x: insetRect.minX + (insetSnapPoint.x / insetSnapshot.image.size.width) * scaledInsetSize,
                            y: insetRect.minY + (insetSnapPoint.y / insetSnapshot.image.size.height) * scaledInsetSize
                        )
                        
                        // Draw line from off-screen main map position to inset (CLIPPED to inset)
                        drawConnectorLine(
                            context: context,
                            from: destinationOnMainMap,
                            to: insetPoint,
                            color: userColor,
                            style: .toInset,
                            clipRect: insetRect
                        )
                        break
                    }
                }
            }
            
            // Case 2: Jump FROM inset BACK TO main
            if !prevInMain && currInMain {
                // Find which inset contains previous location
                for (insetIndex, insetData) in insetSnapshots.enumerated() {
                    if isCoordinate(prevLocation, inRegion: insetData.region) {
                        guard insetIndex < insetPositions.count else { break }
                        
                        // Get point in inset
                        let insetPosition = insetPositions[insetIndex]
                        let insetRect = CGRect(x: insetPosition.x, y: insetPosition.y, width: scaledInsetSize, height: scaledInsetSize)
                        let insetSnapshot = insetData.snapshot
                        let insetSnapPoint = insetSnapshot.point(for: prevLocation)
                        let insetPoint = CGPoint(
                            x: insetRect.minX + (insetSnapPoint.x / insetSnapshot.image.size.width) * scaledInsetSize,
                            y: insetRect.minY + (insetSnapPoint.y / insetSnapshot.image.size.height) * scaledInsetSize
                        )
                        
                        // Get where we're leaving FROM on the main map (off-screen)
                        let departureOnMainMap = coordinateToMainMapPoint(prevLocation)
                        
                        // Get where we're arriving TO on the main map
                        let mainPoint = coordinateToMainMapPoint(currentLocation)
                        
                        // Draw line from inset to off-screen position (CLIPPED to inset)
                        drawConnectorLine(
                            context: context,
                            from: insetPoint,
                            to: departureOnMainMap,
                            color: userColor,
                            style: .fromInset,
                            clipRect: insetRect
                        )
                        
                        // Draw line from off-screen to actual main map point (CLIPPED to main map)
                        drawConnectorLine(
                            context: context,
                            from: departureOnMainMap,
                            to: mainPoint,
                            color: userColor,
                            clipRect: mapRect
                        )
                        break
                    }
                }
            }
            
            // Case 3: Jump FROM one inset TO another inset
            if !prevInMain && !currInMain {
                var prevInsetIndex: Int?
                var currInsetIndex: Int?
                
                for (insetIndex, insetData) in insetSnapshots.enumerated() {
                    if isCoordinate(prevLocation, inRegion: insetData.region) {
                        prevInsetIndex = insetIndex
                    }
                    if isCoordinate(currentLocation, inRegion: insetData.region) {
                        currInsetIndex = insetIndex
                    }
                }
                
                if let prevIdx = prevInsetIndex, let currIdx = currInsetIndex, prevIdx != currIdx {
                    guard prevIdx < insetPositions.count && currIdx < insetPositions.count else { continue }
                    
                    // Get point in previous inset
                    let prevInsetPos = insetPositions[prevIdx]
                    let prevInsetRect = CGRect(x: prevInsetPos.x, y: prevInsetPos.y, width: scaledInsetSize, height: scaledInsetSize)
                    let prevInsetSnapshot = insetSnapshots[prevIdx].snapshot
                    let prevSnapPoint = prevInsetSnapshot.point(for: prevLocation)
                    let prevPoint = CGPoint(
                        x: prevInsetRect.minX + (prevSnapPoint.x / prevInsetSnapshot.image.size.width) * scaledInsetSize,
                        y: prevInsetRect.minY + (prevSnapPoint.y / prevInsetSnapshot.image.size.height) * scaledInsetSize
                    )
                    
                    // Where prev location would be on main map (off-screen)
                    let prevOnMainMap = coordinateToMainMapPoint(prevLocation)
                    
                    // Where current location would be on main map (off-screen)
                    let currOnMainMap = coordinateToMainMapPoint(currentLocation)
                    
                    // Get point in current inset
                    let currInsetPos = insetPositions[currIdx]
                    let currInsetRect = CGRect(x: currInsetPos.x, y: currInsetPos.y, width: scaledInsetSize, height: scaledInsetSize)
                    let currInsetSnapshot = insetSnapshots[currIdx].snapshot
                    let currSnapPoint = currInsetSnapshot.point(for: currentLocation)
                    let currPoint = CGPoint(
                        x: currInsetRect.minX + (currSnapPoint.x / currInsetSnapshot.image.size.width) * scaledInsetSize,
                        y: currInsetRect.minY + (currSnapPoint.y / currInsetSnapshot.image.size.height) * scaledInsetSize
                    )
                    
                    // Draw: prev inset -> off-screen prev (CLIPPED to prev inset)
                    drawConnectorLine(
                        context: context,
                        from: prevPoint,
                        to: prevOnMainMap,
                        color: userColor,
                        style: .fromInset,
                        clipRect: prevInsetRect
                    )
                    
                    // Draw: off-screen prev -> off-screen curr (CLIPPED to main map)
                    drawConnectorLine(
                        context: context,
                        from: prevOnMainMap,
                        to: currOnMainMap,
                        color: userColor,
                        clipRect: mapRect
                    )
                    
                    // Draw: off-screen curr -> curr inset (CLIPPED to curr inset)
                    drawConnectorLine(
                        context: context,
                        from: currOnMainMap,
                        to: currPoint,
                        color: userColor,
                        style: .toInset,
                        clipRect: currInsetRect
                    )
                }
            }
        }
    }

    // helper to draw a single connector line:
    private func drawConnectorLine(
        context: CGContext,
        from: CGPoint,
        to: CGPoint,
        color: UIColor,
        style: ConnectorStyle = .normal,
        clipRect: CGRect? = nil
    ) {
        context.saveGState()
        
        // Apply clipping if provided
        if let clipRect = clipRect {
            context.clip(to: clipRect)
        }
        
        // Different styles for different parts
        switch style {
        case .normal:
            // Main travel line - solid, more visible
            context.setStrokeColor(color.withAlphaComponent(0.8).cgColor)
            context.setLineWidth(2.5)
            context.setLineDash(phase: 0, lengths: [6, 3])
        case .toInset, .fromInset:
            // Line connecting to inset box - lighter, more subtle
            context.setStrokeColor(color.withAlphaComponent(0.5).cgColor)
            context.setLineWidth(1.5)
            context.setLineDash(phase: 0, lengths: [3, 3])
        }
        
        context.setLineCap(.round)
        
        context.move(to: from)
        context.addLine(to: to)
        context.strokePath()
        
        // Draw small circle at endpoints (only for normal style and if within bounds)
        if style == .normal {
            let circleRadius: CGFloat = 4
            context.setLineDash(phase: 0, lengths: []) // solid for circles
            context.setFillColor(color.cgColor)
            
            // Only draw circles if they're within the clip rect
            if clipRect == nil || clipRect!.contains(from) {
                context.fillEllipse(in: CGRect(x: from.x - circleRadius, y: from.y - circleRadius, width: circleRadius * 2, height: circleRadius * 2))
            }
            if clipRect == nil || clipRect!.contains(to) {
                context.fillEllipse(in: CGRect(x: to.x - circleRadius, y: to.y - circleRadius, width: circleRadius * 2, height: circleRadius * 2))
            }
        }
        
        context.restoreGState()
    }
    
    // MARK: - Frame Generation
    
    private func createFrame(
        phase: VideoPhase,
        phaseFrame: Int,
        totalPhaseFrames: Int,
        locations: [CLLocationCoordinate2D],
        statistics: [String: String],
        mapData: (image: UIImage, snapshot: MKMapSnapshotter.Snapshot, regions: [MapRegion], insetSnapshots: [(region: MapRegion, snapshot: MKMapSnapshotter.Snapshot)])?,
        friends: [FriendData]
    ) -> CVPixelBuffer? {
        
        let renderer = UIGraphicsImageRenderer(size: videoSize)
        
        let image = renderer.image { context in
            let ctx = context.cgContext
            
            drawBackground(context: ctx)
            
            switch phase {
            case .intro:
                drawIntro(context: ctx, frame: phaseFrame, totalFrames: totalPhaseFrames)
                
            case .mapAnimation:
                drawMapAnimation(
                    context: ctx,
                    frame: phaseFrame,
                    totalFrames: totalPhaseFrames,
                    locations: locations,
                    mapData: mapData,
                    friends: friends
                )
            
            case .stats:
                drawStats(
                    context: ctx,
                    frame: phaseFrame,
                    totalFrames: totalPhaseFrames,
                    statistics: statistics
                )
                
            case .outro:
                drawOutro(context: ctx, frame: phaseFrame, totalFrames: totalPhaseFrames)
            }
        }
        
        return image.pixelBuffer()
    }
    
    // MARK: - Drawing Functions
    
    private func drawBackground(context: CGContext) {
        let colors = [
            UIColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1.0).cgColor,
            UIColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1.0).cgColor
        ]
        
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                    colors: colors as CFArray,
                                    locations: [0.0, 1.0]) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 0, y: videoSize.height),
                options: []
            )
        }
    }
    
    // MARK: - Draw Intro
    private func drawIntro(context: CGContext, frame: Int, totalFrames: Int) {
        let progress = easeInOut(Double(frame) / Double(totalFrames))
        let alpha = min(1.0, progress * 1.5)
        
        // FIXED font sizes (NOT responsive)
        let yearAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 80, weight: .black),
            .foregroundColor: UIColor.white.withAlphaComponent(alpha)
        ]
        
        let year = "2025"
        let yearSize = year.size(withAttributes: yearAttrs)
        let yearY = videoSize.height / 2 - yearSize.height - 20
        year.draw(
            at: CGPoint(x: (videoSize.width - yearSize.width) / 2, y: yearY),
            withAttributes: yearAttrs
        )
        
        let mappedAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 55, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(alpha * 0.9)
        ]
        
        let mapped = "Mapped"
        let mappedSize = mapped.size(withAttributes: mappedAttrs)
        mapped.draw(
            at: CGPoint(x: (videoSize.width - mappedSize.width) / 2, y: yearY + yearSize.height + 10),
            withAttributes: mappedAttrs
        )
    }
    
    // MARK: - Draw Map Animation
    // MARK: - Draw Map Animation
    private func drawMapAnimation(
        context: CGContext,
        frame: Int,
        totalFrames: Int,
        locations: [CLLocationCoordinate2D],
        mapData: (image: UIImage, snapshot: MKMapSnapshotter.Snapshot, regions: [MapRegion], insetSnapshots: [(region: MapRegion, snapshot: MKMapSnapshotter.Snapshot)])?,
        friends: [FriendData]
    ) {
        guard !locations.isEmpty else { return }
        
        let progress = Double(frame) / Double(totalFrames)
        
        let mapRect = CGRect(x: 30, y: 100, width: 660, height: 670)
        
        // Draw base map (already has insets if multi-region)
        if let snapshot = mapData?.image {
            context.saveGState()
            context.addPath(CGPath(roundedRect: mapRect, cornerWidth: 15, cornerHeight: 15, transform: nil))
            context.clip()
            snapshot.draw(in: mapRect)
            context.restoreGState()
        }
        
        guard let snapshotObj = mapData?.snapshot,
              let regions = mapData?.regions else { return }
        
        let mainRegion = regions[0]
        
        // Helper to convert coordinate to point on main map
        func coordinateToPoint(_ coord: CLLocationCoordinate2D) -> CGPoint {
            let snapshotPoint = snapshotObj.point(for: coord)
            let snapshotSize = mapData?.image.size ?? CGSize(width: 700, height: 700)
            let scaleX = mapRect.width / snapshotSize.width
            let scaleY = mapRect.height / snapshotSize.height
            
            return CGPoint(
                x: mapRect.minX + (snapshotPoint.x * scaleX),
                y: mapRect.minY + (snapshotPoint.y * scaleY)
            )
        }
        
        let visiblePoints = Int(ceil(Double(locations.count) * progress))
        
        // Draw friend paths and dots (both in main region AND insets)
        for friend in friends {
            let friendLocations = friend.coordinates
            guard !friendLocations.isEmpty else { continue }
            
            let friendVisiblePoints = Int(ceil(Double(friendLocations.count) * progress))
            let friendColor = UIColor(hex: friend.color) ?? UIColor.systemRed
            
            // Draw in MAIN region
            let friendMainLocs = friendLocations.filter { isCoordinate($0, inRegion: mainRegion) }
            if !friendMainLocs.isEmpty {
                context.saveGState()
                context.setStrokeColor(friendColor.cgColor)
                context.setLineWidth(3)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                
                var drawnCount = 0
                for loc in friendMainLocs {
                    if drawnCount >= friendVisiblePoints { break }
                    let point = coordinateToPoint(loc)
                    if drawnCount == 0 {
                        context.move(to: point)
                    } else {
                        context.addLine(to: point)
                    }
                    drawnCount += 1
                }
                
                context.strokePath()
                context.restoreGState()
                
                // Draw dots
                context.saveGState()
                drawnCount = 0
                for loc in friendMainLocs {
                    if drawnCount >= friendVisiblePoints { break }
                    let point = coordinateToPoint(loc)
                    context.setFillColor(friendColor.cgColor)
                    context.fillEllipse(in: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8))
                    context.setStrokeColor(UIColor.white.cgColor)
                    context.setLineWidth(1)
                    context.strokeEllipse(in: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8))
                    drawnCount += 1
                }
                context.restoreGState()
            }
            
            // Draw friend walker in main region
            if friendVisiblePoints > 0 {
                let visibleMainLocs = friendMainLocs.prefix(friendVisiblePoints)
                if let lastLoc = visibleMainLocs.last {
                    let point = coordinateToPoint(lastLoc)
                    context.setFillColor(friendColor.cgColor)
                    context.fillEllipse(in: CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16))
                    context.setStrokeColor(UIColor.white.cgColor)
                    context.setLineWidth(2)
                    context.strokeEllipse(in: CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16))
                }
            }
        }
        
        // Draw YOUR path in main region
        let userMainLocs = locations.filter { isCoordinate($0, inRegion: mainRegion) }
        if !userMainLocs.isEmpty {
            context.saveGState()
            let userColor = UIColor(hex: snapshotUserColor) ?? UIColor.systemBlue
            context.setStrokeColor(userColor.cgColor)
            context.setLineWidth(4)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            var drawnCount = 0
            for loc in userMainLocs {
                if drawnCount >= visiblePoints { break }
                let point = coordinateToPoint(loc)
                if drawnCount == 0 {
                    context.move(to: point)
                } else {
                    context.addLine(to: point)
                }
                drawnCount += 1
            }
            
            context.strokePath()
            context.restoreGState()
            
            // Draw YOUR dots
            context.saveGState()
            drawnCount = 0
            for loc in userMainLocs {
                if drawnCount >= visiblePoints { break }
                let point = coordinateToPoint(loc)
                context.setFillColor(userColor.cgColor)
                context.fillEllipse(in: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10))
                context.setStrokeColor(UIColor.white.cgColor)
                context.setLineWidth(1.5)
                context.strokeEllipse(in: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10))
                drawnCount += 1
            }
            context.restoreGState()
        }
        
        // Draw YOUR walker in main region
        if visiblePoints > 0 {
            let visibleMainLocs = userMainLocs.prefix(visiblePoints)
            if let lastLoc = visibleMainLocs.last {
                let point = coordinateToPoint(lastLoc)
                let userColor = UIColor(hex: snapshotUserColor) ?? UIColor.systemBlue
                
                context.setFillColor(userColor.cgColor)
                context.fillEllipse(in: CGRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20))
                context.setStrokeColor(UIColor.white.cgColor)
                context.setLineWidth(2)
                context.strokeEllipse(in: CGRect(x: point.x - 10, y: point.y - 10, width: 20, height: 20))
                
                // Draw emoji
                let emojiAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12)
                ]
                let emojiSize = snapshotUserEmoji.size(withAttributes: emojiAttrs)
                snapshotUserEmoji.draw(at: CGPoint(x: point.x - emojiSize.width/2, y: point.y - emojiSize.height/2), withAttributes: emojiAttrs)
            }
        }
        
        // NOW draw paths/dots in INSET regions WITH ANIMATION
        if let insetSnapshots = mapData?.insetSnapshots, !insetSnapshots.isEmpty {
            let baseInsetSize: CGFloat = 175
            let scaledInsetSize = (baseInsetSize / 700) * mapRect.width
            let padding: CGFloat = 15
            
            // Use the SAME smart positioning function
            let positions = calculateSmartInsetPositions(
                mainRegion: mainRegion,
                mainSnapshot: snapshotObj,
                insetCount: insetSnapshots.count,
                mapRect: mapRect,
                scaledInsetSize: scaledInsetSize,
                padding: padding
            )
            
            // Determine which region the current walker is in
            var currentWalkerRegion: MapRegion?
            if visiblePoints > 0 && visiblePoints <= locations.count {
                let currentLocation = locations[visiblePoints - 1]
                
                // Check which inset region contains the current location
                for insetData in insetSnapshots {
                    if isCoordinate(currentLocation, inRegion: insetData.region) {
                        currentWalkerRegion = insetData.region
                        break
                    }
                }
            }
            
            // Draw each inset with animation
            for (index, insetData) in insetSnapshots.enumerated() {
                guard index < positions.count else { break }
                
                let position = positions[index]
                let insetRect = CGRect(x: position.x, y: position.y, width: scaledInsetSize, height: scaledInsetSize)
                let insetRegion = insetData.region
                let insetSnapshot = insetData.snapshot
                
                // Check if this is the region containing the current walker
                let isCurrentWalkerRegion = (currentWalkerRegion?.name == insetRegion.name)
                
                // Draw friend paths in inset WITH ANIMATION
                for friend in friends {
                    let friendColor = UIColor(hex: friend.color) ?? UIColor.systemRed
                    
                    // Get ALL friend locations in order, then filter to this SPECIFIC inset region
                    var friendInsetLocsWithIndices: [(coord: CLLocationCoordinate2D, originalIndex: Int)] = []
                    for (idx, coord) in friend.coordinates.enumerated() {
                        if isCoordinate(coord, inRegion: insetRegion) {
                            friendInsetLocsWithIndices.append((coord, idx))
                        }
                    }
                    
                    guard !friendInsetLocsWithIndices.isEmpty else { continue }
                    
                    // Calculate how many of THIS friend's locations should be visible
                    let totalFriendLocs = friend.coordinates.count
                    let friendVisiblePoints = Int(ceil(Double(totalFriendLocs) * progress))
                    
                    // Filter to only show locations up to the visible index
                    let visibleInsetLocs = friendInsetLocsWithIndices.filter { $0.originalIndex < friendVisiblePoints }
                    
                    guard !visibleInsetLocs.isEmpty else { continue }
                    
                    // Draw path
                    context.saveGState()
                    context.setStrokeColor(friendColor.cgColor)
                    context.setLineWidth(2)
                    context.setLineCap(.round)
                    context.setLineJoin(.round)
                    
                    for (loopIndex, item) in visibleInsetLocs.enumerated() {
                        let snapPoint = insetSnapshot.point(for: item.coord)
                        let point = CGPoint(
                            x: insetRect.minX + (snapPoint.x / insetSnapshot.image.size.width) * scaledInsetSize,
                            y: insetRect.minY + (snapPoint.y / insetSnapshot.image.size.height) * scaledInsetSize
                        )
                        if loopIndex == 0 {
                            context.move(to: point)
                        } else {
                            context.addLine(to: point)
                        }
                    }
                    
                    context.strokePath()
                    context.restoreGState()
                    
                    // Draw dots
                    context.saveGState()
                    for item in visibleInsetLocs {
                        let snapPoint = insetSnapshot.point(for: item.coord)
                        let point = CGPoint(
                            x: insetRect.minX + (snapPoint.x / insetSnapshot.image.size.width) * scaledInsetSize,
                            y: insetRect.minY + (snapPoint.y / insetSnapshot.image.size.height) * scaledInsetSize
                        )
                        context.setFillColor(friendColor.cgColor)
                        context.fillEllipse(in: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6))
                        context.setStrokeColor(UIColor.white.cgColor)
                        context.setLineWidth(1)
                        context.strokeEllipse(in: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6))
                    }
                    context.restoreGState()
                    
                    // Only draw friend walker if they're currently in THIS region
                    if friendVisiblePoints > 0 && friendVisiblePoints <= friend.coordinates.count {
                        let currentFriendLocation = friend.coordinates[friendVisiblePoints - 1]
                        let isFriendCurrentlyHere = isCoordinate(currentFriendLocation, inRegion: insetRegion)
                        
                        if isFriendCurrentlyHere, let lastVisibleItem = visibleInsetLocs.last {
                            let snapPoint = insetSnapshot.point(for: lastVisibleItem.coord)
                            let point = CGPoint(
                                x: insetRect.minX + (snapPoint.x / insetSnapshot.image.size.width) * scaledInsetSize,
                                y: insetRect.minY + (snapPoint.y / insetSnapshot.image.size.height) * scaledInsetSize
                            )
                            
                            context.saveGState()
                            context.setFillColor(friendColor.cgColor)
                            context.fillEllipse(in: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12))
                            context.setStrokeColor(UIColor.white.cgColor)
                            context.setLineWidth(1.5)
                            context.strokeEllipse(in: CGRect(x: point.x - 6, y: point.y - 6, width: 12, height: 12))
                            context.restoreGState()
                        }
                    }
                }
                
                // Draw YOUR path in inset WITH ANIMATION
                let userColor = UIColor(hex: snapshotUserColor) ?? UIColor.systemBlue
                
                // Get YOUR locations with indices for THIS SPECIFIC inset region
                var userInsetLocsWithIndices: [(coord: CLLocationCoordinate2D, originalIndex: Int)] = []
                for (idx, coord) in locations.enumerated() {
                    if isCoordinate(coord, inRegion: insetRegion) {
                        userInsetLocsWithIndices.append((coord, idx))
                    }
                }
                
                guard !userInsetLocsWithIndices.isEmpty else { continue }
                
                // Filter to visible points
                let visibleUserInsetLocs = userInsetLocsWithIndices.filter { $0.originalIndex < visiblePoints }
                
                guard !visibleUserInsetLocs.isEmpty else { continue }
                
                // Draw path
                context.saveGState()
                context.setStrokeColor(userColor.cgColor)
                context.setLineWidth(2)
                context.setLineCap(.round)
                context.setLineJoin(.round)
                
                for (loopIndex, item) in visibleUserInsetLocs.enumerated() {
                    let snapPoint = insetSnapshot.point(for: item.coord)
                    let point = CGPoint(
                        x: insetRect.minX + (snapPoint.x / insetSnapshot.image.size.width) * scaledInsetSize,
                        y: insetRect.minY + (snapPoint.y / insetSnapshot.image.size.height) * scaledInsetSize
                    )
                    if loopIndex == 0 {
                        context.move(to: point)
                    } else {
                        context.addLine(to: point)
                    }
                }
                
                context.strokePath()
                context.restoreGState()
                
                // Draw YOUR dots in inset
                context.saveGState()
                for item in visibleUserInsetLocs {
                    let snapPoint = insetSnapshot.point(for: item.coord)
                    let point = CGPoint(
                        x: insetRect.minX + (snapPoint.x / insetSnapshot.image.size.width) * scaledInsetSize,
                        y: insetRect.minY + (snapPoint.y / insetSnapshot.image.size.height) * scaledInsetSize
                    )
                    context.setFillColor(userColor.cgColor)
                    context.fillEllipse(in: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8))
                    context.setStrokeColor(UIColor.white.cgColor)
                    context.setLineWidth(1)
                    context.strokeEllipse(in: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8))
                }
                context.restoreGState()
                
                // Draw YOUR walker ONLY if you're currently in THIS region
                if isCurrentWalkerRegion, let lastVisibleItem = visibleUserInsetLocs.last {
                    let snapPoint = insetSnapshot.point(for: lastVisibleItem.coord)
                    let point = CGPoint(
                        x: insetRect.minX + (snapPoint.x / insetSnapshot.image.size.width) * scaledInsetSize,
                        y: insetRect.minY + (snapPoint.y / insetSnapshot.image.size.height) * scaledInsetSize
                    )
                    
                    context.saveGState()
                    context.setFillColor(userColor.cgColor)
                    context.fillEllipse(in: CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16))
                    context.setStrokeColor(UIColor.white.cgColor)
                    context.setLineWidth(2)
                    context.strokeEllipse(in: CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16))
                    
                    // Draw emoji
                    let emojiAttrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 8)  // Smaller for inset
                    ]
                    let emojiSize = snapshotUserEmoji.size(withAttributes: emojiAttrs)
                    snapshotUserEmoji.draw(at: CGPoint(x: point.x - emojiSize.width/2, y: point.y - emojiSize.height/2), withAttributes: emojiAttrs)
                    
                    context.restoreGState()
                }
            }
            
            // Draw connector lines for region jumps (YOUR path)
            drawRegionConnectors(
                context: context,
                locations: locations,
                mainRegion: mainRegion,
                insetSnapshots: insetSnapshots,
                insetPositions: positions,
                mainSnapshot: snapshotObj,
                mapRect: mapRect,
                scaledInsetSize: scaledInsetSize,
                visiblePoints: visiblePoints,
                userColor: UIColor(hex: snapshotUserColor) ?? UIColor.systemBlue
            )
            
            // Draw connector lines for FRIENDS
            for friend in friends {
                let friendColor = UIColor(hex: friend.color) ?? UIColor.systemRed
                let friendVisiblePoints = Int(ceil(Double(friend.coordinates.count) * progress))
                
                drawRegionConnectors(
                    context: context,
                    locations: friend.coordinates,
                    mainRegion: mainRegion,
                    insetSnapshots: insetSnapshots,
                    insetPositions: positions,
                    mainSnapshot: snapshotObj,
                    mapRect: mapRect,
                    scaledInsetSize: scaledInsetSize,
                    visiblePoints: friendVisiblePoints,
                    userColor: friendColor
                )
            }
        }
        
        // Title, progress bar, collage
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 35, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        
        let title = friends.isEmpty ? "Your Journey" : "Your Journeys"
        let titleSize = title.size(withAttributes: titleAttrs)
        title.draw(at: CGPoint(x: (videoSize.width - titleSize.width) / 2, y: 35), withAttributes: titleAttrs)
        
        let progressBarY: CGFloat = 785
        let progressBarHeight: CGFloat = 6
        let progressBarPadding: CGFloat = 40
        let progressBarWidth = videoSize.width - (progressBarPadding * 2)
        
        let progressBgRect = CGRect(x: progressBarPadding, y: progressBarY, width: progressBarWidth, height: progressBarHeight)
        context.setFillColor(UIColor.white.withAlphaComponent(0.2).cgColor)
        context.addPath(CGPath(roundedRect: progressBgRect, cornerWidth: progressBarHeight / 2, cornerHeight: progressBarHeight / 2, transform: nil))
        context.fillPath()
        
        let progressFillWidth = progressBarWidth * CGFloat(progress)
        let progressFillRect = CGRect(x: progressBarPadding, y: progressBarY, width: progressFillWidth, height: progressBarHeight)
        context.setFillColor(UIColor.white.withAlphaComponent(0.9).cgColor)
        context.addPath(CGPath(roundedRect: progressFillRect, cornerWidth: progressBarHeight / 2, cornerHeight: progressBarHeight / 2, transform: nil))
        context.fillPath()
        
        drawPhotoCollage(context: context, progress: progress)
    }
// MARK: - Helper Functions for generating the increasingly complex map lol
    private enum ConnectorStyle {
        case normal      // Main travel line between regions
        case toInset     // Line from off-screen to inset box
        case fromInset   // Line from inset box to off-screen
    }
    
    // MARK: - Photo Collage Drawing (Optimized)
    private func drawPhotoCollage(context: CGContext, progress: Double) {
        guard !collageLayout.isEmpty, !prerenderedPhotos.isEmpty else { return }
        
        // FIXED positions
        let collageStartY: CGFloat = 800
        let collageHeight: CGFloat = 460  // videoSize.height - collageStartY - 20
        let collageWidth: CGFloat = 660   // videoSize.width - 60
        let collageX: CGFloat = 30
        let collageArea = CGRect(x: collageX, y: collageStartY, width: collageWidth, height: collageHeight)
        
        context.saveGState()
        context.clip(to: collageArea)
        
        for (index, item) in collageLayout.enumerated() {
            guard item.appearTime <= progress else { continue }
            guard index < prerenderedPhotos.count else {
                print("⚠️ Warning: Skipping photo at index \(index) - out of bounds (prerenderedPhotos.count = \(prerenderedPhotos.count))")
                continue
            }
            
            let photo = prerenderedPhotos[index]
            let rect = item.rect
            let rotation = item.rotation
            let appearTime = item.appearTime
            
            let timeSinceAppear = progress - appearTime
            let fadeInDuration = 0.03
            let alpha = min(1.0, max(0.0, timeSinceAppear / fadeInDuration))
            
            if alpha < 0.01 { continue }
            
            context.saveGState()
            
            if rotation != 0 {
                context.translateBy(x: rect.midX, y: rect.midY)
                context.rotate(by: rotation)
                context.translateBy(x: -rect.midX, y: -rect.midY)
            }
            
            context.setAlpha(alpha)
            photo.draw(in: rect)
            
            context.restoreGState()
        }
        
        context.restoreGState()
    }
    
    // MARK: - Shape Helpers (Cached)

    private func createHexagonPath(in rect: CGRect) -> CGPath {
        let size = Int(min(rect.width, rect.height))
        let cacheKey = "hex_\(size)"
        
        // Return cached if it exists
        if let cachedPath = shapePathCache[cacheKey] {
            return cachedPath
        }
        
        // Generate new path
        let path = CGMutablePath()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3
            let x = center.x + radius * cos(angle)
            let y = center.y + radius * sin(angle)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        
        shapePathCache[cacheKey] = path
        return path
    }

    private func createTrianglePath(in rect: CGRect) -> CGPath {
        let size = Int(rect.width)
        let cacheKey = "tri_\(size)"
        
        // Return cached if it exists
        if let cachedPath = shapePathCache[cacheKey] {
            return cachedPath
        }
        
        // Generate new path
        let path = CGMutablePath()
        let top = CGPoint(x: rect.midX, y: rect.minY)
        let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
        let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
        
        path.move(to: top)
        path.addLine(to: bottomRight)
        path.addLine(to: bottomLeft)
        path.closeSubpath()
        
        shapePathCache[cacheKey] = path
        return path
    }
    
    // MARK: - Map Completion Flash Effect

    // UPDATE drawMapCompletion signature:
    private func drawMapCompletion(
        context: CGContext,
        frame: Int,
        totalFrames: Int,
        locations: [CLLocationCoordinate2D],
        mapData: (image: UIImage, snapshot: MKMapSnapshotter.Snapshot, regions: [MapRegion], insetSnapshots: [(region: MapRegion, snapshot: MKMapSnapshotter.Snapshot)])?,
        friends: [FriendData]
    ) {
        guard !locations.isEmpty else { return }
        
        // Draw the final map state first
        let mapRect = CGRect(x: 30, y: 100, width: videoSize.width - 60, height: mapHeight)
        
        if let snapshot = mapData?.image {
            context.saveGState()
            context.addPath(CGPath(roundedRect: mapRect, cornerWidth: 15, cornerHeight: 15, transform: nil))
            context.clip()
            snapshot.draw(in: mapRect)
            context.restoreGState()
        }
        
        guard let snapshotObj = mapData?.snapshot else { return }
        
        // Get main region (if multi-region)
        let mainRegion = mapData?.regions.first
        
        func coordinateToPoint(_ coord: CLLocationCoordinate2D) -> CGPoint {
            let snapshotPoint = snapshotObj.point(for: coord)
            let snapshotSize = mapData?.image.size ?? CGSize(width: 700, height: 700)
            let scaleX = mapRect.width / snapshotSize.width
            let scaleY = mapRect.height / snapshotSize.height
            
            return CGPoint(
                x: mapRect.minX + (snapshotPoint.x * scaleX),
                y: mapRect.minY + (snapshotPoint.y * scaleY)
            )
        }
        
        // Filter locations by main region if multi-region
        let userLocsToShow: [CLLocationCoordinate2D]
        if let mainReg = mainRegion {
            userLocsToShow = locations.filter { isCoordinate($0, inRegion: mainReg) }
        } else {
            userLocsToShow = locations
        }
        
        // Draw all friend paths (complete) - only in main region
        for friend in friends {
            let friendLocations: [CLLocationCoordinate2D]
            if let mainReg = mainRegion {
                friendLocations = friend.coordinates.filter { isCoordinate($0, inRegion: mainReg) }
            } else {
                friendLocations = friend.coordinates
            }
            
            guard !friendLocations.isEmpty else { continue }
            
            context.saveGState()
            if let friendColor = UIColor(hex: friend.color) {
                context.setStrokeColor(friendColor.cgColor)
            } else {
                context.setStrokeColor(UIColor.systemRed.cgColor)
            }
            context.setLineWidth(3)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            let friendFirstPoint = coordinateToPoint(friendLocations[0])
            context.move(to: friendFirstPoint)
            
            for i in 1..<friendLocations.count {
                let point = coordinateToPoint(friendLocations[i])
                context.addLine(to: point)
            }
            
            context.strokePath()
            context.restoreGState()
            
            // Draw friend pins
            context.saveGState()
            for i in 0..<friendLocations.count {
                let point = coordinateToPoint(friendLocations[i])
                
                if let friendColor = UIColor(hex: friend.color) {
                    context.setFillColor(friendColor.cgColor)
                } else {
                    context.setFillColor(UIColor.systemRed.cgColor)
                }
                context.fillEllipse(in: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8))
                
                context.setStrokeColor(UIColor.white.cgColor)
                context.setLineWidth(1)
                context.strokeEllipse(in: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8))
            }
            context.restoreGState()
        }
        
        // Draw YOUR complete path (only in main region)
        if !userLocsToShow.isEmpty {
            context.saveGState()
            let userColor = UIColor(hex: snapshotUserColor) ?? UIColor.systemBlue
            context.setStrokeColor(userColor.cgColor)
            context.setLineWidth(4)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            let firstPoint = coordinateToPoint(userLocsToShow[0])
            context.move(to: firstPoint)
            
            for i in 1..<userLocsToShow.count {
                let point = coordinateToPoint(userLocsToShow[i])
                context.addLine(to: point)
            }
            
            context.strokePath()
            context.restoreGState()
            
            // Draw YOUR pins
            context.saveGState()
            for i in 0..<userLocsToShow.count {
                let point = coordinateToPoint(userLocsToShow[i])
                
                context.setFillColor(userColor.cgColor)
                context.fillEllipse(in: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10))
                
                context.setStrokeColor(UIColor.white.cgColor)
                context.setLineWidth(1.5)
                context.strokeEllipse(in: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10))
            }
            context.restoreGState()
        }
        
        // Title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 35, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        
        let title = friends.isEmpty ? "Your Journey" : "Your Journeys"
        let titleSize = title.size(withAttributes: titleAttrs)
        title.draw(at: CGPoint(x: (videoSize.width - titleSize.width) / 2, y: 35), withAttributes: titleAttrs)
        
        // Collage background
        let collageStartY: CGFloat = 800
        let collageHeight: CGFloat = videoSize.height - collageStartY - 20
        let collageWidth = videoSize.width - 60
        let collageX: CGFloat = 30
        let collageRect = CGRect(x: collageX, y: collageStartY, width: collageWidth, height: collageHeight)
        
        context.setFillColor(UIColor.white.cgColor)
        context.fill(collageRect)
        
        // Draw complete collage
        drawPhotoCollage(context: context, progress: 1.0)
        
        //   FLASH EFFECT: Quick bright flash that fades
        let progress = Double(frame) / Double(totalFrames)
        
        // Flash peaks at 30% through the effect, then fades
        let flashAlpha: CGFloat
        if progress < 0.3 {
            flashAlpha = CGFloat(progress / 0.3) * 0.4  // Rise to 40% opacity
        } else {
            flashAlpha = CGFloat((1.0 - progress) / 0.7) * 0.4  // Fade to 0
        }
        
        // Overlay white flash
        context.setFillColor(UIColor.white.withAlphaComponent(flashAlpha).cgColor)
        context.fill(CGRect(x: 0, y: 0, width: videoSize.width, height: videoSize.height))
        
        //   SCALE PULSE: Subtle scale effect on collage
        if progress < 0.5 {
            let scale = 1.0 + (0.03 * sin(progress * .pi * 2))  // Gentle pulse
            
            context.saveGState()
            context.translateBy(x: collageRect.midX, y: collageRect.midY)
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -collageRect.midX, y: -collageRect.midY)
            
            // Redraw collage with subtle glow
            let glowAlpha = CGFloat(0.3 * (1.0 - progress * 2))
            context.setShadow(
                offset: .zero,
                blur: 20,
                color: UIColor.white.withAlphaComponent(glowAlpha).cgColor
            )
            
            context.restoreGState()
        }
    }
    
    // MARK: - Draw Stats
    private func drawStats(
        context: CGContext,
        frame: Int,
        totalFrames: Int,
        statistics: [String: String]
    ) {
        // Enable high-quality rendering
        context.setShouldAntialias(true)
        context.setShouldSmoothFonts(true)
        context.interpolationQuality = .high
        
        // FIXED font sizes
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 50, weight: .bold),
            .foregroundColor: UIColor.white
        ]
        
        let title = "Your Stats"
        let titleSize = title.size(withAttributes: titleAttrs)
        title.draw(at: CGPoint(x: (videoSize.width - titleSize.width) / 2, y: 70), withAttributes: titleAttrs)
        
        let sortedStats = Array(statistics.sorted(by: { $0.key < $1.key }))
        let progress = Double(frame) / Double(totalFrames)
        
        // FIXED spacing
        let padding: CGFloat = 30
        let cardWidth: CGFloat = videoSize.width - (padding * 2)
        let startY: CGFloat = 140
        let verticalSpacing: CGFloat = 12
        let availableHeight = videoSize.height - startY - 30
        let totalSpacing = verticalSpacing * CGFloat(sortedStats.count - 1)
        let cardHeight: CGFloat = (availableHeight - totalSpacing) / CGFloat(sortedStats.count)
        
        let displayStats = sortedStats
        
        for (index, (key, value)) in displayStats.enumerated() {
            let y = startY + (CGFloat(index) * (cardHeight + verticalSpacing))
            
            if y + cardHeight > videoSize.height - 70 {
                continue
            }
            
            let cardStartProgress = Double(index) * 0.08
            let fadeInDuration = 0.15
            let timeSinceStart = progress - cardStartProgress
            
            let cardAlpha: CGFloat
            if timeSinceStart < 0 {
                cardAlpha = 0.0
            } else if timeSinceStart < fadeInDuration {
                let t = timeSinceStart / fadeInDuration
                let eased = 1 - pow(1 - t, 3)
                cardAlpha = CGFloat(eased)
            } else {
                cardAlpha = 1.0
            }
            
            if cardAlpha > 0 {
                let cardRect = CGRect(x: padding, y: y, width: cardWidth, height: cardHeight)
                
                // Card background
                context.setFillColor(UIColor.white.withAlphaComponent(0.15 * cardAlpha).cgColor)
                context.addPath(CGPath(roundedRect: cardRect, cornerWidth: 12, cornerHeight: 12, transform: nil))
                context.fillPath()
                
                // Icon - FIXED size
                let iconSize: CGFloat = 36
                if let icon = systemIconImage(named: iconForStat(key), size: iconSize) {
                    let iconX = padding + cardWidth - iconSize - 15
                    let iconY = y + (cardHeight - iconSize) / 2
                    
                    context.saveGState()
                    context.setAlpha(cardAlpha)
                    context.interpolationQuality = .high
                    icon.draw(in: CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize))
                    context.restoreGState()
                }
                
                let textPadding: CGFloat = 15
                let textWidth = cardWidth - (iconSize + 40)
                
                // Key text - FIXED font size
                let keyAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 18, weight: .semibold),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.85)
                ]
                
                context.saveGState()
                context.setAlpha(cardAlpha)
                let keyText = key as NSString
                let keyRect = CGRect(x: padding + textPadding, y: y + 20, width: textWidth, height: 25)
                keyText.draw(in: keyRect, withAttributes: keyAttrs)
                context.restoreGState()
                
                // Value text - FIXED font size
                let valueAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                
                context.saveGState()
                context.setAlpha(cardAlpha)
                let valueText = value as NSString
                let valueRect = CGRect(x: padding + textPadding, y: y + 50, width: textWidth, height: 40)
                valueText.draw(in: valueRect, withAttributes: valueAttrs)
                context.restoreGState()
            }
        }
    }

    // Helper function for stat icons (add this near drawStats if not already present)
    private func iconForStat(_ title: String) -> String {
        switch title.lowercased() {
        case let t where t.contains("distance"):
            return "arrow.left.and.right"
        case let t where t.contains("photo"):
            return "camera.fill"
        case let t where t.contains("date") || t.contains("range"):
            return "calendar"
        case let t where t.contains("month"):
            return "calendar.badge.clock"
        case let t where t.contains("gap"):
            return "timer"
        case let t where t.contains("place") || t.contains("location") || t.contains("visited"):
            return "mappin.and.ellipse"
        case let t where t.contains("avg") || t.contains("day"):
            return "chart.line.uptrend.xyaxis"
        case let t where t.contains("style") || t.contains("bird") || t.contains("owl"):
            if title.contains("Early") {
                return "sun.max.fill"
            } else {
                return "moon.stars.fill"
            }
        case let t where t.contains("home") || t.contains("farthest"):
            return "airplane"
        default:
            return "star.fill"
        }
    }
    
    private func systemIconImage(named: String, size: CGFloat) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: .semibold)
        return UIImage(systemName: named, withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal)
    }
    
    // MARK: - Draw Outro
    private func drawOutro(context: CGContext, frame: Int, totalFrames: Int) {
        // Animated fade in
        let progress = Double(frame) / Double(totalFrames)
        let fadeIn = min(1.0, progress * 2.0) // Fade in during first half
        
        // Try to load app icon
        var appIcon: UIImage?
        if let icon = UIImage(named: "AppIcon") ?? UIImage(named: "DocumentIcon@3x") {
            appIcon = icon
        }
        
        // Draw app icon if available - FIXED sizes
        if let icon = appIcon {
            let iconSize: CGFloat = 120
            let iconX = (videoSize.width - iconSize) / 2
            let iconY = videoSize.height / 2 - 100
            let iconRect = CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize)
            
            context.saveGState()
            context.setAlpha(fadeIn)
            
            // Add rounded corners to icon
            let cornerRadius = iconSize * 0.2
            context.addPath(CGPath(roundedRect: iconRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil))
            context.clip()
            icon.draw(in: iconRect)
            
            // Add subtle shadow
            context.setShadow(offset: CGSize(width: 0, height: 4), blur: 10, color: UIColor.black.withAlphaComponent(0.3).cgColor)
            context.restoreGState()
        }
        
        // Main CTA text - FIXED font size
        let ctaAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 48, weight: .bold),
            .foregroundColor: UIColor.white.withAlphaComponent(fadeIn)
        ]
        
        let cta = "Create Yours"
        let ctaSize = cta.size(withAttributes: ctaAttrs)
        cta.draw(
            at: CGPoint(x: (videoSize.width - ctaSize.width) / 2, y: videoSize.height / 2 + 40),
            withAttributes: ctaAttrs
        )
        
        // Subtitle text - FIXED font size
        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 24, weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(fadeIn * 0.8)
        ]
        
        let subtitle = "Download Mapped 2025"
        let subtitleSize = subtitle.size(withAttributes: subtitleAttrs)
        subtitle.draw(
            at: CGPoint(x: (videoSize.width - subtitleSize.width) / 2, y: videoSize.height / 2 + 100),
            withAttributes: subtitleAttrs
        )
        
        // Additional encouragement text - FIXED font size
        let encourageAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 18, weight: .regular),
            .foregroundColor: UIColor.white.withAlphaComponent(fadeIn * 0.7)
        ]
        
        let encourage = "Map your year in photos"
        let encourageSize = encourage.size(withAttributes: encourageAttrs)
        encourage.draw(
            at: CGPoint(x: (videoSize.width - encourageSize.width) / 2, y: videoSize.height / 2 + 140),
            withAttributes: encourageAttrs
        )
    }
    
    // MARK: - Helper Functions
    
    private func easeInOut(_ t: Double) -> Double {
        return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t
    }
}

// MARK: - Video Phase Enum

enum VideoPhase {
    case intro
    case mapAnimation
    case stats
    case outro
    
    func frameCount(intro: Int, map: Int, stats: Int, outro: Int) -> Int {
        switch self {
        case .intro: return intro
        case .mapAnimation: return map
        case .stats: return stats
        case .outro: return outro
        }
    }
}

// MARK: - UIImage to CVPixelBuffer Extension

extension UIImage {
    func pixelBuffer() -> CVPixelBuffer? {
        let width = Int(self.size.width)
        let height = Int(self.size.height)
        
        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attrs,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        
        let pixelData = CVPixelBufferGetBaseAddress(buffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: rgbColorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }
        
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        
        UIGraphicsPushContext(context)
        self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        
        return buffer
    }
}
