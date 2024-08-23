import SwiftUI
import MapKit
import UIKit
import AVKit
import AVFoundation
import UserNotifications

// MARK: - Theme Definitions

enum ImageTheme: String, CaseIterable {
    case oceanBlue = "Ocean Blue"
    case sunsetVibes = "Sunset Vibes"
    case forestGreen = "Forest Green"
    case purpleDream = "Purple Dream"
    case goldenHour = "Golden Hour"
    case mintFresh = "Mint Fresh"
    case darkNight = "Dark Night"
    case pinkBlush = "Pink Blush"
    case coralReef = "Coral Reef"
    case electricViolet = "Electric Violet"
    
    var colors: [UIColor] {
        switch self {
        case .oceanBlue:
            return [UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0),
                    UIColor(red: 0.1, green: 0.6, blue: 0.9, alpha: 1.0)]
        case .sunsetVibes:
            return [UIColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 1.0),
                    UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0)]
        case .forestGreen:
            return [UIColor(red: 0.1, green: 0.5, blue: 0.3, alpha: 1.0),
                    UIColor(red: 0.2, green: 0.7, blue: 0.4, alpha: 1.0)]
        case .purpleDream:
            return [UIColor(red: 0.5, green: 0.2, blue: 0.8, alpha: 1.0),
                    UIColor(red: 0.7, green: 0.3, blue: 0.9, alpha: 1.0)]
        case .goldenHour:
            return [UIColor(red: 0.9, green: 0.6, blue: 0.2, alpha: 1.0),
                    UIColor(red: 0.95, green: 0.8, blue: 0.3, alpha: 1.0)]
        case .mintFresh:
            return [UIColor(red: 0.3, green: 0.9, blue: 0.7, alpha: 1.0),
                    UIColor(red: 0.2, green: 0.7, blue: 0.9, alpha: 1.0)]
        case .darkNight:
            return [UIColor(red: 0.1, green: 0.1, blue: 0.2, alpha: 1.0),
                    UIColor(red: 0.2, green: 0.2, blue: 0.4, alpha: 1.0)]
        case .pinkBlush:
            return [UIColor(red: 1.0, green: 0.4, blue: 0.7, alpha: 1.0),
                    UIColor(red: 0.9, green: 0.5, blue: 0.8, alpha: 1.0)]
        case .coralReef:
            return [UIColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1.0),
                    UIColor(red: 0.9, green: 0.6, blue: 0.7, alpha: 1.0)]
        case .electricViolet:
            return [UIColor(red: 0.6, green: 0.0, blue: 1.0, alpha: 1.0),
                    UIColor(red: 0.8, green: 0.2, blue: 0.9, alpha: 1.0)]
        }
    }
    
    var previewColors: [Color] {
        return colors.map { Color($0) }
    }
}

// MARK: - Stat Info with Icons

struct StatInfo {
    let key: String
    let value: String
    let icon: String
}

struct ShareSection: View {
    @ObservedObject var photoLoader: PhotoLoader
    let statistics: [String: String]
    @ObservedObject private var videoExporter: VideoExporter
    @State private var showExportTimeAlert = false
    @State private var shareImage: UIImage?
    @State private var isGenerating = false
    @State private var showShareSheet = false
    @State private var showVideoPlayer = false
    @State private var selectedTab = 0
    @State private var loadedFromCache = false
    @State private var selectedTheme: ImageTheme = .oceanBlue
    @State private var showFriendSelector = false
    @State private var selectedFriendIDs: Set<UUID> = []
    @AppStorage("userEmoji") private var userEmoji = "🚶"
    @AppStorage("userColor") private var userColor = "#33CCBB"
    @AppStorage("userName") private var userName = "You"
    
    @StateObject private var exportManager = VideoExportManager.shared
    
    @State private var showSuccessAlert = false
    @State private var justFinishedExport = false
    @State private var videoPlayerID = UUID()
    
    // ADD: Custom initializer to use shared videoExporter
    init(photoLoader: PhotoLoader, statistics: [String: String]) {
        self.photoLoader = photoLoader
        self.statistics = statistics
        
        // Get or create the shared exporter instance
        if photoLoader.videoExporter == nil {
            photoLoader.videoExporter = VideoExporter()
        }
        self._videoExporter = ObservedObject(wrappedValue: photoLoader.videoExporter!)
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Share Your Year")
                        .font(.system(size: 40, weight: .bold))
                        .padding(.top)
                    
                    Text("Export as Image or Video")
                        .font(.title3)
                        .foregroundColor(.gray)
                    
                    Picker("Export Type", selection: $selectedTab) {
                        Text("Image").tag(0)
                        Text("Video").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    
                    if !photoLoader.friends.isEmpty {
                        Button(action: { showFriendSelector = true }) {
                            HStack {
                                Image(systemName: "person.2.fill")
                                Text("Include Friends (\(selectedFriendIDs.count))")
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: selectedFriendIDs.isEmpty ?
                                    [Color.gray, Color.gray.opacity(0.8)] :
                                        [Color.orange, Color.orange.opacity(0.8)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(15)
                            .shadow(color: (selectedFriendIDs.isEmpty ? Color.gray : Color.orange).opacity(0.3), radius: 5, x: 0, y: 3)
                        }
                        .padding(.horizontal)
                    }
                    
                    if selectedTab == 0 {
                        imageExportView
                    } else {
                        videoExportView
                    }
                    
                    Spacer(minLength: 30)
                }
            }
            
            // UPDATED: Only show overlay for IMAGE generation (fast)
            // Video export uses the global banner now
            if isGenerating {
                Color.black.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)
                
                VStack(spacing: 30) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(2)
                    
                    VStack(spacing: 10) {
                        Text("Generating Image")
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                        
                        Text("This may take a minute...")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(40)
                .background(Color.black.opacity(0.8))
                .cornerRadius(20)
            }
        }
        .sheet(isPresented: $showFriendSelector) {
            FriendSelectorSheet(
                friends: photoLoader.friends,
                selectedFriendIDs: $selectedFriendIDs
            )
        }
        .sheet(isPresented: $showShareSheet) {
            if selectedTab == 0, let image = shareImage {
                ActivityViewController(activityItems: [image])
            } else if selectedTab == 1, let url = videoExporter.exportedVideoURL {
                ActivityViewController(activityItems: [url])
            }
        }
        .onAppear {
            loadCachedShareImage()
            loadCachedVideo()
        }
        .sheet(isPresented: $showVideoPlayer) {
            if let url = videoExporter.exportedVideoURL {
                VideoPlayerView(url: url)
            }
        }
    }
    
    private func exportVideo() {
        let selectedFriends = photoLoader.friends.filter { selectedFriendIDs.contains($0.id) }
        
        // DON'T clear the old video - just hide it during generation
        // The old URL stays intact so if generation fails, user still has their video
        justFinishedExport = false
        
        VideoExportManager.shared.startExport(
            exporter: videoExporter,
            locations: photoLoader.locations,
            timestamps: photoLoader.photoTimeStamps,
            statistics: statistics,
            friends: selectedFriends,
            loadPhotosFromCache: true
        )
    }
    // MARK: Image Export View
    private var imageExportView: some View {
        VStack(spacing: 25) {
            // Theme selector
            VStack(spacing: 15) {
                Text("Choose Your Style")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack(spacing: 20) {
                    Button(action: previousTheme) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.blue)
                    }
                    
                    VStack(spacing: 12) {
                        LinearGradient(
                            colors: selectedTheme.previewColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .frame(height: 100)
                        .cornerRadius(15)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                        )
                        .shadow(color: selectedTheme.previewColors[0].opacity(0.5), radius: 10, x: 0, y: 5)
                        
                        Text(selectedTheme.rawValue)
                            .font(.title3)
                            .fontWeight(.semibold)
                    }
                    .frame(width: 200)
                    
                    Button(action: nextTheme) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.vertical, 10)
            }
            .padding(.horizontal)
            .padding(.vertical, 15)
            .background(Color(.systemGray6))
            .cornerRadius(20)
            .padding(.horizontal)
            
            if let image = shareImage {
                VStack(spacing: 10) {
                    Text("Preview")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .cornerRadius(15)
                        .shadow(radius: 10)
                }
                .padding(.horizontal)
            } else {
                RoundedRectangle(cornerRadius: 15)
                    .fill(Color.gray.opacity(0.1))
                    .frame(height: 300)
                    .overlay(
                        VStack(spacing: 15) {
                            Image(systemName: "photo")
                                .font(.system(size: 50))
                                .foregroundColor(.gray)
                            Text("Generate to see preview")
                                .foregroundColor(.gray)
                                .font(.subheadline)
                        }
                    )
                    .padding(.horizontal)
            }
            
            VStack(spacing: 15) {
                Button(action: generateShareImage) {
                    HStack {
                        Image(systemName: shareImage == nil ? "sparkles" : "arrow.clockwise")
                        Text(shareImage == nil ? "Generate Image" : "Regenerate")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.blue.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(15)
                    .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 3)
                }
                .disabled(isGenerating || photoLoader.locations.isEmpty)
                
                if shareImage != nil {
                    Button(action: { showShareSheet = true }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Image")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(15)
                        .shadow(color: .green.opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    // MARK: - Cache Loading
    
    private func loadCachedShareImage() {
        if let cached = PersistenceManager.shared.loadLastShareImage() {
            // Check if cached image is recent (less than 7 days old)
            let daysSinceCreation = Date().timeIntervalSince(cached.timestamp) / 86400
            
            // Also check if statistics match current statistics
            let statsMatch = cached.statistics == statistics
            
            if daysSinceCreation < 7 && statsMatch {
                DispatchQueue.main.async {
                    self.shareImage = cached.image
                    self.selectedTheme = ImageTheme(rawValue: cached.theme) ?? .oceanBlue
                    self.loadedFromCache = true
                    print("Loaded cached share image from \(cached.timestamp)")
                }
            } else {
                print("ℹ️ Cached share image is outdated or stats changed")
            }
        }
    }
    
    private func loadCachedVideo() {
        if let cached = PersistenceManager.shared.loadLastVideoExport() {
            let daysSinceExport = Date().timeIntervalSince(cached.timestamp) / 86400
            let statsMatch = cached.statistics == statistics
            
            if daysSinceExport < 7 && statsMatch {
                DispatchQueue.main.async {
                    self.videoExporter.exportedVideoURL = cached.url
                    print("Loaded cached video export from \(cached.timestamp)")
                }
            } else {
                print("Cached video is outdated or stats changed")
            }
        }
    }
    
    
    
    // MARK: - Theme Navigation (update to clear cache when theme changes)
    
    private func previousTheme() {
        let allThemes = ImageTheme.allCases
        if let currentIndex = allThemes.firstIndex(of: selectedTheme) {
            let previousIndex = (currentIndex - 1 + allThemes.count) % allThemes.count
            selectedTheme = allThemes[previousIndex]
            shareImage = nil // Clear current image
            loadedFromCache = false
        }
    }
    
    private func nextTheme() {
        let allThemes = ImageTheme.allCases
        if let currentIndex = allThemes.firstIndex(of: selectedTheme) {
            let nextIndex = (currentIndex + 1) % allThemes.count
            selectedTheme = allThemes[nextIndex]
            shareImage = nil // Clear current image
            loadedFromCache = false
        }
    }
    
    // MARK: - Video Export View

    private var videoExportView: some View {
        VStack(spacing: 20) {
            if let videoURL = videoExporter.exportedVideoURL {
                // Show video player (even during export, but we'll hide it)
                if !exportManager.isExporting {
                    // FIX: Use stable player with proper lifecycle
                    StableVideoPlayer(url: videoURL)
                        .frame(height: 500)
                        .cornerRadius(20)
                        .shadow(radius: 10)
                        .padding(.horizontal)
                    
                    HStack(spacing: 15) {
                        Button(action: { showVideoPlayer = true }) {
                            Label("Play", systemImage: "play.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        
                        Button(action: { showShareSheet = true }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal)
                    
                    Button(action: exportVideo) {
                        Label("Export Again", systemImage: "arrow.clockwise")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    .disabled(exportManager.isExporting)
                    
                } else {
                    // Show generating state instead of video player during re-export
                    VStack(spacing: 30) {
                        ProgressView(value: exportManager.exportProgress)
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(2)
                        
                        VStack(spacing: 10) {
                            Text("Creating Your Video")
                                .font(.title2)
                                .bold()
                            
                            Text("\(Int(exportManager.exportProgress * 100))%")
                                .font(.title)
                                .bold()
                                .foregroundColor(.blue)
                            
                            Text("This may take 1-2 minutes")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("You can explore the app open while exporting, we'll notify you when it's ready")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                                .padding(.top, 10)
                        }
                    }
                    .frame(height: 500)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(20)
                    .padding(.horizontal)
                }
                
            } else {
                // No video exists yet - rest stays the same
                VStack(spacing: 20) {
                    if exportManager.isExporting {
                        // GENERATING STATE (first time)
                        VStack(spacing: 30) {
                            ProgressView(value: exportManager.exportProgress)
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(2)
                            
                            VStack(spacing: 10) {
                                Text("Creating Your Video")
                                    .font(.title2)
                                    .bold()
                                
                                Text("\(Int(exportManager.exportProgress * 100))%")
                                    .font(.title)
                                    .bold()
                                    .foregroundColor(.blue)
                                
                                Text("This may take 1-2 minutes")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text("You can navigate away - check the banner at the bottom")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 30)
                                    .padding(.top, 10)
                            }
                        }
                        .frame(height: 500)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                        .padding(.horizontal)
                        
                    } else {
                        // READY TO EXPORT STATE
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.gray.opacity(0.1))
                            .frame(height: 500)
                            .overlay(
                                VStack(spacing: 20) {
                                    Image(systemName: "video.badge.plus")
                                        .font(.system(size: 80))
                                        .foregroundColor(.gray)
                                    
                                    Text("Ready to create your video")
                                        .font(.headline)
                                        .foregroundColor(.gray)
                                    
                                    Text("\(photoLoader.locations.count) locations")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                            )
                            .padding(.horizontal)
                    }
                    
                    VStack(alignment: .leading, spacing: 15) {
                        Label("Your video will include:", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundColor(.green)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "map")
                                Text("Animated map of your journey")
                            }
                            HStack {
                                Image(systemName: "chart.bar")
                                Text("Key statistics")
                            }
                            HStack {
                                Image(systemName: "clock")
                                Text("15 seconds, perfect for Stories")
                            }
                            HStack {
                                Image(systemName: "rectangle.portrait")
                                Text("1080x1920 (Instagram format)")
                            }
                            if !selectedFriendIDs.isEmpty {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                    Text("\(selectedFriendIDs.count) friend\(selectedFriendIDs.count == 1 ? "" : "s") included")
                                }
                                .foregroundColor(.orange)
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                    .padding(.horizontal)
                    
                    // THIS IS THE BUTTON THAT NEEDS THE ALERT
                    Button(action: {
                        UNUserNotificationCenter.current().getNotificationSettings { settings in
                            DispatchQueue.main.async {
                                if settings.authorizationStatus == .notDetermined {
                                    showExportTimeAlert = true
                                } else {
                                    exportVideo()
                                }
                            }
                        }
                    }) {
                        HStack {
                            if exportManager.isExporting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Creating Video...")
                            } else {
                                Image(systemName: "play.rectangle.fill")
                                Text("Create Video")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(exportManager.isExporting ? Color.gray : Color.red)
                        .cornerRadius(15)
                    }
                    .padding(.horizontal)
                    .disabled(photoLoader.locations.isEmpty || exportManager.isExporting)
                    .alert("Video Export", isPresented: $showExportTimeAlert) {
                        Button("Cancel", role: .cancel) {}
                        Button("Start Export") {
                            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                                DispatchQueue.main.async {
                                    exportVideo()
                                }
                            }
                        }
                    } message: {
                        Text("This may take 1-2 minutes. We can notify you when it's done so you can navigate away.")
                    }
                }
            }
            
            if let error = videoExporter.exportError {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                    .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Get Top 8 Stats with Icons
    
    
    private func getTop8Stats() -> [StatInfo] {
        var iconMap: [String: String] = [
            "Photos with Location": "camera.fill",
            "Places Visited": "mappin.and.ellipse",
            "Total Distance": "arrow.left.and.right",
            "Farthest From Home": "airplane",
            "Avg Photos/Day": "calendar",
            "Most Active Month": "chart.bar.fill",
            "Longest Gap": "timer"
        ]
        
        if let photoStyle = statistics["Photo Style"] {
            if photoStyle.contains("Early Bird") {
                iconMap["Photo Style"] = "sun.max.fill"
            } else {
                iconMap["Photo Style"] = "moon.stars.fill"
            }
        }
        
        let priority = [
            "Total Distance",
            "Places Visited",
            "Photos with Location",
            "Most Active Month",
            "Photo Style",
            "Farthest From Home",
            "Avg Photos/Day",
            "Longest Gap"
        ]
        
        var result: [StatInfo] = []
        for key in priority {
            if let value = statistics[key], let icon = iconMap[key] {
                result.append(StatInfo(key: key, value: value, icon: icon))
                if result.count == 8 { break }
            }
        }
        
        for (key, value) in statistics {
            if result.count >= 8 { break }
            if !priority.contains(key) {
                let icon = iconMap[key] ?? "star.fill"
                result.append(StatInfo(key: key, value: value, icon: icon))
            }
        }
        
        return result
    }
    
    // MARK: - Generate Share Image
    
    private func generateShareImage() {
        guard !photoLoader.locations.isEmpty else { return }
        
        isGenerating = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let image = self.createShareImage()
            
            DispatchQueue.main.async {
                self.shareImage = image
                self.isGenerating = false
                self.loadedFromCache = false
                
                // Cache the generated image
                DispatchQueue.global(qos: .utility).async {
                    PersistenceManager.shared.cacheLastShareImage(
                        image,
                        theme: self.selectedTheme.rawValue,
                        statistics: self.statistics
                    )
                    print("Cached new share image")
                }
            }
        }
    }
    
    private func createShareImage() -> UIImage {
        let size = ResponsiveLayout.exportImageSize
        let width = size.width
        let height = size.height
        let mapHeight = ResponsiveLayout.scaleHeight(950) * (height / 1920)
        let mapStartY: CGFloat = 250
        
        let format = UIGraphicsImageRendererFormat()
            format.opaque = true
            format.scale = 2.0
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))
        
        return renderer.image { context in
            let ctx = context.cgContext
            
            // Background gradient
            let colors = selectedTheme.colors.map { $0.cgColor }
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: colors as CFArray,
                                      locations: [0.0, 1.0])!
            ctx.drawLinearGradient(gradient,
                                   start: CGPoint(x: 0, y: 0),
                                   end: CGPoint(x: 0, y: height),
                                   options: [])
            
            // Title
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: width * 0.074, weight: .black),
                .foregroundColor: UIColor.white
            ]
            let title = "My 2025 Mapped"
            let titleSize = title.size(withAttributes: titleAttrs)
            title.draw(at: CGPoint(x: (width - titleSize.width) / 2, y: 120), withAttributes: titleAttrs)
            
            // Map rect
            let padding = width * 0.037 // 40/1080 ratio
            let mapRect = CGRect(x: padding, y: mapStartY, width: width - (padding * 2), height: mapHeight)
            
            // Generate and draw map
            if let mapData = self.generateMapSnapshotForImage() {
                ctx.saveGState()
                ctx.addPath(CGPath(roundedRect: mapRect, cornerWidth: 20, cornerHeight: 20, transform: nil))
                ctx.clip()
                mapData.image.draw(in: mapRect)
                ctx.restoreGState()
                
                // Draw friend paths FIRST (underneath your path)
                let selectedFriends = self.photoLoader.friends.filter { self.selectedFriendIDs.contains($0.id) }
                for friend in selectedFriends {
                    self.drawFriendPathOnImage(
                        context: ctx,
                        mapRect: mapRect,
                        mapData: mapData,
                        friend: friend
                    )
                }
                
                // Draw YOUR path on top
                self.drawPathOnImage(
                    context: ctx,
                    mapRect: mapRect,
                    mapData: mapData
                )
                
                // Draw legend if friends are included
                if !selectedFriends.isEmpty {
                    self.drawMapLegend(
                        context: ctx,
                        mapRect: mapRect,
                        selectedFriends: selectedFriends
                    )
                }
                
                // Map border
                ctx.setStrokeColor(UIColor.white.cgColor)
                ctx.setLineWidth(width * 0.0046) // 5/1080 ratio
                ctx.addPath(CGPath(roundedRect: mapRect, cornerWidth: 20, cornerHeight: 20, transform: nil))
                ctx.strokePath()
            }
            
            // Statistics - SINGLE COLUMN
            let statsStartY: CGFloat = mapStartY + mapHeight + 35
            let statsWidth = (width - (width * 0.093)) / 2 // 100/1080 ratio
            let statsHeight = height * 0.073 // 140/1920 ratio
            let horizontalSpacing = width * 0.0185 // 20/1080 ratio
            let verticalSpacing = height * 0.0078 // 15/1920 ratio
            let leftMargin: CGFloat = 40
            
            let top8Stats = self.getTop8Stats()
            
            for (index, stat) in top8Stats.enumerated() {
                let row = index / 2
                let col = index % 2
                
                let x = leftMargin + CGFloat(col) * (statsWidth + horizontalSpacing)
                let y = statsStartY + CGFloat(row) * (statsHeight + verticalSpacing)
                
                let statRect = CGRect(x: x, y: y, width: statsWidth, height: statsHeight)
                
                // Background with slight transparency
                ctx.setFillColor(UIColor.white.withAlphaComponent(0.15).cgColor)
                ctx.addPath(CGPath(roundedRect: statRect, cornerWidth: 15, cornerHeight: 15, transform: nil))
                ctx.fillPath()
                
                // Icon on the right (WHITE to match text)
                let iconSize = width * 0.06
                let iconPadding: CGFloat = 20
                if let iconImage = self.systemIconImage(named: stat.icon, size: iconSize) {
                    let iconX = x + statsWidth - iconSize - iconPadding
                    let iconY = y + (statsHeight - iconSize) / 2
                    let iconRect = CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize)
                    iconImage.draw(in: iconRect)
                }
                
                let textLeftPadding = width * 0.0185 // 20/1080 ratio
                let textRightPadding = width * 0.102 // 110/1080 ratio
                let textWidth = statsWidth - textLeftPadding - textRightPadding
                
                // Key (label)
                let keyAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: width * 0.0204, weight: .semibold),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.85)
                ]
                let keyText = stat.key as NSString
                let keyRect = CGRect(x: x + textLeftPadding, y: y + 25, width: textWidth, height: 60)
                keyText.draw(in: keyRect, withAttributes: keyAttrs)
                
                // Value
                let valueAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: width * 0.0296, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                let valueText = stat.value as NSString
                let valueRect = CGRect(x: x + textLeftPadding, y: y + 70, width: textWidth, height: 60)
                valueText.draw(in: valueRect, withAttributes: valueAttrs)
            }
        }
    }
    
    // MARK: - Helper: Generate SF Symbol Image
    
    private func systemIconImage(named: String, size: CGFloat) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: .semibold)
        
        return UIImage(systemName: named, withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal)
    }
    // MARK: - Map Snapshot for Image
    
    private func generateMapSnapshotForImage() -> (image: UIImage, snapshot: MKMapSnapshotter.Snapshot)? {
        guard !photoLoader.locations.isEmpty else { return nil }
        
        let options = MKMapSnapshotter.Options()
        
        // Get all locations including selected friends
        var allLocations = photoLoader.locations
        let selectedFriends = photoLoader.friends.filter { selectedFriendIDs.contains($0.id) }
        for friend in selectedFriends {
            allLocations.append(contentsOf: friend.coordinates)
        }
        
        guard !allLocations.isEmpty else { return nil }
        
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
        
        let exportSize = ResponsiveLayout.exportImageSize
        let snapshotSize = exportSize.width * 0.926 // 1000/1080 ratio
        options.region = MKCoordinateRegion(center: center, span: span)
        options.size = CGSize(width: snapshotSize, height: snapshotSize)
        
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
    
    // MARK: - Draw Friend Path on Image
    
    private func drawFriendPathOnImage(
        context: CGContext,
        mapRect: CGRect,
        mapData: (image: UIImage, snapshot: MKMapSnapshotter.Snapshot),
        friend: FriendData
    ) {
        let locations = friend.coordinates
        guard !locations.isEmpty else { return }
        
        let snapshotObj = mapData.snapshot
        let snapshotSize = mapData.image.size
        
        func coordinateToPoint(_ coord: CLLocationCoordinate2D) -> CGPoint {
            let snapshotPoint = snapshotObj.point(for: coord)
            let scaleX = mapRect.width / snapshotSize.width
            let scaleY = mapRect.height / snapshotSize.height
            
            return CGPoint(
                x: mapRect.minX + (snapshotPoint.x * scaleX),
                y: mapRect.minY + (snapshotPoint.y * scaleY)
            )
        }
        
        // Get friend's color
        let friendUIColor = UIColor(hex: friend.color) ?? UIColor.systemRed
        
        // Draw friend path
        context.saveGState()
        context.setStrokeColor(friendUIColor.cgColor)
        context.setLineWidth(5) // Same width as your path
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
        
        // Draw friend pins - SAME COLOR AS PATH
                context.saveGState()
                let dotSize: CGFloat = ResponsiveLayout.exportImageSize.width * 0.0111 // 12/1080 ratio
                let dotRadius = dotSize / 2
                for location in locations {
                    let point = coordinateToPoint(location)
                    
                    context.setFillColor(friendUIColor.cgColor)
                    context.fillEllipse(in: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotSize, height: dotSize))
                    context.setStrokeColor(UIColor.white.cgColor)
                    context.setLineWidth(2)
                    context.strokeEllipse(in: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotSize, height: dotSize))
                }
                context.restoreGState()
    }
    
    // MARK: - Draw Path on Image
    
    private func drawPathOnImage(
        context: CGContext,
        mapRect: CGRect,
        mapData: (image: UIImage, snapshot: MKMapSnapshotter.Snapshot)
    ) {
        guard !photoLoader.locations.isEmpty else { return }
        
        let snapshotObj = mapData.snapshot
        let snapshotSize = mapData.image.size
        
        func coordinateToPoint(_ coord: CLLocationCoordinate2D) -> CGPoint {
            let snapshotPoint = snapshotObj.point(for: coord)
            let scaleX = mapRect.width / snapshotSize.width
            let scaleY = mapRect.height / snapshotSize.height
            
            return CGPoint(
                x: mapRect.minX + (snapshotPoint.x * scaleX),
                y: mapRect.minY + (snapshotPoint.y * scaleY)
            )
        }
        
        // Draw YOUR path - use custom color
        context.saveGState()
        if let userUIColor = UIColor(hex: userColor) {
            context.setStrokeColor(userUIColor.cgColor)
        } else {
            context.setStrokeColor(UIColor.systemBlue.cgColor)
        }
        context.setLineWidth(5)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        let firstPoint = coordinateToPoint(photoLoader.locations[0])
        context.move(to: firstPoint)
        
        for i in 1..<photoLoader.locations.count {
            let point = coordinateToPoint(photoLoader.locations[i])
            context.addLine(to: point)
        }
        
        context.strokePath()
        context.restoreGState()
        
        // Draw YOUR pins - use custom color
                context.saveGState()
                let dotSize: CGFloat = ResponsiveLayout.exportImageSize.width * 0.0111 // 12/1080 ratio
                let dotRadius = dotSize / 2
                for location in photoLoader.locations {
                    let point = coordinateToPoint(location)
                    
                    if let userUIColor = UIColor(hex: userColor) {
                        context.setFillColor(userUIColor.cgColor)
                    } else {
                        context.setFillColor(UIColor.systemBlue.cgColor)
                    }
                    context.fillEllipse(in: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotSize, height: dotSize))
                    context.setStrokeColor(UIColor.white.cgColor)
                    context.setLineWidth(2)
                    context.strokeEllipse(in: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotSize, height: dotSize))
                }
                context.restoreGState()
    }
    
    
    // MARK: - Draw Map Legend
    
    private func drawMapLegend(
        context: CGContext,
        mapRect: CGRect,
        selectedFriends: [FriendData]
    ) {
        guard !selectedFriends.isEmpty else { return }
        
        // Legend background - top right of map
        let legendPadding: CGFloat = 15
        let legendItemHeight: CGFloat = 35
        let legendWidth: CGFloat = 180
        let legendHeight: CGFloat = CGFloat(selectedFriends.count + 1) * legendItemHeight + legendPadding * 2
        
        let legendX = mapRect.maxX - legendWidth - 20
        let legendY = mapRect.minY + 20
        let legendRect = CGRect(x: legendX, y: legendY, width: legendWidth, height: legendHeight)
        
        // Draw legend background
        context.setFillColor(UIColor.black.withAlphaComponent(0.7).cgColor)
        context.addPath(CGPath(roundedRect: legendRect, cornerWidth: 10, cornerHeight: 10, transform: nil))
        context.fillPath()
        
        var currentY = legendY + legendPadding
        
        // Draw "You" entry with custom color/emoji
        drawLegendEntry(
            context: context,
            x: legendX + legendPadding,
            y: currentY,
            color: UIColor(hex: userColor) ?? UIColor.systemBlue,
            label: userName,
            emoji: userEmoji,
            profileImage: nil
        )
        currentY += legendItemHeight
        
        // Draw friend entries
        for friend in selectedFriends {
            let friendColor = UIColor(hex: friend.color) ?? UIColor.systemRed
            var profileImage: UIImage?
            if let imageData = friend.profileImageData {
                profileImage = UIImage(data: imageData)
            }
            
            drawLegendEntry(
                context: context,
                x: legendX + legendPadding,
                y: currentY,
                color: friendColor,
                label: friend.name,
                emoji: friend.emoji,
                profileImage: profileImage
            )
            currentY += legendItemHeight
        }
    }
    
    private func drawLegendEntry(
        context: CGContext,
        x: CGFloat,
        y: CGFloat,
        color: UIColor,
        label: String,
        emoji: String?,  // Make this optional now
        profileImage: UIImage?
    ) {
        // Draw colored circle
        let circleSize: CGFloat = 24
        let circleRect = CGRect(x: x, y: y, width: circleSize, height: circleSize)
        
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: circleRect)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2)
        context.strokeEllipse(in: circleRect)
        
        // Draw emoji if provided
        if let emoji = emoji {
            let emojiAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 14)
            ]
            let emojiSize = emoji.size(withAttributes: emojiAttrs)
            let emojiX = x + (circleSize - emojiSize.width) / 2
            let emojiY = y + (circleSize - emojiSize.height) / 2
            emoji.draw(at: CGPoint(x: emojiX, y: emojiY), withAttributes: emojiAttrs)
        }
        
        // Draw label
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        
        let labelX = x + circleSize + 10
        let labelY = y + (circleSize - 16) / 2
        label.draw(at: CGPoint(x: labelX, y: labelY), withAttributes: labelAttrs)
    }
}
    // MARK: - Friend Selector Sheet

struct FriendSelectorSheet: View {
    let friends: [FriendData]
    @Binding var selectedFriendIDs: Set<UUID>
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(friends) { friend in
                        FriendSelectionRow(
                            friend: friend,
                            isSelected: selectedFriendIDs.contains(friend.id)
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedFriendIDs.contains(friend.id) {
                                selectedFriendIDs.remove(friend.id)
                            } else {
                                selectedFriendIDs.insert(friend.id)
                            }
                        }
                    }
                } header: {
                    Text("Select friends to include in export")
                } footer: {
                    if !selectedFriendIDs.isEmpty {
                        Text("\(selectedFriendIDs.count) friend\(selectedFriendIDs.count == 1 ? "" : "s") selected")
                    }
                }
            }
            .navigationTitle("Include Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear All") {
                        selectedFriendIDs.removeAll()
                    }
                    .disabled(selectedFriendIDs.isEmpty)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FriendSelectionRow: View {
    let friend: FriendData
    let isSelected: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            // Profile picture or emoji
            ZStack {
                Circle()
                    .fill(Color(hex: friend.color) ?? .gray)
                    .frame(width: 45, height: 45)
                
                if let imageData = friend.profileImageData,
                   let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 42, height: 42)
                        .clipShape(Circle())
                } else {
                    Text(friend.emoji)
                        .font(.system(size: 24))
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.name)
                    .font(.headline)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color(hex: friend.color) ?? .gray)
                        .frame(width: 8, height: 8)
                    Text("\(friend.locations.count) locations")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            } else {
                Image(systemName: "circle")
                    .font(.title2)
                    .foregroundColor(.gray.opacity(0.3))
            }
        }
        .padding(.vertical, 4)
    }
}

    // MARK: - Video Player View

struct VideoPlayerView: View {
    let url: URL
    @Environment(\.dismiss) var dismiss
    @StateObject private var playerViewModel = VideoPlayerViewModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                StableVideoPlayer(url: url)
                    .onAppear {
                        AudioSessionManager.allowBackgroundMusic()
                        playerViewModel.setupPlayer(with: url)
                    }
                    .onDisappear {
                        playerViewModel.cleanup()
                    }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
}

class VideoPlayerViewModel: ObservableObject {
    private var player: AVPlayer?
    
    func setupPlayer(with url: URL) {
        player = AVPlayer(url: url)
        player?.automaticallyWaitsToMinimizeStalling = true
    }
    
    func cleanup() {
        player?.pause()
        player = nil
    }
}

    // MARK: - Activity View Controller (for sharing)

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        
        // CRITICAL: Don't exclude anything that might help sharing
        controller.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks
        ]
        
        // Allow file sharing services
        controller.allowsProminentActivity = true
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

struct StableVideoPlayer: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        AudioSessionManager.allowBackgroundMusic()
            
        let controller = AVPlayerViewController()
        let player = AVPlayer(url: url)
            
        // Configure player for better stability
        player.automaticallyWaitsToMinimizeStalling = true
        player.allowsExternalPlayback = false

            
        controller.player = player
        controller.showsPlaybackControls = true
        controller.allowsPictureInPicturePlayback = false
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Only update if URL changed
        if uiViewController.player?.currentItem?.asset as? AVURLAsset != AVURLAsset(url: url) {
            let player = AVPlayer(url: url)
            player.automaticallyWaitsToMinimizeStalling = true
            player.allowsExternalPlayback = false
            uiViewController.player = player
            context.coordinator.observePlayer(player)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        private var playerObserver: NSKeyValueObservation?
        private var itemObserver: NSKeyValueObservation?
        
        func observePlayer(_ player: AVPlayer) {
            // Clean up old observers
            playerObserver?.invalidate()
            itemObserver?.invalidate()
            
            // Observe playback failures
            itemObserver = player.currentItem?.observe(\.status) { item, _ in
                if item.status == .failed {
                    print("Player item failed: \(item.error?.localizedDescription ?? "unknown error")")
                }
            }
            
            // Auto-restart if player stalls
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemPlaybackStalled,
                object: player.currentItem,
                queue: .main
            ) { _ in
                print("Playback stalled, seeking to recover...")
                player.seek(to: player.currentTime())
                player.play()
            }
        }
        
        deinit {
            playerObserver?.invalidate()
            itemObserver?.invalidate()
        }
    }
}

class AudioSessionManager {
    static func allowBackgroundMusic() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set audio session: \(error)")
        }
    }
}
