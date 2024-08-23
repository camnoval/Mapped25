import SwiftUI
import CoreLocation

// MARK: - Constellation Helper Structures

struct ConstellationStar: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let intensity: Int  // Number of locations clustered at this point
    let screenPosition: CGPoint
}

struct ConstellationConnection {
    let from: ConstellationStar
    let to: ConstellationStar
}

// MARK: - Constellation Builder

class ConstellationBuilder {
    
    /// Cluster nearby locations into constellation stars
    /// Cluster nearby locations into constellation stars
    static func buildConstellation(
        locations: [CLLocationCoordinate2D],
        viewSize: CGSize
    ) -> (stars: [ConstellationStar], connections: [ConstellationConnection]) {
        
        guard !locations.isEmpty else { return ([], []) }
        
        // Calculate total geographic span to determine clustering radius
        var minLat = locations[0].latitude
        var maxLat = locations[0].latitude
        var minLon = locations[0].longitude
        var maxLon = locations[0].longitude
        
        for loc in locations {
            minLat = min(minLat, loc.latitude)
            maxLat = max(maxLat, loc.latitude)
            minLon = min(minLon, loc.longitude)
            maxLon = max(maxLon, loc.longitude)
        }
        
        // Calculate the diagonal span across the journey
        let northwestCorner = CLLocation(latitude: maxLat, longitude: minLon)
        let southeastCorner = CLLocation(latitude: minLat, longitude: maxLon)
        let totalSpan = northwestCorner.distance(from: southeastCorner)
        
        // UPDATED: Increase cluster radius to reduce number of stars
        // Use 8% of total span (was 5%) to merge more nearby locations
        // Minimum 2km (was 1km), maximum 100km (was 50km)
        let clusterRadius = max(2000, min(100000, totalSpan * 0.08))
        
        print("Total journey span: \(totalSpan/1000)km, cluster radius: \(clusterRadius/1000)km")
        
        // Step 1: Cluster nearby locations
        var clusters: [(center: CLLocationCoordinate2D, count: Int)] = []
        var remainingLocations = locations
        
        while !remainingLocations.isEmpty {
            let seedLocation = remainingLocations.removeFirst()
            var clusterLocations = [seedLocation]
            
            // Find all nearby locations
            remainingLocations = remainingLocations.filter { location in
                let distance = calculateDistance(from: seedLocation, to: location)
                if distance < clusterRadius {
                    clusterLocations.append(location)
                    return false  // Remove from remaining
                }
                return true  // Keep in remaining
            }
            
            // Calculate cluster center (average position)
            let avgLat = clusterLocations.map { $0.latitude }.reduce(0, +) / Double(clusterLocations.count)
            let avgLon = clusterLocations.map { $0.longitude }.reduce(0, +) / Double(clusterLocations.count)
            let center = CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon)
            
            clusters.append((center: center, count: clusterLocations.count))
        }
        
        // UPDATED: Calculate intensity as percentage of total locations
        let totalLocations = locations.count
        
        // Step 2: Convert clusters to stars with screen positions and normalized intensity
        let stars = clusters.map { cluster -> ConstellationStar in
            let screenPos = mapToScreen(cluster.center, size: viewSize, allLocations: locations)
            
            // Calculate intensity as percentage (0-100)
            let percentage = Double(cluster.count) / Double(totalLocations) * 100.0
            
            // Normalize to 1-10 scale for visual representation
            // Even if someone has 500 photos in one spot, it caps at intensity 10
            let normalizedIntensity = min(10, max(1, Int(percentage / 2.0)))
            
            return ConstellationStar(
                coordinate: cluster.center,
                intensity: normalizedIntensity,
                screenPosition: screenPos
            )
        }
        
        print("Created \(stars.count) constellation stars from \(locations.count) locations")
        print("Intensity range: \(stars.map { $0.intensity }.min() ?? 0) - \(stars.map { $0.intensity }.max() ?? 0)")
        
        // Step 3: Create intelligent connections
        let connections = createConstellationConnections(stars: stars)
        
        return (stars, connections)
    }
    
    /// Create connections between stars to form constellation pattern
    private static func createConstellationConnections(stars: [ConstellationStar]) -> [ConstellationConnection] {
        guard stars.count > 1 else { return [] }
        
        var connections: [ConstellationConnection] = []
        
        // Strategy: Each star connects to its 2-3 nearest neighbors
        // This creates a web-like constellation pattern
        
        for star in stars {
            // Find nearest neighbors (excluding self)
            let otherStars = stars.filter { $0.id != star.id }
            
            let nearestNeighbors = otherStars
                .map { otherStar -> (star: ConstellationStar, distance: CGFloat) in
                    let dist = distance(from: star.screenPosition, to: otherStar.screenPosition)
                    return (otherStar, dist)
                }
                .sorted { $0.distance < $1.distance }
            
            // Connect to 2-3 nearest stars
            let connectionCount = star.intensity >= 3 ? 3 : 2
            
            for neighbor in nearestNeighbors.prefix(connectionCount) {
                // Check if connection already exists (in either direction)
                let connectionExists = connections.contains { connection in
                    (connection.from.id == star.id && connection.to.id == neighbor.star.id) ||
                    (connection.from.id == neighbor.star.id && connection.to.id == star.id)
                }
                
                // Only add if connection doesn't already exist
                // REMOVED: distance threshold to allow long-distance connections
                if !connectionExists {
                    connections.append(ConstellationConnection(from: star, to: neighbor.star))
                }
            }
        }
        
        // NEW: Bridge islands by ensuring global connectivity
        // Use Union-Find to detect disconnected components
        var parent: [UUID: UUID] = [:]
        
        // Initialize each star as its own parent
        for star in stars {
            parent[star.id] = star.id
        }
        
        // Find root parent
        func find(_ id: UUID) -> UUID {
            if parent[id] != id {
                parent[id] = find(parent[id]!)
            }
            return parent[id]!
        }
        
        // Union two components
        func union(_ id1: UUID, _ id2: UUID) {
            let root1 = find(id1)
            let root2 = find(id2)
            if root1 != root2 {
                parent[root1] = root2
            }
        }
        
        // Build connected components from existing connections
        for connection in connections {
            union(connection.from.id, connection.to.id)
        }
        
        // Group stars by their component
        var components: [UUID: [ConstellationStar]] = [:]
        for star in stars {
            let root = find(star.id)
            if components[root] == nil {
                components[root] = []
            }
            components[root]!.append(star)
        }
        
        // If we have multiple components (islands), connect them
        if components.count > 1 {
            let componentRoots = Array(components.keys)
            
            // Connect each island to the next one
            for i in 0..<(componentRoots.count - 1) {
                let component1 = components[componentRoots[i]]!
                let component2 = components[componentRoots[i + 1]]!
                
                // Find the two closest stars between these components
                var minDist: CGFloat = .infinity
                var closestPair: (ConstellationStar, ConstellationStar)?
                
                for star1 in component1 {
                    for star2 in component2 {
                        let dist = distance(from: star1.screenPosition, to: star2.screenPosition)
                        if dist < minDist {
                            minDist = dist
                            closestPair = (star1, star2)
                        }
                    }
                }
                
                // Add bridge connection
                if let pair = closestPair {
                    connections.append(ConstellationConnection(from: pair.0, to: pair.1))
                    union(pair.0.id, pair.1.id)
                    print("🌉 Bridged island: \(minDist) pixels apart")
                }
            }
        }
        
        // Final check: Ensure no isolated stars remain
        let isolatedStars = stars.filter { star in
            !connections.contains { $0.from.id == star.id || $0.to.id == star.id }
        }
        
        for isolatedStar in isolatedStars {
            // Find absolute nearest star
            if let nearest = stars
                .filter({ $0.id != isolatedStar.id })
                .min(by: {
                    distance(from: isolatedStar.screenPosition, to: $0.screenPosition) <
                    distance(from: isolatedStar.screenPosition, to: $1.screenPosition)
                }) {
                connections.append(ConstellationConnection(from: isolatedStar, to: nearest))
                print("🔗 Connected isolated star")
            }
        }
        
        print("🌟 Created \(connections.count) constellation connections (\(components.count) island(s) bridged)")
        
        return connections
    }
    
    // Helper: Calculate geographic distance
    private static func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let loc1 = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let loc2 = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return loc1.distance(from: loc2)
    }
    
    // Helper: Calculate screen distance
    private static func distance(from: CGPoint, to: CGPoint) -> CGFloat {
        let dx = to.x - from.x
        let dy = to.y - from.y
        return sqrt(dx * dx + dy * dy)
    }
    
    // Map geographic coordinate to screen position
    private static func mapToScreen(_ location: CLLocationCoordinate2D, size: CGSize, allLocations: [CLLocationCoordinate2D]) -> CGPoint {
        guard !location.latitude.isNaN && !location.longitude.isNaN else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
        
        guard !allLocations.isEmpty else {
            return CGPoint(x: size.width / 2, y: size.height / 2)
        }
        
        var minLat = allLocations[0].latitude
        var maxLat = allLocations[0].latitude
        var minLon = allLocations[0].longitude
        var maxLon = allLocations[0].longitude
        
        for loc in allLocations {
            minLat = min(minLat, loc.latitude)
            maxLat = max(maxLat, loc.latitude)
            minLon = min(minLon, loc.longitude)
            maxLon = max(maxLon, loc.longitude)
        }
        
        let latPadding = (maxLat - minLat) * 0.2
        let lonPadding = (maxLon - minLon) * 0.2
        
        let paddedMinLat = minLat - latPadding
        let paddedMaxLat = maxLat + latPadding
        let paddedMinLon = minLon - lonPadding
        let paddedMaxLon = maxLon + lonPadding
        
        let latRange = paddedMaxLat - paddedMinLat
        let lonRange = paddedMaxLon - paddedMinLon
        
        let padding: CGFloat = 40
        let usableWidth = size.width - (padding * 2)
        let usableHeight = size.height - (padding * 2)
        
        let normalizedLon = (location.longitude - paddedMinLon) / lonRange
        let normalizedLat = (location.latitude - paddedMinLat) / latRange
        
        let x = padding + (normalizedLon * usableWidth)
        let y = padding + ((1 - normalizedLat) * usableHeight)
        
        let clampedX = max(padding, min(size.width - padding, x))
        let clampedY = max(padding, min(size.height - padding, y))
        
        return CGPoint(x: clampedX, y: clampedY)
    }
}

// MARK: - ConstellationFullView

struct ConstellationFullView: View {
    @ObservedObject var photoLoader: PhotoLoader
    @State private var revealProgress: Double = 0.0
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var backgroundStars: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = []
    @State private var isGeneratingImage = false
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Angle = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastRotation: Angle = .zero
    //generate constellation once
    @State private var constellationStars: [ConstellationStar] = []
    @State private var constellationConnections: [ConstellationConnection] = []
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.top)
            
            // Background stars
            ForEach(Array(backgroundStars.enumerated()), id: \.offset) { index, star in
                Circle()
                    .fill(Color.white.opacity(star.opacity))
                    .frame(width: star.size, height: star.size)
                    .position(x: star.x, y: star.y)
            }
            
            VStack(spacing: 0) {
                // MOVED: Controls to the TOP
                HStack(spacing: 20) {
                    Button(action: restart) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                    }
                    
                    Button(action: shareConstellation) {
                        HStack {
                            if isGeneratingImage {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                            Text(isGeneratingImage ? "Generating..." : "Share")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(12)
                    }
                    .disabled(isGeneratingImage)
                }
                .padding(.top, 60)
                .padding(.bottom, 10)
                
                VStack(spacing: 15) {
                    Text("Your 2025")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Constellation")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                if !photoLoader.locations.isEmpty {
                    GeometryReader { geometry in
                        FullConstellationDisplayView(
                            locations: photoLoader.locations,
                            progress: revealProgress,
                            stars: constellationStars,
                            connections: constellationConnections
                        )
                        .onAppear {
                            if constellationStars.isEmpty {
                                let constellation = ConstellationBuilder.buildConstellation(
                                    locations: photoLoader.locations,
                                    viewSize: geometry.size
                                )
                                constellationStars = constellation.stars
                                constellationConnections = constellation.connections
                            }
                        }
                    }
                    .frame(height: 500)
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
                
                Text("\(constellationStars.count) stars • Your unique pattern")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 5)
                
                Text("Pinch to zoom • Rotate with two fingers")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
                
                Spacer(minLength: 30)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let image = shareImage {
                ShareSheet(activityItems: [image])
            }
        }
        .onAppear {
            generateBackgroundStars()
            restart()
        }
    }
    
    private func generateBackgroundStars() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        var stars: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = []
        
        for _ in 0..<200 {
            stars.append((
                x: CGFloat.random(in: 0...screenWidth),
                y: CGFloat.random(in: 0...screenHeight),
                size: CGFloat.random(in: 1...3),
                opacity: Double.random(in: 0.3...0.9)
            ))
        }
        
        backgroundStars = stars
    }
    
    private func restart() {
        revealProgress = 0.0
        scale = 1.0
        rotation = .zero
        lastScale = 1.0
        lastRotation = .zero
        withAnimation(.easeInOut(duration: 3.0)) {
            revealProgress = 1.0
        }
    }
    
    private func shareConstellation() {
        // Prevent double-tapping
        guard !isGeneratingImage else { return }
        
        isGeneratingImage = true
        
        // Create the view and hosting controller on main thread
        let snapshotView = ConstellationSnapshotView(
            locations: photoLoader.locations,
            locationCount: photoLoader.locations.count,
            scale: scale,
            rotation: rotation,
            backgroundStars: backgroundStars,
            stars: constellationStars,
            connections: constellationConnections
        )
        
        let hostingController = UIHostingController(rootView: snapshotView)
        let targetSize = CGSize(width: 1080, height: 1920)
        hostingController.view.bounds = CGRect(origin: .zero, size: targetSize)
        hostingController.view.backgroundColor = .clear
        
        // Force layout
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        
        // Give SwiftUI time to render, then generate image (all on main thread)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // Render image (must be on main thread)
            let format = UIGraphicsImageRendererFormat()
            format.opaque = true
            format.scale = 2.0
            
            let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
            let image = renderer.image { context in
                // Fill black background first (since opaque)
                UIColor.black.setFill()
                context.fill(CGRect(origin: .zero, size: targetSize))
                
                hostingController.view.drawHierarchy(
                    in: CGRect(origin: .zero, size: targetSize),
                    afterScreenUpdates: true
                )
            }
            
            self.shareImage = image
            self.isGeneratingImage = false
            
            // Small delay before showing share sheet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.showShareSheet = true
            }
            
            print("✅ Constellation image generated: \(image.size.width)x\(image.size.height)")
        }
    }
}

// MARK: - Full Constellation Display View

struct FullConstellationDisplayView: View {
    let locations: [CLLocationCoordinate2D]
    let progress: Double
    let stars: [ConstellationStar]
    let connections: [ConstellationConnection]
    
    var body: some View {
        let visibleStarCount = Int(Double(stars.count) * progress)
        let visibleStars = Array(stars.prefix(visibleStarCount))
        
        let visibleConnections = connections.filter { connection in
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
                        colors: [Color.white.opacity(0.8), Color.blue.opacity(0.6), Color.purple.opacity(0.4)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )
                .shadow(color: .white.opacity(0.5), radius: 3)
                .shadow(color: .blue.opacity(0.3), radius: 5)
            }
            
            // Draw stars
            ForEach(visibleStars) { star in
                FullConstellationStarView(star: star)
            }
        }
    }
}

struct FullConstellationStarView: View {
    let star: ConstellationStar
    
    var body: some View {
        ZStack {
            let glowSize: CGFloat = CGFloat(12 + (star.intensity * 2))
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, .blue.opacity(0.5), .clear],
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
                    .stroke(Color.blue, lineWidth: 1.5)
                    .frame(width: coreSize + 8, height: coreSize + 8)
                    .opacity(0.6)
            }
        }
        .position(star.screenPosition)
    }
}

// MARK: - Snapshot View (for sharing)
struct ConstellationSnapshotView: View {
    let locations: [CLLocationCoordinate2D]
    let locationCount: Int  // Keep this for reference but use star count
    let scale: CGFloat
    let rotation: Angle
    let backgroundStars: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)]
    let stars: [ConstellationStar]
    let connections: [ConstellationConnection]
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(red: 0.1, green: 0.1, blue: 0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Background stars for share image - scaled to match share dimensions
            ForEach(Array(backgroundStars.enumerated()), id: \.offset) { index, star in
                Circle()
                    .fill(Color.white.opacity(star.opacity))
                    .frame(width: star.size, height: star.size)
                    .position(
                        x: star.x * (1080 / UIScreen.main.bounds.width),
                        y: star.y * (1920 / UIScreen.main.bounds.height)
                    )
            }
            
            VStack(spacing: 40) {
                Spacer()
                
                VStack(spacing: 10) {
                    Text("My 2025")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Constellation")
                        .font(.system(size: 36, weight: .light))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Scale the existing constellation to fit 800x800
                ZStack {
                    let scaledStars = scaleStarsToShareSize(stars: stars, targetSize: 800)
                    let scaledConnections = scaleConnectionsToShareSize(connections: connections, stars: stars, scaledStars: scaledStars)
                    
                    // Draw connections
                    ForEach(scaledConnections.indices, id: \.self) { index in
                        let connection = scaledConnections[index]
                        Path { path in
                            path.move(to: connection.from.screenPosition)
                            path.addLine(to: connection.to.screenPosition)
                        }
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.8), Color.blue.opacity(0.6), Color.purple.opacity(0.4)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                        .shadow(color: .white.opacity(0.5), radius: 3)
                        .shadow(color: .blue.opacity(0.3), radius: 5)
                    }
                    
                    // Draw stars
                    ForEach(scaledStars) { star in
                        FullConstellationStarView(star: star)
                    }
                }
                .frame(width: 800, height: 800)
                .scaleEffect(scale)
                .rotationEffect(rotation)
                
                Text("\(stars.count) stars • Mapped 2025")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
            }
        }
        .frame(width: 1080, height: 1920)
    }
    
    // Scale stars from carousel size to share size (800x800)
    private func scaleStarsToShareSize(stars: [ConstellationStar], targetSize: CGFloat) -> [ConstellationStar] {
        guard !stars.isEmpty else { return [] }
        
        // Find the original bounds
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
        
        // Calculate scale to fit in 800x800 with padding
        let padding: CGFloat = 40
        let usableSize = targetSize - (padding * 2)
        let scaleX = usableSize / originalWidth
        let scaleY = usableSize / originalHeight
        let scaleFactor = min(scaleX, scaleY)
        
        // Scale and center
        return stars.map { star in
            let scaledX = (star.screenPosition.x - minX) * scaleFactor + padding
            let scaledY = (star.screenPosition.y - minY) * scaleFactor + padding
            
            return ConstellationStar(
                coordinate: star.coordinate,
                intensity: star.intensity,
                screenPosition: CGPoint(x: scaledX, y: scaledY)
            )
        }
    }
    
    // Scale connections to match scaled stars
    private func scaleConnectionsToShareSize(connections: [ConstellationConnection], stars: [ConstellationStar], scaledStars: [ConstellationStar]) -> [ConstellationConnection] {
        return connections.compactMap { connection in
            guard let fromIndex = stars.firstIndex(where: { $0.id == connection.from.id }),
                  let toIndex = stars.firstIndex(where: { $0.id == connection.to.id }),
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
