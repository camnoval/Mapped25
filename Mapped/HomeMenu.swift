import SwiftUI

struct HomeMenu: View {
    @Binding var selectedFeature: String?
    @Binding var isHomeMenu: Bool
    
    // Cohesive color palette - warm, vibrant tones
    private let warmYellow = Color(red: 1.0, green: 0.75, blue: 0.3)
    private let softBlue = Color(red: 0.4, green: 0.7, blue: 1.0)
    private let deepPurple = Color(red: 0.5, green: 0.3, blue: 0.8)
    private let coral = Color(red: 1.0, green: 0.45, blue: 0.5)
    private let mintGreen = Color(red: 0.3, green: 0.8, blue: 0.7)
    private let peach = Color(red: 1.0, green: 0.6, blue: 0.4)
    private let slate = Color(red: 0.5, green: 0.55, blue: 0.6)
    
    var body: some View {
        ZStack {
            // Background to cover safe area
            slate.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // TOP ROW
                HStack(spacing: 0) {
                    Button(action: { selectedFeature = "YourStory"; isHomeMenu = false }) {
                        VStack(spacing: ResponsiveLayout.dynamicSpacing(base: 12)) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 50)))
                            Text("Year in Review")
                                .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 17), weight: .semibold))
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.8)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(warmYellow)
                        .foregroundColor(.white)
                    }
                    
                    Button(action: { selectedFeature = "Map"; isHomeMenu = false }) {
                        VStack(spacing: ResponsiveLayout.dynamicSpacing(base: 12)) {
                            Image(systemName: "map")
                                .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 50)))
                            Text("Map")
                                .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 17), weight: .semibold))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(softBlue)
                        .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // MIDDLE ROW
                HStack(spacing: 0) {
                    Button(action: { selectedFeature = "Constellation"; isHomeMenu = false }) {
                        VStack(spacing: ResponsiveLayout.dynamicSpacing(base: 12)) {
                            Image(systemName: "star.fill")
                                .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 50)))
                            Text("Constellation")
                                .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 17), weight: .semibold))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(deepPurple)
                        .foregroundColor(.white)
                    }
                    
                    Button(action: { selectedFeature = "Share"; isHomeMenu = false }) {
                        VStack(spacing: ResponsiveLayout.dynamicSpacing(base: 12)) {
                            Image(systemName: "video.fill")
                                .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 50)))
                            Text("Video & Share")
                                .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 17), weight: .semibold))
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.8)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(coral)
                        .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // BOTTOM ROW
                HStack(spacing: 0) {
                    Button(action: { selectedFeature = "Statistics"; isHomeMenu = false }) {
                        VStack(spacing: ResponsiveLayout.dynamicSpacing(base: 12)) {
                            Image(systemName: "chart.bar.fill")
                                .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 50)))
                            Text("Statistics")
                                .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 17), weight: .semibold))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(mintGreen)
                        .foregroundColor(.white)
                    }
                    
                    Button(action: { selectedFeature = "Friends"; isHomeMenu = false }) {
                        VStack(spacing: ResponsiveLayout.dynamicSpacing(base: 12)) {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 50)))
                            Text("Friends")
                                .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 17), weight: .semibold))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(peach)
                        .foregroundColor(.white)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // SETTINGS ROW - Larger and pushed down
                Button(action: { selectedFeature = "Settings"; isHomeMenu = false }) {
                    VStack(spacing: ResponsiveLayout.dynamicSpacing(base: 12)) {
                        Image(systemName: "gear")
                            .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 50)))
                        Text("Settings")
                            .font(.system(size: ResponsiveLayout.dynamicFontSize(base: 17), weight: .semibold))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(slate)
                    .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .frame(height: ResponsiveLayout.scaleHeight(160))
            }
        }
    }
}
