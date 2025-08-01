import SwiftUI

// MARK: - Analysis Progress With Image
struct AnalysisProgressWithImage: View {
    let image: UIImage
    @State private var scanlinePosition: CGFloat = 0
    @State private var progress: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Captured photo as background
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                
                // Dark overlay
                KMTheme.background.opacity(0.7)
                
                // Scanning effect
                VStack {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [.clear, KMTheme.accent.opacity(0.8), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: 3)
                        .offset(y: scanlinePosition)
                        .animation(.linear(duration: 2.5).repeatForever(autoreverses: false), value: scanlinePosition)
                        .onAppear {
                            scanlinePosition = geometry.size.height
                        }
                    
                    Spacer()
                }
                
                // Analysis status card - centered
                VStack {
                    Spacer()
                    
                    VStack(spacing: 20) {
                        // AI icon with pulse
                        ZStack {
                            Circle()
                                .fill(KMTheme.accent.opacity(0.2))
                                .frame(width: 70, height: 70)
                            
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(KMTheme.accent)
                        }
                        
                        VStack(spacing: 12) {
                            Text("Analyzing Image")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(KMTheme.primaryText)
                            
                            Text("Kevin's AI is examining the issue...")
                                .font(.subheadline)
                                .foregroundColor(KMTheme.secondaryText)
                                .multilineTextAlignment(.center)
                            
                            // Progress bar
                            ProgressBar(progress: progress)
                                .frame(width: 200)
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 3)) {
                                        progress = 1.0
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 28)
                    .background(KMTheme.cardBackground.opacity(0.95))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(KMTheme.border, lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    
                    Spacer()
                }
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Analysis Progress
struct AnalysisProgress: View {
    @State private var progress: CGFloat = 0
    @State private var pulseAnimation = false
    
    var body: some View {
        VStack(spacing: 24) {
            // AI Brain Icon with pulse
            ZStack {
                Circle()
                    .fill(KMTheme.accent.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .opacity(pulseAnimation ? 0.3 : 0.6)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulseAnimation)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(KMTheme.accent)
            }
            .onAppear {
                pulseAnimation = true
            }
            
            // Progress content
            VStack(spacing: 16) {
                Text("Analyzing Image")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(KMTheme.primaryText)
                
                Text("Kevin's AI is examining the issue...")
                    .font(.subheadline)
                    .foregroundColor(KMTheme.secondaryText)
                    .multilineTextAlignment(.center)
                
                // Progress bar
                ProgressBar(progress: progress)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 3)) {
                            progress = 1.0
                        }
                    }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .background(KMTheme.cardBackground.opacity(0.95))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(KMTheme.border, lineWidth: 1)
        )
    }
}

// MARK: - Progress Bar
struct ProgressBar: View {
    let progress: CGFloat
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: 2)
                    .fill(KMTheme.border)
                    .frame(height: 4)
                
                // Progress fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [KMTheme.accent, KMTheme.accent.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * progress, height: 4)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Error Panel
struct ErrorPanel: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Error icon
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.red)
            }
            
            // Error content
            VStack(spacing: 12) {
                Text("Analysis Failed")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(KMTheme.primaryText)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(KMTheme.secondaryText)
                    .multilineTextAlignment(.center)
                
                // Retry button
                Button(action: onRetry) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                        
                        Text("Try Again")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(KMTheme.primaryText)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(KMTheme.accent)
                    .cornerRadius(25)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .background(KMTheme.cardBackground.opacity(0.95))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(KMTheme.border, lineWidth: 1)
        )
    }
}

// MARK: - Preview
struct AnalysisProgress_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            KMTheme.background.ignoresSafeArea()
            
            VStack(spacing: 40) {
                AnalysisProgress()
                
                ErrorPanel(
                    message: "Unable to analyze the image. Please try again.",
                    onRetry: { print("Retry tapped") }
                )
            }
        }
    }
}
