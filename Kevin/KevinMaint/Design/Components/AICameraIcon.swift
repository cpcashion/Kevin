import SwiftUI

struct AICameraIcon: View {
    let size: CGFloat
    let color: Color
    
    init(size: CGFloat = 24, color: Color = KMTheme.primaryText) {
        self.size = size
        self.color = color
    }
    
    var body: some View {
        ZStack {
            // Camera outline
            RoundedRectangle(cornerRadius: size * 0.15)
                .stroke(color, lineWidth: size * 0.08)
                .frame(width: size * 0.9, height: size * 0.7)
            
            // Camera lens circle
            Circle()
                .stroke(color, lineWidth: size * 0.06)
                .frame(width: size * 0.45, height: size * 0.45)
            
            // Camera top bump
            RoundedRectangle(cornerRadius: size * 0.08)
                .fill(color.opacity(0.1))
                .frame(width: size * 0.3, height: size * 0.15)
                .offset(y: -size * 0.42)
            
            // AI sparkles inside the lens
            ZStack {
                // Main star in center
                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.2, weight: .medium))
                    .foregroundColor(color)
                
                // Smaller sparkles around
                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.12, weight: .light))
                    .foregroundColor(color.opacity(0.8))
                    .offset(x: -size * 0.1, y: -size * 0.08)
                
                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.1, weight: .light))
                    .foregroundColor(color.opacity(0.6))
                    .offset(x: size * 0.12, y: size * 0.06)
                
                Image(systemName: "sparkle")
                    .font(.system(size: size * 0.08, weight: .ultraLight))
                    .foregroundColor(color.opacity(0.5))
                    .offset(x: size * 0.05, y: -size * 0.12)
            }
        }
        .frame(width: size, height: size)
    }
}

// Preview
struct AICameraIcon_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AICameraIcon(size: 32, color: KMTheme.accent)
            AICameraIcon(size: 24, color: KMTheme.primaryText)
            AICameraIcon(size: 20, color: KMTheme.secondaryText)
        }
        .padding()
        .background(KMTheme.background)
        .previewLayout(.sizeThatFits)
    }
}
