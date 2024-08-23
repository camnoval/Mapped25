import Foundation
import SwiftUI
import CoreLocation

struct StatisticsSection: View {
    let statistics: [String: String]
    @ObservedObject var photoLoader: PhotoLoader
    
    @State private var selectedTab = 0  // ADD: 0 = User, 1 = Friends
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Statistics")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Track your journey")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.top, 30)
                
                // ADD: Tab Picker
                Picker("Stats Type", selection: $selectedTab) {
                    Text("Your Stats").tag(0)
                    Text("Friends").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // UPDATED: Show content based on selected tab
                if selectedTab == 0 {
                    userStatsView
                } else {
                    friendsStatsView
                }
                
                Spacer(minLength: 30)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // NEW: User Stats View (your existing personal stats)
    private var userStatsView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your Personal Stats")
                .font(.title2)
                .bold()
                .padding(.horizontal)
            
            LazyVStack(spacing: 15) {
                ForEach(statistics.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    StatCard(title: key, value: value)
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 30)
    }
    
    // NEW: Friends Stats View (leaderboard)
    private var friendsStatsView: some View {
        VStack(spacing: 20) {
            if photoLoader.friends.isEmpty {
                // Empty state
                VStack(spacing: 20) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 80))
                        .foregroundColor(.gray.opacity(0.5))
                    
                    Text("No Friends Yet")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.gray)
                    
                    Text("Import friends to see comparison stats")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.vertical, 60)
            } else {
                // Generate final leaderboard (all locations completed)
                let finalLeaderboard = LeaderboardCalculator.generateLeaderboard(
                    userLocations: photoLoader.locations,
                    userAnimationIndex: photoLoader.locations.count - 1,
                    friends: photoLoader.friends,
                    friendAnimationIndices: photoLoader.friends.reduce(into: [:]) { dict, friend in
                        dict[friend.id] = friend.coordinates.count - 1
                    }
                )
                
                FriendStatsView(entries: finalLeaderboard)
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.title2)
                    .bold()
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            // Icon based on stat type
            Image(systemName: iconForStat(title))
                .font(.system(size: 30))
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
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
        case let t where t.contains("place") || t.contains("location"):
            return "mappin.and.ellipse"
        case let t where t.contains("avg"):
            return "chart.line.uptrend.xyaxis"
        default:
            return "star.fill"
        }
    }
}

// Preview
//struct StatisticsSection_Previews: PreviewProvider {
//    static var previews: some View {
//        StatisticsSection(statistics: [
//            "Photos with Location": "247",
//            "Total Distance": "1,234.5 km",
//            "Date Range": "Jan 1 - Dec 31",
//            "Most Active Month": "July (45 photos)",
//            "Unique Places": "23",
//            "Longest Gap": "14 days"
//        ], photoLoader: PhotoLoader)
//    }
//}
