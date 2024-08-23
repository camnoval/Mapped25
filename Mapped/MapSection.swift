import Foundation
import SwiftUI
import MapKit
import CoreLocation

// Extension for CLLocationCoordinate2D to make it hashable
extension CLLocationCoordinate2D: @retroactive Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(latitude)
        hasher.combine(longitude)
    }

    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        return lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}

// Custom annotation class to hold photo index
class LocationPhotoAnnotation: MKPointAnnotation {
    var locationIndex: Int = 0
}

struct MapSection: View {
    @ObservedObject var photoLoader: PhotoLoader
    @AppStorage("userEmoji") private var userEmoji = "🚶"
    @AppStorage("userColor") private var userColor = "#33CCBB"
    
    @AppStorage("defaultShowPhotoMarkers") private var defaultShowPhotoMarkers = true
    @AppStorage("defaultShowPolylines") private var defaultShowPolylines = true
    @AppStorage("defaultShowFriendOverlay") private var defaultShowFriendOverlay = true
        
    @State private var mapRegion: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 10, longitudeDelta: 10)
    )
    //View polyline
    @State private var showPolylines = true
    
    // Animation state
    @State private var isAnimating = false
    @State private var animationIndex = 0
    @State private var animationTimer: Timer?
    @State private var animationSpeed: Double = 0.125
    @State private var currentDate: Date?
    
    // Timeline slider state
    @State private var sliderValue: Double = 0
    @State private var isDraggingSlider = false
    
    // Photo viewer state
    @State private var selectedPhotoIndex: Int?
    @State private var showPhotoViewer = false
    
    // Display mode
    @State private var showPhotoBubbles = true
    
    
    // Coordinator reference
    @State private var mapCoordinator: MapView.Coordinator?
    
    // Friend Leaderboard
    @State private var leaderboardEntries: [LeaderboardEntry] = []
    @State private var showExpandedLeaderboard = false

    var body: some View {
        ZStack {
            mapViewLayer
            controlsOverlay
        }
        .onAppear(perform: handleOnAppear)
        .onDisappear(perform: handleOnDisappear)
        .onChange(of: photoLoader.locations) { _ in
            setupInitialRegion()
        }
        .onChange(of: selectedPhotoIndex) { newValue in
            handlePhotoIndexChange(newValue)
        }
        .onChange(of: animationIndex) { _ in
            updateLeaderboard()
        }
        .onChange(of: photoLoader.friendAnimationIndices) { _ in
            updateLeaderboard()
        }
        .onChange(of: photoLoader.friends) { _ in
            updateLeaderboard()
        }
        .sheet(isPresented: $showExpandedLeaderboard) {
            expandedLeaderboardSheet
        }
        .sheet(isPresented: $showPhotoViewer, onDismiss: dismissPhotoViewer) {
            photoViewerSheet
        }
    }

    // MARK: - View Components

    private var mapViewLayer: some View {
        MapView(
            region: $mapRegion,
            locations: photoLoader.locations,
            animationIndex: $animationIndex,
            isAnimating: $isAnimating,
            photoLoader: photoLoader,
            selectedPhotoIndex: $selectedPhotoIndex,
            showPhotoBubbles: $showPhotoBubbles,
            showPolylines: $showPolylines,
            userEmoji: userEmoji,
            userColor: userColor,
            coordinatorCallback: { coordinator in
                mapCoordinator = coordinator
            }
        )
        .edgesIgnoringSafeArea(.all)
    }

    // MARK: - Complete View Components Section

    private var controlsOverlay: some View {
        ZStack {
            // Left side - Leaderboard (at same level as photo button - top right)
            VStack(spacing: 0) {
                HStack(alignment: .top) {
                    if !leaderboardEntries.isEmpty && photoLoader.showFriendOverlay {
                        CompactLeaderboardView(entries: leaderboardEntries)
                            .onTapGesture {
                                showExpandedLeaderboard = true
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.15))
                            )
                            .padding(.leading, 15)
                            .padding(.top, 15)
                    }
                    Spacer()
                }
                Spacer()
            }
            
            // Right side - Control buttons (top right)
            VStack {
                HStack {
                    Spacer()
                    rightButtonStack
                }
                Spacer()
            }
            
            // Bottom - Timeline (unchanged)
            VStack {
                Spacer()
                timelineSection
            }
        }
    }

    private var rightButtonStack: some View {
        VStack(spacing: 12) {
            photoMarkersButton
            toggleLinesButton
            friendOverlayButton
        }
        .padding(.trailing)
        .padding(.top, 15)
    }

    private var photoMarkersButton: some View {
        Button(action: {
            photoLoader.showLocationMarkers.toggle()
        }) {
            Image(systemName: photoLoader.showLocationMarkers ? "photo.fill" : "photo")
                .font(.title2)
                .foregroundColor(photoLoader.showLocationMarkers ? .white : .blue)
                .padding()
                .background(photoLoader.showLocationMarkers ? Color.blue : Color.white)
                .clipShape(Circle())
                .shadow(radius: 3)
        }
    }

    private var toggleLinesButton: some View {
        Button(action: {
            showPolylines.toggle()
        }) {
            Image(systemName: showPolylines ? "line.3.horizontal" : "line.3.horizontal")
                .font(.title)
                .foregroundColor(showPolylines ? .white : .blue)
                .padding()
                .background(showPolylines ? Color.blue : Color.white)
                .clipShape(Circle())
                .shadow(radius: 3)
        }
    }

    @ViewBuilder
    private var friendOverlayButton: some View {
        if !photoLoader.friends.isEmpty {
            Button(action: handleFriendOverlayToggle) {
                Image(systemName: photoLoader.showFriendOverlay ? "person.2.fill" : "person.2")
                    .font(.title2)
                    .foregroundColor(photoLoader.showFriendOverlay ? .white : .orange)
                    .padding()
                    .background(photoLoader.showFriendOverlay ? Color.orange : Color.white)
                    .clipShape(Circle())
                    .shadow(radius: 3)
            }
        }
    }

    @ViewBuilder
    private var timelineSection: some View {
        if !photoLoader.locations.isEmpty {
            TimelineScrubber(
                photoLoader: photoLoader,
                sliderValue: $sliderValue,
                animationIndex: $animationIndex,
                isAnimating: $isAnimating,
                isDraggingSlider: $isDraggingSlider,
                currentDate: $currentDate,
                animationSpeed: $animationSpeed,
                toggleAnimation: toggleAnimation,
                resetAnimation: resetAnimation,
                pauseAnimation: pauseAnimation
            )
        }
    }

    
    private var expandedLeaderboardSheet: some View {
        ExpandedLeaderboardView(entries: leaderboardEntries)
    }

    @ViewBuilder
    private var photoViewerSheet: some View {
        if let index = selectedPhotoIndex {
            if index < photoLoader.allPhotosAtLocation.count {
                PhotoViewerLoadingWrapper(
                    photoLoader: photoLoader,
                    locationIndex: index,
                    totalLocations: photoLoader.locations.count,
                    locationDate: photoLoader.photoTimeStamps[index]
                )
            } else {
                Text("Index out of bounds")
                    .foregroundColor(.white)
                    .padding()
            }
        } else {
            Text("No photo selected")
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Photo Viewer Loading Wrapper

    struct PhotoViewerLoadingWrapper: View {
        @ObservedObject var photoLoader: PhotoLoader
        let locationIndex: Int
        let totalLocations: Int
        let locationDate: Date
        
        @State private var loadedImages: [UIImage] = []
        @State private var isLoading = true
        
        var body: some View {
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(2)
                        Text("Loading photos...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                } else if !loadedImages.isEmpty {
                    FullScreenPhotoViewer(
                        images: loadedImages,
                        locationIndex: locationIndex,
                        totalLocations: totalLocations,
                        locationDate: locationDate
                    )
                } else {
                    Text("Failed to load photos")
                        .foregroundColor(.white)
                        .font(.headline)
                }
            }
            .onAppear {
                loadPhotos()
            }
        }
        
        private func loadPhotos() {
            photoLoader.loadPhotosAtLocation(at: locationIndex) { images in
                if let images = images {
                    loadedImages = images
                }
                isLoading = false
            }
        }
    }

    // MARK: - Action Handlers

    private func handleOnAppear() {
        showPolylines = defaultShowPolylines
        photoLoader.showLocationMarkers = defaultShowPhotoMarkers
        photoLoader.showFriendOverlay = defaultShowFriendOverlay
        
        setupInitialRegion()
        resetAnimation()
        currentDate = photoLoader.photoTimeStamps.first
        photoLoader.resetAllFriendAnimations()
        updateLeaderboard()
    }

    private func handleOnDisappear() {
        pauseAnimation()
        resetAnimation()
    }

    private func handleFriendOverlayToggle() {
        if !photoLoader.showFriendOverlay {
            if let current = currentDate {
                for friend in photoLoader.getVisibleFriends() {
                    let friendIndex = findClosestIndex(for: current, in: friend.timestamps)
                    photoLoader.friendAnimationIndices[friend.id] = friendIndex
                }
            } else {
                for friend in photoLoader.friends {
                    photoLoader.friendAnimationIndices[friend.id] = 0
                }
            }
        }
        photoLoader.showFriendOverlay.toggle()
    }

    private func updateLeaderboard() {
        leaderboardEntries = LeaderboardCalculator.generateLeaderboard(
            userLocations: photoLoader.locations,
            userAnimationIndex: animationIndex,
            friends: photoLoader.friends,
            friendAnimationIndices: photoLoader.friendAnimationIndices
        )
    }

    // NEW: Helper functions for onChange
    
    private func handlePhotoIndexChange(_ newValue: Int?) {
        if newValue != nil {
            showPhotoViewer = true
        }
    }

    private func dismissPhotoViewer() {
        selectedPhotoIndex = nil
    }

    // MARK: - Helper Functions
    
    private func setupInitialRegion() {
        guard !photoLoader.locations.isEmpty else { return }
        
        if let mostVisited = photoLoader.getMostVisitedLocation() {
            mapRegion = MKCoordinateRegion(
                center: mostVisited,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
        } else {
            zoomToFitAll()
        }
    }
    
    private func zoomToFitAll() {
        guard !photoLoader.locations.isEmpty else { return }
        
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
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: (maxLat - minLat) * 1.3,
            longitudeDelta: (maxLon - minLon) * 1.3
        )
        
        mapRegion = MKCoordinateRegion(center: center, span: span)
    }
    


    
    // MARK: - Animation Controls
    
    private func toggleAnimation() {
        if isAnimating {
            pauseAnimation()
        } else {
            playAnimation()
        }
    }
    
    private func playAnimation() {
        guard !photoLoader.locations.isEmpty else { return }
        
        if currentDate == nil {
            currentDate = photoLoader.photoTimeStamps.first
            for friend in photoLoader.friends {
                photoLoader.friendAnimationIndices[friend.id] = 0
            }
        }
        
        isAnimating = true
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: animationSpeed, repeats: true) { _ in
            guard let current = currentDate else { return }
            
            guard let startDate = photoLoader.photoTimeStamps.first,
                  let endDate = photoLoader.photoTimeStamps.last else { return }
            
            let totalTimeInterval = endDate.timeIntervalSince(startDate)
            guard totalTimeInterval > 0 else { return }
            
            let timeStep: TimeInterval = 86400
            let newDate = current.addingTimeInterval(timeStep)
            
            if newDate <= endDate {
                withAnimation(.easeInOut(duration: animationSpeed * 0.8)) {
                    currentDate = newDate
                    animationIndex = findClosestIndex(for: newDate, in: photoLoader.photoTimeStamps)
                    
                    for friend in photoLoader.getVisibleFriends() {
                        let friendIndex = findClosestIndex(for: newDate, in: friend.timestamps)
                        photoLoader.friendAnimationIndices[friend.id] = friendIndex
                    }
                    
                    sliderValue = newDate.timeIntervalSince(startDate) / totalTimeInterval
                }
            } else {
                pauseAnimation()
            }
        }
    }
    
    private func findClosestIndex(for date: Date, in timestamps: [Date]) -> Int {
        guard !timestamps.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let targetMonth = calendar.component(.month, from: date)
        let targetDay = calendar.component(.day, from: date)
        
        var lastValidIndex = 0
        
        for (index, timestamp) in timestamps.enumerated() {
            let month = calendar.component(.month, from: timestamp)
            let day = calendar.component(.day, from: timestamp)
            
            if month < targetMonth || (month == targetMonth && day <= targetDay) {
                lastValidIndex = index
            } else {
                break
            }
        }
        
        return lastValidIndex
    }
    
    private func pauseAnimation() {
        isAnimating = false
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func resetAnimation() {
        pauseAnimation()
        withAnimation {
            animationIndex = 0
            sliderValue = 0
            currentDate = photoLoader.photoTimeStamps.first
            
            for friend in photoLoader.friends {
                photoLoader.friendAnimationIndices[friend.id] = 0
            }
        }
        setupInitialRegion()
    }
}

// MARK: - Timeline Scrubber Component

struct TimelineScrubber: View {
    @ObservedObject var photoLoader: PhotoLoader
    @Binding var sliderValue: Double
    @Binding var animationIndex: Int
    @Binding var isAnimating: Bool
    @Binding var isDraggingSlider: Bool
    @Binding var currentDate: Date?
    @Binding var animationSpeed: Double
    let toggleAnimation: () -> Void
    let resetAnimation: () -> Void
    let pauseAnimation: () -> Void
    
    var body: some View {
        VStack(spacing: 10) {
            MonthLabelsView(photoLoader: photoLoader)
            
            HStack(spacing: 15) {
                PlayPauseButton(isAnimating: isAnimating, action: toggleAnimation)
                
                TimelineSlider(
                    photoLoader: photoLoader,
                    sliderValue: $sliderValue,
                    animationIndex: $animationIndex,
                    isDraggingSlider: $isDraggingSlider,
                    currentDate: $currentDate,
                    pauseAnimation: pauseAnimation
                )
                
                ResetButton(action: resetAnimation)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.6))
            .cornerRadius(15)
            
            CurrentDateView(photoLoader: photoLoader, animationIndex: animationIndex, currentDate: currentDate)
        }
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
}

// MARK: - Timeline Sub-Components

struct MonthLabelsView: View {
    @ObservedObject var photoLoader: PhotoLoader
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(getMonthMarkers(), id: \.month) { marker in
                Text(marker.month)
                    .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 10)))  // Smaller font
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)  // Allow shrinking if needed
            }
        }
        .padding(.horizontal, 40)
    }
    
    private func getMonthMarkers() -> [(month: String, position: Double)] {
        guard !photoLoader.photoTimeStamps.isEmpty else { return [] }
        
        var monthMarkers: [(month: String, position: Double)] = []
        var seenMonths: Set<String> = []
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        
        for (index, timestamp) in photoLoader.photoTimeStamps.enumerated() {
            let monthYear = formatter.string(from: timestamp)
            
            if !seenMonths.contains(monthYear) {
                seenMonths.insert(monthYear)
                let position = Double(index) / Double(photoLoader.locations.count - 1)
                monthMarkers.append((month: monthYear, position: position))
            }
        }
        
        return monthMarkers
    }
}

struct PlayPauseButton: View {
    let isAnimating: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: isAnimating ? "pause.fill" : "play.fill")
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.blue)
                .clipShape(Circle())
        }
    }
}

struct ResetButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.counterclockwise")
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(Color.gray)
                .clipShape(Circle())
        }
    }
}

struct CurrentDateView: View {
    @ObservedObject var photoLoader: PhotoLoader
    let animationIndex: Int
    let currentDate: Date?
    
    var body: some View {
        if let date = currentDate {
            Text(formatDate(date))
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 15)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.6))
                .cornerRadius(10)
        } else if animationIndex < photoLoader.photoTimeStamps.count {
            Text(formatDate(photoLoader.photoTimeStamps[animationIndex]))
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 15)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.6))
                .cornerRadius(10)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

struct TimelineSlider: View {
    @ObservedObject var photoLoader: PhotoLoader
    @Binding var sliderValue: Double
    @Binding var animationIndex: Int
    @Binding var isDraggingSlider: Bool
    @Binding var currentDate: Date?
    let pauseAnimation: () -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.3))
                    .frame(height: 8)
                
                let progressWidth = calculateProgressWidth(geometry: geometry)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue)
                    .frame(width: progressWidth, height: 8)
                
                MonthMarkersView(photoLoader: photoLoader, geometry: geometry)
                
                SliderThumb(
                    geometry: geometry,
                    sliderValue: $sliderValue,
                    animationIndex: $animationIndex,
                    isDraggingSlider: $isDraggingSlider,
                    currentDate: $currentDate,
                    photoLoader: photoLoader,
                    pauseAnimation: pauseAnimation
                )
            }
        }
        .frame(height: 40)
    }
    
    private func calculateProgressWidth(geometry: GeometryProxy) -> CGFloat {
        return geometry.size.width * CGFloat(sliderValue)
    }
}

struct MonthMarkersView: View {
    @ObservedObject var photoLoader: PhotoLoader
    let geometry: GeometryProxy
    
    var body: some View {
        ForEach(getMonthMarkers(), id: \.month) { marker in
            Circle()
                .fill(Color.white)
                .frame(width: 6, height: 6)
                .offset(x: geometry.size.width * CGFloat(marker.position) - 3)
        }
    }
    
    private func getMonthMarkers() -> [(month: String, position: Double)] {
        guard !photoLoader.photoTimeStamps.isEmpty else { return [] }
        
        var monthMarkers: [(month: String, position: Double)] = []
        var seenMonths: Set<String> = []
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM"
        
        for (index, timestamp) in photoLoader.photoTimeStamps.enumerated() {
            let monthYear = formatter.string(from: timestamp)
            
            if !seenMonths.contains(monthYear) {
                seenMonths.insert(monthYear)
                let position = Double(index) / Double(photoLoader.locations.count - 1)
                monthMarkers.append((month: monthYear, position: position))
            }
        }
        
        return monthMarkers
    }
}

struct SliderThumb: View {
    let geometry: GeometryProxy
    @Binding var sliderValue: Double
    @Binding var animationIndex: Int
    @Binding var isDraggingSlider: Bool
    @Binding var currentDate: Date?
    @ObservedObject var photoLoader: PhotoLoader
    let pauseAnimation: () -> Void
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 20, height: 20)
            .shadow(radius: 3)
            .offset(x: calculateThumbOffset())
            .gesture(
                DragGesture()
                    .onChanged { value in
                        handleDragChange(value: value)
                    }
                    .onEnded { _ in
                        isDraggingSlider = false
                    }
            )
    }
    
    private func calculateThumbOffset() -> CGFloat {
        return geometry.size.width * CGFloat(sliderValue) - 10
    }
    
    private func handleDragChange(value: DragGesture.Value) {
        isDraggingSlider = true
        pauseAnimation()
        
        let newValue = max(0, min(1.0, Double(value.location.x / geometry.size.width)))
        sliderValue = newValue
        
        guard let startDate = photoLoader.photoTimeStamps.first,
              let endDate = photoLoader.photoTimeStamps.last else { return }
        
        let totalTimeInterval = endDate.timeIntervalSince(startDate)
        let targetDate = startDate.addingTimeInterval(totalTimeInterval * newValue)
        currentDate = targetDate
        
        animationIndex = findClosestIndex(for: targetDate, in: photoLoader.photoTimeStamps)
        
        for friend in photoLoader.friends {
            let friendIndex = findClosestIndex(for: targetDate, in: friend.timestamps)
            photoLoader.friendAnimationIndices[friend.id] = friendIndex
        }
    }
    
    private func findClosestIndex(for date: Date, in timestamps: [Date]) -> Int {
        guard !timestamps.isEmpty else { return 0 }
        
        let calendar = Calendar.current
        let targetMonth = calendar.component(.month, from: date)
        let targetDay = calendar.component(.day, from: date)
        
        var lastValidIndex = 0
        
        for (index, timestamp) in timestamps.enumerated() {
            let month = calendar.component(.month, from: timestamp)
            let day = calendar.component(.day, from: timestamp)
            
            if month < targetMonth || (month == targetMonth && day <= targetDay) {
                lastValidIndex = index
            } else {
                break
            }
        }
        
        return lastValidIndex
    }
}

// MARK: - MapView Wrapper

struct MapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let locations: [CLLocationCoordinate2D]
    @Binding var animationIndex: Int
    @Binding var isAnimating: Bool
    @ObservedObject var photoLoader: PhotoLoader
    @Binding var selectedPhotoIndex: Int?
    @Binding var showPhotoBubbles: Bool
    @Binding var showPolylines: Bool
    let userEmoji: String
    let userColor: String
    var coordinatorCallback: ((Coordinator) -> Void)? = nil
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        
        mapView.isUserInteractionEnabled = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = true
        
        // iOS 16+ map configuration
        if #available(iOS 16.0, *) {
            let config = MKStandardMapConfiguration()
            config.emphasisStyle = .default
            mapView.preferredConfiguration = config
        }
        
        DispatchQueue.main.async {
            coordinatorCallback?(context.coordinator)
        }
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.showPolylines = showPolylines
        
        context.coordinator.showPhotoBubbles = showPhotoBubbles
        context.coordinator.parent = self
        
        context.coordinator.updateAnnotations(mapView: mapView, locations: locations, animationIndex: animationIndex)
        
        if isAnimating && animationIndex < locations.count - 1 {
            context.coordinator.preloadUpcomingRegions(mapView: mapView, locations: locations, currentIndex: animationIndex)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        var userHasManuallyInteracted = false
        var showPhotoBubbles = false
        private var walkerAnnotation: MKPointAnnotation?
        private var locationAnnotations: [MKPointAnnotation] = []
        private var pathOverlay: MKPolyline?
        private var preloadedSnapshots: [Int: MKMapSnapshotter] = [:]
        private var lastShowLocationMarkers: Bool = false
        var showPolylines = true
        
        // MULTIPLE FRIENDS: Store walkers and paths by friend ID
        private var friendWalkerAnnotations: [UUID: MKPointAnnotation] = [:]
        private var friendPathOverlays: [UUID: MKPolyline] = [:]

        init(_ parent: MapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            if let gestureRecognizers = mapView.gestureRecognizers {
                for recognizer in gestureRecognizers {
                    if recognizer.state == .began || recognizer.state == .changed {
                        userHasManuallyInteracted = true
                        return
                    }
                }
            }
        }
        
        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            if let photoAnnotation = view.annotation as? LocationPhotoAnnotation {
                DispatchQueue.main.async {
                    self.parent.selectedPhotoIndex = photoAnnotation.locationIndex
                }
                mapView.deselectAnnotation(view.annotation, animated: false)
            }
        }
        
        func updateAnnotations(mapView: MKMapView, locations: [CLLocationCoordinate2D], animationIndex: Int) {
            guard !locations.isEmpty else { return }
            
            // YOUR walker - always update position
            if walkerAnnotation == nil {
                let annotation = MKPointAnnotation()
                annotation.coordinate = locations[0]
                annotation.title = "You"
                walkerAnnotation = annotation
                mapView.addAnnotation(annotation)
            }
            
            if animationIndex < locations.count {
                walkerAnnotation?.coordinate = locations[animationIndex]
            }
            
            // ALWAYS maintain and ADD photo annotations up to current index
            let targetCount = animationIndex + 1
            
            if locationAnnotations.count < targetCount {
                // Need to ADD more annotations
                for index in locationAnnotations.count...min(animationIndex, locations.count - 1) {
                    let annotation = LocationPhotoAnnotation()
                    annotation.coordinate = locations[index]
                    annotation.locationIndex = index
                    locationAnnotations.append(annotation)
                    mapView.addAnnotation(annotation)
                }
            } else if locationAnnotations.count > targetCount {
                // Need to REMOVE annotations (going backwards in timeline)
                let toRemove = Array(locationAnnotations[targetCount...])
                mapView.removeAnnotations(toRemove)
                locationAnnotations.removeLast(locationAnnotations.count - targetCount)
            }
            
            // CRITICAL: Always refresh visibility for ALL existing views
            refreshAnnotationVisibility(mapView: mapView)
            
            updatePathAndFriends(mapView: mapView, locations: locations, animationIndex: animationIndex)
        }
        
        // NEW: Extract path and friend updates to separate function
        private func updatePathAndFriends(mapView: MKMapView, locations: [CLLocationCoordinate2D], animationIndex: Int) {
            /// YOUR path overlay - only show if enabled
            if animationIndex > 0 && showPolylines {
                let pathCoordinates = Array(locations.prefix(animationIndex + 1))
                
                if let existingOverlay = pathOverlay {
                    mapView.removeOverlay(existingOverlay)
                }
                
                let polyline = MKPolyline(coordinates: pathCoordinates, count: pathCoordinates.count)
                polyline.title = "Your Path"
                pathOverlay = polyline
                mapView.addOverlay(polyline)
            } else if !showPolylines && pathOverlay != nil {
                // Remove path if lines are toggled off
                if let overlay = pathOverlay {
                    mapView.removeOverlay(overlay)
                }
                pathOverlay = nil
            }
            
            // MULTIPLE FRIENDS HANDLING
            let visibleFriends = parent.photoLoader.getVisibleFriends()
            
            // Remove overlays for friends that are no longer visible
            for (friendId, overlay) in friendPathOverlays {
                if !visibleFriends.contains(where: { $0.id == friendId }) {
                    mapView.removeOverlay(overlay)
                    friendPathOverlays.removeValue(forKey: friendId)
                }
            }
            
            // Remove walkers for friends that are no longer visible
            for (friendId, walker) in friendWalkerAnnotations {
                if !visibleFriends.contains(where: { $0.id == friendId }) {
                    mapView.removeAnnotation(walker)
                    friendWalkerAnnotations.removeValue(forKey: friendId)
                }
            }
            
            // Update each visible friend
            for friend in visibleFriends {
                let friendLocations = friend.coordinates
                let friendIndex = parent.photoLoader.friendAnimationIndices[friend.id] ?? 0
                
                guard !friendLocations.isEmpty else { continue }
                
                // Update or create friend walker
                if let walker = friendWalkerAnnotations[friend.id] {
                    if friendIndex < friendLocations.count {
                        walker.coordinate = friendLocations[friendIndex]
                        walker.title = friend.name
                    }
                } else {
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = friendLocations[0]
                    annotation.title = friend.name
                    friendWalkerAnnotations[friend.id] = annotation
                    if parent.photoLoader.showFriendOverlay {
                        mapView.addAnnotation(annotation)
                    }
                }
                
                // Ensure walker visibility matches overlay state
                if let walker = friendWalkerAnnotations[friend.id] {
                    let isOnMap = mapView.annotations.contains { $0 === walker }
                    if parent.photoLoader.showFriendOverlay && !isOnMap {
                        mapView.addAnnotation(walker)
                    } else if !parent.photoLoader.showFriendOverlay && isOnMap {
                        mapView.removeAnnotation(walker)
                    }
                }
                
                // Update friend path
                if let existingOverlay = friendPathOverlays[friend.id] {
                    mapView.removeOverlay(existingOverlay)
                }
                
                if parent.photoLoader.showFriendOverlay && friendIndex > 0 && showPolylines {
                    let friendPathCoordinates = Array(friendLocations.prefix(friendIndex + 1))
                    let polyline = MKPolyline(coordinates: friendPathCoordinates, count: friendPathCoordinates.count)
                    polyline.title = "Friend Path|\(friend.id.uuidString)|\(friend.color)"
                    friendPathOverlays[friend.id] = polyline
                    mapView.addOverlay(polyline)
                } else if (!showPolylines || !parent.photoLoader.showFriendOverlay) && friendPathOverlays[friend.id] != nil {
                    // Remove friend path if lines are toggled off
                    if let overlay = friendPathOverlays[friend.id] {
                        mapView.removeOverlay(overlay)
                        friendPathOverlays.removeValue(forKey: friend.id)
                    }
                }
            }
        }
        
        func preloadUpcomingRegions(mapView: MKMapView, locations: [CLLocationCoordinate2D], currentIndex: Int) {
            let lookahead = min(10, locations.count - currentIndex - 1)
            
            for i in 1...lookahead {
                let nextIndex = currentIndex + i
                if nextIndex < locations.count {
                    preloadRegion(around: locations[nextIndex], index: nextIndex)
                }
            }
            
            preloadedSnapshots = preloadedSnapshots.filter { $0.key >= currentIndex - 5 }
        }
        
        private func preloadRegion(around coordinate: CLLocationCoordinate2D, index: Int) {
            guard preloadedSnapshots[index] == nil else { return }
            
            let options = MKMapSnapshotter.Options()
            options.region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
            options.size = CGSize(width: 200, height: 200)
            options.scale = UIScreen.main.scale
            
            let snapshotter = MKMapSnapshotter(options: options)
            preloadedSnapshots[index] = snapshotter
            
            snapshotter.start { snapshot, error in }
        }
        
        func refreshAnnotationVisibility(mapView: MKMapView) {
            // Force all location annotation views to update their isHidden state
            for annotation in locationAnnotations {
                if let view = mapView.view(for: annotation) {
                    view.isHidden = !parent.photoLoader.showLocationMarkers
                }
            }
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            // YOUR WALKER - Use custom emoji and color
            if annotation === walkerAnnotation {
                let identifier = "Walker"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    
                    let drawSize = CGSize(width: 28, height: 28)
                    let frameSize = CGSize(width: 32, height: 32)
                    let renderer = UIGraphicsImageRenderer(size: frameSize)
                    let image = renderer.image { context in
                        let offset = (frameSize.width - drawSize.width) / 2
                        let rect = CGRect(x: offset, y: offset, width: drawSize.width, height: drawSize.height)
                        
                        // Use user's custom color
                        if let userUIColor = UIColor(hex: parent.userColor) {
                            context.cgContext.setFillColor(userUIColor.cgColor)
                        } else {
                            context.cgContext.setFillColor(UIColor.systemBlue.cgColor)
                        }
                        context.cgContext.fillEllipse(in: rect)
                        
                        if let imageData = UserDefaults.standard.data(forKey: "userProfileImageData"),
                           let profileImage = UIImage(data: imageData) {
                            // Clip to circle and draw profile image
                            context.cgContext.saveGState()
                            let imageInset: CGFloat = 2
                            let imageRect = CGRect(
                                x: offset + imageInset,
                                y: offset + imageInset,
                                width: drawSize.width - imageInset * 2,
                                height: drawSize.height - imageInset * 2
                            )
                            context.cgContext.addEllipse(in: imageRect)
                            context.cgContext.clip()
                            profileImage.draw(in: imageRect)
                            context.cgContext.restoreGState()
                        } else {
                            // Use user's custom emoji
                            let emoji = parent.userEmoji
                            let attributes: [NSAttributedString.Key: Any] = [
                                .font: UIFont.systemFont(ofSize: 14)
                            ]
                            let emojiSize = emoji.size(withAttributes: attributes)
                            let emojiRect = CGRect(
                                x: offset + (drawSize.width - emojiSize.width) / 2,
                                y: offset + (drawSize.height - emojiSize.height) / 2,
                                width: emojiSize.width,
                                height: emojiSize.height
                            )
                            emoji.draw(in: emojiRect, withAttributes: attributes)
                        }
                        
                        // White border
                        context.cgContext.setStrokeColor(UIColor.white.cgColor)
                        context.cgContext.setLineWidth(2.0)
                        context.cgContext.strokeEllipse(in: rect)
                    }
                    
                    view?.image = image
                    view?.frame.size = frameSize
                    view?.centerOffset = CGPoint(x: 0, y: 0)
                    view?.displayPriority = .required
                } else {
                    view?.annotation = annotation
                }

                return view
            }
            
            // FRIEND WALKERS - Keep small
            if let friendEntry = friendWalkerAnnotations.first(where: { $0.value === annotation }),
               let friend = parent.photoLoader.friends.first(where: { $0.id == friendEntry.key }) {
                
                let identifier = "FriendWalker-\(friend.id.uuidString)"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    
                    // CHANGE: Use fixed size
                    let drawSize = CGSize(width: 28, height: 28)  // Fixed size
                    let frameSize = CGSize(width: 32, height: 32)  // Fixed size
                    let renderer = UIGraphicsImageRenderer(size: frameSize)
                    let image = renderer.image { context in
                        let offset = (frameSize.width - drawSize.width) / 2
                        let rect = CGRect(x: offset, y: offset, width: drawSize.width, height: drawSize.height)
                        
                        // Draw colored background circle
                        if let friendColor = UIColor(hex: friend.color) {
                            context.cgContext.setFillColor(friendColor.cgColor)
                        } else {
                            context.cgContext.setFillColor(UIColor.systemRed.cgColor)
                        }
                        context.cgContext.fillEllipse(in: rect)
                        
                        // Draw profile image or emoji
                        if let imageData = friend.profileImageData,
                           let profileImage = UIImage(data: imageData) {
                            // Clip to circle and draw profile image
                            context.cgContext.saveGState()
                            let imageInset: CGFloat = 2
                            let imageRect = CGRect(
                                x: offset + imageInset,
                                y: offset + imageInset,
                                width: drawSize.width - imageInset * 2,
                                height: drawSize.height - imageInset * 2
                            )
                            context.cgContext.addEllipse(in: imageRect)
                            context.cgContext.clip()
                            profileImage.draw(in: imageRect)
                            context.cgContext.restoreGState()
                        } else {
                            // Draw emoji as fallback
                            let emoji = friend.emoji
                            let attributes: [NSAttributedString.Key: Any] = [
                                .font: UIFont.systemFont(ofSize: 14)  // Fixed size
                            ]
                            let emojiSize = emoji.size(withAttributes: attributes)
                            let emojiRect = CGRect(
                                x: offset + (drawSize.width - emojiSize.width) / 2,
                                y: offset + (drawSize.height - emojiSize.height) / 2,
                                width: emojiSize.width,
                                height: emojiSize.height
                            )
                            emoji.draw(in: emojiRect, withAttributes: attributes)
                        }
                        
                        // White border
                        context.cgContext.setStrokeColor(UIColor.white.cgColor)
                        context.cgContext.setLineWidth(2.0)
                        context.cgContext.strokeEllipse(in: rect)
                    }
                    
                    view?.image = image
                    view?.frame.size = frameSize
                    view?.centerOffset = CGPoint(x: 0, y: 0)
                    view?.displayPriority = .required
                } else {
                    view?.annotation = annotation
                }
                
                return view
            }

            // YOUR PHOTO ANNOTATIONS
            if let photoAnnotation = annotation as? LocationPhotoAnnotation {
                if showPhotoBubbles {
                    // PHOTO BUBBLES MODE
                    let identifier = "PhotoLocation"
                    var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)

                    if view == nil {
                        view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                        view?.canShowCallout = false
                    } else {
                        view?.annotation = annotation
                    }

                    let locationIndex = photoAnnotation.locationIndex
                    let photoLoader = parent.photoLoader

                    if locationIndex < photoLoader.thumbnails.count {
                        let thumbnail = photoLoader.thumbnails[locationIndex]
                        // CHANGE: Use fixed size
                        let drawSize = CGSize(width: 32, height: 32)  // Fixed size
                        let frameSize = CGSize(width: 36, height: 36)  // Fixed size
                        let renderer = UIGraphicsImageRenderer(size: frameSize)
                        let circularImage = renderer.image { context in
                            let offset = (frameSize.width - drawSize.width) / 2
                            let rect = CGRect(x: offset, y: offset, width: drawSize.width, height: drawSize.height)
                            
                            context.cgContext.setFillColor(UIColor.white.cgColor)
                            context.cgContext.fillEllipse(in: rect)

                            let photoInset: CGFloat = 2
                            let photoRect = CGRect(
                                x: offset + photoInset,
                                y: offset + photoInset,
                                width: drawSize.width - photoInset * 2,
                                height: drawSize.height - photoInset * 2
                            )
                            context.cgContext.addEllipse(in: photoRect)
                            context.cgContext.clip()
                            thumbnail.draw(in: photoRect)
                        }

                        view?.image = circularImage
                        view?.frame.size = frameSize
                    } else {
                        // Placeholder - CHANGE: Use fixed size
                        let drawSize = CGSize(width: 32, height: 32)  // Fixed size
                        let frameSize = CGSize(width: 36, height: 36)  // Fixed size
                        let renderer = UIGraphicsImageRenderer(size: frameSize)
                        let placeholderImage = renderer.image { context in
                            let offset = (frameSize.width - drawSize.width) / 2
                            let rect = CGRect(x: offset, y: offset, width: drawSize.width, height: drawSize.height)
                            
                            context.cgContext.setFillColor(UIColor.systemBlue.cgColor)
                            context.cgContext.fillEllipse(in: rect)
                            context.cgContext.setStrokeColor(UIColor.white.cgColor)
                            context.cgContext.setLineWidth(2)
                            context.cgContext.strokeEllipse(in: rect)
                        }
                        view?.image = placeholderImage
                        view?.frame.size = frameSize
                    }

                    view?.displayPriority = .defaultHigh
                    view?.isHidden = !parent.photoLoader.showLocationMarkers
                    return view
                    
                } else {
                    // SIMPLE DOT MODE - this is fine, already auto-scales
                    let identifier = "SimplePin"
                    var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView

                    if view == nil {
                        view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                        view?.markerTintColor = .systemBlue
                        view?.glyphImage = UIImage(systemName: "circle.fill")
                        view?.displayPriority = .defaultHigh
                    } else {
                        view?.annotation = annotation
                        view?.markerTintColor = .systemBlue
                    }

                    view?.displayPriority = .defaultHigh
                    view?.isHidden = !parent.photoLoader.showLocationMarkers
                    return view
                }
            }

            return nil
        }
                
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                
                // Check if this is a friend's path
                if let title = polyline.title, title.starts(with: "Friend Path|") {
                    let components = title.split(separator: "|")
                    if components.count == 3, let colorHex = components.last {
                        renderer.strokeColor = UIColor(hex: String(colorHex)) ?? .systemRed
                    } else {
                        renderer.strokeColor = .systemRed
                    }
                    renderer.lineWidth = 3
                } else {
                    // Your path - use custom color
                    if let userUIColor = UIColor(hex: parent.userColor) {
                        renderer.strokeColor = userUIColor
                    } else {
                        renderer.strokeColor = .systemBlue
                    }
                    renderer.lineWidth = 3
                }
                
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
// MARK: - Full Screen Photo Viewer

struct FullScreenPhotoViewer: View {
    let images: [UIImage]
    let locationIndex: Int
    let totalLocations: Int
    let locationDate: Date
    
    @Environment(\.dismiss) var dismiss
    @State private var currentImageIndex = 0
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Location \(locationIndex + 1) of \(totalLocations)")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        if images.count > 1 {
                            Text("Photo \(currentImageIndex + 1) of \(images.count)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        Text(formatDate(locationDate))
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.7))
                
                // Image carousel with TabView
                TabView(selection: $currentImageIndex) {
                    ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                        GeometryReader { geometry in
                            ZStack {
                                Color.black
                                
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                                    .scaleEffect(scale)
                                    .offset(offset)
                                    .gesture(
                                        MagnificationGesture()
                                            .onChanged { value in
                                                let delta = value / lastScale
                                                lastScale = value
                                                scale = min(max(scale * delta, 1.0), 5.0)
                                                
                                                if scale <= 1.0 {
                                                    offset = .zero
                                                    lastOffset = .zero
                                                }
                                            }
                                            .onEnded { _ in
                                                lastScale = 1.0
                                                
                                                if scale < 1.1 {
                                                    withAnimation(.spring(response: 0.3)) {
                                                        scale = 1.0
                                                        offset = .zero
                                                        lastOffset = .zero
                                                    }
                                                }
                                            }
                                    )
                                    .simultaneousGesture(
                                        scale > 1.0 ?
                                        DragGesture()
                                            .onChanged { value in
                                                let newOffset = CGSize(
                                                    width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height
                                                )
                                                
                                                let maxX = (geometry.size.width * (scale - 1)) / 2
                                                let maxY = (geometry.size.height * (scale - 1)) / 2
                                                
                                                offset = CGSize(
                                                    width: min(max(newOffset.width, -maxX), maxX),
                                                    height: min(max(newOffset.height, -maxY), maxY)
                                                )
                                            }
                                            .onEnded { _ in
                                                lastOffset = offset
                                            }
                                        : nil
                                    )
                                    .onTapGesture(count: 2) {
                                        withAnimation(.spring(response: 0.4)) {
                                            if scale > 1.0 {
                                                scale = 1.0
                                                lastScale = 1.0
                                                offset = .zero
                                                lastOffset = .zero
                                            } else {
                                                scale = 2.5
                                                lastScale = 1.0
                                            }
                                        }
                                    }
                            }
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: currentImageIndex) { _ in
                    withAnimation(.easeOut(duration: 0.2)) {
                        scale = 1.0
                        lastScale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    }
                }
                
                if images.count > 1 {
                    DotsIndicator(totalImages: images.count, currentIndex: currentImageIndex)
                        .frame(height: 30)
                        .background(Color.black.opacity(0.7))
                }
                
                VStack(spacing: 5) {
                    if images.count > 1 {
                        HStack(spacing: 15) {
                            Image(systemName: "chevron.left")
                            Text("Swipe to view \(images.count) photos")
                            Image(systemName: "chevron.right")
                        }
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                    }
                    Text("Pinch to zoom • Double tap to zoom")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding()
                .background(Color.black.opacity(0.7))
            }
        }
    }
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Dots Indicator Component

struct DotsIndicator: View {
    let totalImages: Int
    let currentIndex: Int
    
    var body: some View {
        HStack(spacing: 0) {
            Spacer()
            
            HStack(spacing: 8) {
                let maxDots = 20
                
                if totalImages <= maxDots {
                    ForEach(0..<totalImages, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? Color.white : Color.white.opacity(0.5))
                            .frame(width: 8, height: 8)
                    }
                } else {
                    let halfWindow = maxDots / 2
                    let range = calculateDotRange(total: totalImages, current: currentIndex, halfWindow: halfWindow, maxDots: maxDots)
                    
                    if range.start > 0 {
                        Text("...")
                            .foregroundColor(.white.opacity(0.5))
                            .font(.system(size: 12))
                    }
                    
                    ForEach(range.start..<range.end, id: \.self) { index in
                        Circle()
                            .fill(index == currentIndex ? Color.white : Color.white.opacity(0.5))
                            .frame(width: 8, height: 8)
                    }
                    
                    if range.end < totalImages {
                        Text("...")
                            .foregroundColor(.white.opacity(0.5))
                            .font(.system(size: 12))
                    }
                }
            }
            
            Spacer()
        }
    }
    
    private func calculateDotRange(total: Int, current: Int, halfWindow: Int, maxDots: Int) -> (start: Int, end: Int) {
        if current < halfWindow {
            return (0, maxDots)
        } else if current >= total - halfWindow {
            return (total - maxDots, total)
        } else {
            return (current - halfWindow, current + halfWindow)
        }
    }
}

// MARK: - Share Sheet for iOS

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Create activity items with metadata
        var items: [Any] = []
        
        for item in activityItems {
            if let image = item as? UIImage {
                // Wrap image with metadata provider for rich preview
                let itemSource = ImageItemSource(image: image, title: "My 2025 Mapped")
                items.append(itemSource)
            } else {
                items.append(item)
            }
        }
        
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        // Exclude irrelevant activities
        activityVC.excludedActivityTypes = [
            .addToReadingList,
            .assignToContact,
            .openInIBooks
        ]
        
        return activityVC
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

class ImageItemSource: NSObject, UIActivityItemSource {
    let image: UIImage
    let title: String
    
    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
        super.init()
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return image
    }
    
    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        return image
    }
    
    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        return title
    }
    
    func activityViewController(
        _ activityViewController: UIActivityViewController,
        thumbnailImageForActivityType activityType: UIActivity.ActivityType?,
        suggestedSize size: CGSize
    ) -> UIImage? {
        let thumbnailSize = CGSize(width: 60, height: 60)
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        }
    }
    
    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        return "public.jpeg"
    }
}
