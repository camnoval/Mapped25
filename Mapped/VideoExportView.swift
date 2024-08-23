import SwiftUI
import AVKit
import UserNotifications

struct VideoExportView: View {
    @ObservedObject var photoLoader: PhotoLoader
    @ObservedObject var videoExporter: VideoExporter
    @State private var showExportTimeAlert = false
    let statistics: [String: String]
    
    @State private var showVideoPlayer = false
    @State private var showShareSheet = false
    
    //Initialize with a shared VideoExporter instance
    init(photoLoader: PhotoLoader, statistics: [String: String]) {
        self.photoLoader = photoLoader
        self.statistics = statistics
        
        // Get or create the shared exporter instance
        if photoLoader.videoExporter == nil {
            photoLoader.videoExporter = VideoExporter()
        }
        self.videoExporter = photoLoader.videoExporter!
    }
    
    var body: some View {
            ZStack {
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        VStack(spacing: 10) {
                            Image(systemName: "video.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("Export Your Video")
                                .font(.largeTitle)
                                .bold()
                            
                            Text("Create a shareable 15-second video")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 30)
                        
                        // Preview/Status
                        if let videoURL = videoExporter.exportedVideoURL {
                            VStack(spacing: 20) {
                                // Video preview
                                VideoPreview(url: videoURL)
                                    .frame(height: 500)
                                    .cornerRadius(20)
                                    .shadow(radius: 10)
                                
                                // Action buttons
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
                                
                                Button(action: exportVideo) {
                                    Label("Export Again", systemImage: "arrow.clockwise")
                                        .font(.headline)
                                        .foregroundColor(.blue)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(10)
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            // Export status
                            VStack(spacing: 20) {
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
                                
                                // Info card
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
                                    }
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(15)
                                .padding(.horizontal)
                                
                                Button(action: {
                                    print("🎬 Create Video button tapped")
                                    UNUserNotificationCenter.current().getNotificationSettings { settings in
                                        print("📱 Notification status: \(settings.authorizationStatus.rawValue)")
                                        DispatchQueue.main.async {
                                            if settings.authorizationStatus == .notDetermined {
                                                print("⚠️ Showing alert")
                                                showExportTimeAlert = true
                                            } else {
                                                print("✅ Already determined, starting export")
                                                exportVideo()
                                            }
                                        }
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "play.rectangle.fill")
                                        Text("Create Video")
                                    }
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(15)
                                }
                                .padding(.horizontal)
                                .disabled(photoLoader.locations.isEmpty)
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
                                    Text("This may take 1-2 minutes. We'll notify you when it's done so you can navigate away.")
                                }
                            }
                        }
                        
                        // Error message
                        if let error = videoExporter.exportError {
                            Text(error)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                        
                        Spacer(minLength: 50)
                    }
                }
                
                // Export overlay
                if videoExporter.isExporting {
                    Color.black.opacity(0.7)
                        .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 30) {
                        ProgressView(value: videoExporter.exportProgress)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(2)
                        
                        VStack(spacing: 10) {
                            Text("Creating Your Video")
                                .font(.title2)
                                .bold()
                                .foregroundColor(.white)
                            
                            Text("\(Int(videoExporter.exportProgress * 100))%")
                                .font(.title)
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
            .sheet(isPresented: $showVideoPlayer) {
                if let url = videoExporter.exportedVideoURL {
                    VideoPlayerView(url: url)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = videoExporter.exportedVideoURL {
                    ShareSheetVideo(items: [url])
                }
            }
        }
        
    private func exportVideo() {
        videoExporter.exportVideo(
            locations: photoLoader.locations,
            timestamps: photoLoader.photoTimeStamps,
            statistics: statistics,
            friends: photoLoader.getVisibleFriends(),
            loadPhotosFromCache: true  // ← Changed: simple boolean flag
        ) { result in
            switch result {
            case .success(let url):
                print("✅ Video exported to: \(url)")
            case .failure(let error):
                print("❌ Export failed: \(error)")
            }
        }
    }
    }

// MARK: - Video Preview

struct VideoPreview: View {
    let url: URL
    
    var body: some View {
        VideoPlayer(player: AVPlayer(url: url))
            .disabled(true)
    }
}


// MARK: - Share Sheet

struct ShareSheetVideo: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
