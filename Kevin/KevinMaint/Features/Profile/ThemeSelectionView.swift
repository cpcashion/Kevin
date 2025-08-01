import SwiftUI

struct ThemeSelectionView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 1) {
            // Light Theme Option
            ThemeOptionView(
                icon: "sun.max.fill",
                title: "Light Theme",
                subtitle: "Bright and clean interface",
                isSelected: appState.currentTheme == .light,
                themeMode: .light
            ) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    appState.currentTheme = .light
                }
            }
            
            // Dark Theme Option
            ThemeOptionView(
                icon: "moon.fill",
                title: "Dark Theme",
                subtitle: "Easy on the eyes in low light",
                isSelected: appState.currentTheme == .dark,
                themeMode: .dark
            ) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    appState.currentTheme = .dark
                }
            }
        }
    }
}

struct ThemeOptionView: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let themeMode: ThemeMode
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Theme preview circle with icon
                ZStack {
                    Circle()
                        .fill(previewBackgroundColor)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(previewBorderColor, lineWidth: 1)
                        )
                    
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(previewIconColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(KMTheme.primaryText)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(KMTheme.secondaryText)
                }
                
                Spacer()
                
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(KMTheme.border, lineWidth: 2)
                        .frame(width: 20, height: 20)
                    
                    if isSelected {
                        Circle()
                            .fill(KMTheme.accent)
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(KMTheme.cardBackground)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Theme preview colors
    private var previewBackgroundColor: Color {
        switch themeMode {
        case .light:
            return Color(red: 0xF9/255.0, green: 0xF9/255.0, blue: 0xF9/255.0) // #F9F9F9
        case .dark:
            return Color(red: 0x14/255.0, green: 0x19/255.0, blue: 0x26/255.0) // Dark blue
        }
    }
    
    private var previewBorderColor: Color {
        switch themeMode {
        case .light:
            return Color(red: 0x98/255.0, green: 0xC3/255.0, blue: 0xD8/255.0) // #98C3D8
        case .dark:
            return Color(red: 0.2, green: 0.6, blue: 1.0) // Vibrant blue
        }
    }
    
    private var previewIconColor: Color {
        switch themeMode {
        case .light:
            return Color(red: 0x98/255.0, green: 0xC3/255.0, blue: 0xD8/255.0) // #98C3D8
        case .dark:
            return Color(red: 0.2, green: 0.6, blue: 1.0) // Vibrant blue
        }
    }
}

#Preview {
    VStack {
        ThemeSelectionView()
            .environmentObject(AppState())
    }
    .background(KMTheme.background)
}
