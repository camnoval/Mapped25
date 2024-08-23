import SwiftUI
import CoreLocation

// MARK: - Leaderboard Entry Model

struct LeaderboardEntry: Identifiable {
    let id: UUID
    let name: String
    let distance: Double // in miles
    let color: String
    let emoji: String
    let profileImageData: Data?
    let isCurrentUser: Bool
    let locationCount: Int
    
    var rank: Int = 0
    var medal: Medal {
        switch rank {
        case 1: return .gold
        case 2: return .silver
        case 3: return .bronze
        default: return .none
        }
    }
    
    enum Medal {
        case gold, silver, bronze, none
        
        var icon: String {
            switch self {
            case .gold: return "crown.fill"
            case .silver: return "medal.fill"
            case .bronze: return "medal.fill"
            case .none: return ""
            }
        }
        
        var color: Color {
            switch self {
            case .gold: return .yellow
            case .silver: return .gray
            case .bronze: return Color(red: 0.8, green: 0.5, blue: 0.2)
            case .none: return .clear
            }
        }
    }
}

// MARK: - Leaderboard Calculator

class LeaderboardCalculator {
    
    /// Calculate cumulative distance up to a given index
    static func calculateDistance(
        locations: [CLLocationCoordinate2D],
        upToIndex index: Int
    ) -> Double {
        guard index > 0, index < locations.count else { return 0.0 }
        
        var totalDistance: Double = 0.0
        
        for i in 1...index {
            let prev = CLLocation(
                latitude: locations[i-1].latitude,
                longitude: locations[i-1].longitude
            )
            let current = CLLocation(
                latitude: locations[i].latitude,
                longitude: locations[i].longitude
            )
            
            totalDistance += prev.distance(from: current)
        }
        
        // Convert meters to miles
        return totalDistance / 1609.34
    }
    
    /// Generate leaderboard for current animation state
    static func generateLeaderboard(
        userLocations: [CLLocationCoordinate2D],
        userAnimationIndex: Int,
        friends: [FriendData],
        friendAnimationIndices: [UUID: Int]
    ) -> [LeaderboardEntry] {
        var entries: [LeaderboardEntry] = []
        
        // Get user's custom settings
        let userEmoji = UserDefaults.standard.string(forKey: "userEmoji") ?? "🚶"
        let userColor = UserDefaults.standard.string(forKey: "userColor") ?? "#33CCBB"
        let userName = UserDefaults.standard.string(forKey: "userName") ?? "You"
        
        // Add current user with custom settings
        let userDistance = calculateDistance(
            locations: userLocations,
            upToIndex: userAnimationIndex
        )
        
        entries.append(LeaderboardEntry(
            id: UUID(),
            name: userName,      // Custom name
            distance: userDistance,
            color: userColor,    // Custom color
            emoji: userEmoji,    // Custom emoji
            profileImageData: nil,
            isCurrentUser: true,
            locationCount: userAnimationIndex + 1
        ))
        
        // Add visible friends
        for friend in friends where friend.isVisible {
            let friendIndex = friendAnimationIndices[friend.id] ?? 0
            let friendDistance = calculateDistance(
                locations: friend.coordinates,
                upToIndex: friendIndex
            )
            
            entries.append(LeaderboardEntry(
                id: friend.id,
                name: friend.name,
                distance: friendDistance,
                color: friend.color,
                emoji: friend.emoji,
                profileImageData: friend.profileImageData,
                isCurrentUser: false,
                locationCount: friendIndex + 1
            ))
        }
        
        // Sort by distance (highest first) and assign ranks
        entries.sort { $0.distance > $1.distance }
        for i in 0..<entries.count {
            entries[i].rank = i + 1
        }
        
        return entries
    }
}

// MARK: - Compact Leaderboard View (Minimal Sidebar - NO backgrounds)

struct CompactLeaderboardView: View {
    let entries: [LeaderboardEntry]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Top 3 entries
            ForEach(entries.prefix(3)) { entry in
                CompactLeaderboardRow(entry: entry)
            }
            
            // Show "You" if not in top 3
            if let userEntry = entries.first(where: { $0.isCurrentUser }),
               userEntry.rank > 3 {
                
                // Dots separator
                Text("...")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.vertical, 1)
                    .padding(.leading, 2)
                
                CompactLeaderboardRow(entry: userEntry)
            }
        }
    }
}

struct CompactLeaderboardRow: View {
    let entry: LeaderboardEntry
    
    var body: some View {
        HStack(spacing: 5) {
            // Medal/Rank
            ZStack {
                Circle()
                    .fill(entry.medal.color)
                    .frame(width: 16, height: 16)
                
                if entry.medal != .none {
                    Image(systemName: entry.medal.icon)
                        .font(.system(size: 8))
                        .foregroundColor(.white)
                } else {
                    Text("\(entry.rank)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 2)
            
            // Profile Picture or Emoji
            ZStack {
                Circle()
                    .fill(Color(hex: entry.color) ?? .gray)
                    .frame(width: 18, height: 18)
                
                if let imageData = entry.profileImageData,
                   let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 16, height: 16)
                        .clipShape(Circle())
                } else {
                    Text(entry.emoji)
                        .font(.system(size: 10))
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 2)
            
            // Name
            Text(entry.name)
                .font(.system(size: 10, weight: entry.isCurrentUser ? .bold : .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
                .shadow(color: .black.opacity(0.5), radius: 2)
            
            // Distance
            Text(String(format: "%.1f", entry.distance))
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.5), radius: 2)
            
            // Star for current user
            if entry.isCurrentUser {
                Image(systemName: "star.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.yellow)
                    .shadow(color: .black.opacity(0.5), radius: 2)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
    }
}

// MARK: - Expanded Leaderboard View (Full Screen Modal)

struct ExpandedLeaderboardView: View {
    let entries: [LeaderboardEntry]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.opacity(0.95).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // Podium for top 3
                        if entries.count >= 3 {
                            PodiumView(
                                first: entries[0],
                                second: entries[1],
                                third: entries[2]
                            )
                            .padding(.vertical, 30)
                        }
                        
                        Divider()
                            .background(Color.white.opacity(0.3))
                            .padding(.vertical, 20)
                        
                        // Full list
                        VStack(spacing: 12) {
                            ForEach(entries) { entry in
                                ExpandedLeaderboardRow(entry: entry)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Leaderboard")
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
}

// MARK: - Podium View

struct PodiumView: View {
    let first: LeaderboardEntry
    let second: LeaderboardEntry
    let third: LeaderboardEntry
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 20) {
            // Second place
            PodiumSpot(entry: second, height: 100)
            
            // First place (tallest)
            PodiumSpot(entry: first, height: 140)
            
            // Third place
            PodiumSpot(entry: third, height: 80)
        }
        .padding(.horizontal, 30)
    }
}

struct PodiumSpot: View {
    let entry: LeaderboardEntry
    let height: CGFloat
    
    var body: some View {
        VStack(spacing: 8) {
            // Medal
            Image(systemName: entry.medal.icon)
                .font(.system(size: 30))
                .foregroundColor(entry.medal.color)
            
            // Profile
            ZStack {
                Circle()
                    .fill(Color(hex: entry.color) ?? .gray)
                    .frame(width: 60, height: 60)
                
                if let imageData = entry.profileImageData,
                   let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                } else {
                    Text(entry.emoji)
                        .font(.system(size: 30))
                }
            }
            
            // Name
            Text(entry.name)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
            
            // Distance
            Text(String(format: "%.1f mi", entry.distance))
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.8))
            
            // Podium base
            RoundedRectangle(cornerRadius: 8)
                .fill(entry.medal.color.opacity(0.3))
                .frame(width: 80, height: height)
                .overlay(
                    Text("\(entry.rank)")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white.opacity(0.3))
                )
        }
    }
}

// MARK: - Expanded Row

struct ExpandedLeaderboardRow: View {
    let entry: LeaderboardEntry
    
    var body: some View {
        HStack(spacing: 15) {
            // Rank with medal
            ZStack {
                Circle()
                    .fill(entry.medal.color)
                    .frame(width: 40, height: 40)
                
                if entry.medal != .none {
                    Image(systemName: entry.medal.icon)
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                } else {
                    Text("\(entry.rank)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // Profile
            ZStack {
                Circle()
                    .fill(Color(hex: entry.color) ?? .gray)
                    .frame(width: 50, height: 50)
                
                if let imageData = entry.profileImageData,
                   let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 46, height: 46)
                        .clipShape(Circle())
                } else {
                    Text(entry.emoji)
                        .font(.system(size: 24))
                }
            }
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.name)
                        .font(.system(size: 18, weight: entry.isCurrentUser ? .bold : .semibold))
                        .foregroundColor(.white)
                    
                    if entry.isCurrentUser {
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.yellow)
                    }
                }
                
                Text(String(format: "%.2f miles", entry.distance))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Color indicator
            Circle()
                .fill(Color(hex: entry.color) ?? .gray)
                .frame(width: 12, height: 12)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(entry.isCurrentUser ? Color.blue.opacity(0.2) : Color.white.opacity(0.05))
        )
    }
}

// MARK: - Stats Summary View (For Statistics Tab)

struct FriendStatsView: View {
    let entries: [LeaderboardEntry]
    
    var body: some View {
        VStack(spacing: 20) {
            // Total stats
            GroupBox(label: Label("Race Summary", systemImage: "flag.checkered.2.crossed")) {
                VStack(spacing: 15) {
                    StatRow(
                        label: "Total Participants",
                        value: "\(entries.count)"
                    )
                    
                    if let leader = entries.first {
                        StatRow(
                            label: "Leader",
                            value: leader.name
                        )
                        
                        StatRow(
                            label: "Longest Journey",
                            value: String(format: "%.1f mi", leader.distance)
                        )
                    }
                    
                    if entries.count > 1 {
                        let totalDistance = entries.reduce(0) { $0 + $1.distance }
                        StatRow(
                            label: "Combined Distance",
                            value: String(format: "%.1f mi", totalDistance)
                        )
                        
                        let avgDistance = totalDistance / Double(entries.count)
                        StatRow(
                            label: "Average Distance",
                            value: String(format: "%.1f mi", avgDistance)
                        )
                    }
                }
                .padding(.vertical, 5)
            }
            .padding(.horizontal)
            
            FriendComparisonStats(entries: entries)
            
            // Individual stats
            VStack(alignment: .leading, spacing: 10) {
                Text("Individual Stats")
                    .font(.headline)
                    .padding(.horizontal)
                
                ForEach(entries) { entry in
                    FriendStatCard(entry: entry)
                }
            }
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }
}

struct FriendStatCard: View {
    let entry: LeaderboardEntry
    
    var body: some View {
        HStack(spacing: 15) {
            // Profile
            ZStack {
                Circle()
                    .fill(Color(hex: entry.color) ?? .gray)
                    .frame(width: 50, height: 50)
                
                if let imageData = entry.profileImageData,
                   let image = UIImage(data: imageData) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 46, height: 46)
                        .clipShape(Circle())
                } else {
                    Text(entry.emoji)
                        .font(.system(size: 24))
                }
                
                // Medal overlay
                if entry.medal != .none {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: entry.medal.icon)
                                .font(.system(size: 16))
                                .foregroundColor(entry.medal.color)
                                .background(
                                    Circle()
                                        .fill(Color.black)
                                        .frame(width: 24, height: 24)
                                )
                        }
                        Spacer()
                    }
                    .frame(width: 50, height: 50)
                }
            }
            
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(entry.name)
                        .font(.headline)
                    
                    if entry.isCurrentUser {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
                
                HStack(spacing: 20) {
                    Label(String(format: "%.1f mi", entry.distance), systemImage: "figure.walk")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Label("Rank #\(entry.rank)", systemImage: "trophy")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
        .padding(.horizontal)
    }
}

// MARK: - Friend Comparison Stats

struct FriendComparisonStats: View {
    let entries: [LeaderboardEntry]
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Fun Comparisons")
                .font(.title2)
                .bold()
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 15) {
                // Champion Explorer
                if let champion = entries.max(by: { getLocationCount($0) < getLocationCount($1) }) {
                    ComparisonCard(
                        title: "🏆 Champion Explorer",
                        winner: champion.name,
                        value: "\(getLocationCount(champion)) locations",
                        description: "Most places visited",
                        color: .orange
                    )
                }
                
                // Distance Legend
                if let distanceKing = entries.max(by: { $0.distance < $1.distance }) {
                    ComparisonCard(
                        title: "🌍 Distance Legend",
                        winner: distanceKing.name,
                        value: String(format: "%.1f mi", distanceKing.distance),
                        description: "Farthest journey",
                        color: .blue
                    )
                }
                
                // Hometown
                if let homebody = entries.min(by: { getAvgDistance($0) < getAvgDistance($1) }) {
                    ComparisonCard(
                        title: "🏠 Hometown Hero",
                        winner: homebody.name,
                        value: String(format: "%.1f mi avg", getAvgDistance(homebody)),
                        description: "Smallest jumps between locations",
                        color: .green
                    )
                }
                
                // Speed Demon
                if let speedster = entries.max(by: { getAvgDistance($0) < getAvgDistance($1) }) {
                    ComparisonCard(
                        title: "⚡ Speed Demon",
                        winner: speedster.name,
                        value: String(format: "%.1f mi avg", getAvgDistance(speedster)),
                        description: "Biggest jumps between locations",
                        color: .purple
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    // Helper to get location count (need to pass this from parent)
    private func getLocationCount(_ entry: LeaderboardEntry) -> Int {
        return entry.locationCount  // Now using real data!
    }

    private func getAvgDistance(_ entry: LeaderboardEntry) -> Double {
        guard entry.locationCount > 0 else { return 0 }
        return entry.distance / Double(entry.locationCount)
    }
}

struct ComparisonCard: View {
    let title: String
    let winner: String
    let value: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 15) {
            // Icon
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay(
                    Text(title.prefix(2))
                        .font(.system(size: 28))
                )
            
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(color)
                
                Text(winner)
                    .font(.title3)
                    .bold()
                
                HStack(spacing: 8) {
                    Text(value)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("•")
                        .foregroundColor(.secondary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}
