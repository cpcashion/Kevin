import SwiftUI
import UIKit

enum ThemeMode {
  case light
  case dark
}

enum KMTheme {
  // Theme state - follows system appearance by default
  private static var _manualTheme: ThemeMode?
  
  static var currentTheme: ThemeMode {
    get {
      // Always return dark theme - hardcoded as requested
      return .dark
    }
    set {
      // No-op - theme is hardcoded to dark
    }
  }
  
  static func clearManualTheme() {
    _manualTheme = nil
  }
  
  static func setSystemTheme() {
    _manualTheme = nil
  }
  
  // MARK: - Dynamic Colors
  
  // Primary Colors
  static var accent: Color {
    switch currentTheme {
    case .dark:
      return Color(red: 0.2, green: 0.6, blue: 1.0) // Vibrant blue
    case .light:
      return Color(red: 0x98/255.0, green: 0xC3/255.0, blue: 0xD8/255.0) // #98C3D8 - soft blue
    }
  }
  
  static var accentDark: Color {
    switch currentTheme {
    case .dark:
      return Color(red: 0.1, green: 0.5, blue: 0.9) // Darker blue
    case .light:
      return Color(red: 0x70/255.0, green: 0xA5/255.0, blue: 0xC0/255.0) // Darker version of #98C3D8
    }
  }
  
  // Background Colors
  static var background: Color {
    switch currentTheme {
    case .dark:
      return Color(red: 0x14/255.0, green: 0x19/255.0, blue: 0x26/255.0) // #141926 - dark blue background
    case .light:
      return Color(red: 0xF8/255.0, green: 0xF8/255.0, blue: 0xF6/255.0) // #F8F8F6 - warm light background
    }
  }
  
  static var cardBackground: Color {
    switch currentTheme {
    case .dark:
      return Color(red: 0x1A/255.0, green: 0x1F/255.0, blue: 0x2D/255.0) // #1A1F2D - elevated dark blue card
    case .light:
      return Color.white // #FFFFFF - pure white cards
    }
  }
  
  static var surfaceBackground: Color {
    switch currentTheme {
    case .dark:
      return Color(red: 0x20/255.0, green: 0x25/255.0, blue: 0x34/255.0) // #202534 - higher elevation dark blue
    case .light:
      return Color.white // Pure white for elevated surfaces
    }
  }
  
  // Text Colors
  static var primaryText: Color {
    switch currentTheme {
    case .dark:
      return Color.white
    case .light:
      return Color(red: 0.1, green: 0.1, blue: 0.1) // Dark gray for readability
    }
  }
  
  static var secondaryText: Color {
    switch currentTheme {
    case .dark:
      return Color(red: 0.8, green: 0.8, blue: 0.8)
    case .light:
      return Color(red: 0.4, green: 0.4, blue: 0.4) // Medium gray
    }
  }
  
  static var tertiaryText: Color {
    switch currentTheme {
    case .dark:
      return Color(red: 0.6, green: 0.6, blue: 0.6)
    case .light:
      return Color(red: 0.6, green: 0.6, blue: 0.6) // Light gray
    }
  }
  
  // Status Colors - Unified system for all status displays
  static var success: Color {
    switch currentTheme {
    case .dark:
      return Color(red: 0.5, green: 0.9, blue: 0.3) // Bright lime green
    case .light:
      return Color(red: 0x6B/255.0, green: 0xB3/255.0, blue: 0x2A/255.0) // Darker green from #EBFF9A palette
    }
  }
  
  static var warning: Color {
    switch currentTheme {
    case .dark:
      return Color(red: 1.0, green: 0.6, blue: 0.0) // Orange
    case .light:
      return Color(red: 0.9, green: 0.5, blue: 0.0) // Slightly darker orange
    }
  }
  
  static var danger: Color {
    switch currentTheme {
    case .dark:
      return Color(red: 1.0, green: 0.4, blue: 0.6)
    case .light:
      return Color(red: 0xF4/255.0, green: 0x71/255.0, blue: 0xB5/255.0)
    }
  }
  
  static var progress: Color {
    switch currentTheme {
    case .dark:
      return Color(red: 0.4, green: 0.7, blue: 1.0) // Blue
    case .light:
      return Color(red: 0x98/255.0, green: 0xC3/255.0, blue: 0xD8/255.0) // #98C3D8 - matches accent
    }
  }
  
  static var highPriority: Color {
    switch currentTheme {
    case .dark:
      return Color(red: 1.0, green: 0.6, blue: 0.0) // Orange
    case .light:
      return Color(red: 0.9, green: 0.5, blue: 0.0) // Slightly darker orange
    }
  }
  
  // Input Field Colors
  static var inputBackground: Color {
    switch currentTheme {
    case .dark:
      return Color(red: 0x2A/255.0, green: 0x2F/255.0, blue: 0x3E/255.0) // #2A2F3E - dark input background
    case .light:
      return Color.white // White background for light theme
    }
  }
  
  static var inputText: Color {
    switch currentTheme {
    case .dark:
      return Color.white // White text for dark input background
    case .light:
      return Color(red: 0.1, green: 0.1, blue: 0.1) // Dark text for light input background
    }
  }
  
  static var inputPlaceholder: Color {
    switch currentTheme {
    case .dark:
      return Color(red: 0.7, green: 0.7, blue: 0.7) // Light gray placeholder for dark background
    case .light:
      return Color(red: 0.6, green: 0.6, blue: 0.6) // Medium gray placeholder for light background
    }
  }
  
  static var inputBorder: Color {
    switch currentTheme {
    case .dark:
      return Color(red: 0x3A/255.0, green: 0x3F/255.0, blue: 0x4E/255.0) // #3A3F4E - darker border for dark theme
    case .light:
      return Color(red: 0.85, green: 0.85, blue: 0.85) // Light gray border for light theme
    }
  }
  
  // Border Colors
  static var border: Color {
    switch currentTheme {
    case .dark:
      return Color(red: 0x2A/255.0, green: 0x2F/255.0, blue: 0x3E/255.0) // #2A2F3E - subtle dark blue border
    case .light:
      return Color(red: 0.85, green: 0.85, blue: 0.85) // Light gray border
    }
  }
  
  static var borderSecondary: Color {
    switch currentTheme {
    case .dark:
      return Color(red: 0x16/255.0, green: 0x1B/255.0, blue: 0x28/255.0) // #161B28 - darker blue border
    case .light:
      return Color(red: 0.9, green: 0.9, blue: 0.9) // Very light gray border
    }
  }
  
  // AI Colors
  static var aiGreen: Color {
    switch currentTheme {
    case .dark:
      return Color(red: 0.5, green: 0.9, blue: 0.3) // Bright lime green
    case .light:
      return Color(red: 0xEB/255.0, green: 0xFF/255.0, blue: 0x9A/255.0) // #EBFF9A - light green
    }
  }
  
  static var aiGreenDark: Color {
    switch currentTheme {
    case .dark:
      return Color(red: 0.4, green: 0.8, blue: 0.2) // Darker lime green
    case .light:
      return Color(red: 0xC5/255.0, green: 0xE5/255.0, blue: 0x70/255.0) // Darker version of #EBFF9A
    }
  }
  
  // MARK: - Design System Rules
  // Card Spacing: 12pt between elements, 16pt padding
  // Corner Radius: 12pt for cards, 8pt for small elements
  // Typography: .headline for titles, .body for content, .caption for metadata
  // Status Display: Single StatusPill per item, positioned top-right
  // Information Hierarchy: Title → Status → Description → Metadata
}
