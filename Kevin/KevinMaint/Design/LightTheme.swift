import SwiftUI

struct LightTheme {
    // MARK: - Base Colors
    static let background = Color(red: 0.98, green: 0.98, blue: 0.99) // Off-white with subtle warmth
    static let cardBackground = Color.white
    static let surfaceBackground = Color(red: 0.96, green: 0.97, blue: 0.98) // Subtle gray-blue
    
    // MARK: - Text Colors
    static let primaryText = Color(red: 0.15, green: 0.15, blue: 0.15) // Soft black
    static let secondaryText = Color(red: 0.45, green: 0.45, blue: 0.45) // Medium gray
    static let tertiaryText = Color(red: 0.65, green: 0.65, blue: 0.65) // Light gray
    
    // MARK: - Accent Colors (Muted versions)
    static let accent = Color(red: 0.2, green: 0.6, blue: 0.9) // Soft blue
    static let accentLight = Color(red: 0.85, green: 0.93, blue: 0.98) // Very light blue
    
    // MARK: - Status Colors (Muted)
    static let success = Color(red: 0.2, green: 0.7, blue: 0.4) // Muted green
    static let successLight = Color(red: 0.9, green: 0.97, blue: 0.92) // Light green bg
    
    static let warning = Color(red: 0.9, green: 0.6, blue: 0.1) // Muted orange
    static let warningLight = Color(red: 0.98, green: 0.95, blue: 0.88) // Light orange bg
    
    static let error = Color(red: 0.85, green: 0.3, blue: 0.3) // Muted red
    static let errorLight = Color(red: 0.98, green: 0.92, blue: 0.92) // Light red bg
    
    // MARK: - Priority Colors
    static let lowPriority = Color(red: 0.5, green: 0.7, blue: 0.9) // Soft blue
    static let mediumPriority = Color(red: 0.9, green: 0.7, blue: 0.3) // Soft yellow
    static let highPriority = Color(red: 0.9, green: 0.5, blue: 0.4) // Soft coral
    static let urgentPriority = Color(red: 0.85, green: 0.3, blue: 0.3) // Muted red
    
    // MARK: - Status Badge Colors
    static let openStatus = Color(red: 0.6, green: 0.6, blue: 0.6) // Neutral gray
    static let inProgressStatus = Color(red: 0.2, green: 0.6, blue: 0.9) // Soft blue
    static let waitingStatus = Color(red: 0.9, green: 0.6, blue: 0.1) // Muted orange
    static let completedStatus = Color(red: 0.2, green: 0.7, blue: 0.4) // Muted green
    
    // MARK: - Border Colors
    static let border = Color(red: 0.9, green: 0.9, blue: 0.9) // Very light gray
    static let borderLight = Color(red: 0.95, green: 0.95, blue: 0.95) // Ultra light gray
    
    // MARK: - Shadow
    static let shadow = Color.black.opacity(0.05) // Very subtle shadow
    
    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.custom("SF Pro Display", size: 28).weight(.bold)
        static let title = Font.custom("SF Pro Display", size: 22).weight(.semibold)
        static let headline = Font.custom("SF Pro Display", size: 18).weight(.semibold)
        static let body = Font.custom("SF Pro Text", size: 16).weight(.regular)
        static let bodyMedium = Font.custom("SF Pro Text", size: 16).weight(.medium)
        static let callout = Font.custom("SF Pro Text", size: 15).weight(.regular)
        static let subheadline = Font.custom("SF Pro Text", size: 14).weight(.medium)
        static let footnote = Font.custom("SF Pro Text", size: 13).weight(.regular)
        static let caption = Font.custom("SF Pro Text", size: 12).weight(.regular)
    }
    
    // MARK: - Spacing
    struct Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }
    
    // MARK: - Corner Radius
    struct CornerRadius {
        static let sm: CGFloat = 6
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }
}
