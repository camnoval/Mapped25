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
            // Check if we need to invalidate caches
            let currentCount = photoLoader.locations.count
            let cachedCount = UserDefaults.standard.integer(forKey: "LastPhotoLocationCount")
            
            if cachedCount != currentCount {
                print("📊 Location count changed from \(cachedCount) to \(currentCount), clearing caches")
                shareImage = nil
                videoExporter.exportedVideoURL = nil
                UserDefaults.standard.set(currentCount, forKey: "LastPhotoLocationCount")
            } else {
                loadCachedShareImage()
                loadCachedVideo()
            }
        }
        .sheet(isPresented: $showVideoPlayer) {
            if let url = videoExporter.exportedVideoURL {
                VideoPlayerView(url: url)
            }
        }
    }
    
    private func exportVideo() {
        let selectedFriends = photoLoader.friends.filter { selectedFriendIDs.contains($0.id) }
        
        justFinishedExport = false
        
        // Store current count before export
        UserDefaults.standard.set(photoLoader.locations.count, forKey: "LastPhotoLocationCount")
        
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
                    Button(action: {
                        previousTheme()
                        generateShareImage()
                    }) {
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
                    
                    Button(action: {
                        nextTheme()
                        generateShareImage()
                    }) {
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
            
            // ⭐ Path Color Selector - updates global userColor
            VStack(spacing: 15) {
                Text("Your Path Color")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 10) {
                    ForEach(pathColorOptions, id: \.1) { colorName, colorHex in
                        Button(action: {
                            userColor = colorHex  // ⭐ Update global color
                            generateShareImage()  // Auto-regenerate
                        }) {
                            VStack(spacing: 5) {
                                Circle()
                                    .fill(Color(hex: colorHex) ?? .gray)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(
                                                userColor == colorHex ? Color.primary : Color.clear,  // ⭐ Compare with userColor
                                                lineWidth: 3
                                            )
                                    )
                                
                            }
                        }
                    }
                }
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
            } else if isGenerating {
                VStack(spacing: 15) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(1.5)
                    Text("Generating image...")
                        .foregroundColor(.gray)
                        .font(.subheadline)
                }
                .frame(height: 300)
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
                            Text("Loading preview...")
                                .foregroundColor(.gray)
                                .font(.subheadline)
                        }
                    )
                    .padding(.horizontal)
            }
            
            VStack(spacing: 15) {
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
        .onChange(of: selectedFriendIDs) { _ in
                // Regenerate image when friend selection changes
                generateShareImage()
            }
        .onAppear {
            //RESET to Ocean Blue on appear, keep user's current path color
            selectedTheme = .oceanBlue
            shareImage = nil  // Clear cached image to force regeneration
            
            // Auto-generate with fresh settings
            if !isGenerating {
                generateShareImage()
            }
        }
    }

    //Path color options - use the same set from FriendsManagerView for consistency
    private let pathColorOptions: [(String, String)] = [
        ("Red", "#FF0000"), ("Orange", "#FF8800"), ("Yellow", "#FFD700"),
        ("Green", "#00FF00"), ("Teal", "#00CCCC"), ("Blue", "#0000FF"),
        ("Purple", "#8800FF"), ("Pink", "#FF0088"), ("Magenta", "#FF00FF"),
        ("Cyan", "#00FFFF"), ("Lime", "#00FF88"), ("Coral", "#FF6666"),
        ("Indigo", "#4B0082"), ("Violet", "#8B008B"), ("Crimson", "#DC143C"),
        ("Navy", "#000080"), ("Maroon", "#800000"), ("Olive", "#808000")
    ]
    
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
                
                // Save current location count
                UserDefaults.standard.set(self.photoLoader.locations.count, forKey: "LastPhotoLocationCount")
                
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
            let padding = width * 0.037
            let mapRect = CGRect(x: padding, y: mapStartY, width: width - (padding * 2), height: mapHeight)
            
            // Generate and draw map
            if let mapData = self.generateMapSnapshotForImage() {
                ctx.saveGState()
                ctx.addPath(CGPath(roundedRect: mapRect, cornerWidth: 20, cornerHeight: 20, transform: nil))
                ctx.clip()
                mapData.image.draw(in: mapRect)
                ctx.restoreGState()
                
                // Draw legend if friends are included
                let selectedFriends = mapData.selectedFriends
                if !selectedFriends.isEmpty {
                    self.drawMapLegend(
                        context: ctx,
                        mapRect: mapRect,
                        selectedFriends: selectedFriends
                    )
                }
                
                // Draw exit indicators for region jumps
                let allLocations = self.photoLoader.locations + selectedFriends.flatMap { $0.coordinates }
                let regions = self.detectRegions(from: allLocations)
                
                if regions.count > 1 {
                    print("🗺️ Detected \(regions.count) regions, drawing exit indicators")
                    self.drawExitIndicators(
                        context: ctx,
                        mapRect: mapRect,
                        mapData: (mapData.image, mapData.snapshot),
                        regions: regions
                    )
                }
                
                // Map border
                ctx.setStrokeColor(UIColor.white.cgColor)
                ctx.setLineWidth(width * 0.0046)
                ctx.addPath(CGPath(roundedRect: mapRect, cornerWidth: 20, cornerHeight: 20, transform: nil))
                ctx.strokePath()
            }
            
            // Statistics - SINGLE COLUMN
            let statsStartY: CGFloat = mapStartY + mapHeight + 35
            let statsWidth = (width - (width * 0.093)) / 2
            let statsHeight = height * 0.073
            let horizontalSpacing = width * 0.0185
            let verticalSpacing = height * 0.0078
            let leftMargin: CGFloat = 40
            
            let top8Stats = self.getTop8Stats()
            
            for (index, stat) in top8Stats.enumerated() {
                let row = index / 2
                let col = index % 2
                
                let x = leftMargin + CGFloat(col) * (statsWidth + horizontalSpacing)
                let y = statsStartY + CGFloat(row) * (statsHeight + verticalSpacing)
                
                let statRect = CGRect(x: x, y: y, width: statsWidth, height: statsHeight)
                
                ctx.setFillColor(UIColor.white.withAlphaComponent(0.15).cgColor)
                ctx.addPath(CGPath(roundedRect: statRect, cornerWidth: 15, cornerHeight: 15, transform: nil))
                ctx.fillPath()
                
                let iconSize = width * 0.06
                let iconPadding: CGFloat = 20
                if let iconImage = self.systemIconImage(named: stat.icon, size: iconSize) {
                    let iconX = x + statsWidth - iconSize - iconPadding
                    let iconY = y + (statsHeight - iconSize) / 2
                    let iconRect = CGRect(x: iconX, y: iconY, width: iconSize, height: iconSize)
                    iconImage.draw(in: iconRect)
                }
                
                let textLeftPadding = width * 0.0185
                let textRightPadding = width * 0.102
                let textWidth = statsWidth - textLeftPadding - textRightPadding
                
                let keyAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: width * 0.0204, weight: .semibold),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.85)
                ]
                let keyText = stat.key as NSString
                let keyRect = CGRect(x: x + textLeftPadding, y: y + 25, width: textWidth, height: 60)
                keyText.draw(in: keyRect, withAttributes: keyAttrs)
                
                let valueToDisplay = stat.key.contains("Date Range") ?
                    formatDateRangeWithoutYear(stat.value) : stat.value
                
                let valueAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: width * 0.0296, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                let valueText = valueToDisplay as NSString
                let valueRect = CGRect(x: x + textLeftPadding, y: y + 70, width: textWidth, height: 60)
                valueText.draw(in: valueRect, withAttributes: valueAttrs)
            }
        }
    }
    
    // MARK: - Draw Connector Lines for Image Export

    private func drawRegionConnectorsForImage(
        context: CGContext,
        locations: [CLLocationCoordinate2D],
        mainRegion: MapRegion,
        insetSnapshots: [(region: MapRegion, snapshot: MKMapSnapshotter.Snapshot)],
        insetPositions: [(x: CGFloat, y: CGFloat)],
        mainSnapshot: MKMapSnapshotter.Snapshot,
        mapSize: CGFloat,
        insetSize: CGFloat,
        userColor: UIColor
    ) {
        guard insetSnapshots.count > 1 else { return }
        
        let snapshotSize = mainSnapshot.image.size
        
        // Helper to convert coordinate to point on main map
        func coordinateToMainMapPoint(_ coord: CLLocationCoordinate2D) -> CGPoint {
            let snapshotPoint = mainSnapshot.point(for: coord)
            let scaleX = mapSize / snapshotSize.width
            let scaleY = mapSize / snapshotSize.height
            
            return CGPoint(
                x: snapshotPoint.x * scaleX,
                y: snapshotPoint.y * scaleY
            )
        }
        
        // Track region transitions
        for i in 1..<locations.count {
            let prevLocation = locations[i - 1]
            let currentLocation = locations[i]
            
            let prevInMain = isCoordinate(prevLocation, inRegion: mainRegion)
            let currInMain = isCoordinate(currentLocation, inRegion: mainRegion)
            
            // Case 1: Jump FROM main TO inset
            if prevInMain && !currInMain {
                for (insetIndex, insetData) in insetSnapshots.enumerated() {
                    if isCoordinate(currentLocation, inRegion: insetData.region) {
                        guard insetIndex < insetPositions.count else { break }
                        
                        let mainPoint = coordinateToMainMapPoint(prevLocation)
                        let destinationOnMainMap = coordinateToMainMapPoint(currentLocation)
                        
                        // Draw line on main map (clipped)
                        drawConnectorLineForImage(
                            context: context,
                            from: mainPoint,
                            to: destinationOnMainMap,
                            color: userColor,
                            clipRect: CGRect(x: 0, y: 0, width: mapSize, height: mapSize)
                        )
                        
                        // Draw line to inset
                        let insetPosition = insetPositions[insetIndex]
                        let insetRect = CGRect(x: insetPosition.x, y: insetPosition.y, width: insetSize, height: insetSize)
                        let insetSnapshot = insetData.snapshot
                        let insetSnapPoint = insetSnapshot.point(for: currentLocation)
                        let insetPoint = CGPoint(
                            x: insetRect.minX + (insetSnapPoint.x / insetSnapshot.image.size.width) * insetSize,
                            y: insetRect.minY + (insetSnapPoint.y / insetSnapshot.image.size.height) * insetSize
                        )
                        
                        drawConnectorLineForImage(
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
                for (insetIndex, insetData) in insetSnapshots.enumerated() {
                    if isCoordinate(prevLocation, inRegion: insetData.region) {
                        guard insetIndex < insetPositions.count else { break }
                        
                        let insetPosition = insetPositions[insetIndex]
                        let insetRect = CGRect(x: insetPosition.x, y: insetPosition.y, width: insetSize, height: insetSize)
                        let insetSnapshot = insetData.snapshot
                        let insetSnapPoint = insetSnapshot.point(for: prevLocation)
                        let insetPoint = CGPoint(
                            x: insetRect.minX + (insetSnapPoint.x / insetSnapshot.image.size.width) * insetSize,
                            y: insetRect.minY + (insetSnapPoint.y / insetSnapshot.image.size.height) * insetSize
                        )
                        
                        let departureOnMainMap = coordinateToMainMapPoint(prevLocation)
                        let mainPoint = coordinateToMainMapPoint(currentLocation)
                        
                        drawConnectorLineForImage(
                            context: context,
                            from: insetPoint,
                            to: departureOnMainMap,
                            color: userColor,
                            style: .fromInset,
                            clipRect: insetRect
                        )
                        
                        drawConnectorLineForImage(
                            context: context,
                            from: departureOnMainMap,
                            to: mainPoint,
                            color: userColor,
                            clipRect: CGRect(x: 0, y: 0, width: mapSize, height: mapSize)
                        )
                        break
                    }
                }
            }
            
            // Case 3: Jump between insets
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
                    
                    // Get points in both insets
                    let prevInsetPos = insetPositions[prevIdx]
                    let prevInsetRect = CGRect(x: prevInsetPos.x, y: prevInsetPos.y, width: insetSize, height: insetSize)
                    let prevInsetSnapshot = insetSnapshots[prevIdx].snapshot
                    let prevSnapPoint = prevInsetSnapshot.point(for: prevLocation)
                    let prevPoint = CGPoint(
                        x: prevInsetRect.minX + (prevSnapPoint.x / prevInsetSnapshot.image.size.width) * insetSize,
                        y: prevInsetRect.minY + (prevSnapPoint.y / prevInsetSnapshot.image.size.height) * insetSize
                    )
                    
                    let prevOnMainMap = coordinateToMainMapPoint(prevLocation)
                    let currOnMainMap = coordinateToMainMapPoint(currentLocation)
                    
                    let currInsetPos = insetPositions[currIdx]
                    let currInsetRect = CGRect(x: currInsetPos.x, y: currInsetPos.y, width: insetSize, height: insetSize)
                    let currInsetSnapshot = insetSnapshots[currIdx].snapshot
                    let currSnapPoint = currInsetSnapshot.point(for: currentLocation)
                    let currPoint = CGPoint(
                        x: currInsetRect.minX + (currSnapPoint.x / currInsetSnapshot.image.size.width) * insetSize,
                        y: currInsetRect.minY + (currSnapPoint.y / currInsetSnapshot.image.size.height) * insetSize
                    )
                    
                    // Draw three segments
                    drawConnectorLineForImage(
                        context: context,
                        from: prevPoint,
                        to: prevOnMainMap,
                        color: userColor,
                        style: .fromInset,
                        clipRect: prevInsetRect
                    )
                    
                    drawConnectorLineForImage(
                        context: context,
                        from: prevOnMainMap,
                        to: currOnMainMap,
                        color: userColor,
                        clipRect: CGRect(x: 0, y: 0, width: mapSize, height: mapSize)
                    )
                    
                    drawConnectorLineForImage(
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

    private enum ConnectorStyleImage {
        case normal
        case toInset
        case fromInset
    }

    private func drawConnectorLineForImage(
        context: CGContext,
        from: CGPoint,
        to: CGPoint,
        color: UIColor,
        style: ConnectorStyleImage = .normal,
        clipRect: CGRect? = nil
    ) {
        context.saveGState()
        
        if let clipRect = clipRect {
            context.clip(to: clipRect)
        }
        
        switch style {
        case .normal:
            context.setStrokeColor(color.withAlphaComponent(0.8).cgColor)
            context.setLineWidth(2.5)
            context.setLineDash(phase: 0, lengths: [6, 3])
        case .toInset, .fromInset:
            context.setStrokeColor(color.withAlphaComponent(0.5).cgColor)
            context.setLineWidth(1.5)
            context.setLineDash(phase: 0, lengths: [3, 3])
        }
        
        context.setLineCap(.round)
        context.move(to: from)
        context.addLine(to: to)
        context.strokePath()
        
        if style == .normal {
            let circleRadius: CGFloat = 4
            context.setLineDash(phase: 0, lengths: [])
            context.setFillColor(color.cgColor)
            
            if clipRect == nil || clipRect!.contains(from) {
                context.fillEllipse(in: CGRect(x: from.x - circleRadius, y: from.y - circleRadius, width: circleRadius * 2, height: circleRadius * 2))
            }
            if clipRect == nil || clipRect!.contains(to) {
                context.fillEllipse(in: CGRect(x: to.x - circleRadius, y: to.y - circleRadius, width: circleRadius * 2, height: circleRadius * 2))
            }
        }
        
        context.restoreGState()
    }
    
    // MARK: - Helper: Generate SF Symbol Image
    
    private func systemIconImage(named: String, size: CGFloat) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: size, weight: .semibold)
        
        return UIImage(systemName: named, withConfiguration: config)?.withTintColor(.white, renderingMode: .alwaysOriginal)
    }
    
    // MARK: - Helper: Format Date Range Without Year in Image
    private func formatDateRangeWithoutYear(_ dateRangeString: String) -> String {
        // Input format: "Jan 1, 2025 - Nov 26, 2025"
        // Output format: "Jan 1 - Nov 26"
        
        let components = dateRangeString.components(separatedBy: " - ")
        guard components.count == 2 else { return dateRangeString }
        
        let start = components[0].replacingOccurrences(of: ", 2025", with: "")
                                 .replacingOccurrences(of: ", 2024", with: "")
        let end = components[1].replacingOccurrences(of: ", 2025", with: "")
                               .replacingOccurrences(of: ", 2024", with: "")
        
        return "\(start) - \(end)"
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
        
        func coordinateToPoint(_ coord: CLLocationCoordinate2D) -> CGPoint? {
            let snapshotPoint = snapshotObj.point(for: coord)
            
            // FIXED: More generous buffer
            let buffer: CGFloat = snapshotSize.width * 0.5
            if snapshotPoint.x < -buffer || snapshotPoint.x > snapshotSize.width + buffer ||
               snapshotPoint.y < -buffer || snapshotPoint.y > snapshotSize.height + buffer {
                return nil
            }
            
            let scaleX = mapRect.width / snapshotSize.width
            let scaleY = mapRect.height / snapshotSize.height
            
            return CGPoint(
                x: mapRect.minX + (snapshotPoint.x * scaleX),
                y: mapRect.minY + (snapshotPoint.y * scaleY)
            )
        }
        
        let friendUIColor = UIColor(hex: friend.color) ?? UIColor.systemRed
        
        // Draw friend path
        context.saveGState()
        context.setStrokeColor(friendUIColor.cgColor)
        context.setLineWidth(5)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        var currentPath = [CGPoint]()
        
        for location in locations {
            if let point = coordinateToPoint(location) {
                currentPath.append(point)
            } else {
                // Hit a point in different region - draw what we have and reset
                if currentPath.count >= 2 {
                    context.move(to: currentPath[0])
                    for i in 1..<currentPath.count {
                        context.addLine(to: currentPath[i])
                    }
                }
                currentPath.removeAll()
            }
        }
        
        // Draw any remaining path
        if currentPath.count >= 2 {
            context.move(to: currentPath[0])
            for i in 1..<currentPath.count {
                context.addLine(to: currentPath[i])
            }
        }
        
        context.strokePath()
        context.restoreGState()
        
        // Draw friend pins
        context.saveGState()
        let dotSize: CGFloat = ResponsiveLayout.exportImageSize.width * 0.0111
        let dotRadius = dotSize / 2
        
        for location in locations {
            if let point = coordinateToPoint(location) {
                context.setFillColor(friendUIColor.cgColor)
                context.fillEllipse(in: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotSize, height: dotSize))
                context.setStrokeColor(UIColor.white.cgColor)
                context.setLineWidth(2)
                context.strokeEllipse(in: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotSize, height: dotSize))
            }
        }
        context.restoreGState()
    }
    
    // MARK: - Region Detection

    private struct MapRegion {
        let locations: [CLLocationCoordinate2D]
        let name: String
        let center: CLLocationCoordinate2D
        let span: MKCoordinateSpan
    }

    private func detectRegions(from allLocations: [CLLocationCoordinate2D]) -> [MapRegion] {
        guard !allLocations.isEmpty else { return [] }
        
        // Simple clustering by continent/distance
        var clusters: [[CLLocationCoordinate2D]] = []
        
        for location in allLocations {
            var addedToCluster = false
            
            for i in 0..<clusters.count {
                // If location is within ~2000km of any location in cluster, add it
                if clusters[i].contains(where: { existingLoc in
                    let loc1 = CLLocation(latitude: location.latitude, longitude: location.longitude)
                    let loc2 = CLLocation(latitude: existingLoc.latitude, longitude: existingLoc.longitude)
                    let distance = loc1.distance(from: loc2)
                    return distance < 10_000_000 // 2000km threshold
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

    // MARK: - Map Snapshot for Image

    private func generateMapSnapshotForImage() -> (image: UIImage, snapshot: MKMapSnapshotter.Snapshot, selectedFriends: [FriendData])? {
        guard !photoLoader.locations.isEmpty else { return nil }
        
        var allLocations = photoLoader.locations
        let selectedFriends = photoLoader.friends.filter { selectedFriendIDs.contains($0.id) }
        for friend in selectedFriends {
            allLocations.append(contentsOf: friend.coordinates)
        }
        
        guard !allLocations.isEmpty else { return nil }
        
        let regions = detectRegions(from: allLocations)
        let exportSize = ResponsiveLayout.exportImageSize
        let snapshotSize = exportSize.width * 0.926
        
        if regions.count == 1 {
            // Single region - generate snapshot AND draw paths on it
            guard let snapshotResult = generateSingleRegionSnapshot(region: regions[0], size: snapshotSize) else {
                return nil
            }
            
            // Draw paths on the single region map
            let imageWithPaths = drawPathsOnSnapshot(
                snapshot: snapshotResult.snapshot,
                region: regions[0],
                size: snapshotSize,
                selectedFriends: selectedFriends
            )
            
            return (imageWithPaths, snapshotResult.snapshot, selectedFriends)
            
        } else {
            // Multiple regions - create composite map
            if let result = generateMultiRegionSnapshot(regions: regions, size: snapshotSize, selectedFriends: selectedFriends) {
                return (result.image, result.snapshot, selectedFriends)
            }
            return nil
        }
    }

    // NEW helper function
    private func drawPathsOnSnapshot(
        snapshot: MKMapSnapshotter.Snapshot,
        region: MapRegion,
        size: CGFloat,
        selectedFriends: [FriendData]
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 2.0
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        
        return renderer.image { context in
            let ctx = context.cgContext
            
            // Draw base map
            snapshot.image.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
            
            // Draw all paths
            drawPathsOnMainRegion(
                context: ctx,
                mainSnapshot: snapshot,
                mainRegion: region,
                size: size,
                selectedFriends: selectedFriends
            )
        }
    }
    private func generateSingleRegionSnapshot(region: MapRegion, size: CGFloat) -> (image: UIImage, snapshot: MKMapSnapshotter.Snapshot)? {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: region.center, span: region.span)
        options.size = CGSize(width: size, height: size)
        
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

    private func generateMultiRegionSnapshot(regions: [MapRegion], size: CGFloat, selectedFriends: [FriendData]) -> (image: UIImage, snapshot: MKMapSnapshotter.Snapshot)? {
        guard !regions.isEmpty else { return nil }
        
        let mainRegion = regions[0]
        let insetRegions = Array(regions.dropFirst())
        
        let mainMapSize = size
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: mainRegion.center, span: mainRegion.span)
        options.size = CGSize(width: mainMapSize, height: mainMapSize)
        
        let snapshotter = MKMapSnapshotter(options: options)
        let semaphore = DispatchSemaphore(value: 0)
        var mainSnapshot: MKMapSnapshotter.Snapshot?
        
        snapshotter.start { snapshot, error in
            defer { semaphore.signal() }
            mainSnapshot = snapshot
        }
        semaphore.wait()
        
        guard let mainSnap = mainSnapshot else { return nil }
        
        var insetSnapshots: [(region: MapRegion, snapshot: MKMapSnapshotter.Snapshot)] = []
        
        for insetRegion in insetRegions {
            let insetOptions = MKMapSnapshotter.Options()
            insetOptions.region = MKCoordinateRegion(center: insetRegion.center, span: insetRegion.span)
            
            let insetSize = size * 0.25
            insetOptions.size = CGSize(width: insetSize, height: insetSize)
            
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
        
        let compositeImage = createCompositeMapImage(
            mainSnapshot: mainSnap,
            mainRegion: mainRegion,
            insetSnapshots: insetSnapshots,
            size: size,
            selectedFriends: selectedFriends  // PASS IT THROUGH
        )
        
        return (compositeImage, mainSnap)
    }


// MARK: - Even more helper functions !
    // NEW FUNCTION 0: boundds calculation
    private func isCoordinate(_ coord: CLLocationCoordinate2D, inRegion region: MapRegion) -> Bool {
        // Calculate region bounds
        let minLat = region.locations.map(\.latitude).min() ?? 0
        let maxLat = region.locations.map(\.latitude).max() ?? 0
        let minLon = region.locations.map(\.longitude).min() ?? 0
        let maxLon = region.locations.map(\.longitude).max() ?? 0
        
        // Add small buffer (5% of span)
        let latBuffer = (maxLat - minLat) * 0.05
        let lonBuffer = (maxLon - minLon) * 0.05
        
        return coord.latitude >= (minLat - latBuffer) &&
               coord.latitude <= (maxLat + latBuffer) &&
               coord.longitude >= (minLon - lonBuffer) &&
               coord.longitude <= (maxLon + lonBuffer)
    }
    
    // NEW FUNCTION 1: Smart positioning
    private func findBestInsetPositions(
        mainRegion: MapRegion,
        insetCount: Int,
        mainSnapshot: MKMapSnapshotter.Snapshot,
        size: CGFloat,
        insetSize: CGFloat,
        padding: CGFloat
    ) -> [(x: CGFloat, y: CGFloat)] {
        
        // Define all possible corner positions
        let allPositions: [(x: CGFloat, y: CGFloat, corner: String)] = [
            (padding, padding, "top-left"),
            (size - insetSize - padding, padding, "top-right"),
            (padding, size - insetSize - padding, "bottom-left"),
            (size - insetSize - padding, size - insetSize - padding, "bottom-right")
        ]
        
        // Score each position based on how many main region points are nearby
        var scoredPositions: [(position: (x: CGFloat, y: CGFloat), score: Int)] = []
        
        for position in allPositions {
            let cornerRect = CGRect(
                x: position.x,
                y: position.y,
                width: insetSize,
                height: insetSize
            )
            
            // Count how many points from main region fall in this area
            var pointsInArea = 0
            for location in mainRegion.locations {
                let point = mainSnapshot.point(for: location)
                let scaledPoint = CGPoint(
                    x: point.x * (size / mainSnapshot.image.size.width),
                    y: point.y * (size / mainSnapshot.image.size.height)
                )
                
                if cornerRect.contains(scaledPoint) {
                    pointsInArea += 1
                }
            }
            
            // Lower score is better (fewer points = less coverage)
            scoredPositions.append((position: (position.x, position.y), score: pointsInArea))
        }
        
        // Sort by score (lowest first)
        scoredPositions.sort { $0.score < $1.score }
        
        // Return best positions
        return scoredPositions.prefix(insetCount).map { $0.position }
    }

    // NEW FUNCTION 2: Draw paths inside insets
    private func drawPathsInInset(
        context: CGContext,
        insetRect: CGRect,
        insetRegion: MapRegion,
        insetSnapshot: MKMapSnapshotter.Snapshot,
        selectedFriends: [FriendData]  // NEW PARAMETER
    ) {
        let snapshotSize = insetSnapshot.image.size
        
        // Get user's locations that are in this region using bounds check
        let userLocationsInRegion = photoLoader.locations.filter { location in
            isCoordinate(location, inRegion: insetRegion)
        }
        
        let userUIColor = UIColor(hex: userColor) ?? UIColor.systemBlue
        
        // Draw user's path in this inset
        if !userLocationsInRegion.isEmpty {
            context.saveGState()
            context.setStrokeColor(userUIColor.cgColor)
            context.setLineWidth(3)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            var firstPoint = true
            for location in userLocationsInRegion {
                let snapshotPoint = insetSnapshot.point(for: location)
                let scaleX = insetRect.width / snapshotSize.width
                let scaleY = insetRect.height / snapshotSize.height
                
                let point = CGPoint(
                    x: insetRect.minX + (snapshotPoint.x * scaleX),
                    y: insetRect.minY + (snapshotPoint.y * scaleY)
                )
                
                if firstPoint {
                    context.move(to: point)
                    firstPoint = false
                } else {
                    context.addLine(to: point)
                }
            }
            
            context.strokePath()
            context.restoreGState()
            
            // Draw dots in this inset
            context.saveGState()
            let dotSize: CGFloat = 8
            let dotRadius = dotSize / 2
            
            for location in userLocationsInRegion {
                let snapshotPoint = insetSnapshot.point(for: location)
                let scaleX = insetRect.width / snapshotSize.width
                let scaleY = insetRect.height / snapshotSize.height
                
                let point = CGPoint(
                    x: insetRect.minX + (snapshotPoint.x * scaleX),
                    y: insetRect.minY + (snapshotPoint.y * scaleY)
                )
                
                context.setFillColor(userUIColor.cgColor)
                context.fillEllipse(in: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotSize, height: dotSize))
                context.setStrokeColor(UIColor.white.cgColor)
                context.setLineWidth(1.5)
                context.strokeEllipse(in: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotSize, height: dotSize))
            }
            context.restoreGState()
        }
        
        // Draw friend paths in this inset
        for friend in selectedFriends {
            let friendLocationsInRegion = friend.coordinates.filter { location in
                isCoordinate(location, inRegion: insetRegion)
            }
            
            guard !friendLocationsInRegion.isEmpty else { continue }
            
            let friendUIColor = UIColor(hex: friend.color) ?? UIColor.systemRed
            
            context.saveGState()
            context.setStrokeColor(friendUIColor.cgColor)
            context.setLineWidth(3)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            var firstPoint = true
            for location in friendLocationsInRegion {
                let snapshotPoint = insetSnapshot.point(for: location)
                let scaleX = insetRect.width / snapshotSize.width
                let scaleY = insetRect.height / snapshotSize.height
                
                let point = CGPoint(
                    x: insetRect.minX + (snapshotPoint.x * scaleX),
                    y: insetRect.minY + (snapshotPoint.y * scaleY)
                )
                
                if firstPoint {
                    context.move(to: point)
                    firstPoint = false
                } else {
                    context.addLine(to: point)
                }
            }
            
            context.strokePath()
            context.restoreGState()
            
            // Draw friend dots
            context.saveGState()
            let dotSize: CGFloat = 8
            let dotRadius = dotSize / 2
            
            for location in friendLocationsInRegion {
                let snapshotPoint = insetSnapshot.point(for: location)
                let scaleX = insetRect.width / snapshotSize.width
                let scaleY = insetRect.height / snapshotSize.height
                
                let point = CGPoint(
                    x: insetRect.minX + (snapshotPoint.x * scaleX),
                    y: insetRect.minY + (snapshotPoint.y * scaleY)
                )
                
                context.setFillColor(friendUIColor.cgColor)
                context.fillEllipse(in: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotSize, height: dotSize))
                context.setStrokeColor(UIColor.white.cgColor)
                context.setLineWidth(1.5)
                context.strokeEllipse(in: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotSize, height: dotSize))
            }
            context.restoreGState()
        }
    }

    
    // NEW FUNCTION 3: Exit indicators
    private func drawExitIndicators(
        context: CGContext,
        mapRect: CGRect,
        mapData: (image: UIImage, snapshot: MKMapSnapshotter.Snapshot),
        regions: [MapRegion]
    ) {
        guard regions.count > 1 else { return }
        
        let mainRegion = regions[0]
        let snapshotObj = mapData.snapshot
        let snapshotSize = mapData.image.size
        
        // Helper to convert coordinate to screen point
        func coordinateToPoint(_ coord: CLLocationCoordinate2D) -> CGPoint? {
            let snapshotPoint = snapshotObj.point(for: coord)
            
            let buffer: CGFloat = snapshotSize.width * 0.5
            if snapshotPoint.x < -buffer || snapshotPoint.x > snapshotSize.width + buffer ||
               snapshotPoint.y < -buffer || snapshotPoint.y > snapshotSize.height + buffer {
                return nil
            }
            
            let scaleX = mapRect.width / snapshotSize.width
            let scaleY = mapRect.height / snapshotSize.height
            
            return CGPoint(
                x: mapRect.minX + (snapshotPoint.x * scaleX),
                y: mapRect.minY + (snapshotPoint.y * scaleY)
            )
        }
        
        let userUIColor = UIColor(hex: userColor) ?? UIColor.systemBlue
        
        // Track state as we go through locations
        var lastWasInMain = false
        var lastPoint: CGPoint?
        
        for (index, location) in photoLoader.locations.enumerated() {
            let isInMain = isCoordinate(location, inRegion: mainRegion)
            let point = coordinateToPoint(location)
            
            // Detect transition from main region to other region
            if lastWasInMain && !isInMain, let exitPoint = lastPoint {
                // Draw exit indicator at the last point before leaving
                drawRegionJumpIndicator(
                    context: context,
                    at: exitPoint,
                    color: userUIColor,
                    outgoing: true
                )
                print("🚪 Exit indicator at location \(index-1)")
            }
            
            // Detect transition from other region back to main region
            if !lastWasInMain && isInMain, let entryPoint = point {
                // Draw entry indicator at the first point after returning
                drawRegionJumpIndicator(
                    context: context,
                    at: entryPoint,
                    color: userUIColor,
                    outgoing: false
                )
                print("🚪 Entry indicator at location \(index)")
            }
            
            lastWasInMain = isInMain
            if let pt = point {
                lastPoint = pt
            }
        }
        
        // Also draw indicators for friends
        let selectedFriends = photoLoader.friends.filter { selectedFriendIDs.contains($0.id) }
        for friend in selectedFriends {
            let friendUIColor = UIColor(hex: friend.color) ?? UIColor.systemRed
            
            var friendLastWasInMain = false
            var friendLastPoint: CGPoint?
            
            for (index, location) in friend.coordinates.enumerated() {
                let isInMain = isCoordinate(location, inRegion: mainRegion)
                let point = coordinateToPoint(location)
                
                if friendLastWasInMain && !isInMain, let exitPoint = friendLastPoint {
                    drawRegionJumpIndicator(
                        context: context,
                        at: exitPoint,
                        color: friendUIColor,
                        outgoing: true
                    )
                    print("🚪 Friend '\(friend.name)' exit at \(index-1)")
                }
                
                if !friendLastWasInMain && isInMain, let entryPoint = point {
                    drawRegionJumpIndicator(
                        context: context,
                        at: entryPoint,
                        color: friendUIColor,
                        outgoing: false
                    )
                    print("🚪 Friend '\(friend.name)' entry at \(index)")
                }
                
                friendLastWasInMain = isInMain
                if let pt = point {
                    friendLastPoint = pt
                }
            }
        }
    }

    // MARK: - Updated createCompositeMapImage with smart positioning

    private func createCompositeMapImage(
        mainSnapshot: MKMapSnapshotter.Snapshot,
        mainRegion: MapRegion,
        insetSnapshots: [(region: MapRegion, snapshot: MKMapSnapshotter.Snapshot)],
        size: CGFloat,
        selectedFriends: [FriendData]  // NEW PARAMETER
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 2.0
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        
        return renderer.image { context in
            let ctx = context.cgContext
            
            // 1. Draw main map
            mainSnapshot.image.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
            
            // 2. Draw paths on main map FIRST (before insets)
            drawPathsOnMainRegion(
                context: ctx,
                mainSnapshot: mainSnapshot,
                mainRegion: mainRegion,
                size: size,
                selectedFriends: selectedFriends  // PASS IT THROUGH
            )
            
            // 3. NOW draw inset boxes on top
            let insetSize = size * 0.25
            let padding: CGFloat = 15
            
            let bestPositions = findBestInsetPositions(
                mainRegion: mainRegion,
                insetCount: insetSnapshots.count,
                mainSnapshot: mainSnapshot,
                size: size,
                insetSize: insetSize,
                padding: padding
            )
            
            for (index, inset) in insetSnapshots.enumerated() {
                let position = bestPositions[index]
                let xPos = position.x
                let yPos = position.y
                
                let insetRect = CGRect(x: xPos, y: yPos, width: insetSize, height: insetSize)
                
                // Draw shadow
                ctx.setShadow(offset: CGSize(width: 0, height: 2), blur: 5, color: UIColor.black.withAlphaComponent(0.3).cgColor)
                ctx.setFillColor(UIColor.white.cgColor)
                ctx.fill(insetRect)
                ctx.setShadow(offset: .zero, blur: 0, color: nil)
                
                // Draw inset map
                inset.snapshot.image.draw(in: insetRect)
                
                // Draw paths INSIDE inset
                drawPathsInInset(
                    context: ctx,
                    insetRect: insetRect,
                    insetRegion: inset.region,
                    insetSnapshot: inset.snapshot,
                    selectedFriends: selectedFriends  // PASS IT THROUGH
                )
                
                self.drawPathsInInset(
                    context: ctx,
                    insetRect: insetRect,
                    insetRegion: inset.region,
                    insetSnapshot: inset.snapshot,
                    selectedFriends: selectedFriends
                )

                // ADD THIS SECTION - Draw connector lines
                let userUIColor = UIColor(hex: self.userColor) ?? UIColor.systemBlue
                self.drawRegionConnectorsForImage(
                    context: ctx,
                    locations: self.photoLoader.locations,
                    mainRegion: mainRegion,
                    insetSnapshots: insetSnapshots,
                    insetPositions: bestPositions,
                    mainSnapshot: mainSnapshot,
                    mapSize: size,
                    insetSize: insetSize,
                    userColor: userUIColor
                )

                
                // Draw border
                ctx.setStrokeColor(UIColor.white.cgColor)
                ctx.setLineWidth(3)
                ctx.stroke(insetRect)
                
                // Draw label
                let labelAttrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                    .foregroundColor: UIColor.white,
                    .backgroundColor: UIColor.black.withAlphaComponent(0.7)
                ]
                let labelText = " \(inset.region.name) " as NSString
                let labelSize = labelText.size(withAttributes: labelAttrs)
                let labelRect = CGRect(
                    x: xPos + 5,
                    y: yPos + 5,
                    width: labelSize.width,
                    height: labelSize.height
                )
                labelText.draw(in: labelRect, withAttributes: labelAttrs)
            }
        }
    }

    
    private func drawPathsOnMainRegion(
        context: CGContext,
        mainSnapshot: MKMapSnapshotter.Snapshot,
        mainRegion: MapRegion,
        size: CGFloat,
        selectedFriends: [FriendData]  // NEW PARAMETER
    ) {
        let snapshotSize = mainSnapshot.image.size
        
        func coordinateToPoint(_ coord: CLLocationCoordinate2D) -> CGPoint? {
            guard isCoordinate(coord, inRegion: mainRegion) else { return nil }
            
            let snapshotPoint = mainSnapshot.point(for: coord)
            let buffer: CGFloat = snapshotSize.width * 0.5
            
            if snapshotPoint.x < -buffer || snapshotPoint.x > snapshotSize.width + buffer ||
               snapshotPoint.y < -buffer || snapshotPoint.y > snapshotSize.height + buffer {
                return nil
            }
            
            let scaleX = size / snapshotSize.width
            let scaleY = size / snapshotSize.height
            
            return CGPoint(
                x: snapshotPoint.x * scaleX,
                y: snapshotPoint.y * scaleY
            )
        }
        
        // Draw friend paths first (underneath user path)
        for friend in selectedFriends {
            let friendUIColor = UIColor(hex: friend.color) ?? UIColor.systemRed
            
            context.saveGState()
            context.setStrokeColor(friendUIColor.cgColor)
            context.setLineWidth(5)
            context.setLineCap(.round)
            context.setLineJoin(.round)
            
            var currentPath = [CGPoint]()
            for location in friend.coordinates {
                if let point = coordinateToPoint(location) {
                    currentPath.append(point)
                } else {
                    if currentPath.count >= 2 {
                        context.move(to: currentPath[0])
                        for i in 1..<currentPath.count {
                            context.addLine(to: currentPath[i])
                        }
                    }
                    currentPath.removeAll()
                }
            }
            
            if currentPath.count >= 2 {
                context.move(to: currentPath[0])
                for i in 1..<currentPath.count {
                    context.addLine(to: currentPath[i])
                }
            }
            
            context.strokePath()
            context.restoreGState()
            
            // Draw friend dots
            context.saveGState()
            let dotSize: CGFloat = 12.0
            let dotRadius = dotSize / 2
            
            for location in friend.coordinates {
                if let point = coordinateToPoint(location) {
                    context.setFillColor(friendUIColor.cgColor)
                    context.fillEllipse(in: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotSize, height: dotSize))
                    context.setStrokeColor(UIColor.white.cgColor)
                    context.setLineWidth(2)
                    context.strokeEllipse(in: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotSize, height: dotSize))
                }
            }
            context.restoreGState()
        }
        
        // Draw user path on top
        let userUIColor = UIColor(hex: userColor) ?? UIColor.systemBlue
        
        context.saveGState()
        context.setStrokeColor(userUIColor.cgColor)
        context.setLineWidth(5)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        var currentPath = [CGPoint]()
        for location in photoLoader.locations {
            if let point = coordinateToPoint(location) {
                currentPath.append(point)
            } else {
                if currentPath.count >= 2 {
                    context.move(to: currentPath[0])
                    for i in 1..<currentPath.count {
                        context.addLine(to: currentPath[i])
                    }
                }
                currentPath.removeAll()
            }
        }
        
        if currentPath.count >= 2 {
            context.move(to: currentPath[0])
            for i in 1..<currentPath.count {
                context.addLine(to: currentPath[i])
            }
        }
        
        context.strokePath()
        context.restoreGState()
        
        // Draw user dots
        context.saveGState()
        let dotSize: CGFloat = 12.0
        let dotRadius = dotSize / 2
        
        for location in photoLoader.locations {
            if let point = coordinateToPoint(location) {
                context.setFillColor(userUIColor.cgColor)
                context.fillEllipse(in: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotSize, height: dotSize))
                context.setStrokeColor(UIColor.white.cgColor)
                context.setLineWidth(2)
                context.strokeEllipse(in: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotSize, height: dotSize))
            }
        }
        context.restoreGState()
    }

    
    private func drawConnectionIndicator(
        context: CGContext,
        from coordinate: CLLocationCoordinate2D,
        to insetCenter: CGPoint,
        mainSnapshot: MKMapSnapshotter.Snapshot,
        mapSize: CGFloat,
        insetRect: CGRect
    ) {
        // Get point on main map for this coordinate
        let mainMapPoint = mainSnapshot.point(for: coordinate)
        
        // Check if point is visible on main map
        guard mainMapPoint.x >= 0 && mainMapPoint.x <= mainSnapshot.image.size.width &&
              mainMapPoint.y >= 0 && mainMapPoint.y <= mainSnapshot.image.size.height else {
            return
        }
        
        // Scale point to composite image coordinates
        let scaleX = mapSize / mainSnapshot.image.size.width
        let scaleY = mapSize / mainSnapshot.image.size.height
        let startPoint = CGPoint(
            x: mainMapPoint.x * scaleX,
            y: mainMapPoint.y * scaleY
        )
        
        // Draw dotted line
        context.saveGState()
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(2)
        context.setLineDash(phase: 0, lengths: [6, 4])
        
        context.move(to: startPoint)
        context.addLine(to: insetCenter)
        context.strokePath()
        
        // Draw arrow at inset end
        let arrowSize: CGFloat = 8
        let angle = atan2(insetCenter.y - startPoint.y, insetCenter.x - startPoint.x)
        
        let arrowPoint1 = CGPoint(
            x: insetCenter.x - arrowSize * cos(angle - .pi / 6),
            y: insetCenter.y - arrowSize * sin(angle - .pi / 6)
        )
        let arrowPoint2 = CGPoint(
            x: insetCenter.x - arrowSize * cos(angle + .pi / 6),
            y: insetCenter.y - arrowSize * sin(angle + .pi / 6)
        )
        
        context.setLineDash(phase: 0, lengths: [])
        context.move(to: arrowPoint1)
        context.addLine(to: insetCenter)
        context.addLine(to: arrowPoint2)
        context.strokePath()
        
        context.restoreGState()
    }
    
    // MARK: - Draw Path on Image (UPDATED with jump indicators)

    // MARK: - Draw Path on Image (FIXED - simpler visibility check)

    private func drawPathOnImage(
        context: CGContext,
        mapRect: CGRect,
        mapData: (image: UIImage, snapshot: MKMapSnapshotter.Snapshot)
    ) {
        guard !photoLoader.locations.isEmpty else { return }
        
        let snapshotObj = mapData.snapshot
        let snapshotSize = mapData.image.size
        
        func coordinateToPoint(_ coord: CLLocationCoordinate2D) -> CGPoint? {
            let snapshotPoint = snapshotObj.point(for: coord)
            
            // FIXED: More generous buffer - only exclude if REALLY far outside
            let buffer: CGFloat = snapshotSize.width * 0.5  // 50% of map size as buffer
            if snapshotPoint.x < -buffer || snapshotPoint.x > snapshotSize.width + buffer ||
               snapshotPoint.y < -buffer || snapshotPoint.y > snapshotSize.height + buffer {
                return nil // Point is definitely in a different region
            }
            
            let scaleX = mapRect.width / snapshotSize.width
            let scaleY = mapRect.height / snapshotSize.height
            
            return CGPoint(
                x: mapRect.minX + (snapshotPoint.x * scaleX),
                y: mapRect.minY + (snapshotPoint.y * scaleY)
            )
        }
        
        // Get user color
        let userUIColor = UIColor(hex: userColor) ?? UIColor.systemBlue
        
        // Draw path segments
        context.saveGState()
        context.setStrokeColor(userUIColor.cgColor)
        context.setLineWidth(5)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        var currentPath = [CGPoint]()
        
        for location in photoLoader.locations {
            if let point = coordinateToPoint(location) {
                currentPath.append(point)
            } else {
                // Hit a point in different region - draw what we have and reset
                if currentPath.count >= 2 {
                    context.move(to: currentPath[0])
                    for i in 1..<currentPath.count {
                        context.addLine(to: currentPath[i])
                    }
                }
                currentPath.removeAll()
            }
        }
        
        // Draw any remaining path
        if currentPath.count >= 2 {
            context.move(to: currentPath[0])
            for i in 1..<currentPath.count {
                context.addLine(to: currentPath[i])
            }
        }
        
        context.strokePath()
        context.restoreGState()
        
        // Draw pins
        context.saveGState()
        let dotSize: CGFloat = ResponsiveLayout.exportImageSize.width * 0.0111
        let dotRadius = dotSize / 2
        
        for location in photoLoader.locations {
            if let point = coordinateToPoint(location) {
                context.setFillColor(userUIColor.cgColor)
                context.fillEllipse(in: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotSize, height: dotSize))
                context.setStrokeColor(UIColor.white.cgColor)
                context.setLineWidth(2)
                context.strokeEllipse(in: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotSize, height: dotSize))
            }
        }
        context.restoreGState()
    }

    // NEW: Draw indicator for region jumps
    private func drawRegionJumpIndicator(
        context: CGContext,
        at point: CGPoint,
        color: UIColor,
        outgoing: Bool
    ) {
        context.saveGState()
        
        // Draw a small circle with dashed border to indicate "continues elsewhere"
        let indicatorSize: CGFloat = 16
        let indicatorRect = CGRect(
            x: point.x - indicatorSize / 2,
            y: point.y - indicatorSize / 2,
            width: indicatorSize,
            height: indicatorSize
        )
        
        // Fill
        context.setFillColor(color.withAlphaComponent(0.3).cgColor)
        context.fillEllipse(in: indicatorRect)
        
        // Dashed border
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(2)
        context.setLineDash(phase: 0, lengths: [3, 2])
        context.strokeEllipse(in: indicatorRect)
        
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
