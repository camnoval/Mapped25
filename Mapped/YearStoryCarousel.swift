import SwiftUI
import MapKit
import CoreLocation
import Photos

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
    
    @Binding var constellationScale: CGFloat
    @Binding var constellationRotation: Angle
    @Binding var constellationBackgroundStars: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)]
    @Binding var constellationStars: [ConstellationStar]
    @Binding var constellationConnections: [ConstellationConnection]
    
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
                
                // NEW ORDER: Map is now 3rd
                MapPreviewCard(
                    photoLoader: photoLoader,
                    accentTeal: accentTeal,
                    onNavigate: {
                        navigateToFeature("Map")
                    },
                    isGeneratingShare: $isGeneratingShare
                )
                .tag(2)
                
                // Constellation is now 4th
                ConstellationCard(
                    photoLoader: photoLoader,
                    accentTeal: accentTeal,
                    deepPurple: deepPurple,
                    scale: $constellationScale,
                    rotation: $constellationRotation,
                    backgroundStars: $constellationBackgroundStars,
                    stars: $constellationStars,
                    connections: $constellationConnections,
                    isGeneratingShare: $isGeneratingShare
                )
                .tag(3)
                
                // Stats Highlight is now 5th (Your Journey by numbers)
                StatsHighlightCard(photoLoader: photoLoader, accentTeal: accentTeal, warmCoral: warmCoral, deepPurple: deepPurple)
                    .tag(4)
                
                // Personal Insights is now 6th
                UniqueInsightsCard(photoLoader: photoLoader, accentTeal: accentTeal, warmCoral: warmCoral, deepPurple: deepPurple, softLavender: softLavender)
                    .tag(5)
                
                // Final CTA is now 7th (last)
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
        // Special handling for constellation card (index 3)
        if currentIndex == 3 {
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
            scale: 1.0,
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

// Around line 230, replace the WelcomeCard struct:

struct WelcomeCard: View {
    @ObservedObject var photoLoader: PhotoLoader
    let accentTeal: Color
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color(white: 0.95))
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 24) {
                    Text("\(photoLoader.photosYear > 0 ? String(photoLoader.photosYear) : "2025")")
                        .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 96), weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [accentTeal, colorScheme == .dark ? .white : .black],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: accentTeal.opacity(0.5), radius: 20)
                    
                    VStack(spacing: 8) {
                        Text("Your Year")
                            .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 32), weight: .light))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8))
                        
                        Text("in Review")
                            .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 32), weight: .light))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8))
                    }
                    
                    if photoLoader.photosYear > 0 && photoLoader.photosYear != Calendar.current.component(.year, from: Date()) {
                        Text("Using \(String(photoLoader.photosYear)) photos (no \(String(Calendar.current.component(.year, from: Date()))) photos found)")
                            .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 14), weight: .medium))
                            .foregroundColor(.yellow.opacity(0.9))
                            .padding(.horizontal, 40)
                            .multilineTextAlignment(.center)
                    }
                    
                    HStack(spacing: 40) {
                        StatPill(value: "\(photoLoader.locations.count)", label: "Places", color: accentTeal, colorScheme: colorScheme)
                        StatPill(value: String(format: "%.0f", photoLoader.totalDistance / 1609.34), label: "Miles", color: accentTeal, colorScheme: colorScheme)
                        StatPill(value: "\(photoLoader.totalPhotosWithLocation)", label: "Photos", color: accentTeal, colorScheme: colorScheme)
                    }
                    .padding(.top, 32)
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    Text("Swipe to explore")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6))
                    
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
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(spacing: 6) {
            Text(value)
                .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 28), weight: .bold))
                .foregroundColor(color)
            
            if #available(iOS 16.0, *) {
                Text(label)
                    .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 13), weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6))
                    .textCase(.uppercase)
                    .kerning(1)
            } else {
                Text(label)
                    .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 13), weight: .medium))
                    .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6))
                    .textCase(.uppercase)
            }
        }
    }
}

// MARK: - Card 2: Top 12 Photos (FIXED VERSION with All Photos Option)

struct Top12PhotosCard: View {
    @ObservedObject var photoLoader: PhotoLoader
    let warmCoral: Color
    let softLavender: Color
    @Binding var isGeneratingShare: Bool
    @Environment(\.colorScheme) var colorScheme
    
    @State private var selectedPhotos: [Int: UIImage] = [:]
    @State private var photosByMonth: [String: [(locationIndex: Int, photoIndex: Int)]] = [:]
    @State private var allPhotoRefs: [(locationIndex: Int, photoIndex: Int)] = []
    @State private var monthKeys: [String] = []
    @State private var isLoadingPhotos = true
    @State private var useAllPhotos = false  // Toggle for including non-GPS photos
    
    var body: some View {
        ZStack {
            if colorScheme == .dark {
                LinearGradient(
                    colors: [warmCoral.opacity(0.4), softLavender.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: [warmCoral.opacity(0.2), softLavender.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }
            
            if isLoadingPhotos {
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ? .white : .black))
                        .scaleEffect(1.5)
                    Text(useAllPhotos ? "Loading all photos..." : "Loading photos...")
                        .foregroundColor(colorScheme == .dark ? .white : .black)
                        .padding(.top)
                }
            } else {
                VStack(spacing: 40) {
                    Spacer()
                    
                    VStack(spacing: 10) {
                        Text("Your Year")
                            .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 50), weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        
                        Text("in 12 Moments")
                            .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 28), weight: .light))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8))
                        
                        if !isGeneratingShare {
                            Text("Tap Pictures to Shuffle")
                                .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 14), weight: .medium))
                                .foregroundColor(warmCoral)
                                .padding(.top, 4)
                            
                            // NEW: Always visible toggle button
                            HStack(spacing: 8) {
                                Button(action: {
                                    if useAllPhotos {
                                        // Switch to GPS photos only
                                        useAllPhotos = false
                                        loadPhotosGroupedByMonth()
                                    } else {
                                        // Switch to all photos
                                        useAllPhotos = true
                                        loadAllPhotosWithoutLocation()
                                    }
                                }) {
                                    HStack(spacing: 6) {
                                        Image(systemName: useAllPhotos ? "location.slash.fill" : "location.fill")
                                            .font(.system(size: 11))
                                        Text(useAllPhotos ? "All Photos" : "GPS Photos Only")
                                            .font(.system(size: 11, weight: .semibold))
                                        Image(systemName: "arrow.left.arrow.right")
                                            .font(.system(size: 9))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(useAllPhotos ? Color.purple : warmCoral)
                                    .cornerRadius(6)
                                }
                                .padding(.top, 6)
                                
                                if photoLoader.locations.isEmpty && !useAllPhotos {
                                    Text("(No GPS photos found)")
                                        .font(.system(size: 10))
                                        .foregroundColor(.yellow.opacity(0.8))
                                }
                            }
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
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                                    .frame(width: ResponsiveLayout.scale(110), height: ResponsiveLayout.scale(110))
                                    .overlay(
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: colorScheme == .dark ? .white : .black))
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
            // Auto-switch to all photos if no GPS photos available
            if photoLoader.locations.isEmpty {
                useAllPhotos = true
                loadAllPhotosWithoutLocation()
            } else {
                loadPhotosGroupedByMonth()
            }
        }
    }
    
    // Load ALL photos from library (even without GPS)
    private func loadAllPhotosWithoutLocation() {
        isLoadingPhotos = true
        selectedPhotos.removeAll() // Clear existing photos
        
        DispatchQueue.global(qos: .userInitiated).async {
            let fetchOptions = PHFetchOptions()
            let calendar = Calendar.current
            
            // Use the same year logic as PhotoLoader
            let currentYear = photoLoader.photosYear > 0 ? photoLoader.photosYear : calendar.component(.year, from: Date())
            
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
                DispatchQueue.main.async {
                    self.isLoadingPhotos = false
                }
                return
            }
            
            fetchOptions.predicate = NSPredicate(
                format: "creationDate >= %@ AND creationDate <= %@",
                startDate as CVarArg,
                endDate as CVarArg
            )
            fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
            
            let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            
            print("📸 Found \(assets.count) total photos from \(currentYear) (including non-GPS)")
            
            guard assets.count > 0 else {
                DispatchQueue.main.async {
                    self.isLoadingPhotos = false
                }
                return
            }
            
            // Group by month
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM"
            
            var assetsByMonth: [String: [PHAsset]] = [:]
            var allAssets: [PHAsset] = []
            
            assets.enumerateObjects { asset, _, _ in
                if let timestamp = asset.creationDate {
                    let monthKey = dateFormatter.string(from: timestamp)
                    if assetsByMonth[monthKey] == nil {
                        assetsByMonth[monthKey] = []
                    }
                    assetsByMonth[monthKey]?.append(asset)
                    allAssets.append(asset)
                }
            }
            
            let sortedMonthKeys = assetsByMonth.keys.sorted()
            
            // Load 12 photos
            let dispatchGroup = DispatchGroup()
            var loadedPhotos: [Int: UIImage] = [:]
            let lock = NSLock()
            let imageManager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            for slot in 0..<12 {
                dispatchGroup.enter()
                
                // Select asset
                let asset: PHAsset
                if slot < sortedMonthKeys.count {
                    let monthKey = sortedMonthKeys[slot]
                    asset = assetsByMonth[monthKey]?.randomElement() ?? allAssets.randomElement() ?? assets[0]
                } else {
                    asset = allAssets.randomElement() ?? assets[0]
                }
                
                // Load image
                imageManager.requestImage(
                    for: asset,
                    targetSize: CGSize(width: 800, height: 800),
                    contentMode: .aspectFill,
                    options: options
                ) { image, _ in
                    lock.lock()
                    if let image = image {
                        loadedPhotos[slot] = image
                    } else {
                        loadedPhotos[slot] = self.createPlaceholder()
                    }
                    lock.unlock()
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                self.selectedPhotos = loadedPhotos
                self.isLoadingPhotos = false
                
                print("✅ Loaded \(loadedPhotos.count)/12 photos from full library")
            }
        }
    }
    
    private func loadPhotosGroupedByMonth() {
        // Clear existing photos when switching modes
        selectedPhotos.removeAll()
        
        // If no GPS photos, show empty state
        guard !photoLoader.locations.isEmpty else {
            isLoadingPhotos = false
            return
        }
        
        isLoadingPhotos = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM"
            
            var grouped: [String: [(locationIndex: Int, photoIndex: Int)]] = [:]
            
            // Build a map of all photos by month
            for (locIndex, timestamp) in photoLoader.photoTimeStamps.enumerated() {
                let monthKey = dateFormatter.string(from: timestamp)
                if grouped[monthKey] == nil {
                    grouped[monthKey] = []
                }
                
                // Add ALL photos at this location
                let photoCount = photoLoader.allPhotosAtLocation[locIndex].count
                for photoIndex in 0..<photoCount {
                    grouped[monthKey]?.append((locIndex, photoIndex))
                }
            }
            
            let sortedMonthKeys = grouped.keys.sorted()
            
            // Build a flat list of all photo references
            var allPhotoRefs: [(locationIndex: Int, photoIndex: Int)] = []
            for (locIndex, photosAtLoc) in photoLoader.allPhotosAtLocation.enumerated() {
                for photoIndex in 0..<photosAtLoc.count {
                    allPhotoRefs.append((locIndex, photoIndex))
                }
            }
            
            // Load photos in parallel with proper error handling
            let dispatchGroup = DispatchGroup()
            var loadedPhotos: [Int: UIImage] = [:]
            let lock = NSLock()
            
            for slot in 0..<12 {
                dispatchGroup.enter()
                
                // Select photo reference
                let photoRef: (locationIndex: Int, photoIndex: Int)
                if slot < sortedMonthKeys.count {
                    let monthKey = sortedMonthKeys[slot]
                    photoRef = grouped[monthKey]?.randomElement() ?? allPhotoRefs.randomElement() ?? (0, 0)
                } else {
                    photoRef = allPhotoRefs.randomElement() ?? (0, 0)
                }
                
                // Load with proper fallback chain
                self.loadPhotoWithFallback(photoRef: photoRef) { image in
                    lock.lock()
                    if let image = image {
                        loadedPhotos[slot] = image
                    } else {
                        // Create placeholder as last resort
                        loadedPhotos[slot] = self.createPlaceholder()
                    }
                    lock.unlock()
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                self.photosByMonth = grouped
                self.monthKeys = sortedMonthKeys
                self.allPhotoRefs = allPhotoRefs
                self.selectedPhotos = loadedPhotos
                self.isLoadingPhotos = false
                
                let successCount = loadedPhotos.values.filter { $0.size.width > 100 }.count
                print("📸 Loaded \(successCount)/12 photos successfully")
            }
        }
    }
    
    // Robust photo loading with fallback chain
    private func loadPhotoWithFallback(
        photoRef: (locationIndex: Int, photoIndex: Int),
        completion: @escaping (UIImage?) -> Void
    ) {
        print("🔍 Attempting to load photo at location \(photoRef.locationIndex), photo \(photoRef.photoIndex)")
        
        // Try 1: Load from allPhotosAtLocation cache
        photoLoader.loadPhotosAtLocation(at: photoRef.locationIndex) { images in
            if let images = images, photoRef.photoIndex < images.count {
                let image = images[photoRef.photoIndex]
                // Check if it's not a placeholder
                if image.size.width > 100 {
                    print("✅ Loaded from allPhotosAtLocation cache")
                    completion(image)
                    return
                }
            }
            
            print("⚠️ Failed to load from allPhotosAtLocation, trying thumbnail...")
            
            // Try 2: Load thumbnail (first photo at location)
            if photoRef.locationIndex < photoLoader.thumbnails.count {
                photoLoader.loadThumbnail(at: photoRef.locationIndex) { thumbnail in
                    if let thumbnail = thumbnail, thumbnail.size.width > 100 {
                        print("✅ Loaded from thumbnail cache")
                        completion(thumbnail)
                        return
                    }
                    
                    print("⚠️ Failed to load thumbnail, trying in-memory...")
                    
                    // Try 3: Use in-memory thumbnail if already loaded
                    let memoryThumbnail = photoLoader.thumbnails[photoRef.locationIndex]
                    if memoryThumbnail.size.width > 100 {
                        print("✅ Loaded from memory")
                        completion(memoryThumbnail)
                        return
                    }
                    
                    print("❌ All attempts failed for location \(photoRef.locationIndex)")
                    // All attempts failed
                    completion(nil)
                }
            } else {
                print("❌ Location index out of bounds: \(photoRef.locationIndex) >= \(photoLoader.thumbnails.count)")
                completion(nil)
            }
        }
    }
    
    private func shufflePhoto(at slot: Int) {
        // If using all photos mode, reload from library
        if useAllPhotos {
            shuffleFromAllPhotos(at: slot)
            return
        }
        
        let photoRefsPool: [(locationIndex: Int, photoIndex: Int)]
        
        if slot < monthKeys.count {
            let key = monthKeys[slot]
            photoRefsPool = photosByMonth[key] ?? allPhotoRefs
        } else {
            photoRefsPool = allPhotoRefs
        }
        
        guard photoRefsPool.count > 1 else { return }
        
        // Pick a random photo reference
        let newPhotoRef = photoRefsPool.randomElement()!
        
        // Load with fallback chain
        loadPhotoWithFallback(photoRef: newPhotoRef) { image in
            if let image = image {
                withAnimation(.spring(response: 0.3)) {
                    self.selectedPhotos[slot] = image
                }
            }
        }
    }
    
    // Shuffle from all photos in library
    private func shuffleFromAllPhotos(at slot: Int) {
        DispatchQueue.global(qos: .userInitiated).async {
            let fetchOptions = PHFetchOptions()
            let calendar = Calendar.current
            let currentYear = photoLoader.photosYear > 0 ? photoLoader.photosYear : calendar.component(.year, from: Date())
            
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
            
            let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
            guard assets.count > 0 else { return }
            
            let randomIndex = Int.random(in: 0..<assets.count)
            let asset = assets[randomIndex]
            
            let imageManager = PHImageManager.default()
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            
            imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 800, height: 800),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                if let image = image {
                    DispatchQueue.main.async {
                        withAnimation(.spring(response: 0.3)) {
                            self.selectedPhotos[slot] = image
                        }
                    }
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
    @Environment(\.colorScheme) var colorScheme  // ADD THIS
    
    var body: some View {
        ZStack {
            // UPDATED: Adaptive background
            (colorScheme == .dark ? Color.black : Color(white: 0.95))
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        Text("Your Journey")
                            .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 42), weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        
                        Text("by the numbers")
                            .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 20), weight: .light))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7))
                    }
                    
                    VStack(spacing: 24) {
                        BigStatRow(icon: "figure.walk", label: "Total Distance", value: String(format: "%.1f miles", photoLoader.totalDistance / 1609.34), color: accentTeal, colorScheme: colorScheme)
                        BigStatRow(icon: "mappin.circle.fill", label: "Places Visited", value: "\(photoLoader.locations.count)", color: warmCoral, colorScheme: colorScheme)
                        BigStatRow(icon: "camera.fill", label: "Photos Captured", value: "\(photoLoader.totalPhotosWithLocation)", color: deepPurple, colorScheme: colorScheme)
                        
                        if let mostActive = getMostActiveMonth() {
                            BigStatRow(icon: "calendar", label: "Most Active Month", value: mostActive, color: Color(red: 1.0, green: 0.6, blue: 0.3), colorScheme: colorScheme)
                        }
                    }
                    .padding(.horizontal, 32)
                }
                
                Spacer()
            }
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
    let colorScheme: ColorScheme
    
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
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6))
                        .textCase(.uppercase)
                        .kerning(0.5)
                } else {
                    Text(label)
                        .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 14), weight: .medium))
                        .foregroundColor(colorScheme == .dark ? .white.opacity(0.7) : .black.opacity(0.6))
                        .textCase(.uppercase)
                }
                
                Text(value)
                    .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 26), weight: .bold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
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
    @Environment(\.colorScheme) var colorScheme  // ADD THIS
    
    var body: some View {
        GeometryReader { geometry in
            let isSmallDevice = geometry.size.height < 750
            let isMediumDevice = geometry.size.height < 900
            
            ZStack {
                // UPDATED: Adaptive background
                (colorScheme == .dark ? Color.black : Color(white: 0.95))
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack(spacing: isSmallDevice ? 12 : isMediumDevice ? 16 : 20) {
                        VStack(spacing: 8) {
                            Text("Personal")
                                .font(.system(size: isSmallDevice ? 32 : isMediumDevice ? 36 : 38, weight: .bold))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                            
                            Text("Insights")
                                .font(.system(size: isSmallDevice ? 32 : isMediumDevice ? 36 : 38, weight: .bold))
                                .foregroundColor(colorScheme == .dark ? .white.opacity(0.6) : .black.opacity(0.5))
                        }
                        
                        VStack(spacing: isSmallDevice ? 8 : isMediumDevice ? 10 : 12) {
                            if let homeBase = findHomeBase() {
                                InsightCard(
                                    emoji: "🏠",
                                    title: "Your Home Base",
                                    description: getHomeBaseDescription(homeBase),
                                    gradient: [accentTeal, accentTeal.opacity(0.6)],
                                    isSmallDevice: isSmallDevice,
                                    isMediumDevice: isMediumDevice,
                                    colorScheme: colorScheme
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
                                    isMediumDevice: isMediumDevice,
                                    colorScheme: colorScheme
                                )
                            }
                            
                            if let explorationStyle = getExplorationStyle() {
                                InsightCard(
                                    emoji: explorationStyle.emoji,
                                    title: explorationStyle.title,
                                    description: explorationStyle.description,
                                    gradient: [accentTeal.opacity(0.8), Color(red: 0.3, green: 0.9, blue: 0.6)],
                                    isSmallDevice: isSmallDevice,
                                    isMediumDevice: isMediumDevice,
                                    colorScheme: colorScheme
                                )
                            }
                            
                            if let achievement = getDistanceAchievement() {
                                InsightCard(
                                    emoji: "🌎",
                                    title: achievement.title,
                                    description: achievement.description,
                                    gradient: [warmCoral, Color(red: 1.0, green: 0.5, blue: 0.3)],
                                    isSmallDevice: isSmallDevice,
                                    isMediumDevice: isMediumDevice,
                                    colorScheme: colorScheme
                                )
                            }
                        }
                        .padding(.horizontal, isSmallDevice ? 20 : 24)
                    }
                    
                    Spacer()
                }
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
    let colorScheme: ColorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: isSmallDevice ? 8 : isMediumDevice ? 10 : 12) {
            Text(emoji)
                .font(.system(size: isSmallDevice ? 32 : isMediumDevice ? 36 : 40))
            
            Text(title)
                .font(.system(size: isSmallDevice ? 17 : isMediumDevice ? 18 : 20, weight: .bold))
                .foregroundColor(colorScheme == .dark ? .white : .black)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            
            Text(description)
                .font(.system(size: isSmallDevice ? 13 : isMediumDevice ? 13.5 : 14, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7))
                .lineSpacing(isSmallDevice ? 2 : 3)
                .minimumScaleFactor(0.9)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(isSmallDevice ? 14 : isMediumDevice ? 16 : 18)
        .background(
            LinearGradient(
                colors: gradient.map { $0.opacity(colorScheme == .dark ? 0.3 : 0.2) },
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

// MARK: - Card 5: Constellation (Static Display)

struct ConstellationCard: View {
    @ObservedObject var photoLoader: PhotoLoader
    let accentTeal: Color
    let deepPurple: Color
    @Binding var scale: CGFloat
    @Binding var rotation: Angle
    @Binding var backgroundStars: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)]
    @Binding var stars: [ConstellationStar]
    @Binding var connections: [ConstellationConnection]
    @Binding var isGeneratingShare: Bool
    @Environment(\.colorScheme) var colorScheme
    
    @State private var revealProgress: Double = 0.0
    @State private var hasAppeared = false
    @State private var hasBuiltConstellation = false
    @State private var showReplayButton = false
    
    var body: some View {
        ZStack {
            // Constellation always has black background
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
                    Text("Your \(photoLoader.photosYear > 0 ? String(photoLoader.photosYear) : String(Calendar.current.component(.year, from: Date())))")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Constellation")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(accentTeal.opacity(0.9))
                }
                
                Spacer()
                
                if !photoLoader.locations.isEmpty {
                    GeometryReader { geometry in
                        let containerWidth = geometry.size.width
                        let containerHeight = ResponsiveLayout.scaleHeight(450)
                        
                        ZStack {
                            if hasBuiltConstellation {
                                let visibleStarCount = Int(Double(stars.count) * revealProgress)
                                let visibleStars = Array(stars.prefix(visibleStarCount))
                                
                                let visibleConnections = connections.filter { connection in
                                    visibleStars.contains(where: { $0.id == connection.from.id }) &&
                                    visibleStars.contains(where: { $0.id == connection.to.id })
                                }
                                
                                // Scale to fit container
                                let scaledStars = scaleStarsToContainer(
                                    stars: visibleStars,
                                    containerSize: CGSize(width: containerWidth, height: containerHeight)
                                )
                                let scaledConnections = scaleConnectionsToContainer(
                                    connections: visibleConnections,
                                    originalStars: visibleStars,
                                    scaledStars: scaledStars
                                )
                                
                                // Draw connections
                                ForEach(scaledConnections.indices, id: \.self) { index in
                                    let connection = scaledConnections[index]
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
                                ForEach(scaledStars) { star in
                                    ConstellationStarView(star: star, accentTeal: accentTeal, deepPurple: deepPurple)
                                }
                            }
                        }
                        .frame(width: containerWidth, height: containerHeight)
                    }
                    .frame(height: ResponsiveLayout.scaleHeight(450))
                    .padding(.horizontal, 30)
                }
                
                Spacer()
                
                Text("\(stars.count) stars | Your unique pattern")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 10)
                
                if !isGeneratingShare {
                    Text("Tap 'Constellation' in menu to explore interactively")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.bottom, 80)
                }
            }
            
        }
        .onAppear {
            if !hasAppeared {
                generateBackgroundStars()
                hasBuiltConstellation = true
                hasAppeared = true
                
                resetConstellation()
            }
        }
        .onDisappear {
            revealProgress = 0.0
            hasAppeared = false
            hasBuiltConstellation = false
        }
    }
    
    // Reset function (just replays animation)
    private func resetConstellation() {
        revealProgress = 0.0
        
        // Restart animation
        withAnimation(.easeInOut(duration: 2.5)) {
            revealProgress = 1.0
        }
        
        
        print("🔄 Reset constellation - stars: \(stars.count), built: \(hasBuiltConstellation)")
    }
    
    private func generateBackgroundStars() {
        guard backgroundStars.isEmpty else { return }
        
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        var newStars: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = []
        
        for _ in 0..<150 {
            newStars.append((
                x: CGFloat.random(in: 0...screenWidth),
                y: CGFloat.random(in: 0...screenHeight),
                size: CGFloat.random(in: 1...3),
                opacity: Double.random(in: 0.3...0.9)
            ))
        }
        
        backgroundStars = newStars
    }
    
    private func scaleStarsToContainer(stars: [ConstellationStar], containerSize: CGSize) -> [ConstellationStar] {
        guard !stars.isEmpty else { return [] }
        
        // Handle single star - return centered
        if stars.count == 1 {
            return [ConstellationStar(
                coordinate: stars[0].coordinate,
                intensity: stars[0].intensity,
                screenPosition: CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
            )]
        }
        
        var minX = stars[0].screenPosition.x
        var maxX = stars[0].screenPosition.x
        var minY = stars[0].screenPosition.y
        var maxY = stars[0].screenPosition.y
        
        for star in stars {
            minX = min(minX, star.screenPosition.x)
            maxX = max(maxX, star.screenPosition.x)
            minY = min(minY, star.screenPosition.y)
            maxY = max(maxY, star.screenPosition.y)
        }
        
        let originalWidth = maxX - minX
        let originalHeight = maxY - minY
        
        // Prevent division by zero
        guard originalWidth > 0 && originalHeight > 0 else {
            return stars.map { star in
                ConstellationStar(
                    coordinate: star.coordinate,
                    intensity: star.intensity,
                    screenPosition: CGPoint(x: containerSize.width / 2, y: containerSize.height / 2)
                )
            }
        }
        
        let padding: CGFloat = 40
        let availableWidth = containerSize.width - (padding * 2)
        let availableHeight = containerSize.height - (padding * 2)
        
        let scaleX = availableWidth / originalWidth
        let scaleY = availableHeight / originalHeight
        let scaleFactor = min(scaleX, scaleY)
        
        let scaledWidth = originalWidth * scaleFactor
        let scaledHeight = originalHeight * scaleFactor
        let offsetX = (containerSize.width - scaledWidth) / 2
        let offsetY = (containerSize.height - scaledHeight) / 2
        
        return stars.map { star in
            let scaledX = (star.screenPosition.x - minX) * scaleFactor + offsetX
            let scaledY = (star.screenPosition.y - minY) * scaleFactor + offsetY
            
            return ConstellationStar(
                coordinate: star.coordinate,
                intensity: star.intensity,
                screenPosition: CGPoint(x: scaledX, y: scaledY)
            )
        }
    }
    
    private func scaleConnectionsToContainer(
        connections: [ConstellationConnection],
        originalStars: [ConstellationStar],
        scaledStars: [ConstellationStar]
    ) -> [ConstellationConnection] {
        return connections.compactMap { connection in
            guard let fromIndex = originalStars.firstIndex(where: { $0.id == connection.from.id }),
                  let toIndex = originalStars.firstIndex(where: { $0.id == connection.to.id }),
                  fromIndex < scaledStars.count,
                  toIndex < scaledStars.count else {
                return nil
            }
            
            return ConstellationConnection(
                from: scaledStars[fromIndex],
                to: scaledStars[toIndex]
            )
        }
    }
}

// Constellation View

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

// Replace the MapPreviewCard struct in YearStoryCarousel.swift with this updated version

struct MapPreviewCard: View {
    @ObservedObject var photoLoader: PhotoLoader
    let accentTeal: Color
    let onNavigate: () -> Void
    @Binding var isGeneratingShare: Bool
    @Environment(\.colorScheme) var colorScheme
    @State private var mapSnapshot: UIImage?
    
    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color(white: 0.95))
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        Text("Your Path")
                            .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 42), weight: .bold))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        
                        Text("across \(photoLoader.photosYear > 0 ? String(photoLoader.photosYear) : String(Calendar.current.component(.year, from: Date())))")
                            .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 20), weight: .light))
                            .foregroundColor(colorScheme == .dark ? .white.opacity(0.8) : .black.opacity(0.7))
                    }
                    
                    if let snapshot = mapSnapshot {
                        Button(action: onNavigate) {
                            Image(uiImage: snapshot)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: ResponsiveLayout.scaleHeight(400))
                                .frame(maxWidth: .infinity)
                                .clipped()
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
                            .fill(colorScheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.05))
                            .frame(height: ResponsiveLayout.scaleHeight(400))
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: accentTeal))
                                    .scaleEffect(1.5)
                            )
                            .padding(.horizontal, 24)
                    }
                    
                    if !isGeneratingShare {
                        Text("Tap map to explore")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(accentTeal.opacity(0.9))
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
        .onAppear {
            generateMapSnapshot()
        }
    }
    
    // MARK: - Region Detection (copied from ShareSection)
    
    private struct MapRegion {
        let locations: [CLLocationCoordinate2D]
        let name: String
        let center: CLLocationCoordinate2D
        let span: MKCoordinateSpan
    }
    
    // MARK: - Draw Connector Lines for Carousel

    private func drawRegionConnectorsForCarousel(
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
        
        func coordinateToMainMapPoint(_ coord: CLLocationCoordinate2D) -> CGPoint {
            let snapshotPoint = mainSnapshot.point(for: coord)
            let scaleX = mapSize / snapshotSize.width
            let scaleY = mapSize / snapshotSize.height
            
            return CGPoint(
                x: snapshotPoint.x * scaleX,
                y: snapshotPoint.y * scaleY
            )
        }
        
        // Same logic as ShareSection - track region transitions
        for i in 1..<locations.count {
            let prevLocation = locations[i - 1]
            let currentLocation = locations[i]
            
            let prevInMain = isCoordinate(prevLocation, inRegion: mainRegion)
            let currInMain = isCoordinate(currentLocation, inRegion: mainRegion)
            
            if prevInMain && !currInMain {
                for (insetIndex, insetData) in insetSnapshots.enumerated() {
                    if isCoordinate(currentLocation, inRegion: insetData.region) {
                        guard insetIndex < insetPositions.count else { break }
                        
                        let mainPoint = coordinateToMainMapPoint(prevLocation)
                        let destinationOnMainMap = coordinateToMainMapPoint(currentLocation)
                        
                        drawConnectorLineForCarousel(
                            context: context,
                            from: mainPoint,
                            to: destinationOnMainMap,
                            color: userColor,
                            clipRect: CGRect(x: 0, y: 0, width: mapSize, height: mapSize)
                        )
                        
                        let insetPosition = insetPositions[insetIndex]
                        let insetRect = CGRect(x: insetPosition.x, y: insetPosition.y, width: insetSize, height: insetSize)
                        let insetSnapshot = insetData.snapshot
                        let insetSnapPoint = insetSnapshot.point(for: currentLocation)
                        let insetPoint = CGPoint(
                            x: insetRect.minX + (insetSnapPoint.x / insetSnapshot.image.size.width) * insetSize,
                            y: insetRect.minY + (insetSnapPoint.y / insetSnapshot.image.size.height) * insetSize
                        )
                        
                        drawConnectorLineForCarousel(
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
                        
                        drawConnectorLineForCarousel(
                            context: context,
                            from: insetPoint,
                            to: departureOnMainMap,
                            color: userColor,
                            style: .fromInset,
                            clipRect: insetRect
                        )
                        
                        drawConnectorLineForCarousel(
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
                    
                    drawConnectorLineForCarousel(
                        context: context,
                        from: prevPoint,
                        to: prevOnMainMap,
                        color: userColor,
                        style: .fromInset,
                        clipRect: prevInsetRect
                    )
                    
                    drawConnectorLineForCarousel(
                        context: context,
                        from: prevOnMainMap,
                        to: currOnMainMap,
                        color: userColor,
                        clipRect: CGRect(x: 0, y: 0, width: mapSize, height: mapSize)
                    )
                    
                    drawConnectorLineForCarousel(
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

    private enum ConnectorStyle {
        case normal
        case toInset
        case fromInset
    }
    
    private func drawConnectorLineForCarousel(
        context: CGContext,
        from: CGPoint,
        to: CGPoint,
        color: UIColor,
        style: ConnectorStyle = .normal,
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
    
    private func detectRegions(from allLocations: [CLLocationCoordinate2D]) -> [MapRegion] {
        guard !allLocations.isEmpty else { return [] }
        
        var clusters: [[CLLocationCoordinate2D]] = []
        
        for location in allLocations {
            var addedToCluster = false
            
            for i in 0..<clusters.count {
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
        
        clusters.sort { $0.count > $1.count }
        
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
    
    // MARK: - Check if coordinate is in region
    
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
    
    // MARK: - Generate Map Snapshot
    
    private func generateMapSnapshot() {
        guard !photoLoader.locations.isEmpty else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let allLocations = photoLoader.locations
            let regions = self.detectRegions(from: allLocations)
            
            let snapshotSize = ResponsiveLayout.scale(800)
            
            if regions.count == 1 {
                // Single region - simple map
                self.generateSingleRegionSnapshot(region: regions[0], size: snapshotSize)
            } else {
                // Multiple regions - composite map with insets
                self.generateMultiRegionSnapshot(regions: regions, size: snapshotSize)
            }
        }
    }
    
    private func generateSingleRegionSnapshot(region: MapRegion, size: CGFloat) {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: region.center, span: region.span)
        options.size = CGSize(width: size, height: size)
        options.scale = 2.0
        
        let snapshotter = MKMapSnapshotter(options: options)
        
        snapshotter.start { snapshot, error in
            guard let snapshot = snapshot else { return }
            
            let userColorHex = UserDefaults.standard.string(forKey: "userColor") ?? "#33CCBB"
            let lineColor = UIColor(hex: userColorHex) ?? UIColor(red: 0.2, green: 0.8, blue: 0.7, alpha: 1.0)
            
            let image = UIGraphicsImageRenderer(size: options.size).image { context in
                snapshot.image.draw(at: .zero)
                
                let ctx = context.cgContext
                
                // Draw path
                ctx.setStrokeColor(lineColor.cgColor)
                ctx.setLineWidth(ResponsiveLayout.scale(5))
                ctx.setLineCap(.round)
                ctx.setLineJoin(.round)
                
                for (index, location) in self.photoLoader.locations.enumerated() {
                    let point = snapshot.point(for: location)
                    
                    if index == 0 {
                        ctx.move(to: point)
                    } else {
                        ctx.addLine(to: point)
                    }
                }
                
                ctx.strokePath()
                
                // Draw dots
                for location in self.photoLoader.locations {
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
    
    private func generateMultiRegionSnapshot(regions: [MapRegion], size: CGFloat) {
        guard !regions.isEmpty else { return }
        
        let mainRegion = regions[0]
        let insetRegions = Array(regions.dropFirst())
        
        // Generate main map
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: mainRegion.center, span: mainRegion.span)
        options.size = CGSize(width: size, height: size)
        options.scale = 2.0
        
        let snapshotter = MKMapSnapshotter(options: options)
        let semaphore = DispatchSemaphore(value: 0)
        var mainSnapshot: MKMapSnapshotter.Snapshot?
        
        snapshotter.start { snapshot, error in
            defer { semaphore.signal() }
            mainSnapshot = snapshot
        }
        semaphore.wait()
        
        guard let mainSnap = mainSnapshot else { return }
        
        // Generate inset maps
        var insetSnapshots: [(region: MapRegion, snapshot: MKMapSnapshotter.Snapshot)] = []
        
        for insetRegion in insetRegions {
            let insetOptions = MKMapSnapshotter.Options()
            insetOptions.region = MKCoordinateRegion(center: insetRegion.center, span: insetRegion.span)
            
            let insetSize = size * 0.25
            insetOptions.size = CGSize(width: insetSize, height: insetSize)
            insetOptions.scale = 2.0
            
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
        
        // Create composite image
        let compositeImage = self.createCompositeMapImage(
            mainSnapshot: mainSnap,
            mainRegion: mainRegion,
            insetSnapshots: insetSnapshots,
            size: size
        )
        
        DispatchQueue.main.async {
            self.mapSnapshot = compositeImage
        }
    }
    
    private func createCompositeMapImage(
        mainSnapshot: MKMapSnapshotter.Snapshot,
        mainRegion: MapRegion,
        insetSnapshots: [(region: MapRegion, snapshot: MKMapSnapshotter.Snapshot)],
        size: CGFloat
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 2.0
        
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)
        
        return renderer.image { context in
            let ctx = context.cgContext
            
            // Draw main map
            mainSnapshot.image.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
            
            // Draw path on main map
            self.drawPathOnMainRegion(
                context: ctx,
                mainSnapshot: mainSnapshot,
                mainRegion: mainRegion,
                size: size
            )
            
            // Draw insets
            let insetSize = size * 0.25
            let padding: CGFloat = 15
            
            let bestPositions = self.findBestInsetPositions(
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
                
                // Shadow
                ctx.setShadow(offset: CGSize(width: 0, height: 2), blur: 5, color: UIColor.black.withAlphaComponent(0.3).cgColor)
                ctx.setFillColor(UIColor.white.cgColor)
                ctx.fill(insetRect)
                ctx.setShadow(offset: .zero, blur: 0, color: nil)
                
                // Draw inset map
                inset.snapshot.image.draw(in: insetRect)
                
                // Draw path in inset
                self.drawPathsInInset(
                    context: ctx,
                    insetRect: insetRect,
                    insetRegion: inset.region,
                    insetSnapshot: inset.snapshot
                )
                
                // Draw path in inset (existing code)
                self.drawPathsInInset(
                    context: ctx,
                    insetRect: insetRect,
                    insetRegion: inset.region,
                    insetSnapshot: inset.snapshot
                )

                // 🆕 ADD THIS SECTION - Draw connector lines
                let userColorHex = UserDefaults.standard.string(forKey: "userColor") ?? "#33CCBB"
                let lineColor = UIColor(hex: userColorHex) ?? UIColor.systemBlue
                self.drawRegionConnectorsForCarousel(
                    context: ctx,
                    locations: self.photoLoader.locations,
                    mainRegion: mainRegion,
                    insetSnapshots: insetSnapshots,
                    insetPositions: bestPositions,
                    mainSnapshot: mainSnapshot,
                    mapSize: size,
                    insetSize: insetSize,
                    userColor: lineColor
                )
                
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
                let labelRect = CGRect(x: xPos + 5, y: yPos + 5, width: labelSize.width, height: labelSize.height)
                labelText.draw(in: labelRect, withAttributes: labelAttrs)
            }
        }
    }
    
    private func drawPathOnMainRegion(
        context: CGContext,
        mainSnapshot: MKMapSnapshotter.Snapshot,
        mainRegion: MapRegion,
        size: CGFloat
    ) {
        let snapshotSize = mainSnapshot.image.size
        let userColorHex = UserDefaults.standard.string(forKey: "userColor") ?? "#33CCBB"
        let lineColor = UIColor(hex: userColorHex) ?? UIColor(red: 0.2, green: 0.8, blue: 0.7, alpha: 1.0)
        
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
            
            return CGPoint(x: snapshotPoint.x * scaleX, y: snapshotPoint.y * scaleY)
        }
        
        // Draw path
        context.saveGState()
        context.setStrokeColor(lineColor.cgColor)
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
        
        // Draw dots
        context.saveGState()
        let dotSize: CGFloat = 12.0
        let dotRadius = dotSize / 2
        
        for location in photoLoader.locations {
            if let point = coordinateToPoint(location) {
                context.setFillColor(lineColor.cgColor)
                context.fillEllipse(in: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotSize, height: dotSize))
                context.setStrokeColor(UIColor.white.cgColor)
                context.setLineWidth(2)
                context.strokeEllipse(in: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotSize, height: dotSize))
            }
        }
        context.restoreGState()
    }
    
    private func drawPathsInInset(
        context: CGContext,
        insetRect: CGRect,
        insetRegion: MapRegion,
        insetSnapshot: MKMapSnapshotter.Snapshot
    ) {
        let snapshotSize = insetSnapshot.image.size
        let userColorHex = UserDefaults.standard.string(forKey: "userColor") ?? "#33CCBB"
        let lineColor = UIColor(hex: userColorHex) ?? UIColor(red: 0.2, green: 0.8, blue: 0.7, alpha: 1.0)
        
        let userLocationsInRegion = photoLoader.locations.filter { location in
            isCoordinate(location, inRegion: insetRegion)
        }
        
        guard !userLocationsInRegion.isEmpty else { return }
        
        // Draw path
        context.saveGState()
        context.setStrokeColor(lineColor.cgColor)
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
        
        // Draw dots
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
            
            context.setFillColor(lineColor.cgColor)
            context.fillEllipse(in: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotSize, height: dotSize))
            context.setStrokeColor(UIColor.white.cgColor)
            context.setLineWidth(1.5)
            context.strokeEllipse(in: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotSize, height: dotSize))
        }
        context.restoreGState()
    }
    
    private func findBestInsetPositions(
        mainRegion: MapRegion,
        insetCount: Int,
        mainSnapshot: MKMapSnapshotter.Snapshot,
        size: CGFloat,
        insetSize: CGFloat,
        padding: CGFloat
    ) -> [(x: CGFloat, y: CGFloat)] {
        let allPositions: [(x: CGFloat, y: CGFloat, corner: String)] = [
            (padding, padding, "top-left"),
            (size - insetSize - padding, padding, "top-right"),
            (padding, size - insetSize - padding, "bottom-left"),
            (size - insetSize - padding, size - insetSize - padding, "bottom-right")
        ]
        
        var scoredPositions: [(position: (x: CGFloat, y: CGFloat), score: Int)] = []
        
        for position in allPositions {
            let cornerRect = CGRect(x: position.x, y: position.y, width: insetSize, height: insetSize)
            
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
            
            scoredPositions.append((position: (position.x, position.y), score: pointsInArea))
        }
        
        scoredPositions.sort { $0.score < $1.score }
        
        return scoredPositions.prefix(insetCount).map { $0.position }
    }
}
// MARK: - Card 7: Final CTA

struct FinalCTACard: View {
    let accentTeal: Color
    let onNavigate: (String?) -> Void
    @Environment(\.colorScheme) var colorScheme  // ADD THIS
    @State private var pulseAnimation = false
    
    var body: some View {
        ZStack {
            // UPDATED: Adaptive background
            (colorScheme == .dark ? Color.black : Color(white: 0.95))
                .ignoresSafeArea()
            
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
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                        
                        Text("Explore?")
                            .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 38), weight: .bold))
                            .foregroundColor(accentTeal)
                    }
                    
                    VStack(spacing: 16) {
                        Button(action: {
                            onNavigate("Map")
                        }) {
                            FeaturePillButton(icon: "map.fill", text: "Interactive Map", color: accentTeal, colorScheme: colorScheme)
                        }
                        
                        Button(action: {
                            onNavigate("Share")
                        }) {
                            FeaturePillButton(icon: "video.fill", text: "Create Collage Video", color: accentTeal, colorScheme: colorScheme)
                        }
                        
                        Button(action: {
                            onNavigate("Friends")
                        }) {
                            FeaturePillButton(icon: "person.2.fill", text: "Share with Friends", color: accentTeal, colorScheme: colorScheme)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: {
                    onNavigate(nil)
                }) {
                    Text("Explore Everything")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(colorScheme == .dark ? .black : .white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(accentTeal)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
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
    let colorScheme: ColorScheme
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 18)))
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(text)
                .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 16), weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white : .black)
            
            Spacer()
            
            Image(systemName: "arrow.right")
                .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 14)))
                .foregroundColor(color.opacity(0.7))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.08))
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
