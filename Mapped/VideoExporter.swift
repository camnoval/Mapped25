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
            if loadPhotosFromCache {
                print("📸 Loading cached photos for video export...")
                
                // Load photos from disk (happens on background thread already)
                if let cached = PersistenceManager.shared.loadCachedVideoPhotos() {
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
                        
                        // ✅ CRITICAL: Clear photos from memory after export
                        self.photoItems = []
                        self.prerenderedPhotos = []
                        self.collageLayout = []
                        print("🧹 Cleared video photos from memory")
                        
                        finishSuccessfully(videoURL)
                    } catch {
                        // Clear memory even on error
                        self.photoItems = []
                        self.prerenderedPhotos = []
                        self.collageLayout = []
                        print("🧹 Cleared video photos from memory (after error)")
                        
                        finishWithError(error)
                    }
                    
                } else {
                    // Fallback: load from library if cache doesn't exist
                    print("⚠️ No cached photos found, loading from library...")
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

        // If under 200 photos, use all of them. Otherwise, limit to 3 per day
        if selectedAssets.count <= 200 {
            print("📸 Using all \(selectedAssets.count) photos for video (under 200 threshold)")
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

        // Load up to 200 photos with stride sampling
        let maxPhotos = min(200, selectedAssets.count)
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
        
        // Fixed positions for consistent 720x1280 video on all devices
        let collageHeight: CGFloat = videoSize.height - collageStartY - 20  // ~460px height
        let collageWidth: CGFloat = videoSize.width - 60  // 660px width
        let collageX: CGFloat = 30  // 30px from left edge
        
        //   SCALED photo sizes for 720p
        let photoSizes = ResponsiveLayout.photoSizes
        
        var layout: [(image: UIImage, rect: CGRect, rotation: CGFloat, hasBorder: Bool, appearTime: Double, size: CGFloat, shape: PhotoShape)] = []
        
        let appearTimes = photoItems.map { findAppearTime(for: $0.date, in: timestamps) }
        
        let bleedAmount = ResponsiveLayout.scale(70)
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
    
    // MARK: - Map Snapshot Generation
    
    private func generateMapSnapshot(locations: [CLLocationCoordinate2D], friends: [FriendData]) -> (image: UIImage, snapshot: MKMapSnapshotter.Snapshot)? {
        var allLocations = locations
        
        // Include friend locations for bounds calculation
        for friend in friends {
            allLocations.append(contentsOf: friend.coordinates)
        }
        
        guard !allLocations.isEmpty else { return nil }
        
        let options = MKMapSnapshotter.Options()
        
        var minLat = allLocations[0].latitude
        var maxLat = allLocations[0].latitude
        var minLon = allLocations[0].longitude
        var maxLon = allLocations[0].longitude
        
        for location in allLocations {
            minLat = min(minLat, location.latitude)
            maxLat = max(maxLat, location.latitude)
            minLon = min(minLon, location.longitude)
            maxLon = max(maxLon, location.longitude)
        }
        
        let latPadding = (maxLat - minLat) * 0.2
        let lonPadding = (maxLon - minLon) * 0.2
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) + latPadding,
            longitudeDelta: (maxLon - minLon) + lonPadding
        )
        
        options.region = MKCoordinateRegion(center: center, span: span)
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
    
    // MARK: - Frame Generation
    
    
    private func createFrame(
        phase: VideoPhase,
        phaseFrame: Int,
        totalPhaseFrames: Int,
        locations: [CLLocationCoordinate2D],
        statistics: [String: String],
        mapData: (image: UIImage, snapshot: MKMapSnapshotter.Snapshot)?,
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
    private func drawIntro(context: CGContext, frame: Int, totalFrames: Int) {
        let progress = easeInOut(Double(frame) / Double(totalFrames))
        let alpha = min(1.0, progress * 1.5)
        
        let yearAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: ResponsiveLayout.dynamicFontSize(base: 80), weight: .black),
            .foregroundColor: UIColor.white.withAlphaComponent(alpha)
        ]
        
        let year = "2025"
        let yearSize = year.size(withAttributes: yearAttrs)
        let yearY = videoSize.height / 2 - yearSize.height - ResponsiveLayout.scale(20)
        year.draw(
            at: CGPoint(x: (videoSize.width - yearSize.width) / 2, y: yearY),
            withAttributes: yearAttrs
        )
        
        let mappedAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: ResponsiveLayout.dynamicFontSize(base: 55), weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(alpha * 0.9)
        ]
        
        let mapped = "Mapped"
        let mappedSize = mapped.size(withAttributes: mappedAttrs)
        mapped.draw(
            at: CGPoint(x: (videoSize.width - mappedSize.width) / 2, y: yearY + yearSize.height + ResponsiveLayout.scale(10)),
            withAttributes: mappedAttrs
        )
    }
    
    private func drawMapAnimation(
        context: CGContext,
        frame: Int,
        totalFrames: Int,
        locations: [CLLocationCoordinate2D],
        mapData: (image: UIImage, snapshot: MKMapSnapshotter.Snapshot)?,
        friends: [FriendData]
    ) {
        guard !locations.isEmpty else { return }
        
        let progress = Double(frame) / Double(totalFrames)
        
        // Map area
        let mapRect = CGRect(
            x: ResponsiveLayout.scaleWidth(30),
            y: ResponsiveLayout.scaleHeight(100),
            width: videoSize.width - ResponsiveLayout.scaleWidth(60),
            height: ResponsiveLayout.scaleHeight(670)
        )
        
        if let snapshot = mapData?.image {
            context.saveGState()
            context.addPath(CGPath(roundedRect: mapRect, cornerWidth: 15, cornerHeight: 15, transform: nil))
            context.clip()
            snapshot.draw(in: mapRect)
            context.restoreGState()
        } else {
            context.setFillColor(UIColor.white.withAlphaComponent(0.1).cgColor)
            context.addPath(CGPath(roundedRect: mapRect, cornerWidth: 15, cornerHeight: 15, transform: nil))
            context.fillPath()
        }
        
        guard let snapshotObj = mapData?.snapshot else { return }
        
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
        
        // Draw friend paths FIRST (underneath your path)
        for friend in friends {
            let friendLocations = friend.coordinates
            guard !friendLocations.isEmpty else { continue }
            
            let friendVisiblePoints = max(2, Int(Double(friendLocations.count) * progress))
            
            context.saveGState()
            if let friendColor = UIColor(hex: friend.color) {
                context.setStrokeColor(friendColor.cgColor)
            } else {
                context.setStrokeColor(UIColor.systemRed.cgColor)
            }
            context.setLineWidth(ResponsiveLayout.scale(3))
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            let friendFirstPoint = coordinateToPoint(friendLocations[0])
            context.move(to: friendFirstPoint)
            
            for i in 1..<min(friendVisiblePoints, friendLocations.count) {
                let point = coordinateToPoint(friendLocations[i])
                context.addLine(to: point)
            }
            
            context.strokePath()
            context.restoreGState()
            
            // Draw friend pins
            context.saveGState()
            let friendDotSize: CGFloat = ResponsiveLayout.scale(8)
            let friendDotRadius = friendDotSize / 2
            for i in 0..<min(friendVisiblePoints, friendLocations.count) {
                let point = coordinateToPoint(friendLocations[i])
                
                if let friendColor = UIColor(hex: friend.color) {
                    context.setFillColor(friendColor.cgColor)
                } else {
                    context.setFillColor(UIColor.systemRed.cgColor)
                }
                context.fillEllipse(in: CGRect(x: point.x - friendDotRadius, y: point.y - friendDotRadius, width: friendDotSize, height: friendDotSize))
                
                context.setStrokeColor(UIColor.white.cgColor)
                context.setLineWidth(ResponsiveLayout.scale(1))
                context.strokeEllipse(in: CGRect(x: point.x - friendDotRadius, y: point.y - friendDotRadius, width: friendDotSize, height: friendDotSize))
            }
            context.restoreGState()
            
            // Draw friend current walker
            if friendVisiblePoints < friendLocations.count {
                let currentPoint = coordinateToPoint(friendLocations[friendVisiblePoints])
                
                let friendWalkerSize: CGFloat = ResponsiveLayout.scale(16)
                let friendWalkerRadius = friendWalkerSize / 2
                
                if let friendColor = UIColor(hex: friend.color) {
                    context.setFillColor(friendColor.cgColor)
                } else {
                    context.setFillColor(UIColor.systemRed.cgColor)
                }
                context.fillEllipse(in: CGRect(x: currentPoint.x - friendWalkerRadius, y: currentPoint.y - friendWalkerRadius, width: friendWalkerSize, height: friendWalkerSize))
                context.setStrokeColor(UIColor.white.cgColor)
                context.setLineWidth(ResponsiveLayout.scale(2))
                context.strokeEllipse(in: CGRect(x: currentPoint.x - friendWalkerRadius, y: currentPoint.y - friendWalkerRadius, width: friendWalkerSize, height: friendWalkerSize))
            }
        }
        
        // Draw YOUR path - USE SNAPSHOT COLOR
        let visiblePoints = max(2, Int(Double(locations.count) * progress))
        
        context.saveGState()
        if let userUIColor = UIColor(hex: snapshotUserColor) {
            context.setStrokeColor(userUIColor.cgColor)
        } else {
            context.setStrokeColor(UIColor.systemBlue.cgColor)
        }
        context.setLineWidth(ResponsiveLayout.scale(4))
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        let firstPoint = coordinateToPoint(locations[0])
        context.move(to: firstPoint)
        
        for i in 1..<min(visiblePoints, locations.count) {
            let point = coordinateToPoint(locations[i])
            context.addLine(to: point)
        }
        
        context.strokePath()
        context.restoreGState()
        
        // Draw YOUR pins - USE SNAPSHOT COLOR
        context.saveGState()
        let dotSize: CGFloat = ResponsiveLayout.scale(10)
        let dotRadius = dotSize / 2
        for i in 0..<min(visiblePoints, locations.count) {
            let point = coordinateToPoint(locations[i])
            
            if let userUIColor = UIColor(hex: snapshotUserColor) {
                context.setFillColor(userUIColor.cgColor)
            } else {
                context.setFillColor(UIColor.systemRed.cgColor)
            }
            context.fillEllipse(in: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotSize, height: dotSize))
            
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(ResponsiveLayout.scale(1.5))
            context.strokeEllipse(in: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotSize, height: dotSize))
        }
        context.restoreGState()
        
        // Draw YOUR current walker - USE SNAPSHOT EMOJI AND COLOR
        if visiblePoints < locations.count {
            let currentPoint = coordinateToPoint(locations[visiblePoints])
            
            let walkerSize: CGFloat = ResponsiveLayout.scale(20)
            let walkerRadius = walkerSize / 2
            
            // Background circle with custom color
            if let userUIColor = UIColor(hex: snapshotUserColor) {
                context.setFillColor(userUIColor.cgColor)
            } else {
                context.setFillColor(UIColor.systemBlue.cgColor)
            }
            context.fillEllipse(in: CGRect(x: currentPoint.x - walkerRadius, y: currentPoint.y - walkerRadius, width: walkerSize, height: walkerSize))
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(ResponsiveLayout.scale(2))
            context.strokeEllipse(in: CGRect(x: currentPoint.x - walkerRadius, y: currentPoint.y - walkerRadius, width: walkerSize, height: walkerSize))
            
            // Draw custom emoji
            let emojiAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: ResponsiveLayout.scale(12))
            ]
            let emojiSize = snapshotUserEmoji.size(withAttributes: emojiAttrs)
            let emojiX = currentPoint.x - emojiSize.width / 2
            let emojiY = currentPoint.y - emojiSize.height / 2
            snapshotUserEmoji.draw(at: CGPoint(x: emojiX, y: emojiY), withAttributes: emojiAttrs)
        }
        
        // Title overlay
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: ResponsiveLayout.dynamicFontSize(base: 35), weight: .bold),
            .foregroundColor: UIColor.white
        ]
        
        let title = friends.isEmpty ? "Your Journey" : "Your Journeys"
        let titleSize = title.size(withAttributes: titleAttrs)
        title.draw(at: CGPoint(x: (videoSize.width - titleSize.width) / 2, y: ResponsiveLayout.scale(35)), withAttributes: titleAttrs)
        
        // Progress bar between map and collage
        let progressBarY: CGFloat = collageStartY  // 5px above collage (785px)
        let progressBarHeight: CGFloat = 6
        let progressBarPadding: CGFloat = 40
        let progressBarWidth = videoSize.width - (progressBarPadding * 2)

        // Progress bar background
        let progressBgRect = CGRect(
            x: progressBarPadding,
            y: progressBarY,
            width: progressBarWidth,
            height: progressBarHeight
        )
        context.setFillColor(UIColor.white.withAlphaComponent(0.2).cgColor)
        context.addPath(CGPath(roundedRect: progressBgRect, cornerWidth: progressBarHeight / 2, cornerHeight: progressBarHeight / 2, transform: nil))
        context.fillPath()
        
        // Progress bar fill
        let progressFillWidth = progressBarWidth * CGFloat(progress)
        let progressFillRect = CGRect(
            x: progressBarPadding,
            y: progressBarY,
            width: progressFillWidth,
            height: progressBarHeight
        )
        context.setFillColor(UIColor.white.withAlphaComponent(0.9).cgColor)
        context.addPath(CGPath(roundedRect: progressFillRect, cornerWidth: progressBarHeight / 2, cornerHeight: progressBarHeight / 2, transform: nil))
        context.fillPath()
        
        // Collage background
//        let collageStartY: CGFloat = ResponsiveLayout.collageStartY
//        let collageHeight: CGFloat = ResponsiveLayout.collageHeight
//        let collageWidth = ResponsiveLayout.collageWidth
//        let collageX: CGFloat = ResponsiveLayout.collageX
        //let collageRect = CGRect(x: collageX, y: collageStartY, width: collageWidth, height: collageHeight)
        
        
        drawPhotoCollage(context: context, progress: progress)
    }

    // MARK: - Photo Collage Drawing (Optimized)

    private func drawPhotoCollage(context: CGContext, progress: Double) {
        guard !collageLayout.isEmpty, !prerenderedPhotos.isEmpty else { return }
        
        // Match the scaled values - use ResponsiveLayout to be consistent
            let collageStartY: CGFloat = ResponsiveLayout.collageStartY
            let collageHeight: CGFloat = ResponsiveLayout.collageHeight
            let collageWidth = ResponsiveLayout.collageWidth
            let collageX: CGFloat = ResponsiveLayout.collageX
            let collageArea = CGRect(x: collageX, y: collageStartY, width: collageWidth, height: collageHeight)
            
            context.saveGState()
            context.clip(to: collageArea)
        
        for (index, item) in collageLayout.enumerated() {
            guard item.appearTime <= progress else { continue }
            guard index < prerenderedPhotos.count else { continue }
            
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
        
        //   FIX: Just check if key exists, don't assign to variable
        if shapePathCache[cacheKey] != nil {
            // Create a copy at the correct position
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
            return path
        }
        
        // Generate and cache (rest stays the same)
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
        
        // Check cache first
        if let _ = shapePathCache[cacheKey] {
            // Triangles are simple enough to just recreate
            let path = CGMutablePath()
            let top = CGPoint(x: rect.midX, y: rect.minY)
            let bottomLeft = CGPoint(x: rect.minX, y: rect.maxY)
            let bottomRight = CGPoint(x: rect.maxX, y: rect.maxY)
            
            path.move(to: top)
            path.addLine(to: bottomRight)
            path.addLine(to: bottomLeft)
            path.closeSubpath()
            return path
        }
        
        // Generate and cache
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

    private func drawMapCompletion(
        context: CGContext,
        frame: Int,
        totalFrames: Int,
        locations: [CLLocationCoordinate2D],
        mapData: (image: UIImage, snapshot: MKMapSnapshotter.Snapshot)?,
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
        
        // Draw all friend paths (complete)
        for friend in friends {
            let friendLocations = friend.coordinates
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
        
        // Draw YOUR complete path
        context.saveGState()
        context.setStrokeColor(UIColor.systemBlue.cgColor)
        context.setLineWidth(4)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        let firstPoint = coordinateToPoint(locations[0])
        context.move(to: firstPoint)
        
        for i in 1..<locations.count {
            let point = coordinateToPoint(locations[i])
            context.addLine(to: point)
        }
        
        context.strokePath()
        context.restoreGState()
        
        // Draw YOUR pins
        context.saveGState()
        for i in 0..<locations.count {
            let point = coordinateToPoint(locations[i])
            
            context.setFillColor(UIColor.systemRed.cgColor)
            context.fillEllipse(in: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10))
            
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(1.5)
            context.strokeEllipse(in: CGRect(x: point.x - 5, y: point.y - 5, width: 10, height: 10))
        }
        context.restoreGState()
        
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
    
    //MARK: Draw Stats
    private func drawStats(
        context: CGContext,
        frame: Int,
        totalFrames: Int,
        statistics: [String: String]
    ) {
        // Enable high-quality rendering for entire context
        context.setShouldAntialias(true)
        context.setShouldSmoothFonts(true)
        context.interpolationQuality = .high
        
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: ResponsiveLayout.dynamicFontSize(base: 50), weight: .bold),
            .foregroundColor: UIColor.white
        ]
        
        let title = "Your Stats"
        let titleSize = title.size(withAttributes: titleAttrs)
        title.draw(at: CGPoint(x: (videoSize.width - titleSize.width) / 2, y: ResponsiveLayout.scale(70)), withAttributes: titleAttrs)
        
        let sortedStats = Array(statistics.sorted(by: { $0.key < $1.key }))
        let progress = Double(frame) / Double(totalFrames)
        
        let padding: CGFloat = ResponsiveLayout.scale(30)
        let cardWidth: CGFloat = videoSize.width - (padding * 2)
        let startY: CGFloat = ResponsiveLayout.scale(140)
        let verticalSpacing: CGFloat = ResponsiveLayout.scale(12)
        let availableHeight = videoSize.height - startY - ResponsiveLayout.scale(30)
        let totalSpacing = verticalSpacing * CGFloat(sortedStats.count - 1)
        let cardHeight: CGFloat = (availableHeight - totalSpacing) / CGFloat(sortedStats.count)
        
        let displayStats = sortedStats
        
        for (index, (key, value)) in displayStats.enumerated() {
            let y = startY + (CGFloat(index) * (cardHeight + verticalSpacing))
            
            if y + cardHeight > videoSize.height - ResponsiveLayout.scale(70) {
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
                context.addPath(CGPath(roundedRect: cardRect, cornerWidth: ResponsiveLayout.scale(12), cornerHeight: ResponsiveLayout.scale(12), transform: nil))
                context.fillPath()
                
                // Icon
                let iconSize: CGFloat = ResponsiveLayout.scale(36)
                if let icon = systemIconImage(named: iconForStat(key), size: iconSize) {
                    let iconX = padding + cardWidth - iconSize - ResponsiveLayout.scale(15)
                    let iconY = y + (cardHeight - iconSize) / 2
                    
                    context.saveGState()
                    context.setAlpha(cardAlpha)
                    context.interpolationQuality = .high
                    icon.draw(in: CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize))
                    context.restoreGState()
                }
                
                let textPadding: CGFloat = ResponsiveLayout.scale(15)
                let textWidth = cardWidth - (iconSize + ResponsiveLayout.scale(40))
                
                // Key text
                let keyAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: ResponsiveLayout.dynamicFontSize(base: 18), weight: .semibold),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.85)
                ]
                
                context.saveGState()
                context.setAlpha(cardAlpha)
                let keyText = key as NSString
                let keyRect = CGRect(x: padding + textPadding, y: y + ResponsiveLayout.scale(20), width: textWidth, height: ResponsiveLayout.scale(25))
                keyText.draw(in: keyRect, withAttributes: keyAttrs)
                context.restoreGState()
                
                // Value text
                let valueAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: ResponsiveLayout.dynamicFontSize(base: 28), weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                
                context.saveGState()
                context.setAlpha(cardAlpha)
                let valueText = value as NSString
                let valueRect = CGRect(x: padding + textPadding, y: y + ResponsiveLayout.scale(50), width: textWidth, height: ResponsiveLayout.scale(40))
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
    
    private func drawOutro(context: CGContext, frame: Int, totalFrames: Int) {
        // Animated fade in
        let progress = Double(frame) / Double(totalFrames)
        let fadeIn = min(1.0, progress * 2.0) // Fade in during first half
        
        // Try to load app icon
        var appIcon: UIImage?
        if let icon = UIImage(named: "AppIcon") ?? UIImage(named: "DocumentIcon@3x") {
            appIcon = icon
        }
        
        // Draw app icon if available
        if let icon = appIcon {
            let iconSize: CGFloat = ResponsiveLayout.scale(120)
            let iconX = (videoSize.width - iconSize) / 2
            let iconY = videoSize.height / 2 - ResponsiveLayout.scale(100)
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
        
        // Main CTA text
        let ctaAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: ResponsiveLayout.dynamicFontSize(base: 48), weight: .bold),
            .foregroundColor: UIColor.white.withAlphaComponent(fadeIn)
        ]
        
        let cta = "Create Yours"
        let ctaSize = cta.size(withAttributes: ctaAttrs)
        cta.draw(
            at: CGPoint(x: (videoSize.width - ctaSize.width) / 2, y: videoSize.height / 2 + ResponsiveLayout.scale(40)),
            withAttributes: ctaAttrs
        )
        
        // Subtitle text
        let subtitleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: ResponsiveLayout.dynamicFontSize(base: 24), weight: .medium),
            .foregroundColor: UIColor.white.withAlphaComponent(fadeIn * 0.8)
        ]
        
        let subtitle = "Download Mapped 2025"
        let subtitleSize = subtitle.size(withAttributes: subtitleAttrs)
        subtitle.draw(
            at: CGPoint(x: (videoSize.width - subtitleSize.width) / 2, y: videoSize.height / 2 + ResponsiveLayout.scale(100)),
            withAttributes: subtitleAttrs
        )
        
        // Additional encouragement text
        let encourageAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: ResponsiveLayout.dynamicFontSize(base: 18), weight: .regular),
            .foregroundColor: UIColor.white.withAlphaComponent(fadeIn * 0.7)
        ]
        
        let encourage = "Map your year in photos"
        let encourageSize = encourage.size(withAttributes: encourageAttrs)
        encourage.draw(
            at: CGPoint(x: (videoSize.width - encourageSize.width) / 2, y: videoSize.height / 2 + ResponsiveLayout.scale(140)),
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
