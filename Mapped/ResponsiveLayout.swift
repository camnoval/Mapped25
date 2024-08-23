//
//  ResponsiveLayout.swift
//  Mapped
//
//  Created by Noval, Cameron on 11/18/25.
//

import UIKit
import SwiftUI

/// Universal layout helper for all iPhone sizes
struct ResponsiveLayout {
    
    // MARK: - Screen Dimensions
    
    static var screenWidth: CGFloat {
        UIScreen.main.bounds.width
    }
    
    static var screenHeight: CGFloat {
        UIScreen.main.bounds.height
    }
    
    static var screenSize: CGSize {
        UIScreen.main.bounds.size
    }
    
    // MARK: - Device Categories
    
    enum DeviceSize {
        case small      
        case medium
        case large
        case extraLarge
        
        static var current: DeviceSize {
            let width = UIScreen.main.bounds.width
            if width <= 375 {
                return .small
            } else if width <= 393 {
                return .medium
            } else if width <= 430 {
                return .large
            } else {
                return .extraLarge
            }
        }
        
        var isSmall: Bool { self == .small }
        var isMedium: Bool { self == .medium }
        var isLarge: Bool { self == .large }
    }
    
    // MARK: - Scaling Functions
    
    /// Scale a value based on screen width (base: iPhone 14 Pro = 393)
    static func scaleWidth(_ value: CGFloat) -> CGFloat {
        let baseWidth: CGFloat = 393
        return value * (screenWidth / baseWidth)
    }
    
    /// Scale a value based on screen height (base: iPhone 14 Pro = 852)
    static func scaleHeight(_ value: CGFloat) -> CGFloat {
        let baseHeight: CGFloat = 852
        return value * (screenHeight / baseHeight)
    }
    
    /// Scale a value proportionally (uses smaller of width/height scaling)
    static func scale(_ value: CGFloat) -> CGFloat {
        return min(scaleWidth(value), scaleHeight(value))
    }
    
    // MARK: - Font Sizes
    
    static func fontSize(small: CGFloat, medium: CGFloat, large: CGFloat) -> CGFloat {
        switch DeviceSize.current {
        case .small:
            return small
        case .medium:
            return medium
        case .large, .extraLarge:
            return large
        }
    }
    
    static func dynamicFontSize(base: CGFloat) -> CGFloat {
        switch DeviceSize.current {
        case .small:
            return base * 0.85
        case .medium:
            return base
        case .large:
            return base * 1.1
        case .extraLarge:
            return base * 1.15
        }
    }
    
    // MARK: - Spacing
    
    static func spacing(small: CGFloat, medium: CGFloat, large: CGFloat) -> CGFloat {
        switch DeviceSize.current {
        case .small:
            return small
        case .medium:
            return medium
        case .large, .extraLarge:
            return large
        }
    }
    
    static func dynamicSpacing(base: CGFloat) -> CGFloat {
        scale(base)
    }
    
    // MARK: - Padding
    
    static var horizontalPadding: CGFloat {
        spacing(small: 16, medium: 20, large: 24)
    }
    
    static var verticalPadding: CGFloat {
        spacing(small: 12, medium: 16, large: 20)
    }
    
    // MARK: - Safe Areas
    
    static var safeAreaTop: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 0
    }
    
    static var safeAreaBottom: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.bottom ?? 0
    }
    
    // MARK: - Video Export Dimensions
    
    /// Standard video dimensions (9:16 aspect ratio)
    static var videoSize: CGSize {
        // Use screen proportions but standardize to common video resolutions
        let aspectRatio: CGFloat = 9.0 / 16.0
        
        // Target 720p vertical video for all devices (good quality, reasonable size)
        let width: CGFloat = 720
        let height: CGFloat = width / aspectRatio
        
        return CGSize(width: width, height: height)
    }
    
    /// High quality image export dimensions (9:16 aspect ratio)
    static var exportImageSize: CGSize {
        // Always use 1080x1920 for share images (Instagram Story standard)
        return CGSize(width: 1080, height: 1920)
    }
    
    // MARK: - Constellation View
    
    static var constellationSnapshotSize: CGSize {
        // Use export image size for consistency
        return exportImageSize
    }
    
    // MARK: - Map Annotations
    
    static var photoMarkerSize: CGFloat {
        scale(32) // Base 32, scales with device
    }
    
    static var walkerMarkerSize: CGFloat {
        scale(28) // Base 28, scales with device
    }
    
    // MARK: - Button Sizes
    
    static var standardButtonHeight: CGFloat {
        spacing(small: 44, medium: 50, large: 56)
    }
    
    static var compactButtonHeight: CGFloat {
        spacing(small: 36, medium: 40, large: 44)
    }
    
    // MARK: - Card Dimensions
    
    static func cardHeight(base: CGFloat) -> CGFloat {
        scaleHeight(base)
    }
    
    static var standardCornerRadius: CGFloat {
        scale(15)
    }
    
    // MARK: - Icon Sizes
    
    static func iconSize(base: CGFloat) -> CGFloat {
        scale(base)
    }
    
    // MARK: - Collage Layout (Video Export)
    
    static var collageStartY: CGFloat {
        // Scale based on video height
        return (videoSize.height * 0.625) + scaleHeight(35) // 62.5% down the screen
    }
    
    static var collageHeight: CGFloat {
        videoSize.height - collageStartY - scaleHeight(20)
    }
    
    static var collageWidth: CGFloat {
        videoSize.width - scaleWidth(60)
    }
    
    static var collageX: CGFloat {
        scaleWidth(30)
    }
    
    static var photoSizes: [CGFloat] {
        let baseSizes: [CGFloat] = [55, 60, 65, 70, 75, 80, 85, 90, 95, 100, 110]
        return baseSizes.map { scale($0) }
    }
}

// MARK: - SwiftUI Extensions

extension View {
    func responsivePadding() -> some View {
        self.padding(.horizontal, ResponsiveLayout.horizontalPadding)
            .padding(.vertical, ResponsiveLayout.verticalPadding)
    }
    
    func responsiveFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        self.font(.system(size: ResponsiveLayout.dynamicFontSize(base: size), weight: weight))
    }
}

// MARK: - UIKit Helpers

extension ResponsiveLayout {
    /// Create a properly sized rendering context for the current device
    static func createImageRenderer(size: CGSize? = nil) -> UIGraphicsImageRenderer {
        let targetSize = size ?? screenSize
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: targetSize, format: format)
    }
    
    /// Get optimal JPEG compression based on device
    static var jpegQuality: CGFloat {
        switch DeviceSize.current {
        case .small:
            return 0.7
        case .medium:
            return 0.8
        case .large, .extraLarge:
            return 0.85
        }
    }
}
