import SwiftUI
import MapKit

struct YearStoryCarousel: View {
    @ObservedObject var photoLoader: PhotoLoader
    @Binding var hasCompletedOnboarding: Bool
    @Binding var selectedFeature: String?
    @Binding var isHomeMenu: Bool
    
    @State private var currentIndex = 0
    @State private var dragOffset: CGFloat = 0
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var isGeneratingShare = false
    
    //pass star variables
    @State private var constellationScale: CGFloat = 1.0
    @State private var constellationRotation: Angle = .zero
    @State private var constellationBackgroundStars: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = []
    @State private var constellationStars: [ConstellationStar] = []
    @State private var constellationConnections: [ConstellationConnection] = []
    
    private let totalPages = 7
    
    // Custom color palette
    private let accentTeal = Color(red: 0.2, green: 0.8, blue: 0.7)
    private let deepPurple = Color(red: 0.4, green: 0.2, blue: 0.6)
    private let warmCoral = Color(red: 1.0, green: 0.4, blue: 0.5)
    private let softLavender = Color(red: 0.7, green: 0.5, blue: 0.9)
    
    var body: some View {
        ZStack {
            // Content area - FULLSCREEN
            TabView(selection: $currentIndex) {
                WelcomeCard(photoLoader: photoLoader, accentTeal: accentTeal)
                    .tag(0)
                
                Top12PhotosCard(photoLoader: photoLoader, warmCoral: warmCoral, softLavender: softLavender, isGeneratingShare: $isGeneratingShare)
                    .tag(1)
                
                StatsHighlightCard(photoLoader: photoLoader, accentTeal: accentTeal, warmCoral: warmCoral, deepPurple: deepPurple)
                    .tag(2)
                
                UniqueInsightsCard(photoLoader: photoLoader, accentTeal: accentTeal, warmCoral: warmCoral, deepPurple: deepPurple, softLavender: softLavender)
                    .tag(3)
                
                ConstellationCard(
                    photoLoader: photoLoader,
                    accentTeal: accentTeal,
                    deepPurple: deepPurple,
                    scale: $constellationScale,
                    rotation: $constellationRotation,
                    backgroundStars: $constellationBackgroundStars,
                    stars: $constellationStars,
                    connections: $constellationConnections
                )
                .tag(4)
                
                MapPreviewCard(
                    photoLoader: photoLoader,
                    accentTeal: accentTeal,
                    onNavigate: {
                        navigateToFeature("Map")
                    },
                    isGeneratingShare: $isGeneratingShare
                )
                .tag(5)
                
                FinalCTACard(
                    accentTeal: accentTeal,
                    onNavigate: { feature in
                        if let feature = feature {
                            navigateToFeature(feature)
                        } else {
                            selectedFeature = nil
                            isHomeMenu = true
                            hasCompletedOnboarding = true
                        }
                    }
                )
                .tag(6)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
        
            
            // ONLY show overlay when NOT generating share
            if !isGeneratingShare {
                VStack(spacing: 0) {
                    // Top buttons with gradient fade background
                    ZStack(alignment: .top) {
                        // Gradient fade to make buttons readable
                        LinearGradient(
                            colors: [Color.black.opacity(0.5), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 120)
                        .ignoresSafeArea(edges: .top)
                        
                        HStack {
                            // Share button (left)
                            Button(action: shareCurrentSlide) {
                                HStack(spacing: 6) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Share")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                            }
                            
                            Spacer()
                            
                            // Close button (right)
                            Button(action: {
                                selectedFeature = nil
                                isHomeMenu = true
                                hasCompletedOnboarding = true
                            }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }
                    
                    Spacer()
                    
                    // Progress bars at BOTTOM
                    ZStack(alignment: .bottom) {
                        // Gradient fade
                        LinearGradient(
                            colors: [Color.clear, Color.black.opacity(0.3)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 100)
                        .allowsHitTesting(false)
                        
                        HStack(spacing: 4) {
                            ForEach(0..<totalPages, id: \.self) { index in
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.white.opacity(0.3))
                                            .frame(height: 3)
                                        
                                        Capsule()
                                            .fill(accentTeal)
                                            .frame(width: progressWidth(for: index, in: geometry), height: 3)
                                    }
                                }
                                .frame(height: 3)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                        .allowsHitTesting(false)
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ActivityViewController(activityItems: [image])
            }
        }
    }
    
    private func shareCurrentSlide() {
        // Special handling for constellation card (index 4)
        if currentIndex == 4 {
            shareConstellationCard()
            return
        }
        
        // Original screenshot logic for other cards
        isGeneratingShare = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                self.isGeneratingShare = false
                return
            }
            
            let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
            let screenshot = renderer.image { context in
                window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            
            self.shareImage = screenshot
            self.isGeneratingShare = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showShareSheet = true
            }
        }
    }

    private func shareConstellationCard() {
        isGeneratingShare = true

        let snapshotView = ConstellationSnapshotView(
            locations: photoLoader.locations,
            locationCount: photoLoader.locations.count,
            scale: constellationScale,
            rotation: constellationRotation,
            backgroundStars: constellationBackgroundStars,
            stars: constellationStars,
            connections: constellationConnections
        )
        
        let hostingController = UIHostingController(rootView: snapshotView)
        let targetSize = CGSize(width: 1080, height: 1920)
        hostingController.view.bounds = CGRect(origin: .zero, size: targetSize)
        hostingController.view.backgroundColor = UIColor.clear
        
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let format = UIGraphicsImageRendererFormat()
            format.opaque = true
            format.scale = 2.0
            
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            let image = renderer.image { context in
                UIColor.black.setFill()
                context.fill(CGRect(origin: .zero, size: targetSize))
                
                hostingController.view.drawHierarchy(
                    in: CGRect(origin: .zero, size: targetSize),
                    afterScreenUpdates: true
                )
            }
            
            self.shareImage = image
            self.isGeneratingShare = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showShareSheet = true
            }
        }
    }
    
    private func navigateToFeature(_ feature: String) {
        selectedFeature = feature
        isHomeMenu = false
        hasCompletedOnboarding = true
    }
    
    private func progressWidth(for index: Int, in geometry: GeometryProxy) -> CGFloat {
        if index < currentIndex {
            return geometry.size.width
        } else if index == currentIndex {
            return geometry.size.width
        } else {
            return 0
        }
    }
}

// MARK: - Card 1: Welcome

struct WelcomeCard: View {
    @ObservedObject var photoLoader: PhotoLoader
    let accentTeal: Color
    
    var body: some View {
        ZStack {
            // Full screen black background
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 24) {
                    Text("2025")
                        .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 96), weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [accentTeal, .white],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: accentTeal.opacity(0.5), radius: 20)
                    
                    VStack(spacing: 8) {
                        Text("Your Year")
                            .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 32), weight: .light))
                            .foregroundColor(.white.opacity(0.9))
                        
                        Text("in Review")
                            .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 32), weight: .light))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    HStack(spacing: 40) {
                        StatPill(value: "\(photoLoader.locations.count)", label: "Places", color: accentTeal)
                        StatPill(value: String(format: "%.0f", photoLoader.totalDistance / 1609.34), label: "Miles", color: accentTeal)
                        StatPill(value: "\(photoLoader.totalPhotosWithLocation)", label: "Photos", color: accentTeal)
                    }
                    .padding(.top, 32)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Text("Swipe to explore")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14))
                        .foregroundColor(accentTeal)
                }
                .padding(.bottom, 80)
            }
        }
    }
}

struct StatPill: View {
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 28), weight: .bold))
                .foregroundColor(color)
            
            if #available(iOS 16.0, *) {
                Text(label)
                    .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 13), weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .textCase(.uppercase)
                    .kerning(1)
            } else {
                Text(label)
                    .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 13), weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .textCase(.uppercase)
            }
        }
    }
}

// MARK: - Card 2: Top 12 Photos

struct Top12PhotosCard: View {
    @ObservedObject var photoLoader: PhotoLoader
    let warmCoral: Color
    let softLavender: Color
    @Binding var isGeneratingShare: Bool
    
    @State private var selectedPhotos: [Int: UIImage] = [:]
    @State private var photosByMonth: [String: [Int]] = [:] // Store INDICES instead of images
    @State private var monthKeys: [String] = []
    @State private var isLoadingPhotos = true
    
    var body: some View {
        ZStack {
            // Full screen gradient
            LinearGradient(
                colors: [warmCoral.opacity(0.4), softLavender.opacity(0.4)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if isLoadingPhotos {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    Text("Loading photos...")
                        .foregroundColor(.white)
                        .padding(.top)
                }
            } else {
                VStack(spacing: 40) {
                    Spacer()
                    
                    VStack(spacing: 10) {
                        Text("Your Year")
                            .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 50), weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("in 12 Moments")
                            .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 28), weight: .light))
                            .foregroundColor(.white.opacity(0.9))
                        
                        if !isGeneratingShare {
                            Text("Tap to shuffle")
                                .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 14), weight: .medium))
                                .foregroundColor(warmCoral)
                                .padding(.top, 4)
                        }
                    }
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        ForEach(0..<12, id: \.self) { index in
                            if let photo = selectedPhotos[index] {
                                Button(action: {
                                    shufflePhoto(at: index)
                                }) {
                                    Image(uiImage: photo)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: ResponsiveLayout.scale(110), height: ResponsiveLayout.scale(110))
                                        .clipped()
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(warmCoral.opacity(0.5), lineWidth: 2)
                                        )
                                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                                }
                            } else {
                                // Loading placeholder
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: ResponsiveLayout.scale(110), height: ResponsiveLayout.scale(110))
                                    .overlay(
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 35)
                    
                    Spacer()
                }
            }
        }
        .onAppear {
            loadPhotosGroupedByMonth()
        }
    }
    
    private func loadPhotosGroupedByMonth() {
        isLoadingPhotos = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM"
            
            var grouped: [String: [Int]] = [:] // Store indices instead of images
            
            // Group photo INDICES by month
            for (index, timestamp) in photoLoader.photoTimeStamps.enumerated() {
                let monthKey = dateFormatter.string(from: timestamp)
                
                if grouped[monthKey] == nil {
                    grouped[monthKey] = []
                }
                
                // Store the location index
                grouped[monthKey]?.append(index)
            }
            
            let sortedMonthKeys = grouped.keys.sorted()
            let allIndices = Array(0..<photoLoader.locations.count)
            
            // Load first photo for each of the 12 slots
            let dispatchGroup = DispatchGroup()
            var loadedPhotos: [Int: UIImage] = [:]
            
            for slot in 0..<12 {
                dispatchGroup.enter()
                
                let photoIndex: Int
                if slot < sortedMonthKeys.count {
                    let monthKey = sortedMonthKeys[slot]
                    photoIndex = grouped[monthKey]?.first ?? 0
                } else {
                    // Use random photo for missing months
                    photoIndex = allIndices.randomElement() ?? 0
                }
                
                // Load the actual image from disk
                photoLoader.loadThumbnail(at: photoIndex) { image in
                    if let image = image {
                        loadedPhotos[slot] = image
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                self.photosByMonth = grouped
                self.monthKeys = sortedMonthKeys
                self.selectedPhotos = loadedPhotos
                self.isLoadingPhotos = false
            }
        }
    }
    
    private func shufflePhoto(at slot: Int) {
        // Get the indices pool for this slot
        let indicesPool: [Int]
        
        if slot < monthKeys.count {
            // Use photos from this month
            let key = monthKeys[slot]
            indicesPool = photosByMonth[key] ?? Array(0..<photoLoader.locations.count)
        } else {
            // For slots beyond available months, use all photos
            indicesPool = Array(0..<photoLoader.locations.count)
        }
        
        // Need at least 2 photos to shuffle
        guard indicesPool.count > 1 else { return }
        
        // Find current photo's index
        guard let currentImage = selectedPhotos[slot],
              let currentIndex = photoLoader.thumbnails.firstIndex(where: { $0 === currentImage }) else {
            return
        }
        
        // Pick different index from the pool
        var newIndex = indicesPool.randomElement()!
        while newIndex == currentIndex && indicesPool.count > 1 {
            newIndex = indicesPool.randomElement()!
        }
        
        // Load the new image
        photoLoader.loadThumbnail(at: newIndex) { image in
            if let image = image {
                withAnimation(.spring(response: 0.3)) {
                    selectedPhotos[slot] = image
                }
            }
        }
    }
    
    private func createPlaceholder() -> UIImage {
        let size = CGSize(width: ResponsiveLayout.scale(110), height: ResponsiveLayout.scale(110))
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            context.cgContext.setFillColor(UIColor.gray.cgColor)
            context.cgContext.fill(CGRect(origin: .zero, size: size))
        }
    }
}

// MARK: - Card 3: Stats Highlight

struct StatsHighlightCard: View {
    @ObservedObject var photoLoader: PhotoLoader
    let accentTeal: Color
    let warmCoral: Color
    let deepPurple: Color
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("Your Journey")
                        .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 42), weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("by the numbers")
                        .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 20), weight: .light))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                VStack(spacing: 24) {
                    BigStatRow(icon: "figure.walk", label: "Total Distance", value: String(format: "%.1f miles", photoLoader.totalDistance / 1609.34), color: accentTeal)
                    BigStatRow(icon: "mappin.circle.fill", label: "Places Visited", value: "\(photoLoader.locations.count)", color: warmCoral)
                    BigStatRow(icon: "camera.fill", label: "Photos Captured", value: "\(photoLoader.totalPhotosWithLocation)", color: deepPurple)
                    
                    if let mostActive = getMostActiveMonth() {
                        BigStatRow(icon: "calendar", label: "Most Active Month", value: mostActive, color: Color(red: 1.0, green: 0.6, blue: 0.3))
                    }
                }
                .padding(.horizontal, 32)
            }
            
            Spacer()
        }
    }
    
    private func getMostActiveMonth() -> String? {
        guard !photoLoader.allPhotoTimestamps.isEmpty else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        var monthCounts: [String: Int] = [:]
        
        for timestamp in photoLoader.allPhotoTimestamps {
            let month = formatter.string(from: timestamp)
            monthCounts[month, default: 0] += 1
        }
        
        return monthCounts.max(by: { $0.value < $1.value })?.key
    }
}

struct BigStatRow: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: ResponsiveLayout.scale(56), height: ResponsiveLayout.scale(56))
                
                Image(systemName: icon)
                    .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 24)))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                if #available(iOS 16.0, *) {
                    Text(label)
                        .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 14), weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .textCase(.uppercase)
                        .kerning(0.5)
                } else {
                    Text(label)
                        .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 14), weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                        .textCase(.uppercase)
                }
                
                Text(value)
                    .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 26), weight: .bold))
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.08))
        .cornerRadius(16)
    }
}

// MARK: - Card 4: Unique Insights

struct UniqueInsightsCard: View {
    @ObservedObject var photoLoader: PhotoLoader
    let accentTeal: Color
    let warmCoral: Color
    let deepPurple: Color
    let softLavender: Color
    
    var body: some View {
        GeometryReader { geometry in
            let isSmallDevice = geometry.size.height < 750  // iPhone SE, etc.
            let isMediumDevice = geometry.size.height < 900  // iPhone 13/14/15
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: isSmallDevice ? 12 : isMediumDevice ? 16 : 20) {
                    VStack(spacing: 8) {
                        Text("Personal")
                            .font(.system(size: isSmallDevice ? 32 : isMediumDevice ? 36 : 38, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Insights")
                            .font(.system(size: isSmallDevice ? 32 : isMediumDevice ? 36 : 38, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    
                    VStack(spacing: isSmallDevice ? 8 : isMediumDevice ? 10 : 12) {
                        if let homeBase = findHomeBase() {
                            InsightCard(
                                emoji: "🏠",
                                title: "Your Home Base",
                                description: getHomeBaseDescription(homeBase),
                                gradient: [accentTeal, accentTeal.opacity(0.6)],
                                isSmallDevice: isSmallDevice,
                                isMediumDevice: isMediumDevice
                            )
                        }
                        
                        if let photoStyle = getPhotoStyle() {
                            InsightCard(
                                emoji: photoStyle.isEarlyBird ? "🌅" : "🌃",
                                title: photoStyle.isEarlyBird ? "Early Bird" : "Night Owl",
                                description: photoStyle.description,
                                gradient: photoStyle.isEarlyBird ?
                                    [Color(red: 1.0, green: 0.7, blue: 0.3), Color(red: 1.0, green: 0.9, blue: 0.4)] :
                                    [deepPurple, softLavender],
                                isSmallDevice: isSmallDevice,
                                isMediumDevice: isMediumDevice
                            )
                        }
                        
                        if let explorationStyle = getExplorationStyle() {
                            InsightCard(
                                emoji: explorationStyle.emoji,
                                title: explorationStyle.title,
                                description: explorationStyle.description,
                                gradient: [accentTeal.opacity(0.8), Color(red: 0.3, green: 0.9, blue: 0.6)],
                                isSmallDevice: isSmallDevice,
                                isMediumDevice: isMediumDevice
                            )
                        }
                        
                        if let achievement = getDistanceAchievement() {
                            InsightCard(
                                emoji: "🌎",
                                title: achievement.title,
                                description: achievement.description,
                                gradient: [warmCoral, Color(red: 1.0, green: 0.5, blue: 0.3)],
                                isSmallDevice: isSmallDevice,
                                isMediumDevice: isMediumDevice
                            )
                        }
                    }
                    .padding(.horizontal, isSmallDevice ? 20 : 24)
                }
                
                Spacer()
            }
        }
    }
    
    private func findHomeBase() -> CLLocationCoordinate2D? {
        guard !photoLoader.locations.isEmpty else { return nil }
        
        var locationClusters: [CLLocationCoordinate2D: Int] = [:]
        let clusterRadius = 5000.0
        
        for location in photoLoader.locations {
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
    
    private func getHomeBaseDescription(_ homeBase: CLLocationCoordinate2D) -> String {
        let homeLocation = CLLocation(latitude: homeBase.latitude, longitude: homeBase.longitude)
        var withinRadius = 0
        
        for location in photoLoader.locations {
            let loc = CLLocation(latitude: location.latitude, longitude: location.longitude)
            if homeLocation.distance(from: loc) < 8046.72 {
                withinRadius += 1
            }
        }
        
        let percentage = (Double(withinRadius) / Double(photoLoader.locations.count)) * 100
        return String(format: "%.0f%% of your photos were within 5 miles of home", percentage)
    }
    
    private func getPhotoStyle() -> (isEarlyBird: Bool, description: String)? {
        guard !photoLoader.allPhotoTimestamps.isEmpty else { return nil }
        
        var dayPhotos = 0
        var nightPhotos = 0
        
        let calendar = Calendar.current
        for timestamp in photoLoader.allPhotoTimestamps {
            let hour = calendar.component(.hour, from: timestamp)
            if hour >= 6 && hour < 18 {
                dayPhotos += 1
            } else {
                nightPhotos += 1
            }
        }
        
        let total = dayPhotos + nightPhotos
        let isEarlyBird = dayPhotos > nightPhotos
        let percentage = Double(isEarlyBird ? dayPhotos : nightPhotos) / Double(total) * 100
        
        let description = String(format: "%.0f%% of your photos were taken during the %@",
                                percentage, isEarlyBird ? "day" : "night")
        
        return (isEarlyBird, description)
    }
    
    private func getExplorationStyle() -> (emoji: String, title: String, description: String)? {
        guard photoLoader.locations.count > 1 else { return nil }
        
        let avgDistance = photoLoader.totalDistance / Double(photoLoader.locations.count)
        let avgMiles = avgDistance / 1609.34
        
        if avgMiles < 5 {
            return ("🏘️", "Local Explorer",
                    String(format: "Average %.1f miles between spots - you love exploring nearby!", avgMiles))
        } else if avgMiles < 20 {
            return ("🏙️", "City Wanderer",
                    String(format: "Average %.1f miles between spots - embracing the journey!", avgMiles))
        } else {
            return ("✈️", "Long Distance Traveler",
                    String(format: "Average %.1f miles between spots - you go the distance!", avgMiles))
        }
    }
    
    private func getDistanceAchievement() -> (title: String, description: String)? {
        let totalMiles = photoLoader.totalDistance / 1609.34
        let equatorMiles = 24901.0
        let ratio = totalMiles / equatorMiles
        
        if ratio >= 1.0 {
            return ("Earth Circumnavigator",
                    String(format: "You traveled %.1fx around Earth's equator!", ratio))
        } else if ratio >= 0.5 {
            return ("Halfway Around the World",
                    String(format: "You traveled %.0f%% of Earth's circumference!", ratio * 100))
        } else if totalMiles >= 10000 {
            return ("10K Milestone",
                    String(format: "You traveled %.0f miles this year!", totalMiles))
        } else if totalMiles >= 5000 {
            return ("5K Milestone",
                    String(format: "You traveled %.0f miles this year!", totalMiles))
        } else if totalMiles >= 1000 {
            return ("1K Milestone",
                    String(format: "You traveled %.0f miles this year!", totalMiles))
        } else {
            return ("Journey Starter",
                    String(format: "%.0f miles of memories created!", totalMiles))
        }
    }
}

struct InsightCard: View {
    let emoji: String
    let title: String
    let description: String
    let gradient: [Color]
    let isSmallDevice: Bool
    let isMediumDevice: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: isSmallDevice ? 8 : isMediumDevice ? 10 : 12) {
            Text(emoji)
                .font(.system(size: isSmallDevice ? 32 : isMediumDevice ? 36 : 40))
            
            Text(title)
                .font(.system(size: isSmallDevice ? 17 : isMediumDevice ? 18 : 20, weight: .bold))
                .foregroundColor(.white)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            
            Text(description)
                .font(.system(size: isSmallDevice ? 13 : isMediumDevice ? 13.5 : 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .lineSpacing(isSmallDevice ? 2 : 3)
                .minimumScaleFactor(0.9)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(isSmallDevice ? 14 : isMediumDevice ? 16 : 18)
        .background(
            LinearGradient(
                colors: gradient.map { $0.opacity(0.3) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(isSmallDevice ? 14 : 16)
        .overlay(
            RoundedRectangle(cornerRadius: isSmallDevice ? 14 : 16)
                .stroke(
                    LinearGradient(
                        colors: gradient.map { $0.opacity(0.5) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

// MARK: - Card 5: Constellation

struct ConstellationCard: View {
    @ObservedObject var photoLoader: PhotoLoader
    let accentTeal: Color
    let deepPurple: Color
    @Binding var scale: CGFloat
    @Binding var rotation: Angle
    @Binding var backgroundStars: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)]
    @Binding var stars: [ConstellationStar]
    @Binding var connections: [ConstellationConnection]
    
    @State private var revealProgress: Double = 0.0
    @State private var hasAppeared = false
    @State private var lastScale: CGFloat = 1.0
    @State private var lastRotation: Angle = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ForEach(Array(backgroundStars.enumerated()), id: \.offset) { index, star in
                Circle()
                    .fill(Color.white.opacity(star.opacity))
                    .frame(width: star.size, height: star.size)
                    .position(x: star.x, y: star.y)
            }
            
            VStack(spacing: 0) {
                Spacer().frame(height: 100)
                
                VStack(spacing: 15) {
                    Text("Your 2025")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Constellation")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(accentTeal.opacity(0.9))
                }
                
                Spacer()
                
                if !photoLoader.locations.isEmpty {
                    GeometryReader { geometry in
                        let constellation = ConstellationBuilder.buildConstellation(
                            locations: photoLoader.locations,
                            viewSize: geometry.size
                        )
                        
                        let visibleStarCount = Int(Double(constellation.stars.count) * revealProgress)
                        let visibleStars = Array(constellation.stars.prefix(visibleStarCount))
                        
                        let visibleConnections = constellation.connections.filter { connection in
                            visibleStars.contains(where: { $0.id == connection.from.id }) &&
                            visibleStars.contains(where: { $0.id == connection.to.id })
                        }
                        
                        ZStack {
                            // Draw connections
                            ForEach(visibleConnections.indices, id: \.self) { index in
                                let connection = visibleConnections[index]
                                Path { path in
                                    path.move(to: connection.from.screenPosition)
                                    path.addLine(to: connection.to.screenPosition)
                                }
                                .stroke(
                                    LinearGradient(
                                        colors: [accentTeal.opacity(0.8), deepPurple.opacity(0.6), Color.white.opacity(0.4)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 2
                                )
                                .shadow(color: accentTeal.opacity(0.5), radius: 3)
                                .shadow(color: deepPurple.opacity(0.3), radius: 5)
                            }
                            
                            // Draw stars
                            ForEach(visibleStars) { star in
                                ConstellationStarView(star: star, accentTeal: accentTeal, deepPurple: deepPurple)
                            }
                        }
                        .onAppear {
                            // Store the constellation for sharing
                            if stars.isEmpty {
                                stars = constellation.stars
                                connections = constellation.connections
                            }
                        }
                    }
                    .frame(height: ResponsiveLayout.scaleHeight(450))
                    .padding(.horizontal, 30)
                    .scaleEffect(scale)
                    .rotationEffect(rotation)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = lastScale * value
                                }
                                .onEnded { value in
                                    lastScale = scale
                                },
                            RotationGesture()
                                .onChanged { value in
                                    rotation = lastRotation + value
                                }
                                .onEnded { value in
                                    lastRotation = rotation
                                }
                        )
                    )
                }
                
                Spacer()
                
                Text("\(stars.count) stars | Your unique pattern")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 10)
                
                Text("Pinch to zoom | Rotate with two fingers")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.bottom, 80)
            }
        }
        .onAppear {
            if !hasAppeared {
                generateBackgroundStars()
                hasAppeared = true
                
                // Initialize lastScale and lastRotation from binding values
                lastScale = scale
                lastRotation = rotation
                
                withAnimation(.easeInOut(duration: 2.5)) {
                    revealProgress = 1.0
                }
            }
        }
        .onDisappear {
            revealProgress = 0.0
            hasAppeared = false
        }
    }
    
    private func generateBackgroundStars() {
        guard backgroundStars.isEmpty else { return } // Don't regenerate if already populated
        
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        var stars: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = []
        
        for _ in 0..<150 {
            stars.append((
                x: CGFloat.random(in: 0...screenWidth),
                y: CGFloat.random(in: 0...screenHeight),
                size: CGFloat.random(in: 1...3),
                opacity: Double.random(in: 0.3...0.9)
            ))
        }
        
        backgroundStars = stars
    }
}

struct ConstellationView: View {
    let locations: [CLLocationCoordinate2D]
    let progress: Double
    let accentTeal: Color
    let deepPurple: Color
    
    var body: some View {
        GeometryReader { geometry in
            let constellation = ConstellationBuilder.buildConstellation(
                locations: locations,
                viewSize: geometry.size
            )
            
            let visibleStarCount = Int(Double(constellation.stars.count) * progress)
            let visibleStars = Array(constellation.stars.prefix(visibleStarCount))
            
            let visibleConnections = constellation.connections.filter { connection in
                visibleStars.contains(where: { $0.id == connection.from.id }) &&
                visibleStars.contains(where: { $0.id == connection.to.id })
            }
            
            ZStack {
                // Draw connections
                ForEach(visibleConnections.indices, id: \.self) { index in
                    let connection = visibleConnections[index]
                    Path { path in
                        path.move(to: connection.from.screenPosition)
                        path.addLine(to: connection.to.screenPosition)
                    }
                    .stroke(
                        LinearGradient(
                            colors: [accentTeal.opacity(0.8), deepPurple.opacity(0.6), Color.white.opacity(0.4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2
                    )
                    .shadow(color: accentTeal.opacity(0.5), radius: 3)
                    .shadow(color: deepPurple.opacity(0.3), radius: 5)
                }
                
                // Draw stars
                ForEach(visibleStars) { star in
                    ConstellationStarView(star: star, accentTeal: accentTeal, deepPurple: deepPurple)
                }
            }
        }
    }
}

struct ConstellationStarView: View {
    let star: ConstellationStar
    let accentTeal: Color
    let deepPurple: Color
    
    var body: some View {
        ZStack {
            let glowSize: CGFloat = CGFloat(12 + (star.intensity * 2))
            Circle()
                .fill(
                    RadialGradient(
                        colors: [accentTeal, deepPurple.opacity(0.5), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: glowSize / 2
                    )
                )
                .frame(width: glowSize, height: glowSize)
            
            let coreSize: CGFloat = CGFloat(4 + min(star.intensity, 8))
            Circle()
                .fill(Color.white)
                .frame(width: coreSize, height: coreSize)
            
            if star.intensity >= 5 {
                Circle()
                    .stroke(accentTeal, lineWidth: 1.5)
                    .frame(width: coreSize + 8, height: coreSize + 8)
                    .opacity(0.6)
            }
        }
        .position(star.screenPosition)
    }
}

// MARK: - Card 6: Map Preview

struct MapPreviewCard: View {
    @ObservedObject var photoLoader: PhotoLoader
    let accentTeal: Color
    let onNavigate: () -> Void
    @Binding var isGeneratingShare: Bool
    @State private var mapSnapshot: UIImage?
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("Your Path")
                        .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 42), weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("across 2025")
                        .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 20), weight: .light))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                if let snapshot = mapSnapshot {
                    Button(action: onNavigate) {
                        Image(uiImage: snapshot)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: ResponsiveLayout.scaleHeight(400))
                            .frame(maxWidth: .infinity)
                            .clipped()  // ADD: Clip overflow
                            .cornerRadius(24)
                            .shadow(color: accentTeal.opacity(0.3), radius: 20)
                            .overlay(
                                RoundedRectangle(cornerRadius: 24)
                                    .stroke(accentTeal.opacity(0.5), lineWidth: 2)
                            )
                    }
                    .padding(.horizontal, 24)
                } else {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: ResponsiveLayout.scaleHeight(400))
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: accentTeal))
                                .scaleEffect(1.5)
                        )
                        .padding(.horizontal, 24)
                }
                
                // ONLY show when NOT generating share
                if !isGeneratingShare {
                    Text("Tap map to explore")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(accentTeal.opacity(0.9))
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .onAppear {
            generateMapSnapshot()
        }
    }
    
    private func generateMapSnapshot() {
        guard !photoLoader.locations.isEmpty else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let options = MKMapSnapshotter.Options()
            
            var minLat = photoLoader.locations[0].latitude
            var maxLat = photoLoader.locations[0].latitude
            var minLon = photoLoader.locations[0].longitude
            var maxLon = photoLoader.locations[0].longitude
            
            for location in photoLoader.locations {
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
            
            let snapshotSize = ResponsiveLayout.scale(800)
            options.region = MKCoordinateRegion(center: center, span: span)
            options.size = CGSize(width: snapshotSize, height: snapshotSize)
            options.scale = 2.0
            
            let snapshotter = MKMapSnapshotter(options: options)
            
            snapshotter.start { snapshot, error in
                guard let snapshot = snapshot else { return }
                
                // Get user's custom color
                let userColorHex = UserDefaults.standard.string(forKey: "userColor") ?? "#33CCBB"
                let lineColor = UIColor(hex: userColorHex) ?? UIColor(red: 0.2, green: 0.8, blue: 0.7, alpha: 1.0)
                
                let image = UIGraphicsImageRenderer(size: options.size).image { context in
                    snapshot.image.draw(at: .zero)
                    
                    let ctx = context.cgContext
                    
                    // Draw line with user's custom color
                    ctx.setStrokeColor(lineColor.cgColor)
                    ctx.setLineWidth(ResponsiveLayout.scale(5))
                    ctx.setLineCap(.round)
                    ctx.setLineJoin(.round)
                    
                    for (index, location) in photoLoader.locations.enumerated() {
                        let point = snapshot.point(for: location)
                        
                        if index == 0 {
                            ctx.move(to: point)
                        } else {
                            ctx.addLine(to: point)
                        }
                    }
                    
                    ctx.strokePath()
                    
 
                    for location in photoLoader.locations {
                        let point = snapshot.point(for: location)
                        ctx.setFillColor(lineColor.cgColor)
                        ctx.fillEllipse(in: CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16))
                        ctx.setStrokeColor(UIColor.white.cgColor)
                        ctx.setLineWidth(3)
                        ctx.strokeEllipse(in: CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16))
                    }
                }
                
                DispatchQueue.main.async {
                    self.mapSnapshot = image
                }
            }
        }
    }
}

// MARK: - Card 7: Final CTA

struct FinalCTACard: View {
    let accentTeal: Color
    let onNavigate: (String?) -> Void
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 48) {
                ZStack {
                    Circle()
                        .fill(accentTeal.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulseAnimation ? 1.3 : 1.0)
                        .opacity(pulseAnimation ? 0 : 1)
                    
                    Circle()
                        .fill(accentTeal.opacity(0.3))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "sparkles")
                        .font(.system(size: 48))
                        .foregroundColor(accentTeal)
                }
                
                VStack(spacing: 16) {
                    Text("Ready to")
                        .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 38), weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Explore?")
                        .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 38), weight: .bold))
                        .foregroundColor(accentTeal)
                }
                
                VStack(spacing: 16) {
                    Button(action: {
                        onNavigate("Map")
                    }) {
                        FeaturePillButton(icon: "map.fill", text: "Interactive Map", color: accentTeal)
                    }
                    
                    Button(action: {
                        onNavigate("Share")
                    }) {
                        FeaturePillButton(icon: "video.fill", text: "Create Collage Video", color: accentTeal)
                    }
                    
                    Button(action: {
                        onNavigate("Friends")
                    }) {
                        FeaturePillButton(icon: "person.2.fill", text: "Share with Friends", color: accentTeal)
                    }
                }
            }
            
            Spacer()
            
            Button(action: {
                onNavigate(nil)
            }) {
                Text("Explore Everything")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(accentTeal)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                pulseAnimation = true
            }
        }
    }
}

struct FeaturePillButton: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 18)))
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 16), weight: .medium))
                .foregroundColor(.white)
            
            Spacer()
            
            Image(systemName: "arrow.right")
                .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 14)))
                .foregroundColor(color.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.15))
        .cornerRadius(12)
        .padding(.horizontal, 40)
    }
}

// MARK: - View to Image Extension

extension View {
    func asInstagramStory() -> UIImage {
        let storySize = CGSize(width: 1080, height: 1920)
        
        let hostingController = UIHostingController(rootView: self
            .frame(width: storySize.width, height: storySize.height)
            .background(Color.black)
        )
        
        hostingController.view.bounds = CGRect(origin: .zero, size: storySize)
        hostingController.view.backgroundColor = .clear
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 2.0
        
        let renderer = UIGraphicsImageRenderer(size: storySize, format: format)
        
        return renderer.image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: storySize))
            hostingController.view.drawHierarchy(in: CGRect(origin: .zero, size: storySize), afterScreenUpdates: true)
        }
    }
}
