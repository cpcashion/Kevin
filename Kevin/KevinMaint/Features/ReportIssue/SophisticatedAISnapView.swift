import SwiftUI
import PhotosUI
import AVFoundation
import Combine

// MARK: - Analysis State Management
enum AnalysisState: Equatable {
    case ready
    case analyzing
    case completed
    case creating  // Creating issue after location confirmation
    case error(String)
}

struct AnalysisResult {
    let title: String
    let description: String
    let severity: IssueSeverity
    let estimatedCost: String
    let timeToFix: String
    let recommendations: [String]
    let confidence: Double
    let category: String
}

enum IssueSeverity {
    case low, medium, high
    
    var color: Color {
        switch self {
        case .low: return KMTheme.success
        case .medium: return KMTheme.warning
        case .high: return KMTheme.danger
        }
    }
    
    var displayName: String {
        switch self {
        case .low: return "Low Priority"
        case .medium: return "Medium Priority"
        case .high: return "High Priority"
        }
    }
}

// MARK: - Sophisticated AI Snap View
struct SophisticatedAISnapView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedTab: Int
    @Binding var issuesFilter: IssueStatusFilter
    
    @State private var analysisState: AnalysisState = .ready
    @State private var analysisResult: AnalysisResult?
    @State private var capturedImage: UIImage?
    @State private var showingPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    // Location detection
    @StateObject private var magicalLocationService = MagicalLocationService.shared
    @State private var showingLocationSelection = false
    @State private var locationContext: LocationContext?
    @State private var selectedRestaurant: NearbyBusiness?
    
    // Priority selection
    @State private var selectedPriority: String = "Normal" // Default to Normal
    
    // Voice transcription
    @State private var voiceTranscription: String = ""
    
    private var aiService: AIService { AIService.shared }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Full-screen camera interface (hide when analyzing or completed)
                if analysisState == .ready {
                    CameraInterface(
                        onCapture: handlePhotoCapture,
                        isAnalyzing: false
                    )
                    .ignoresSafeArea()
                } else {
                    // Show dark background when not in camera mode
                    KMTheme.background.ignoresSafeArea()
                }
                
                // Overlay UI based on state
                VStack {
                    Spacer()
                    
                    switch analysisState {
                    case .ready:
                        CaptureControls(
                            onCameraCapture: triggerCameraCapture,
                            onPhotoLibrary: { showingPhotoPicker = true }
                        )
                        
                    case .analyzing:
                        VStack(spacing: 24) {
                            // Show captured image preview with animated border
                            if let image = capturedImage {
                                AnimatedBorderImageView(image: image)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 500)
                                    .padding(.horizontal, 24)
                            }
                            
                            // AI Analysis Loader
                            AIAnalysisLoader()
                                .padding(.horizontal, 24)
                        }
                        .padding(.bottom, 100)
                        
                    case .completed:
                        if let result = analysisResult {
                            AnalysisResultsPanel(
                                result: result,
                                capturedImage: capturedImage,
                                voiceTranscription: $voiceTranscription,
                                selectedPriority: $selectedPriority,
                                isDetectingLocation: magicalLocationService.isDetectingLocation,
                                onSelectLocation: proceedToLocationSelection,
                                onRetake: resetToReady
                            )
                        }
                        
                    case .creating:
                        VStack(spacing: 24) {
                            // Success animation with scale effect
                            ZStack {
                                Circle()
                                    .fill(KMTheme.success.opacity(0.2))
                                    .frame(width: 120, height: 120)
                                    .scaleEffect(1.0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.1), value: analysisState)
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(KMTheme.success)
                                    .scaleEffect(1.0)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2), value: analysisState)
                            }
                            .padding(.top, 100)
                            .transition(.scale.combined(with: .opacity))
                            
                            VStack(spacing: 12) {
                                Text("Issue Created!")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(KMTheme.primaryText)
                                
                                if let restaurant = selectedRestaurant {
                                    Text("at \(restaurant.name)")
                                        .font(.body)
                                        .foregroundColor(KMTheme.secondaryText)
                                }
                            }
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        
                    case .error(let message):
                        ErrorPanel(
                            message: message,
                            onRetry: resetToReady
                        )
                    }
                }
            }
            .background(KMTheme.background)
            .navigationBarHidden(true)
            .statusBarHidden()
            .preferredColorScheme(.dark)
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    handlePhotoCapture(image)
                }
            }
        }
        .overlay(locationCardOverlay)
    }
    
    // MARK: - Location Card Overlay
    private var locationCardOverlay: some View {
        Group {
            if showingLocationSelection, let context = locationContext {
                MagicalLocationCard(
                    locationContext: context,
                    selectedRestaurant: $selectedRestaurant,
                    onConfirm: { business in
                        confirmLocationAndCreateIssue(business)
                    },
                    onDismiss: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            showingLocationSelection = false
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingLocationSelection)
            }
        }
    }
    
    // MARK: - Action Handlers
    private func triggerCameraCapture() {
        print("📸 [SophisticatedAISnapView] Camera capture triggered")
        
        // IMMEDIATE UI FEEDBACK: Show analyzing state instantly
        analysisState = .analyzing
        
        // Trigger camera capture via notification
        NotificationCenter.default.post(name: NSNotification.Name("TriggerCameraCapture"), object: nil)
    }
    
    private func handlePhotoCapture(_ image: UIImage) {
        print("📸 [SophisticatedAISnapView] Photo captured, starting AI analysis immediately")
        
        capturedImage = image
        
        // CRITICAL: Set analyzing state immediately to show progress UI
        print("🎬 [SophisticatedAISnapView] Setting analysisState to .analyzing")
        withAnimation(.easeInOut(duration: 0.3)) {
            analysisState = .analyzing
        }
        print("🎬 [SophisticatedAISnapView] analysisState is now: \(analysisState)")
        
        // Start AI analysis immediately
        Task {
            await analyzePhoto(image)
        }
    }
    
    private func analyzePhoto(_ image: UIImage) async {
        do {
            // Call existing AI service with user ID
            let analysis = try await aiService.analyzeImage(image, userId: appState.currentAppUser?.id, appState: appState)
            
            // Convert to our result format
            let result = AnalysisResult(
                title: analysis.summary ?? analysis.description,
                description: analysis.description,
                severity: mapPriorityToSeverity(analysis.priority),
                estimatedCost: formatEstimatedCost(analysis.estimatedCost),
                timeToFix: analysis.timeToComplete ?? "TBD",
                recommendations: analysis.recommendations ?? [],
                confidence: analysis.confidence ?? 0.8,
                category: analysis.category ?? "General"
            )
            
            await MainActor.run {
                self.analysisResult = result
                // Set priority based on AI analysis
                switch result.severity {
                case .low:
                    self.selectedPriority = "Low"
                case .medium:
                    self.selectedPriority = "Normal"
                case .high:
                    self.selectedPriority = "High"
                }
                self.analysisState = .completed
                // Don't auto-trigger location - wait for user to tap button
            }
            
        } catch {
            await MainActor.run {
                self.analysisState = .error("Analysis failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func mapPriorityToSeverity(_ priority: String) -> IssueSeverity {
        switch priority.lowercased() {
        case "low": return .low
        case "medium": return .medium
        case "high": return .high
        default: return .medium
        }
    }
    
    private func mapSeverityToPriority(_ severity: IssueSeverity) -> IssuePriority {
        switch severity {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        }
    }
    
    private func mapSeverityToRequestPriority(_ severity: IssueSeverity) -> MaintenancePriority {
        switch severity {
        case .low: return .low
        case .medium: return .medium
        case .high: return .high
        }
    }
    
    private func mapCategoryToRequestCategory(_ category: String) -> MaintenanceCategory {
        let lowercased = category.lowercased()
        // Primary categories
        if lowercased.contains("plumb") { return .plumbing }
        if lowercased.contains("elect") { return .electrical }
        if lowercased.contains("hvac") || lowercased.contains("heat") || lowercased.contains("cool") || lowercased.contains("air") { return .hvac }
        if lowercased.contains("refrig") || lowercased.contains("fridge") || lowercased.contains("cooler") || lowercased.contains("walk-in") { return .refrigeration }
        if lowercased.contains("door") || lowercased.contains("window") { return .doors_windows }
        if lowercased.contains("floor") || lowercased.contains("tile") { return .flooring }
        if lowercased.contains("paint") || lowercased.contains("wall") { return .painting }
        if lowercased.contains("clean") { return .cleaning }
        if lowercased.contains("kitchen") || lowercased.contains("appliance") || lowercased.contains("sink") || lowercased.contains("stove") || lowercased.contains("oven") { return .kitchen }
        // Fallback
        return .other
    }
    
    private func formatEstimatedCost(_ cost: Double?) -> String {
        guard let cost = cost else { return "Contact for estimate" }
        return String(format: "$%.0f", cost)
    }
    
    // Voice recording removed from AI Snap - now available in work updates
    
    private func proceedToLocationSelection() {
        print("🎯 [SophisticatedAISnapView] ===== STARTING LOCATION DETECTION =====")
        // Trigger location detection when user taps button
        Task {
            print("📍 [SophisticatedAISnapView] Calling magicalLocationService.detectLocation()...")
            let context = await magicalLocationService.detectLocation()
            
            guard let context = context else {
                print("❌ [SophisticatedAISnapView] Location detection returned nil")
                await MainActor.run {
                    analysisState = .error("Failed to detect location. Please check location permissions.")
                }
                return
            }
            
            print("✅ [SophisticatedAISnapView] Location detection succeeded!")
            print("📍 [SophisticatedAISnapView] Location: (\(context.latitude), \(context.longitude))")
            print("📍 [SophisticatedAISnapView] Accuracy: \(context.accuracy)m")
            print("🏪 [SophisticatedAISnapView] Found \(context.nearbyBusinesses.count) nearby businesses")
            
            // Log all businesses found
            for (index, business) in context.nearbyBusinesses.prefix(10).enumerated() {
                print("   \(index + 1). \(business.name) (\(business.businessType.displayName)) - \(String(format: "%.0f", business.distance))m")
            }
            
            await MainActor.run {
                self.locationContext = context
                withAnimation {
                    self.showingLocationSelection = true
                }
            }
        }
    }
    
    private func confirmLocationAndCreateIssue(_ business: NearbyBusiness) {
        print("🎯 [SophisticatedAISnapView] ===== CONFIRM LOCATION AND CREATE ISSUE =====")
        print("🎯 [SophisticatedAISnapView] Business: \(business.name) (ID: \(business.id))")
        print("🎯 [SophisticatedAISnapView] Current user: \(appState.currentAppUser?.id ?? "NO USER")")
        print("🎯 [SophisticatedAISnapView] Current user email: \(appState.currentAppUser?.email ?? "NO EMAIL")")
        
        selectedRestaurant = business
        
        // IMMEDIATE FEEDBACK: Success haptic FIRST
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.prepare() // Prepare for immediate response
        successFeedback.notificationOccurred(.success)
        
        // IMMEDIATE FEEDBACK: Close location modal and show creating state with animation
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showingLocationSelection = false
            analysisState = .creating
        }
        
        print("🎬 [SophisticatedAISnapView] Showing creating animation immediately")
        
        guard let result = analysisResult,
              let image = capturedImage else {
            print("❌ [SophisticatedAISnapView] Missing result or image")
            return
        }
        
        print("✅ [SophisticatedAISnapView] Analysis result: \(result.title)")
        print("✅ [SophisticatedAISnapView] Image size: \(image.size)")
        
        // Create maintenance request using MaintenanceServiceV2
        Task {
            do {
                print("📝 [SophisticatedAISnapView] Creating AI analysis object...")
                // Create AI analysis object from result
                let aiAnalysis = AIAnalysis(
                    summary: result.title,
                    description: result.description,
                    category: result.category,
                    priority: result.severity.displayName,
                    estimatedCost: nil,
                    timeToComplete: result.timeToFix,
                    materialsNeeded: nil,
                    safetyWarnings: nil,
                    repairInstructions: nil,
                    recommendations: result.recommendations,
                    confidence: result.confidence
                )
                print("✅ [SophisticatedAISnapView] AI analysis created")
                
                let requestId = UUID().uuidString
                print("📝 [SophisticatedAISnapView] Creating maintenance request with ID: \(requestId)")
                
                // Map user-selected priority to MaintenancePriority
                let finalPriority: MaintenancePriority
                switch selectedPriority {
                case "Low": finalPriority = .low
                case "High": finalPriority = .high
                default: finalPriority = .medium // "Normal" maps to medium
                }
                
                // Combine AI recommendations with voice transcription
                var finalDescription = result.recommendations.joined(separator: "\n")
                if !voiceTranscription.isEmpty {
                    finalDescription += "\n\n🎤 Additional Details: \(voiceTranscription)"
                }
                
                // CRITICAL FIX: Use currentRestaurant.id if available, otherwise use Google Place ID
                // This ensures issues are properly associated with the user's restaurant for filtering
                let finalBusinessId = appState.currentRestaurant?.id ?? business.id
                print("🔑 [SophisticatedAISnapView] Using businessId: \(finalBusinessId)")
                print("🔑 [SophisticatedAISnapView] - Current restaurant ID: \(appState.currentRestaurant?.id ?? "nil")")
                print("🔑 [SophisticatedAISnapView] - Google Place ID: \(business.id)")
                
                let request = MaintenanceRequest(
                    id: requestId,
                    businessId: finalBusinessId,  // Use restaurant UUID if available
                    locationId: business.id,      // Keep Google Place ID for location tracking
                    reporterId: appState.currentAppUser?.id ?? "",
                    title: result.title,
                    description: finalDescription,
                    category: mapCategoryToRequestCategory(result.category),
                    priority: finalPriority,
                    status: .reported,
                    aiAnalysis: aiAnalysis,
                    photoUrls: [],
                    createdAt: Date(),
                    updatedAt: Date()
                )
                
                print("✅ [SophisticatedAISnapView] Maintenance request object created")
                print("📤 [SophisticatedAISnapView] Calling MaintenanceServiceV2.createRequest...")
                
                try await MaintenanceServiceV2.shared.createRequest(request, images: [image])
                
                print("✅ [SophisticatedAISnapView] Issue created successfully!")
                print("🔄 [SophisticatedAISnapView] Refreshing locations...")
                
                // Refresh locations to include the new location
                await appState.locationsService.loadLocations()
                
                print("🔄 [SophisticatedAISnapView] Navigating to issues tab...")
                // Navigate to issues tab
                await MainActor.run {
                    selectedTab = 1
                    issuesFilter = .reported
                }
                resetToReady()
                
                print("✅ [SophisticatedAISnapView] ===== ISSUE CREATION COMPLETE =====")
                
            } catch {
                print("❌ [SophisticatedAISnapView] Failed to create issue: \(error)")
                print("❌ [SophisticatedAISnapView] Error details: \(error.localizedDescription)")
                analysisState = .error("Failed to create issue: \(error.localizedDescription)")
            }
        }
    }
    
    private func resetToReady() {
        analysisState = .ready
        analysisResult = nil
        capturedImage = nil
        showingLocationSelection = false
        locationContext = nil
        selectedRestaurant = nil
        selectedPriority = "Normal" // Reset to default
        voiceTranscription = "" // Reset voice transcription
    }
}

// MARK: - Animated Border Image View
struct AnimatedBorderImageView: View {
    let image: UIImage
    @State private var rotation: Double = 0
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Main image
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                
                // Animated glowing border
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                KMTheme.accent,
                                KMTheme.success,
                                KMTheme.accent.opacity(0.3),
                                KMTheme.accent
                            ]),
                            center: .center,
                            startAngle: .degrees(rotation),
                            endAngle: .degrees(rotation + 360)
                        ),
                        lineWidth: 3
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .shadow(color: KMTheme.accent.opacity(0.6), radius: 8)
                    .shadow(color: KMTheme.success.opacity(0.4), radius: 12)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - Preview
struct SophisticatedAISnapView_Previews: PreviewProvider {
    static var previews: some View {
        SophisticatedAISnapView(
            selectedTab: .constant(0),
            issuesFilter: .constant(.all)
        )
        .environmentObject(AppState())
    }
}
