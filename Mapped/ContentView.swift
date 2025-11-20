import SwiftUI
import MapKit
import CoreLocation

struct ContentView: View {
    @StateObject private var photoLoader = PhotoLoader()
    @State private var isHomeMenu: Bool = true
    @State private var selectedFeature: String?
    @StateObject private var exportManager = VideoExportManager.shared
    
    @State private var bannerPosition: CGPoint?
    @State private var isCollapsed = false
    @GestureState private var dragOffset: CGSize = .zero
    @State private var showVideoCompleteNotification = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var previousExportProgress: Double = 0.0
    
    @State private var sharedConstellationScale: CGFloat = 1.0
    @State private var sharedConstellationRotation: Angle = .zero
    @State private var sharedConstellationBackgroundStars: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = []
    @State private var sharedConstellationStars: [ConstellationStar] = []
    @State private var sharedConstellationConnections: [ConstellationConnection] = []
    
    var body: some View {
        if !hasCompletedOnboarding {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        } else {

            ZStack {
                if isHomeMenu {
                    HomeMenu(selectedFeature: $selectedFeature, isHomeMenu: $isHomeMenu)
                        .onChange(of: selectedFeature) { newFeature in
                            if newFeature != nil {
                                isHomeMenu = false
                            }
                        }
                } else {
                    VStack(spacing: 0) {
                        if let feature = selectedFeature {
                            featureView(for: feature)
                        }
                        
                        //ONLY show back button if NOT viewing Your Story
                        if selectedFeature != "YourStory" {
                            Spacer(minLength: 0)
                            Button(action: {
                                if selectedFeature == "Map" {
                                    resetMapState()
                                }
                                selectedFeature = nil
                                isHomeMenu = true
                            }) {
                                HStack {
                                    Image(systemName: "chevron.left")
                                    Text("Back to Home")
                                }
                                .foregroundColor(.white)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                            }
                            .edgesIgnoringSafeArea(.bottom)
                        }
                    }
                }
                
                if photoLoader.isLoading {
                    LoadingOverlay(progress: photoLoader.loadingProgress)
                }
                
                if let error = photoLoader.errorMessage {
                    VStack {
                        Spacer()
                        Text(error)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red.opacity(0.9))
                            .cornerRadius(10)
                            .padding()
                    }
                }
            }
            .overlay(
                // Export progress banner
                Group {
                    if exportManager.isExporting {
                        GeometryReader { geometry in
                            ZStack {
                                if isCollapsed {
                                    DraggableCollapsedBanner(
                                        progress: exportManager.exportProgress,
                                        position: $bannerPosition,
                                        screenSize: geometry.size,
                                        onExpand: {
                                            withAnimation(.spring()) {
                                                isCollapsed = false
                                            }
                                        }
                                    )
                                } else {
                                    DraggableExpandedBanner(
                                        progress: exportManager.exportProgress,
                                        position: $bannerPosition,
                                        screenSize: geometry.size,
                                        onCollapse: {
                                            withAnimation(.spring()) {
                                                isCollapsed = true
                                            }
                                        },
                                        onCancel: {
                                            withAnimation {
                                                exportManager.cancelExport()
                                            }
                                        }
                                    )
                                }
                            }
                        }
                    }
                }
            )
            .overlay(
                VStack {
                    if showVideoCompleteNotification {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Video Ready! 🎉")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Your 2025 Mapped video is ready to share")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                withAnimation {
                                    showVideoCompleteNotification = false
                                }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: Color.green.opacity(0.5), radius: 10, x: 0, y: 5)
                        .padding(.horizontal)
                        .padding(.top, 50)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    Spacer()
                }
            )
            .onAppear {
                photoLoader.checkPhotoLibraryPermission()
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("ImportFriend"))) { notification in
                guard let userInfo = notification.userInfo,
                      let name = userInfo["name"] as? String,
                      let data = userInfo["data"] as? Data else {
                    print("❌ Failed to extract friend data from notification")
                    return
                }
                
                print("📥 Processing friend import: \(name)")
                photoLoader.importFriend(from: data, name: name)
                print("✅ Friend import complete")
            }
            .onChange(of: exportManager.isExporting) { isExporting in
                if !isExporting {
                    withAnimation {
                        isCollapsed = false
                        bannerPosition = nil
                    }
                }
            }
            .onChange(of: exportManager.exportProgress) { newProgress in
                if previousExportProgress < 0.99 && newProgress >= 0.99 && !showVideoCompleteNotification {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showVideoCompleteNotification = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
                        withAnimation {
                            showVideoCompleteNotification = false
                        }
                    }
                }
                previousExportProgress = newProgress
            }
        }
    }
    
    // MARK: - Feature Views
    
    @ViewBuilder
    private func featureView(for feature: String) -> some View {
        switch feature {
        case "YourStory":
            YearStoryCarousel(
                photoLoader: photoLoader,
                hasCompletedOnboarding: $hasCompletedOnboarding,
                selectedFeature: $selectedFeature,
                isHomeMenu: $isHomeMenu,
                constellationScale: $sharedConstellationScale,
                constellationRotation: $sharedConstellationRotation,
                constellationBackgroundStars: $sharedConstellationBackgroundStars,
                constellationStars: $sharedConstellationStars,
                constellationConnections: $sharedConstellationConnections
            )
            .id(photoLoader.locations.count)
            .onAppear {
                buildConstellationIfNeeded()
            }
        case "Map":
            MapSection(photoLoader: photoLoader)
                .id(photoLoader.locations.count)
        case "Constellation":
            ConstellationFullView(
                photoLoader: photoLoader,
                scale: $sharedConstellationScale,
                rotation: $sharedConstellationRotation,
                backgroundStars: $sharedConstellationBackgroundStars,
                stars: $sharedConstellationStars,
                connections: $sharedConstellationConnections
            )
            .id(photoLoader.locations.count)
            .onAppear {
                buildConstellationIfNeeded()
            }
        case "Statistics":
            StatisticsSection(statistics: getStatistics(), photoLoader: photoLoader)
                .id(photoLoader.locations.count)
        case "Friends":
            FriendsManagerView(photoLoader: photoLoader)
        case "Share":
            ShareSection(photoLoader: photoLoader, statistics: getStatistics())
                .id(photoLoader.locations.count)
        case "Settings":
            SettingsView(photoLoader: photoLoader)
        default:
            Text("Feature not implemented yet")
        }
    }
    
    private func resetMapState() {
        // Reset all friend animation indices
        photoLoader.resetAllFriendAnimations()
        
        // Turn off friend overlay
        photoLoader.showFriendOverlay = false
        
        // Reset location markers to default
        photoLoader.showLocationMarkers = true
    }
    
    // MARK: - Statistics Calculation
    
    private func getStatistics() -> [String: String] {
        var stats = [String: String]()
        
        let locations = photoLoader.locations
        let allTimestamps = photoLoader.allPhotoTimestamps
        
        // Total photos
        stats["Photos with Location"] = "\(photoLoader.totalPhotosWithLocation)"
        
        // Places Visited
        stats["Places Visited"] = "\(locations.count)"
        
        // Date range
        if let first = allTimestamps.first, let last = allTimestamps.last {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            stats["Date Range"] = "\(formatter.string(from: first)) - \(formatter.string(from: last))"
        } else {
            stats["Date Range"] = "N/A"
        }
        
        // Total distance WITH EQUATOR COMPARISON (in miles)
        let distanceMiles = photoLoader.totalActualDistance / 1609.34 // Convert meters to miles
        let equatorMiles = 24901.0 // Earth's equator in miles
        let tripsAroundEquator = distanceMiles / equatorMiles
        if tripsAroundEquator >= 0.01 {
            stats["Total Distance"] = String(format: "%.1f mi\n%.2f× around equator", distanceMiles, tripsAroundEquator)
        } else {
            let percentOfEquator = (distanceMiles / equatorMiles) * 100
            stats["Total Distance"] = String(format: "%.1f mi\n%.1f%% of equator", distanceMiles, percentOfEquator)
        }
        
        // FARTHEST FROM HOME (in miles)
        if let home = findHomeBase(locations: locations), !locations.isEmpty {
            var maxDistance: CLLocationDistance = 0
            let homeLocation = CLLocation(latitude: home.latitude, longitude: home.longitude)
            
            for location in locations {
                let loc = CLLocation(latitude: location.latitude, longitude: location.longitude)
                let distance = homeLocation.distance(from: loc)
                maxDistance = max(maxDistance, distance)
            }
            
            stats["Farthest From Home"] = String(format: "%.0f mi", maxDistance / 1609.34)
        }
        
        // NIGHT OWL VS EARLY BIRD
        if !allTimestamps.isEmpty {
            var dayPhotos = 0
            var nightPhotos = 0
            
            let calendar = Calendar.current
            for timestamp in allTimestamps {
                let hour = calendar.component(.hour, from: timestamp)
                if hour >= 6 && hour < 18 {
                    dayPhotos += 1
                } else {
                    nightPhotos += 1
                }
            }
            
            let total = dayPhotos + nightPhotos
            if dayPhotos > nightPhotos {
                let percent = Double(dayPhotos) / Double(total) * 100
                stats["Photo Style"] = String(format: "Early Bird\n%.0f%% daytime", percent)
            } else {
                let percent = Double(nightPhotos) / Double(total) * 100
                stats["Photo Style"] = String(format: "Night Owl\n%.0f%% nighttime", percent)
            }
        }
        
        // Average photos per day
        if let first = allTimestamps.first, let last = allTimestamps.last {
            let days = Calendar.current.dateComponents([.day], from: first, to: last).day ?? 1
            let avgPerDay = Double(photoLoader.totalPhotosWithLocation) / Double(max(days, 1))
            stats["Avg Photos/Day"] = String(format: "%.1f", avgPerDay)
        }
        
        // Most active month
        if !allTimestamps.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            var monthCounts: [String: Int] = [:]
            
            for timestamp in allTimestamps {
                let month = formatter.string(from: timestamp)
                monthCounts[month, default: 0] += 1
            }
            
            if let mostActive = monthCounts.max(by: { $0.value < $1.value }) {
                stats["Most Active Month"] = "\(mostActive.key)\n(\(mostActive.value) photos)"
            }
        }
        
        // Longest gap
        if allTimestamps.count > 1 {
            var longestGap: TimeInterval = 0
            for i in 1..<allTimestamps.count {
                let gap = allTimestamps[i].timeIntervalSince(allTimestamps[i-1])
                longestGap = max(longestGap, gap)
            }
            let days = Int(longestGap / 86400)
            stats["Longest Gap Between Traveling"] = "\(days) days"
        }
        
        return stats
    }

    // Helper function after getStatistics()
    private func findHomeBase(locations: [CLLocationCoordinate2D]) -> CLLocationCoordinate2D? {
        guard !locations.isEmpty else { return nil }
        
        let clusters = clusterLocations(locations, radius: 5000)
        
        guard let largestCluster = clusters.max(by: { $0.count < $1.count }),
              !largestCluster.isEmpty else {
            return locations.first
        }
        
        let avgLat = largestCluster.map({ $0.latitude }).reduce(0, +) / Double(largestCluster.count)
        let avgLon = largestCluster.map({ $0.longitude }).reduce(0, +) / Double(largestCluster.count)
        
        return CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
    }
    
    // Helper to cluster nearby locations
    private func clusterLocations(_ locations: [CLLocationCoordinate2D], radius: Double) -> [[CLLocationCoordinate2D]] {
        var clusters: [[CLLocationCoordinate2D]] = []
        var remaining = locations
        
        while !remaining.isEmpty {
            let center = remaining.removeFirst()
            var cluster = [center]
            
            remaining = remaining.filter { location in
                let loc1 = CLLocation(latitude: center.latitude, longitude: center.longitude)
                let loc2 = CLLocation(latitude: location.latitude, longitude: location.longitude)
                
                if loc1.distance(from: loc2) < radius {
                    cluster.append(location)
                    return false
                }
                return true
            }
            
            clusters.append(cluster)
        }
        
        return clusters
    }
    // MARK: - Constellation Builder Helper
        
    private func buildConstellationIfNeeded() {
        guard sharedConstellationStars.isEmpty && !photoLoader.locations.isEmpty else { return }
        
        print("🌟 Building constellation for the first time")
        
        // Build with a normalized square size - we'll scale to fit in each view
        let buildSize = CGSize(width: 600, height: 600)
        
        let constellation = ConstellationBuilder.buildConstellation(
            locations: photoLoader.locations,
            viewSize: buildSize
        )
        
        sharedConstellationStars = constellation.stars
        sharedConstellationConnections = constellation.connections
        
        print("✅ Built \(constellation.stars.count) stars, \(constellation.connections.count) connections")
    }
}

// MARK: - Loading Overlay

struct LoadingOverlay: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView(value: progress)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(2)
                
                Text("Loading Photos...")
                    .foregroundColor(.white)
                    .font(.headline)
                
                Text("\(Int(progress * 100))%")
                    .foregroundColor(.white)
                    .font(.title2)
                    .bold()
            }
            .padding(40)
            .background(Color.black.opacity(0.8))
            .cornerRadius(20)
        }
    }
}

// MARK: - Draggable Collapsed Banner Component

struct DraggableCollapsedBanner: View {
    let progress: Double
    @Binding var position: CGPoint?
    let screenSize: CGSize
    let onExpand: () -> Void
    
    @State private var currentOffset: CGSize = .zero
    
    var body: some View {
        let defaultPos = CGPoint(x: screenSize.width - 70, y: screenSize.height - 150)
        let actualPos = position ?? defaultPos
        
        Button(action: onExpand) {
            HStack(spacing: 8) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.7)
                
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Image(systemName: "chevron.up.circle.fill")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.blue)
            .clipShape(Capsule())
            .shadow(radius: 10)
        }
        .offset(currentOffset)
        .position(actualPos)
        .gesture(
            DragGesture()
                .onChanged { value in
                    currentOffset = value.translation
                }
                .onEnded { value in
                    var newX = actualPos.x + value.translation.width
                    var newY = actualPos.y + value.translation.height
                    
                    // Keep within bounds with padding
                    newX = max(60, min(screenSize.width - 60, newX))
                    newY = max(60, min(screenSize.height - 60, newY))
                    
                    position = CGPoint(x: newX, y: newY)
                    currentOffset = .zero
                }
        )
    }
}

// MARK: - Draggable Expanded Banner Component

struct DraggableExpandedBanner: View {
    let progress: Double
    @Binding var position: CGPoint?
    let screenSize: CGSize
    let onCollapse: () -> Void
    let onCancel: () -> Void
    
    @State private var currentOffset: CGSize = .zero
    
    var body: some View {
        let defaultPos = CGPoint(x: screenSize.width / 2, y: screenSize.height - 80)
        let actualPos = position ?? defaultPos
        
        VStack(alignment: .leading, spacing: 8) {
            // Drag handle
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 40, height: 4)
                Spacer()
            }
            .padding(.top, 4)
            
            HStack {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Creating Video")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Drag me anywhere!")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                Text("\(Int(progress * 100))%")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(minWidth: 45)
                
                Button(action: onCollapse) {
                    Image(systemName: "chevron.down.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
                
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
            
            ProgressView(value: progress)
                .progressViewStyle(LinearProgressViewStyle(tint: .white))
        }
        .padding()
        .frame(width: screenSize.width - 32)
        .background(Color.blue)
        .cornerRadius(15)
        .shadow(radius: 10)
        .offset(currentOffset)
        .position(actualPos)
        .gesture(
            DragGesture()
                .onChanged { value in
                    currentOffset = value.translation
                }
                .onEnded { value in
                    var newY = actualPos.y + value.translation.height
                    
                    // Only allow vertical movement, keep centered horizontally
                    newY = max(80, min(screenSize.height - 80, newY))
                    
                    position = CGPoint(x: screenSize.width / 2, y: newY)
                    currentOffset = .zero
                }
        )
    }
}


// MARK: - Settings View
struct SettingsView: View {
    @ObservedObject var photoLoader: PhotoLoader
    @State private var showClearCacheAlert = false
    @State private var cacheType: CacheType = .all
    
    @AppStorage("userEmoji") private var userEmoji = "🚶"
    @AppStorage("userColor") private var userColor = "#33CCBB"
    @AppStorage("userName") private var userName = "You"
    @State private var showYourCustomization = false
    
    @AppStorage("defaultShowPhotoMarkers") private var defaultShowPhotoMarkers = true
    @AppStorage("defaultShowPolylines") private var defaultShowPolylines = true
    @AppStorage("defaultShowFriendOverlay") private var defaultShowFriendOverlay = true
    
    @State private var showPhotoManagement = false
    
    enum CacheType {
        case images
        case video
        case shareImage
        case all
        
        var title: String {
            switch self {
            case .images: return "Image Cache"
            case .video: return "Video Cache"
            case .shareImage: return "Share Image Cache"
            case .all: return "All Caches"
            }
        }
        
        var description: String {
            switch self {
            case .images: return "Clear cached photos and thumbnails"
            case .video: return "Clear cached video exports"
            case .shareImage: return "Clear cached share images"
            case .all: return "Clear all cached data"
            }
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Settings")
                    .font(.largeTitle)
                    .bold()
                    .padding()
                
                VStack(spacing: 15) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Your Appearance")
                                .font(.title3)
                                .bold()
                            Text("How you appear on the map")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    HStack(spacing: 15) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: userColor) ?? .blue)
                                .frame(width: 60, height: 60)
                            
                            if let imageData = UserDefaults.standard.data(forKey: "userProfileImageData"),
                               let image = UIImage(data: imageData) {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 56, height: 56)
                                    .clipShape(Circle())
                            } else {
                                Text(userEmoji)
                                    .font(.system(size: 35))
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text(userName)
                                .font(.title3)
                                .bold()
                            
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: userColor) ?? .blue)
                                    .frame(width: 8, height: 8)
                                Text(userColor.uppercased())
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: { showYourCustomization = true }) {
                            HStack {
                                Image(systemName: "paintbrush.fill")
                                Text("Customize")
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(15)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                }
                
                Divider()
                    .padding(.vertical, 10)
                
                GroupBox(label: Label("Default Map Preferences", systemImage: "map")) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("These settings control how the map appears when you first open it. You can still toggle them on/off while using the map.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 5)
                        
                        Toggle(isOn: $defaultShowPhotoMarkers) {
                            HStack {
                                Image(systemName: "photo.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                Text("Show photo markers")
                            }
                        }
                        
                        Toggle(isOn: $defaultShowPolylines) {
                            HStack {
                                Image(systemName: "line.3.horizontal")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)
                                Text("Show path lines")
                            }
                        }
                        
                        Toggle(isOn: $defaultShowFriendOverlay) {
                            HStack {
                                Image(systemName: "person.2.fill")
                                    .foregroundColor(.orange)
                                    .frame(width: 24)
                                Text("Show friends overlay")
                            }
                        }
                    }
                    .padding(.vertical, 5)
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.vertical, 10)
                
                GroupBox(label: Label("Photo Library", systemImage: "photo.stack")) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Photos with GPS:")
                            Spacer()
                            Text("\(photoLoader.locations.count)")
                                .bold()
                        }
                        
                        HStack {
                            Text("Total Distance:")
                            Spacer()
                            Text(String(format: "%.1f mi", photoLoader.totalDistance / 1609.34))
                                .bold()
                        }
                        
                        HStack {
                            Text("Date Range:")
                            Spacer()
                            Text(photoLoader.getDateRange())
                                .font(.caption)
                                .bold()
                        }
                    }
                    .padding(.vertical, 5)
                }
                .padding(.horizontal)
                
                Button(action: {
                    PersistenceManager.shared.clearImageCache()
                    photoLoader.checkPhotoLibraryPermission()
                }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Reload Photos from Library")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Button(action: {
                    showPhotoManagement = true
                }) {
                    HStack {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Manage Individual Photos")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Divider()
                    .padding(.vertical, 10)
                
                GroupBox(label: Label("Cache Management", systemImage: "tray.full")) {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Cached data helps load your photos instantly")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let thumbnailCount = getCachedThumbnailCount() {
                            HStack {
                                Image(systemName: "photo.circle")
                                    .foregroundColor(.blue)
                                Text("\(thumbnailCount) cached thumbnails")
                                    .font(.subheadline)
                                Spacer()
                            }
                        }
                        
                        if hasVideoCache() {
                            HStack {
                                Image(systemName: "video.circle")
                                    .foregroundColor(.green)
                                Text("Video export cached")
                                    .font(.subheadline)
                                Spacer()
                            }
                        }
                        
                        if hasShareImageCache() {
                            HStack {
                                Image(systemName: "photo.circle.fill")
                                    .foregroundColor(.purple)
                                Text("Share image cached")
                                    .font(.subheadline)
                                Spacer()
                            }
                        }
                        
                        Divider()
                        
                        VStack(spacing: 10) {
                            Button(action: {
                                cacheType = .images
                                showClearCacheAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Clear Image Cache")
                                    Spacer()
                                }
                                .foregroundColor(.orange)
                            }
                            
                            Button(action: {
                                cacheType = .video
                                showClearCacheAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Clear Video Cache")
                                    Spacer()
                                }
                                .foregroundColor(.orange)
                            }
                            
                            Button(action: {
                                cacheType = .shareImage
                                showClearCacheAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("Clear Share Image Cache")
                                    Spacer()
                                }
                                .foregroundColor(.orange)
                            }
                            
                            Button(action: {
                                cacheType = .all
                                showClearCacheAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "trash.fill")
                                    Text("Clear All Caches")
                                    Spacer()
                                }
                                .foregroundColor(.red)
                                .font(.system(size: 17, weight: .bold))
                            }
                        }
                    }
                    .padding(.vertical, 5)
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
        .alert("Clear \(cacheType.title)?", isPresented: $showClearCacheAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                clearCache(type: cacheType)
            }
        } message: {
            Text(cacheType.description)
        }
        .sheet(isPresented: $showYourCustomization) {
            YourCustomizationSheet(
                userName: $userName,
                userEmoji: $userEmoji,
                userColor: $userColor
            )
        }
        .sheet(isPresented: $showPhotoManagement) {
            PhotoManagementSheet(photoLoader: photoLoader)
        }
    }
    
    private func getCachedThumbnailCount() -> Int? {
        return UserDefaults.standard.value(forKey: "ThumbnailsCache") as? Int
    }
    
    private func hasVideoCache() -> Bool {
        return UserDefaults.standard.dictionary(forKey: "LastVideoExport") != nil
    }
    
    private func hasShareImageCache() -> Bool {
        return UserDefaults.standard.dictionary(forKey: "LastShareImage") != nil
    }
    
    private func clearCache(type: CacheType) {
        switch type {
        case .images:
            PersistenceManager.shared.clearImageCache()
        case .video:
            PersistenceManager.shared.clearVideoCache()
        case .shareImage:
            PersistenceManager.shared.clearShareImageCache()
        case .all:
            PersistenceManager.shared.clearAllCaches()
        }
        
        print("✅ Cleared \(type.title)")
    }
}

// MARK: - Photo Management Sheet

struct PhotoManagementSheet: View {
    @ObservedObject var photoLoader: PhotoLoader
    @Environment(\.dismiss) var dismiss
    @State private var selectedPhotos: Set<PhotoIdentifier> = []
    @State private var showDeleteConfirmation = false
    @State private var showReloadConfirmation = false
    
    private var allPhotos: [PhotoIdentifier] {
        var photos: [PhotoIdentifier] = []
        for (locationIndex, photosAtLocation) in photoLoader.allPhotosAtLocation.enumerated() {
            for photoIndex in 0..<photosAtLocation.count {
                photos.append(PhotoIdentifier(locationIndex: locationIndex, photoIndex: photoIndex))
            }
        }
        return photos
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Total Photos")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("\(allPhotos.count)")
                            .font(.title2)
                            .bold()
                    }
                    
                    if !selectedPhotos.isEmpty {
                        Divider()
                            .frame(height: 40)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Selected")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(selectedPhotos.count)")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Spacer()
                    
                    if !selectedPhotos.isEmpty {
                        Button(action: {
                            selectedPhotos.removeAll()
                        }) {
                            Text("Clear")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                    Text("Tap photos to select/deselect them for deletion")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 2) {
                        ForEach(allPhotos) { photoId in
                            IndividualPhotoCell(
                                photoLoader: photoLoader,
                                photoId: photoId,
                                isSelected: selectedPhotos.contains(photoId),
                                onTap: {
                                    if selectedPhotos.contains(photoId) {
                                        selectedPhotos.remove(photoId)
                                    } else {
                                        selectedPhotos.insert(photoId)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.bottom, 80)
                }
            }
            .navigationTitle("Manage Photos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Reload All") {
                        showReloadConfirmation = true
                    }
                    .foregroundColor(.orange)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !selectedPhotos.isEmpty {
                        Button("Hide (\(selectedPhotos.count))") {
                            showDeleteConfirmation = true
                        }
                        .foregroundColor(.red)
                    } else {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Hide \(selectedPhotos.count) Photo\(selectedPhotos.count == 1 ? "" : "s")?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Hide", role: .destructive) {
                    let photosToDelete = selectedPhotos.map { ($0.locationIndex, $0.photoIndex) }
                    photoLoader.deleteMultiplePhotos(photosToDelete)
                    selectedPhotos.removeAll()
                }
            } message: {
                Text("This will hide these photos from your journey. You can restore them by reloading all photos in Reload Photos from Library.")
            }
            .alert("Reload All Photos?", isPresented: $showReloadConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Reload", role: .destructive) {
                    photoLoader.reloadAllPhotos()
                    dismiss()
                }
            } message: {
                Text("This will reload all photos from your library, restoring any deleted photos. This may take a minute.")
            }
        }
    }
}

// MARK: - Photo Identifier

struct PhotoIdentifier: Identifiable, Hashable {
    let locationIndex: Int
    let photoIndex: Int
    
    var id: String {
        "\(locationIndex)-\(photoIndex)"
    }
}

// MARK: - Individual Photo Cell

struct IndividualPhotoCell: View {
    @ObservedObject var photoLoader: PhotoLoader
    let photoId: PhotoIdentifier
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        )
                }
                
                if isSelected {
                    Color.white.opacity(0.3)
                    
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 28, height: 28)
                                
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(8)
                        }
                        Spacer()
                    }
                } else {
                    // FIXED: iOS 15+ compatible version
                    VStack {
                        HStack {
                            Spacer()
                            ZStack {
                                Circle()
                                    .fill(Color.black.opacity(0.3))
                                    .frame(width: 28, height: 28)
                                
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                                    .frame(width: 28, height: 28)
                            }
                            .padding(8)
                        }
                        Spacer()
                    }
                }
                
                VStack {
                    Spacer()
                    HStack {
                        if photoId.locationIndex < photoLoader.photoTimeStamps.count {
                            Text(formatDate(photoLoader.photoTimeStamps[photoId.locationIndex]))
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(4)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(4)
                        }
                        Spacer()
                    }
                }
                .padding(4)
            }
            .frame(width: 120, height: 120)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard photoId.locationIndex < photoLoader.allPhotosAtLocation.count,
              photoId.photoIndex < photoLoader.allPhotosAtLocation[photoId.locationIndex].count else {
            return
        }
        
        photoLoader.loadPhotosAtLocation(at: photoId.locationIndex) { images in
            if let images = images, photoId.photoIndex < images.count {
                self.image = images[photoId.photoIndex]
                self.isLoading = false
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
