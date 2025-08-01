import SwiftUI

struct AIAnalysisLoader: View {
    let hasError: Bool
    let errorMessage: String?
    let debugImage: UIImage?
    let onDebugTapped: (() -> Void)?
    let onRetryTapped: (() -> Void)?
    
    @State private var isAnimating = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotationAngle: Double = 0
    @State private var sparkleOpacity: Double = 0.3
    @State private var progressValue: Double = 0.0
    
    init(
        hasError: Bool = false,
        errorMessage: String? = nil,
        debugImage: UIImage? = nil,
        onDebugTapped: (() -> Void)? = nil,
        onRetryTapped: (() -> Void)? = nil
    ) {
        self.hasError = hasError
        self.errorMessage = errorMessage
        self.debugImage = debugImage
        self.onDebugTapped = onDebugTapped
        self.onRetryTapped = onRetryTapped
    }
    
    let analysisSteps = [
        "Analyzing image...",
        "Identifying damage...",
        "Generating recommendations...",
        "Finalizing report..."
    ]
    
    @State private var currentStep = 0
    @State private var stepProgress: Double = 0.0
    
    var body: some View {
        VStack(spacing: 24) {
            if hasError {
                errorContent
            } else {
                progressContent
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(KMTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(KMTheme.accent.opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            if !hasError {
                startAnimation()
            }
        }
    }
    
    private var progressContent: some View {
        VStack(spacing: 12) {
            // Current step text
            Text(analysisSteps[currentStep])
                .font(.headline)
                .fontWeight(.medium)
                .foregroundColor(KMTheme.primaryText)
                .animation(.easeInOut(duration: 0.3), value: currentStep)
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background
                    RoundedRectangle(cornerRadius: 8)
                        .fill(KMTheme.accent.opacity(0.1))
                        .frame(height: 8)
                    
                    // Progress fill with gradient
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: [KMTheme.accent, KMTheme.success, KMTheme.danger],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progressValue, height: 8)
                        .animation(.easeInOut(duration: 0.5), value: progressValue)
                }
            }
            .frame(height: 8)
            
            // Progress percentage
            Text("\(Int(progressValue * 100))%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(KMTheme.secondaryText)
        }
    }
    
    private var errorContent: some View {
        VStack(spacing: 20) {
            // Error icon
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(KMTheme.danger)
            
            // Error message
            VStack(spacing: 8) {
                Text("AI Analysis Failed")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(KMTheme.primaryText)
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(KMTheme.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Action buttons
            VStack(spacing: 12) {
                if let onRetryTapped = onRetryTapped {
                    Button(action: onRetryTapped) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Retry Analysis")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(KMTheme.accent)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                
                if let onDebugTapped = onDebugTapped, debugImage != nil {
                    Button(action: onDebugTapped) {
                        HStack {
                            Image(systemName: "wrench.and.screwdriver")
                            Text("Debug Analysis")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(KMTheme.cardBackground)
                        .foregroundColor(KMTheme.primaryText)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(KMTheme.accent, lineWidth: 1)
                        )
                    }
                }
            }
        }
    }
    
    private func startAnimation() {
        // Simulate step-by-step progress
        simulateProgress()
    }
    
    private func simulateProgress() {
        let stepDuration: Double = 1.0
        let totalSteps = analysisSteps.count
        
        for step in 0..<totalSteps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(step) * stepDuration) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentStep = step
                }
                
                // Animate progress within each step
                let stepProgressDuration = stepDuration * 0.8
                withAnimation(.easeInOut(duration: stepProgressDuration)) {
                    progressValue = Double(step + 1) / Double(totalSteps)
                }
            }
        }
    }
}

struct AIAnalysisLoader_Previews: PreviewProvider {
    static var previews: some View {
        AIAnalysisLoader()
            .padding()
            .background(KMTheme.background)
            .previewLayout(.sizeThatFits)
    }
}
