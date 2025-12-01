//
//  OnboardingView.swift
//  Mapped
//
//  Created by Noval, Cameron on 11/17/25.
//

import Foundation
import SwiftUI
import Photos

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    @State private var showLoadingScreen = false
    
    var body: some View {
        ZStack {
            if !showLoadingScreen {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Page content
                    TabView(selection: $currentPage) {
                        OnboardingPage1()
                            .tag(0)
                        
                        OnboardingPage2()
                            .tag(1)
                        
                        OnboardingPage3(onContinue: {
                            showLoadingScreen = true
                        })
                        .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .indexViewStyle(.page(backgroundDisplayMode: .always))
                }
            } else {

                PhotoLoadingScreen(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
    }
}

// MARK: - Page 1: Welcome

struct OnboardingPage1: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // App icon/logo
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "map.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 15) {
                Text("Welcome to")
                    .font(.title2)
                    .foregroundColor(.secondary)
                
                Text("2025 Mapped")
                    .font(.system(size: 44, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text("Map your year in photos")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // Swipe indicator
            VStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Swipe to continue")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 40)
        }
        .padding()
    }
}

// MARK: - Page 2: Privacy

struct OnboardingPage2: View {
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Privacy icon
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
            }
            
            VStack(spacing: 15) {
                Text("Privacy First")
                    .font(.system(size: 36, weight: .bold))
                
                Text("Your photos never leave your device")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Feature list
            VStack(alignment: .leading, spacing: 20) {
                PrivacyFeatureRow(
                    icon: "iphone",
                    text: "All processing happens on your device"
                )
                
                PrivacyFeatureRow(
                    icon: "network.slash",
                    text: "No data sent to servers"
                )
                
                PrivacyFeatureRow(
                    icon: "location.fill",
                    text: "GPS data stays private"
                )
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Swipe indicator
            VStack(spacing: 8) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundColor(.blue)
                Text("Swipe to continue")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 40)
        }
        .padding()
    }
}

struct PrivacyFeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
                .frame(width: 30)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Page 3: Permission

struct OnboardingPage3: View {
    let onContinue: () -> Void
    @State private var showPermissionAlert = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Photo icon
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 120, height: 120)
                
                Image(systemName: "photo.stack.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 15) {
                Text("Access Your Photos")
                    .font(.system(size: 36, weight: .bold))
                
                Text("We'll analyze GPS data from your 2025 photos to create your year map")
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // What we'll show
            VStack(alignment: .leading, spacing: 20) {
                InfoRow(
                    icon: "map",
                    title: "Interactive Map",
                    description: "See everywhere you've been"
                )
                
                InfoRow(
                    icon: "chart.bar",
                    title: "Statistics",
                    description: "Distance, places, highlights"
                )
                
                InfoRow(
                    icon: "sparkles",
                    title: "Constellation View",
                    description: "Your journey as stars"
                )
            }
            .padding(.horizontal, 30)
            
            Spacer()
            
            // Continue button
            Button(action: handleGetStarted) {
                HStack {
                    Text("Get Started")
                        .font(.headline)
                    Image(systemName: "arrow.right")
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [Color.blue, Color.blue.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(15)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .padding()
        .alert("Photo Access Required", isPresented: $showPermissionAlert) {
            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Try Again") {
                handleGetStarted()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please grant access to your photo library to use this app. You can change this in Settings.")
        }
    }
    
    private func handleGetStarted() {
        // Request photo permission
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    onContinue()
                    
                case .denied, .restricted:
                    // Show alert to go to settings
                    showPermissionAlert = true
                    
                case .notDetermined:
                    // This shouldn't happen, but handle it
                    showPermissionAlert = true
                    
                @unknown default:
                    showPermissionAlert = true
                }
            }
        }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - Photo loading screen

struct PhotoLoadingScreen: View {
    @Binding var hasCompletedOnboarding: Bool
    @StateObject private var photoLoader = PhotoLoader()
    @State private var loadingPhase: LoadingPhase = .starting
    @State private var showCarousel = false
    @State private var fakeProgress: Double = 0.0
    @State private var useFakeProgress = true
    @State private var progressTimer: Timer?
    @State private var hasTriggeredTransition = false
    @State private var failsafeTimer: Timer?
    
    // ADD: Constellation state for YearStoryCarousel
    @State private var constellationScale: CGFloat = 1.0
    @State private var constellationRotation: Angle = .zero
    @State private var constellationBackgroundStars: [(x: CGFloat, y: CGFloat, size: CGFloat, opacity: Double)] = []
    @State private var constellationStars: [ConstellationStar] = []
    @State private var constellationConnections: [ConstellationConnection] = []
    
    enum LoadingPhase {
        case starting
        case loadingPhotos
        case findingLocations
        case analyzingJourney
        case creatingStory
        case complete
        
        var message: String {
            switch self {
            case .starting: return "Getting started..."
            case .loadingPhotos: return "Loading your photos..."
            case .findingLocations: return "Finding your locations..."
            case .analyzingJourney: return "Analyzing your journey..."
            case .creatingStory: return "Creating your story..."
            case .complete: return "Ready!"
            }
        }
        
        var progress: Double {
            switch self {
            case .starting: return 0.0
            case .loadingPhotos: return 0.2
            case .findingLocations: return 0.4
            case .analyzingJourney: return 0.6
            case .creatingStory: return 0.8
            case .complete: return 1.0
            }
        }
    }
    
    private var displayProgress: Double {
        if useFakeProgress {
            return fakeProgress
        } else {
            return min(fakeProgress, photoLoader.loadingProgress)
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if !showCarousel {
                VStack(spacing: 40) {
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: loadingPhase == .complete ? "checkmark.circle.fill" : "map.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                            .scaleEffect(loadingPhase == .complete ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: loadingPhase)
                    }
                    
                    VStack(spacing: 15) {
                        Text(loadingPhase.message)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .id(loadingPhase)
                            .transition(.opacity)
                        
                        if photoLoader.photosYear > 0 && photoLoader.photosYear != Calendar.current.component(.year, from: Date()) {
                            Text("No \(String(Calendar.current.component(.year, from: Date()))) photos found. Loading \(String(photoLoader.photosYear)) photos, the most recent year available.")
                                .font(.caption)
                                .foregroundColor(.yellow.opacity(0.9))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 30)
                        }
                        
                        ProgressView(value: displayProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .white))
                            .frame(width: 250)
                        
                        Text("\(Int(displayProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    Text(getLoadingTip())
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 50)
                        .padding(.bottom, 40)
                }
            } else {
                YearStoryCarousel(
                    photoLoader: photoLoader,
                    hasCompletedOnboarding: $hasCompletedOnboarding,
                    selectedFeature: .constant(nil),
                    isHomeMenu: .constant(true),
                    constellationScale: $constellationScale,
                    constellationRotation: $constellationRotation,
                    constellationBackgroundStars: $constellationBackgroundStars,
                    constellationStars: $constellationStars,
                    constellationConnections: $constellationConnections
                )
            }
        }
        .onAppear {
            print("🎬 PhotoLoadingScreen appeared")
            startFakeProgress()
            loadPhotos()
            startFailsafeTimer()
        }
        .onDisappear {
            print("🎬 PhotoLoadingScreen disappeared")
            progressTimer?.invalidate()
            failsafeTimer?.invalidate()
        }
        .onChange(of: displayProgress) { newValue in
            updateLoadingPhase(progress: newValue)
        }
        // ✅ FIXED: Only trigger on completion, not on intermediate states
        .onChange(of: photoLoader.isLoading) { isLoading in
            if !isLoading && photoLoader.loadingProgress >= 0.99 {
                print("✅ Loading complete, building constellation")
                buildConstellationForCarousel()
                
                // Wait for constellation to build before transitioning
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.checkAndTransition()
                }
            }
        }
    }
    
    // Helper Functions
    
    private func buildConstellationForCarousel() {
        guard constellationStars.isEmpty && !photoLoader.locations.isEmpty else { return }
        
        print("🌟 Pre-building constellation for carousel...")
        
        let buildSize = CGSize(width: 600, height: 600)
        
        let constellation = ConstellationBuilder.buildConstellation(
            locations: photoLoader.locations,
            viewSize: buildSize
        )
        
        constellationStars = constellation.stars
        constellationConnections = constellation.connections
        
        print("✅ Pre-built \(constellation.stars.count) stars for carousel")
    }
    
    private func startFailsafeTimer() {
        failsafeTimer?.invalidate()
        
        var checksWithoutProgress = 0
        var lastProgress: Double = 0.0
        
        failsafeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in  // ✅ Removed [weak self]
            let currentProgress = self.displayProgress
            
            // Check if progress is stuck
            if abs(currentProgress - lastProgress) < 0.001 {
                checksWithoutProgress += 1
            } else {
                checksWithoutProgress = 0
            }
            lastProgress = currentProgress
            
            print("🔍 FAILSAFE: progress=\(currentProgress), stuck=\(checksWithoutProgress), isLoading=\(self.photoLoader.isLoading), locations=\(self.photoLoader.locations.count)")
            
            if !self.hasTriggeredTransition {
                // Force transition if:
                // 1. Stuck at same progress for 5+ seconds
                // 2. At 100% and loading complete
                // 3. Has locations and loading complete
                // 4. Has error message
                
                let stuckTooLong = checksWithoutProgress >= 5
                let atComplete = currentProgress >= 0.99 && !self.photoLoader.isLoading
                let hasData = self.photoLoader.locations.count > 0 && !self.photoLoader.isLoading
                let hasError = self.photoLoader.errorMessage != nil
                
                if stuckTooLong || atComplete || hasData || hasError {
                    print("⚠️ FAILSAFE TRIGGERED: stuck=\(stuckTooLong), complete=\(atComplete), data=\(hasData), error=\(hasError)")
                    self.checkAndTransition()
                }
            }
        }
    }
    
    private func checkAndTransition() {
        guard !hasTriggeredTransition else {
            print("⏭️ Transition already triggered, skipping")
            return
        }
        
        let shouldTransition = !photoLoader.isLoading &&
                              (photoLoader.locations.count > 0 || displayProgress >= 0.99 || photoLoader.errorMessage != nil)
        
        if shouldTransition {
            print("🎯 Triggering transition: locations=\(photoLoader.locations.count), progress=\(displayProgress), error=\(photoLoader.errorMessage != nil)")
            hasTriggeredTransition = true
            
            progressTimer?.invalidate()
            failsafeTimer?.invalidate()
            
            DispatchQueue.main.async {
                self.loadingPhase = .complete
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation(.spring(response: 0.6)) {
                    self.showCarousel = true
                }
            }
        }
    }
    
    private func startFakeProgress() {
        let updateInterval: Double = 0.05
        
        progressTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { timer in
            DispatchQueue.main.async {
                if self.useFakeProgress {
                    let fastIncrement: Double = (0.7 / 5.0) * updateInterval
                    if self.fakeProgress < 0.7 {
                        self.fakeProgress += fastIncrement
                    } else {
                        self.useFakeProgress = false
                    }
                } else {
                    let slowIncrement: Double = 0.002
                    if self.fakeProgress < 1.0 {
                        self.fakeProgress += slowIncrement
                    }
                    
                    if self.fakeProgress >= 1.0 {
                        timer.invalidate()
                    }
                }
            }
        }
    }
    
    private func loadPhotos() {
        photoLoader.checkPhotoLibraryPermission()
    }
    
    private func updateLoadingPhase(progress: Double) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if progress < 0.2 {
                loadingPhase = .loadingPhotos
            } else if progress < 0.4 {
                loadingPhase = .findingLocations
            } else if progress < 0.6 {
                loadingPhase = .analyzingJourney
            } else if progress < 0.8 {
                loadingPhase = .creatingStory
            } else if progress >= 1.0 {
                loadingPhase = .complete
            } else {
                loadingPhase = .creatingStory
            }
        }
    }
    
    private func getLoadingTip() -> String {
        let tips = [
            "✨ Your photos are processed entirely on your device",
            "🔒 No data ever leaves your phone",
            "🌍 We're mapping your entire year",
            "⭐ Creating something special for you",
            "📸 Analyzing GPS data from your photos",
            "🗺️ Building your personal journey map"
        ]
        
        let tipIndex = Int(displayProgress * Double(tips.count - 1))
        return tips[min(tipIndex, tips.count - 1)]
    }
}

// MARK: - Preview

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(hasCompletedOnboarding: .constant(false))
    }
}
