import SwiftUI
// MARK: - Analysis Results Panel
struct AnalysisResultsPanel: View {
    let result: AnalysisResult
    let capturedImage: UIImage?
    @Binding var voiceTranscription: String
    @Binding var selectedPriority: String
    let isDetectingLocation: Bool
    let onSelectLocation: () -> Void
    let onRetake: () -> Void
    
    @State private var showingFullImage = false
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Large photo thumbnail at top
                if let image = capturedImage {
                    Button(action: { showingFullImage = true }) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(KMTheme.border, lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Kevin's AI Analysis Header
                HStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.title2)
                        .foregroundColor(KMTheme.accent)
                    
                    Text("Kevin's AI Analysis")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(KMTheme.accent)
                    
                    Spacer()
                }
                .padding(.top, 8)
                
                // Full analysis description
                Text(result.description)
                    .font(.body)
                    .foregroundColor(KMTheme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Recommendations section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recommendations:")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(KMTheme.primaryText)
                    
                    ForEach(Array(result.recommendations.enumerated()), id: \.offset) { index, recommendation in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .foregroundColor(KMTheme.primaryText)
                            Text(recommendation)
                                .font(.body)
                                .foregroundColor(KMTheme.primaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Voice Description Button
                VoiceDescriptionButton(
                    transcribedText: $voiceTranscription,
                    onTranscriptionComplete: { _ in
                        // Voice transcription updated via binding
                    }
                )
                
                // Priority selection
                PrioritySelectionSection(selectedPriority: $selectedPriority)
                
                // Action buttons
                ActionButtonsSection(
                    isDetectingLocation: isDetectingLocation,
                    onSelectLocation: onSelectLocation,
                    onRetake: onRetake
                )
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 100)
        }
        .background(KMTheme.background)
        .fullScreenCover(isPresented: $showingFullImage) {
            if let image = capturedImage {
                FullScreenImageView(image: image, isPresented: $showingFullImage)
            }
        }
    }
}

// MARK: - Drag Handle
struct DragHandle: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(KMTheme.tertiaryText)
            .frame(width: 40, height: 4)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }
}

// MARK: - Results Header
struct ResultsHeader: View {
    let result: AnalysisResult
    let capturedImage: UIImage?
    let onImageTap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Image thumbnail
            if let image = capturedImage {
                Button(action: onImageTap) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        )
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Issue details
            VStack(alignment: .leading, spacing: 8) {
                Text(result.title)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                HStack(spacing: 12) {
                    // Severity badge
                    SeverityBadge(severity: result.severity)
                    
                    // Category
                    CategoryBadge(category: result.category)
                }
                
                // Confidence indicator
                ConfidenceIndicator(confidence: result.confidence)
            }
            
            Spacer()
        }
    }
}

// MARK: - Severity Badge
struct SeverityBadge: View {
    let severity: IssueSeverity
    
    var body: some View {
        Text(severity.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(severity.color)
            .cornerRadius(6)
    }
}

// MARK: - Category Badge
struct CategoryBadge: View {
    let category: String
    
    var body: some View {
        Text(category)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white.opacity(0.8))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.white.opacity(0.2))
            .cornerRadius(6)
    }
}

// MARK: - Confidence Indicator
struct ConfidenceIndicator: View {
    let confidence: Double
    
    var body: some View {
        HStack(spacing: 8) {
            Text("Confidence")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.white.opacity(0.2))
                        .frame(height: 4)
                    
                    RoundedRectangle(cornerRadius: 2)
                        .fill(
                            LinearGradient(
                                colors: [KMTheme.accent, KMTheme.accent.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * confidence, height: 4)
                }
            }
            .frame(height: 4)
            
            Text("\(Int(confidence * 100))%")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(KMTheme.accent)
        }
    }
}

// MARK: - Metrics Section
struct MetricsSection: View {
    let result: AnalysisResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Estimated Details")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            HStack(spacing: 16) {
                AnalysisMetricCard(
                    icon: "dollarsign.circle",
                    title: "Cost",
                    value: result.estimatedCost,
                    color: KMTheme.success
                )
                
                AnalysisMetricCard(
                    icon: "clock",
                    title: "Time",
                    value: result.timeToFix,
                    color: KMTheme.accent
                )
            }
        }
    }
}

// MARK: - Analysis Metric Card
struct AnalysisMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding(16)
        .background(.white.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Recommendations Section
struct RecommendationsSection: View {
    let recommendations: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recommended Actions")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(recommendations.enumerated()), id: \.offset) { index, recommendation in
                    RecommendationRow(
                        number: index + 1,
                        text: recommendation
                    )
                }
            }
        }
    }
}

// MARK: - Recommendation Row
struct RecommendationRow: View {
    let number: Int
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step number
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(KMTheme.accent)
                .clipShape(Circle())
            
            // Recommendation text
            Text(text)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer()
        }
    }
}

// MARK: - Voice Transcription Section
struct VoiceTranscriptionSection: View {
    let transcription: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(KMTheme.accent)
                
                Text("Voice Notes")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            
            Text(transcription)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.9))
                .padding(16)
                .background(.white.opacity(0.1))
                .cornerRadius(12)
        }
    }
}

// MARK: - Action Buttons Section
struct ActionButtonsSection: View {
    let isDetectingLocation: Bool
    let onSelectLocation: () -> Void
    let onRetake: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Primary action - Select Location
            Button(action: onSelectLocation) {
                HStack(spacing: 8) {
                    if isDetectingLocation {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Detecting Location...")
                            .font(.headline)
                            .fontWeight(.semibold)
                    } else {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 18, weight: .medium))
                        Text("Select Location")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isDetectingLocation ? KMTheme.accent.opacity(0.6) : KMTheme.accent)
                .cornerRadius(12)
            }
            .disabled(isDetectingLocation)
            .buttonStyle(PlainButtonStyle())
            
            // Secondary action - Retake (same size as primary)
            Button(action: onRetake) {
                HStack(spacing: 8) {
                    Image(systemName: "camera.rotate")
                        .font(.system(size: 18, weight: .medium))
                    
                    Text("Retake Photo")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(KMTheme.cardBackground)
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}

// MARK: - Full Screen Image View
struct FullScreenImageView: View {
    let image: UIImage
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                HStack {
                    Spacer()
                    
                    Button("Done") {
                        isPresented = false
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                }
                
                Spacer()
                
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding()
                
                Spacer()
            }
        }
    }
}

// MARK: - Corner Radius Extension
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Priority Selection Section
struct PrioritySelectionSection: View {
    @Binding var selectedPriority: String
    
    let priorities = [
        ("Low", "bookmark.fill", "Can wait for scheduled maintenance", Color.green),
        ("Normal", "calendar", "Standard repair timeline", Color.blue),
        ("High", "wrench.fill", "Needs attention within 24 hours", Color.pink)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(KMTheme.warning)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Priority Level")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(KMTheme.primaryText)
                    
                    Text("Tap to override AI's assessment")
                        .font(.caption)
                        .foregroundColor(KMTheme.secondaryText)
                }
                
                Spacer()
                
                if selectedPriority != "Normal" {
                    Button("Reset") {
                        selectedPriority = "Normal"
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(KMTheme.accent)
                }
            }
            
            VStack(spacing: 12) {
                ForEach(priorities, id: \.0) { priority in
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedPriority = priority.0
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                        }
                    }) {
                        HStack(spacing: 12) {
                            // Priority Icon
                            ZStack {
                                Circle()
                                    .fill(priority.3.opacity(0.15))
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: priority.1)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(priority.3)
                            }
                            
                            // Priority Info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(priority.0)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(KMTheme.primaryText)
                                
                                Text(priority.2)
                                    .font(.subheadline)
                                    .foregroundColor(KMTheme.secondaryText)
                            }
                            
                            Spacer()
                            
                            // Selection Indicator
                            if selectedPriority == priority.0 {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(priority.3)
                            } else {
                                Circle()
                                    .stroke(KMTheme.border, lineWidth: 2)
                                    .frame(width: 24, height: 24)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            selectedPriority == priority.0 ?
                                priority.3.opacity(0.08) :
                                KMTheme.cardBackground
                        )
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    selectedPriority == priority.0 ?
                                        priority.3.opacity(0.5) :
                                        KMTheme.border,
                                    lineWidth: selectedPriority == priority.0 ? 2 : 1
                                )
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(20)
        .background(KMTheme.cardBackground.opacity(0.5))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(KMTheme.border, lineWidth: 0.5)
        )
    }
}

// MARK: - Preview
struct AnalysisResultsPanel_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                Spacer()
                
                AnalysisResultsPanel(
                    result: AnalysisResult(
                        title: "Broken Window",
                        description: "The window appears to be cracked and needs immediate attention.",
                        severity: .high,
                        estimatedCost: "$200-300",
                        timeToFix: "2-3 hours",
                        recommendations: [
                            "Replace the broken glass",
                            "Check window frame for damage",
                            "Clean up any glass shard"
                        ],
                        confidence: 0.95,
                        category: "Window"
                    ),
                    capturedImage: nil,
                    voiceTranscription: .constant("The door handle is really loose and wobbly when you try to open it."),
                    selectedPriority: .constant("Normal"),
                    isDetectingLocation: false,
                    onSelectLocation: { print("Select location") },
                    onRetake: { print("Retake") }
                )
            }
        }
    }
}
