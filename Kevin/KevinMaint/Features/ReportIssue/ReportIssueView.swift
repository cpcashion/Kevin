import SwiftUI
import PhotosUI
import Combine

private struct Toast: Identifiable, Equatable {
  let id = UUID()
  let message: String
  let color: Color
  static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
}

struct ReportIssueView: View {
  @EnvironmentObject var appState: AppState
  @Binding var selectedTab: Int
  @Binding var issuesFilter: IssueStatusFilter
  @State private var title = ""
  @State private var note = ""
  @State private var type = "Door"
  @State private var priority = "Normal"
  @State private var photos: [UIImage] = []
  @State private var isSubmitting = false
  @State private var toast: Toast? = nil
  @State private var showingConversation: Conversation? = nil
  @State private var imageAnalysis: ImageAnalysisResult?
  @State private var showingAIAnalysis = false
  @State private var hasRequestedSpeechPermission = false
  @State private var isAnalyzingImage = false
  @State private var issueStats: (open: Int, inProgress: Int, completed: Int) = (0, 0, 0)
  // Removed location-related state variables
  @State private var showingVoiceNotesPrompt = false
  @State private var voiceNotes = ""
  @State private var isRecordingVoiceNotes = false
  @State private var liveTranscription = ""
  @State private var userSelectedPriority: String? = nil
  @State private var selectedImage: UIImage? = nil
  @State private var analysisResult: ImageAnalysisResult? = nil
  
  // Magical Location Detection
  @StateObject private var magicalLocationService = MagicalLocationService.shared
  @StateObject private var retryManager = LocationRetryManager()
  @State private var showingLocationCard = false
  @State private var locationContext: LocationContext?
  @State private var selectedRestaurant: NearbyBusiness?
  @State private var showingSuccessAnimation = false
  @State private var showingLocationDetection = false
  @State private var showingLocationError = false
  @State private var locationError: LocationDetectionError?
  @State private var isLocationDetectionInProgress = false
  @State private var showingAIDebug = false
  @State private var aiAnalysisError: Error?
  
  private var aiService: AIService { AIService.shared }
  
  private var isKevinAdmin: Bool {
    appState.currentAppUser?.role == .admin
  }
  
  private var canSubmitIssue: Bool {
    // Can submit if both location and priority are selected
    selectedRestaurant != nil && userSelectedPriority != nil
  }

  let types = ["Door","Wall","Table","Paint","Plumbing",
               "Electrical","Flooring","Signage","Other"]
  let priorities = ["Low","Normal","High"]

  var body: some View {
    // Use the new sophisticated interface
    SophisticatedAISnapView(
      selectedTab: $selectedTab,
      issuesFilter: $issuesFilter
    )
    .environmentObject(appState)
  }
  
  private var mainContent: some View {
    ZStack {
      KMTheme.background.ignoresSafeArea()

      if KMTheme.currentTheme == .light {
        subtleBackgroundGradients
      }

      ScrollView {
        VStack(spacing: 16) {
          prominentPhotoSection
            .padding(.horizontal, 16)
            .padding(.top, 8)

          Group {
            if isAnalyzingImage {
              AIAnalysisLoader()
                .padding(.horizontal, 16)
            } else if let error = aiAnalysisError, let image = selectedImage {
              AIAnalysisLoader(
                hasError: true,
                errorMessage: error.localizedDescription,
                debugImage: image,
                onDebugTapped: {
                  showingAIDebug = true
                },
                onRetryTapped: {
                  aiAnalysisError = nil
                  analyzePhoto(image)
                }
              )
              .padding(.horizontal, 16)
            }
            
            if showingLocationDetection {
              LocationDetectionLoader()
                .padding(.horizontal, 16)
            }

            if imageAnalysis != nil {
              consolidatedAnalysisView
                .padding(.horizontal, 16)
            }
          }
        }
      }
      .background(KMTheme.background)
    }
    .overlay(locationCardOverlay)
    .overlay(locationErrorOverlay)
    .overlay(successAnimationOverlay)
    .overlay(toastOverlay)
    .onAppear { onAppearActions() }
    .task { await backupTaskIfNeeded() }
  }
  
  private var locationCardOverlay: some View {
    Group {
      if showingLocationCard, let context = locationContext {
        MagicalLocationCard(
          locationContext: context,
          selectedRestaurant: $selectedRestaurant,
          onConfirm: { business in
            confirmLocation(business)
          },
          onDismiss: {
            withAnimation(.easeInOut(duration: 0.3)) {
              showingLocationCard = false
            }
          }
        )
        .transition(.asymmetric(
          insertion: .move(edge: .bottom).combined(with: .opacity),
          removal: .move(edge: .bottom).combined(with: .opacity)
        ))
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showingLocationCard)
      }
    }
  }
  
  private var locationErrorOverlay: some View {
    Group {
      if showingLocationError, let error = locationError {
        LocationErrorView(
          error: error,
          onRetry: {
            showingLocationError = false
            retryLocationDetection()
          },
          onManualSelection: {
            showingLocationError = false
            showManualLocationSelection()
          },
          onDismiss: {
            showingLocationError = false
          }
        )
      }
    }
  }
  
  private var successAnimationOverlay: some View {
    Group {
      if showingSuccessAnimation {
        SuccessAnimation(
          message: "Issue created successfully!",
          restaurantName: selectedRestaurant?.name,
          isShowing: $showingSuccessAnimation
        )
      }
    }
  }
  
  private var toastOverlay: some View {
    Group {
      if let toast = toast {
        VStack {
          Spacer()
          HStack {
            Text(toast.message)
              .font(.subheadline)
              .foregroundColor(.white)
              .padding(.horizontal, 16)
              .padding(.vertical, 12)
              .background(toast.color)
              .cornerRadius(8)
              .shadow(radius: 4)
            Spacer()
          }
          .padding(.horizontal, 16)
          .padding(.bottom, 100)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
          DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { self.toast = nil }
          }
        }
      }
    }
    .animation(.easeInOut, value: toast)
  }

  private func onAppearActions() {
    LaunchTimeProfiler.shared.checkpoint("ReportIssueView appeared")
    
    // Track screen view for monitoring
    CrashReportingService.shared.trackScreenView("ReportIssueView")
    PerformanceMonitoringService.shared.trackScreenLoad("ReportIssueView")
    
    // Defer stats loading to improve launch time
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      Task {
        LaunchTimeProfiler.shared.checkpoint("Loading issue stats started (deferred)")
        await loadIssueStats()
        LaunchTimeProfiler.shared.checkpoint("Issue stats loaded")
      }
    }
  }

  private func backupTaskIfNeeded() async {
    // No longer needed
  }
  
  private var dashboardMetrics: some View {
    HStack(spacing: 12) {
      Button(action: {
        issuesFilter = .reported
        selectedTab = 1
      }) {
        EnhancedMetricCard(number: "\(issueStats.open)", label: "Reported", color: KMTheme.danger, icon: "exclamationmark.circle.fill", isSelected: false)
      }
      .buttonStyle(PlainButtonStyle())
      
      Button(action: {
        issuesFilter = .inProgress
        selectedTab = 1
      }) {
        EnhancedMetricCard(number: "\(issueStats.inProgress)", label: "In Progress", color: KMTheme.accent, icon: "gear.circle.fill", isSelected: false)
      }
      .buttonStyle(PlainButtonStyle())
      
      Button(action: {
        issuesFilter = .completed
        selectedTab = 1
      }) {
        EnhancedMetricCard(number: "\(issueStats.completed)", label: "Completed", color: KMTheme.success, icon: "checkmark.circle.fill", isSelected: false)
      }
      .buttonStyle(PlainButtonStyle())
    }
    .padding(.horizontal, 16)
  }
  
  private var aiVoiceSection: some View {
    VStack(spacing: 20) {
      HStack {
        Text("Voice Report")
          .font(.title2)
          .fontWeight(.semibold)
          .foregroundColor(.white)
        
        Spacer()
        
        if aiService.isTranscribing {
          HStack(spacing: 6) {
            Circle()
              .fill(KMTheme.aiGreen)
              .frame(width: 6, height: 6)
            
            Text("AI Active")
              .font(.caption)
              .foregroundColor(KMTheme.aiGreen)
          }
        }
      }
      
      VStack(spacing: 16) {
        Button(action: toggleVoiceRecording) {
          ZStack {
            Circle()
              .stroke(aiService.isTranscribing ? KMTheme.accent : KMTheme.border, lineWidth: 2)
              .frame(width: 64, height: 64)
            
            Image(systemName: aiService.isTranscribing ? "stop.fill" : "mic.fill")
              .font(.title2)
              .foregroundColor(aiService.isTranscribing ? KMTheme.accent : KMTheme.secondaryText)
          }
        }
        
        Text(aiService.isTranscribing ? "Tap to stop recording" : "Describe the Issue")
          .font(.headline)
          .foregroundColor(.white)
        
        Text("AI will transcribe and analyze your report automatically")
          .font(.subheadline)
          .foregroundColor(.white.opacity(0.8))
          .multilineTextAlignment(.center)
        
        if !aiService.transcriptionText.isEmpty {
          VStack(alignment: .leading, spacing: 12) {
            Text("Transcription")
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(.white.opacity(0.7))
            
            Text(aiService.transcriptionText)
              .font(.body)
              .foregroundColor(.white)
              .padding(16)
              .background(KMTheme.cardBackground)
              .cornerRadius(12)
              .overlay(
                RoundedRectangle(cornerRadius: 12)
                  .stroke(aiService.isTranscribing ? KMTheme.accent : KMTheme.border, lineWidth: 1)
              )
          }
        }
      }
      .padding(24)
      .background(KMTheme.cardBackground)
      .cornerRadius(16)
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(KMTheme.border, lineWidth: 0.5)
      )
    }
  }
  
  private var aiAnalysisSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: "brain.head.profile")
          .foregroundColor(KMTheme.accent)
          .font(.title3)
        
        Text("AI Analysis")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.accent)
      }
      
      Text(aiService.aiAnalysis)
        .font(.body)
        .foregroundColor(KMTheme.primaryText)
        .lineLimit(nil)
      
      HStack {
        Text("Confidence")
          .font(.caption)
          .foregroundColor(KMTheme.secondaryText)
        
        GeometryReader { geometry in
          ZStack(alignment: .leading) {
            Rectangle()
              .fill(KMTheme.borderSecondary)
              .frame(height: 4)
              .cornerRadius(2)
            
            Rectangle()
              .fill(LinearGradient(colors: [KMTheme.accent, KMTheme.accentDark], startPoint: .leading, endPoint: .trailing))
              .frame(width: geometry.size.width * aiService.confidenceScore, height: 4)
              .cornerRadius(2)
          }
        }
        .frame(height: 4)
        
        Text("\(Int(aiService.confidenceScore * 100))%")
          .font(.caption)
          .foregroundColor(KMTheme.secondaryText)
      }
    }
    .padding(20)
    .background(KMTheme.accent.opacity(0.1))
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(KMTheme.accent.opacity(0.3), lineWidth: 0.5)
    )
  }
  
  private var prominentPhotoSection: some View {
    VStack(alignment: .leading, spacing: 20) {
      photoHeaderSection
      
      if photos.isEmpty {
        emptyPhotoSection
      } else {
        photoGridSection
      }
      
    }
    .padding(24)
    .background(KMTheme.cardBackground)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(KMTheme.border, lineWidth: 0.5)
    )
  }
  
  private var subtleBackgroundGradients: some View {
    ZStack {
      // Top left gradient spot
      Circle()
        .fill(
          RadialGradient(
            colors: [
              Color(red: 0x98/255.0, green: 0xC3/255.0, blue: 0xD8/255.0).opacity(0.08),
              Color.clear
            ],
            center: .center,
            startRadius: 20,
            endRadius: 120
          )
        )
        .frame(width: 200, height: 200)
        .position(x: 80, y: 150)
      
      // Top right gradient spot
      Circle()
        .fill(
          RadialGradient(
            colors: [
              Color(red: 0xEB/255.0, green: 0xFF/255.0, blue: 0x9A/255.0).opacity(0.06),
              Color.clear
            ],
            center: .center,
            startRadius: 15,
            endRadius: 100
          )
        )
        .frame(width: 160, height: 160)
        .position(x: UIScreen.main.bounds.width - 60, y: 200)
      
      // Bottom center gradient spot
      Circle()
        .fill(
          RadialGradient(
            colors: [
              Color(red: 0x98/255.0, green: 0xC3/255.0, blue: 0xD8/255.0).opacity(0.05),
              Color.clear
            ],
            center: .center,
            startRadius: 25,
            endRadius: 140
          )
        )
        .frame(width: 220, height: 220)
        .position(x: UIScreen.main.bounds.width / 2, y: UIScreen.main.bounds.height - 200)
    }
  }
  
  private var photoHeaderSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Snap a Photo")
        .font(.title2)
        .fontWeight(.bold)
        .foregroundColor(KMTheme.primaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
      
      Text("Point your camera at what's broken and Kevin's AI will analyze it instantly")
        .font(.subheadline)
        .foregroundColor(KMTheme.secondaryText)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }
  
  private var emptyPhotoSection: some View {
    VStack(spacing: 16) {
      cameraButton
      orDivider
      PhotoPickerButton(photos: $photos, selectedImage: $selectedImage, imageAnalysis: $imageAnalysis, isAnalyzingImage: $isAnalyzingImage, showingAIAnalysis: $showingAIAnalysis, onPhotoSelected: analyzePhoto)
        .frame(height: 120)
    }
  }
  
  private var cameraButton: some View {
    CameraButton(
      photos: $photos,
      selectedImage: $selectedImage,
      imageAnalysis: $imageAnalysis,
      isAnalyzingImage: $isAnalyzingImage,
      showingAIAnalysis: $showingAIAnalysis,
      onPhotoSelected: analyzePhoto
    )
  }
  
  private var orDivider: some View {
    Text("OR")
      .font(.caption)
      .foregroundColor(KMTheme.tertiaryText)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity)
  }
  
  private var photoGridSection: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
      ForEach(photos.indices, id: \.self) { index in
        Image(uiImage: photos[index])
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(height: 140)
          .frame(maxWidth: .infinity)
          .background(Color(.systemGray6))
          .cornerRadius(12)
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(KMTheme.accent.opacity(0.3), lineWidth: 1)
          )
      }
      
      if photos.count < 4 {
        PhotoPickerButton(photos: $photos, selectedImage: $selectedImage, imageAnalysis: $imageAnalysis, isAnalyzingImage: $isAnalyzingImage, showingAIAnalysis: $showingAIAnalysis, onPhotoSelected: analyzePhoto)
          .frame(height: 140)
      }
    }
  }
  
  private func aiAnalysisResultsSection(_ analysis: ImageAnalysisResult) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      analysisHeader
      analysisDescription(analysis)
      analysisRecommendations(analysis)
      analysisMetadata(analysis)
      smartActionButtons(analysis)
    }
    .padding(16)
    .background(KMTheme.accent.opacity(0.1))
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(KMTheme.accent.opacity(0.3), lineWidth: 0.5)
    )
  }
  
  private var analysisHeader: some View {
    HStack {
      Image(systemName: "brain.head.profile")
        .foregroundColor(KMTheme.accent)
        .font(.title3)
      
      Text("Kevin's AI Analysis")
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(KMTheme.accent)
    }
  }
  
  private func analysisDescription(_ analysis: ImageAnalysisResult) -> some View {
    Text(analysis.description)
      .font(.body)
      .foregroundColor(KMTheme.primaryText)
  }
  
  private func analysisRecommendations(_ analysis: ImageAnalysisResult) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Recommendations:")
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundColor(KMTheme.primaryText)
      
      ForEach(analysis.recommendations ?? [], id: \.self) { recommendation in
        Text("• \(recommendation)")
          .font(.body)
          .foregroundColor(KMTheme.secondaryText)
      }
    }
  }
  
  private func analysisMetadata(_ analysis: ImageAnalysisResult) -> some View {
    HStack {
      HStack(spacing: 4) {
        Image(systemName: "brain.head.profile")
          .font(.caption)
        Text("\(Int((analysis.confidence ?? 0.0) * 100))% confident")
          .font(.caption)
          .fontWeight(.medium)
      }
      .foregroundColor(KMTheme.accent)
      
      Spacer()
      
      HStack(spacing: 4) {
        Image(systemName: priorityIcon(analysis.priority))
          .font(.caption)
        Text(analysis.priority)
          .font(.caption)
          .fontWeight(.medium)
      }
      .foregroundColor(priorityColor(analysis.priority))
    }
  }
  
  private func smartActionButtons(_ analysis: ImageAnalysisResult) -> some View {
    VStack(spacing: 12) {
      submitButton(analysis)
      messageKevinButton
    }
    .padding(.top, 16)
  }
  
  private var messageKevinButton: some View {
    Button(action: {
      print("🔥 [ReportIssueView] Message Kevin button tapped!")
      startGeneralConversation()
    }) {
      HStack {
        Image(systemName: "message")
          .font(.system(size: 16, weight: .semibold))
        
        Text("Message Kevin")
          .font(.subheadline)
          .fontWeight(.semibold)
      }
      .foregroundColor(KMTheme.accent)
      .frame(maxWidth: .infinity)
      .padding(12)
      .background(KMTheme.accent.opacity(0.1))
      .cornerRadius(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(KMTheme.accent.opacity(0.3), lineWidth: 1)
      )
    }
  }
  
  private func startGeneralConversation() {
    print("🔥 [ReportIssueView] startGeneralConversation called")
    print("🔥 [ReportIssueView] - Current user: \(appState.currentUser?.displayName ?? "nil")")
    print("🔥 [ReportIssueView] - Is admin: \(appState.currentAppUser?.role == .admin)")
    print("🔥 [ReportIssueView] - Current restaurant: \(appState.currentRestaurant?.name ?? "nil")")
    
    guard let currentUser = appState.currentAppUser else {
      print("❌ [ReportIssueView] No current user found")
      return
    }
    
    Task {
      do {
        let conversation = try await MessagingService.shared.createGeneralConversation(
          restaurantId: appState.currentRestaurant?.id,
          userId: currentUser.id,
          userName: currentUser.name
        )
        print("✅ [ReportIssueView] General conversation created: \(conversation.id)")
        
        // Navigate to messages tab
        await MainActor.run {
          // Post notification to switch to messages tab
          NotificationCenter.default.post(
            name: .openConversation,
            object: nil,
            userInfo: ["conversationId": conversation.id]
          )
        }
      } catch {
        print("❌ [ReportIssueView] Failed to create general conversation: \(error)")
      }
    }
  }
  
  private func submitButton(_ analysis: ImageAnalysisResult) -> some View {
    Button(action: { 
      print("🔥 [ReportIssueView] Submit button tapped!")
      
      // Prevent multiple submissions
      guard !isSubmitting else {
        print("⚠️ [ReportIssueView] Already submitting - ignoring duplicate tap")
        return
      }
      
      // Track user action
      CrashReportingService.shared.trackUserAction("Submit Issue", screen: "ReportIssueView")
      
      // Validate photo is attached
      guard selectedImage != nil else {
        print("❌ [ReportIssueView] No photo attached - showing error")
        toast = Toast(message: "Please attach a photo before submitting", color: KMTheme.danger)
        return
      }
      
      Task {
        isSubmitting = true
        await createWorkOrder(from: analysis)
        isSubmitting = false
      }
    }) {
      HStack {
        Spacer()
        
        if isSubmitting {
          HStack(spacing: 8) {
            ProgressView()
              .scaleEffect(0.8)
            Text("Submitting...")
              .font(.headline)
              .fontWeight(.semibold)
          }
        } else {
          Text("Submit")
            .font(.headline)
            .fontWeight(.semibold)
        }
        
        Spacer()
      }
      .foregroundColor(userSelectedPriority != nil ? .black.opacity(0.8) : KMTheme.accent)
      .padding(16)
      .background(
        userSelectedPriority != nil ? 
          KMTheme.danger : 
          Color.clear
      )
      .cornerRadius(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(KMTheme.accent, lineWidth: userSelectedPriority != nil ? 0 : 2)
      )
    }
  }
  
  private func secondaryActionButtons(_ analysis: ImageAnalysisResult) -> some View {
    HStack(spacing: 12) {
      Button("Save as Issue") {
        guard !isSubmitting else {
          print("⚠️ [ReportIssueView] Already submitting - ignoring duplicate tap")
          return
        }
        guard selectedImage != nil else {
          toast = Toast(message: "Please attach a photo before submitting", color: KMTheme.danger)
          return
        }
        Task {
          isSubmitting = true
          await createWorkOrder(from: analysis)
          isSubmitting = false
        }
      }
      .font(.subheadline)
      .foregroundColor(KMTheme.accent)
      .padding(.vertical, 12)
      .padding(.horizontal, 16)
      .background(KMTheme.accent.opacity(0.1))
      .cornerRadius(8)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(KMTheme.accent.opacity(0.3), lineWidth: 1)
      )
      
      Button("Get Quote") {
        guard !isSubmitting else {
          print("⚠️ [ReportIssueView] Already submitting - ignoring duplicate tap")
          return
        }
        guard selectedImage != nil else {
          toast = Toast(message: "Please attach a photo before submitting", color: KMTheme.danger)
          return
        }
        Task {
          isSubmitting = true
          await createWorkOrder(from: analysis)
          isSubmitting = false
        }
      }
      .font(.subheadline)
      .foregroundColor(KMTheme.success)
      .padding(.vertical, 12)
      .padding(.horizontal, 16)
      .background(KMTheme.success.opacity(0.1))
      .cornerRadius(8)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(KMTheme.success.opacity(0.3), lineWidth: 1)
      )
    }
  }
  
  private func saveIssueButton(_ analysis: ImageAnalysisResult) -> some View {
    Button(action: { 
      guard !isSubmitting else {
        print("⚠️ [ReportIssueView] Already submitting - ignoring duplicate tap")
        return
      }
      guard selectedImage != nil else {
        toast = Toast(message: "Please attach a photo before submitting", color: KMTheme.danger)
        return
      }
      Task {
        isSubmitting = true
        await createWorkOrder(from: analysis)
        isSubmitting = false
      }
    }) {
      HStack {
        Image(systemName: "bookmark")
          .font(.system(size: 14))
        Text("Save Issue")
          .font(.subheadline)
          .fontWeight(.medium)
      }
      .foregroundColor(KMTheme.accent)
      .padding(.vertical, 12)
      .padding(.horizontal, 16)
      .background(KMTheme.accent.opacity(0.1))
      .cornerRadius(8)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(KMTheme.accent.opacity(0.3), lineWidth: 1)
      )
    }
  }
  
  private func getQuoteButton(_ analysis: ImageAnalysisResult) -> some View {
    Button(action: { 
      guard !isSubmitting else {
        print("⚠️ [ReportIssueView] Already submitting - ignoring duplicate tap")
        return
      }
      guard selectedImage != nil else {
        toast = Toast(message: "Please attach a photo before submitting", color: KMTheme.danger)
        return
      }
      Task {
        isSubmitting = true
        await createWorkOrder(from: analysis)
        isSubmitting = false
      }
    }) {
      HStack {
        Image(systemName: "doc.text")
          .font(.system(size: 14))
        Text("Get Quote")
          .font(.subheadline)
          .fontWeight(.medium)
      }
      .foregroundColor(KMTheme.success)
      .padding(.vertical, 12)
      .padding(.horizontal, 16)
      .background(KMTheme.success.opacity(0.1))
      .cornerRadius(8)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(KMTheme.success.opacity(0.3), lineWidth: 1)
      )
    }
  }
  
  private var photoAnalysisSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      photoAnalysisHeader
      photoGrid
      consolidatedAnalysisView
    }
  }
  
  private var photoAnalysisHeader: some View {
    Text("Photo Analysis")
      .font(.headline)
      .fontWeight(.semibold)
      .foregroundColor(KMTheme.primaryText)
  }
  
  private var photoGrid: some View {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
      ForEach(photos.indices, id: \.self) { index in
        Image(uiImage: photos[index])
          .resizable()
          .aspectRatio(1, contentMode: .fill)
          .frame(height: 120)
          .clipped()
          .cornerRadius(8)
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(KMTheme.accent, lineWidth: 1)
          )
      }
      
      if photos.count < 4 {
        PhotoPickerButton(photos: $photos, selectedImage: $selectedImage, imageAnalysis: $imageAnalysis, isAnalyzingImage: $isAnalyzingImage, showingAIAnalysis: $showingAIAnalysis, onPhotoSelected: analyzePhoto)
      }
    }
  }
  
  private var consolidatedAnalysisView: some View {
    Group {
      if let analysis = imageAnalysis {
        analysisCard(analysis)
      }
    }
    .sheet(item: $showingConversation) { conversation in
      ChatView(conversation: conversation)
        .environmentObject(appState)
    }
    .sheet(isPresented: $showingAIDebug) {
      if let image = selectedImage {
        AIAnalysisDebugView(image: image)
      }
    }
  }
  
  private func analysisCard(_ analysis: ImageAnalysisResult) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      consolidatedAnalysisHeader
      consolidatedAnalysisContent(analysis)
      consolidatedAnalysisRecommendations(analysis)
      consolidatedAnalysisMetadata(analysis)
      voiceNotesIntegratedSection
      priorityOverrideSection
      locationSelectionSection
      
      // Submit button - only active when location and priority are selected
      VStack(spacing: 12) {
        Button(action: {
          print("🔥 [ReportIssueView] Submit Issue button tapped!")
          
          guard !isSubmitting else {
            print("⚠️ [ReportIssueView] Already submitting - ignoring duplicate tap")
            return
          }
          
          print("🔥 [ReportIssueView] - Analysis: \(analysis.description)")
          print("🔥 [ReportIssueView] - Priority: \(userSelectedPriority ?? "default")")
          
          Task {
            print("🔥 [ReportIssueView] Starting createWorkOrder task...")
            isSubmitting = true
            await createWorkOrder(from: analysis)
            isSubmitting = false
          }
        }) {
          HStack {
            if isSubmitting {
              ProgressView()
                .scaleEffect(0.8)
              Text("Submitting Issue...")
            } else {
              Text("Submit Issue")
            }
          }
        }
        .font(.headline)
        .foregroundColor(canSubmitIssue && !isSubmitting ? .white : KMTheme.secondaryText)
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(canSubmitIssue && !isSubmitting ? KMTheme.accent : KMTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(canSubmitIssue && !isSubmitting ? Color.clear : KMTheme.border, lineWidth: 1)
        )
        .disabled(!canSubmitIssue || isSubmitting)
        
        Button("Start Over") {
          print("🔥 [ReportIssueView] Start Over button tapped!")
          resetForm()
          print("🔥 [ReportIssueView] Form reset completed")
        }
        .font(.subheadline)
        .foregroundColor(KMTheme.secondaryText)
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(KMTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(KMTheme.border, lineWidth: 1)
        )
      }
    }
    .padding(20)
    .background(KMTheme.accent.opacity(0.1))
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(KMTheme.accent.opacity(0.3), lineWidth: 0.5)
    )
  }
  
  private var consolidatedAnalysisHeader: some View {
    HStack {
      Image(systemName: "brain.head.profile")
        .foregroundColor(KMTheme.accent)
        .font(.title3)
      
      Text("Kevin's AI Analysis")
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(KMTheme.accent)
    }
  }
  
  private func consolidatedAnalysisContent(_ analysis: ImageAnalysisResult) -> some View {
    Text(analysis.description)
      .font(.body)
      .foregroundColor(KMTheme.primaryText)
  }
  
  private func consolidatedAnalysisRecommendations(_ analysis: ImageAnalysisResult) -> some View {
    Group {
      if let recommendations = analysis.recommendations, !recommendations.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("Recommendations:")
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.primaryText)
          
          ForEach(recommendations, id: \.self) { recommendation in
            Text("• \(recommendation)")
              .font(.body)
              .foregroundColor(KMTheme.secondaryText)
          }
        }
      }
    }
  }
  
  private func consolidatedAnalysisMetadata(_ analysis: ImageAnalysisResult) -> some View {
    HStack {
      HStack(spacing: 4) {
        Image(systemName: "brain.head.profile")
          .font(.caption)
        Text("\(Int((analysis.confidence ?? 0.0) * 100))% confident")
          .font(.caption)
          .fontWeight(.medium)
      }
      .foregroundColor(KMTheme.accent)
      
      Spacer()
      
      HStack(spacing: 4) {
        Image(systemName: priorityIcon(analysis.priority))
          .font(.caption)
        Text(analysis.priority)
          .font(.caption)
          .fontWeight(.medium)
      }
      .foregroundColor(priorityColor(analysis.priority))
    }
  }
  
  private var voiceNotesIntegratedSection: some View {
    VStack(alignment: .center, spacing: 12) {
      HStack {
        Image(systemName: "mic.badge.plus")
          .foregroundColor(KMTheme.accent)
          .font(.subheadline)
        
        Text("Add Voice Notes")
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundColor(KMTheme.primaryText)
        
        // Recording Status Indicator
        if isRecordingVoiceNotes {
          HStack(spacing: 4) {
            Circle()
              .fill(Color.red)
              .frame(width: 8, height: 8)
              .scaleEffect(1.2)
              .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isRecordingVoiceNotes)
            
            Text("Recording...")
              .font(.caption)
              .foregroundColor(.red)
              .fontWeight(.medium)
          }
        }
      }
      
      HStack(spacing: 12) {
        // Record Button with Clear State
        Button(action: toggleVoiceNotesRecording) {
          HStack(spacing: 8) {
            Image(systemName: isRecordingVoiceNotes ? "stop.circle.fill" : "mic.circle.fill")
              .font(.title3)
              .foregroundColor(isRecordingVoiceNotes ? .red : KMTheme.accent)
            
            Text(isRecordingVoiceNotes ? "Stop" : "Record")
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(isRecordingVoiceNotes ? .red : KMTheme.accent)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 10)
          .background(isRecordingVoiceNotes ? Color.red.opacity(0.1) : KMTheme.accent.opacity(0.1))
          .cornerRadius(20)
          .overlay(
            RoundedRectangle(cornerRadius: 20)
              .stroke(isRecordingVoiceNotes ? Color.red.opacity(0.3) : KMTheme.accent.opacity(0.3), lineWidth: 1)
          )
        }
        
        // Clear Button (if voice notes exist)
        if !voiceNotes.isEmpty && !liveTranscription.isEmpty {
          Button("Clear") {
            voiceNotes = ""
            liveTranscription = ""
          }
          .font(.subheadline)
          .foregroundColor(KMTheme.secondaryText)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(KMTheme.cardBackground)
          .cornerRadius(16)
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .stroke(KMTheme.border, lineWidth: 1)
          )
        }
      }
      .frame(maxWidth: .infinity)
      
      // Live Transcription Display
      if isRecordingVoiceNotes && !liveTranscription.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Text("Live Transcription")
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.secondaryText)
            
            Spacer()
            
            // Animated dots to show it's live
            HStack(spacing: 2) {
              ForEach(0..<3) { index in
                Circle()
                  .fill(KMTheme.accent)
                  .frame(width: 4, height: 4)
                  .scaleEffect(1.0)
                  .animation(
                    .easeInOut(duration: 0.6)
                      .repeatForever(autoreverses: true)
                      .delay(Double(index) * 0.2),
                    value: isRecordingVoiceNotes
                  )
              }
            }
          }
          
          Text(liveTranscription)
            .font(.body)
            .foregroundColor(KMTheme.primaryText)
            .padding(12)
            .background(KMTheme.cardBackground)
            .cornerRadius(8)
            .overlay(
              RoundedRectangle(cornerRadius: 8)
                .stroke(KMTheme.accent.opacity(0.3), lineWidth: 1)
            )
        }
      }
      
      // Final Voice Notes Display
      if !voiceNotes.isEmpty && !isRecordingVoiceNotes {
        VStack(alignment: .leading, spacing: 8) {
          Text("Voice Notes Added")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.success)
          
          Text(voiceNotes)
            .font(.body)
            .foregroundColor(KMTheme.primaryText)
            .padding(12)
            .background(KMTheme.success.opacity(0.1))
            .cornerRadius(8)
            .overlay(
              RoundedRectangle(cornerRadius: 8)
                .stroke(KMTheme.success.opacity(0.3), lineWidth: 1)
            )
        }
      }
    }
    .padding(.top, 8)
  }
  
  private var priorityOverrideSection: some View {
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
            .font(.subheadline)
            .foregroundColor(KMTheme.secondaryText)
        }
        
        Spacer()
        
        if userSelectedPriority != nil {
          Button("Reset") {
            userSelectedPriority = nil
          }
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundColor(KMTheme.accent)
        }
      }
      
      VStack(spacing: 12) {
        ForEach(priorities, id: \.self) { priority in
          Button(action: {
            userSelectedPriority = priority
          }) {
            HStack(spacing: 12) {
              // Priority Icon
              ZStack {
                Circle()
                  .fill(priorityColor(priority).opacity(0.15))
                  .frame(width: 40, height: 40)
                
                Image(systemName: priorityIcon(priority))
                  .font(.title3)
                  .fontWeight(.semibold)
                  .foregroundColor(priorityColor(priority))
              }
              
              // Priority Info
              VStack(alignment: .leading, spacing: 2) {
                Text(priority)
                  .font(.headline)
                  .fontWeight(.semibold)
                  .foregroundColor(KMTheme.primaryText)
                
                Text(priorityDescription(priority))
                  .font(.subheadline)
                  .foregroundColor(KMTheme.secondaryText)
              }
              
              Spacer()
              
              // Selection Indicator
              if userSelectedPriority == priority {
                Image(systemName: "checkmark.circle.fill")
                  .font(.title2)
                  .foregroundColor(priorityColor(priority))
              } else {
                Circle()
                  .stroke(KMTheme.border, lineWidth: 2)
                  .frame(width: 24, height: 24)
              }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
              userSelectedPriority == priority ? 
                priorityColor(priority).opacity(0.08) : 
                KMTheme.cardBackground
            )
            .cornerRadius(12)
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .stroke(
                  userSelectedPriority == priority ? 
                    priorityColor(priority).opacity(0.3) : 
                    KMTheme.border.opacity(0.3), 
                  lineWidth: userSelectedPriority == priority ? 2 : 1
                )
            )
          }
          .buttonStyle(PlainButtonStyle())
        }
      }
    }
    .padding(.top, 8)
  }
  
  private func toggleVoiceNotesRecording() {
    if isRecordingVoiceNotes {
      // Stop recording
      isRecordingVoiceNotes = false
      aiService.stopTranscription()
      
      // Capture the final transcription as voice notes
      voiceNotes = liveTranscription
      liveTranscription = ""
      
      // Clear the main transcription to avoid duplication
      aiService.transcriptionText = ""
    } else {
      // Start recording
      isRecordingVoiceNotes = true
      liveTranscription = ""
      voiceNotes = ""
      
      requestSpeechPermissionIfNeeded()
      Task {
        do {
          try await aiService.startTranscription()
          
          // Monitor live transcription
          await monitorLiveTranscription()
        } catch {
          await MainActor.run {
            isRecordingVoiceNotes = false
            toast = Toast(message: "Voice recording failed: \(error.localizedDescription)", color: KMTheme.danger)
          }
          print("Voice recording error: \(error)")
        }
      }
    }
  }
  
  private func monitorLiveTranscription() async {
    while isRecordingVoiceNotes {
      await MainActor.run {
        liveTranscription = aiService.transcriptionText
      }
      try? await Task.sleep(nanoseconds: 100_000_000) // Update every 0.1 seconds
    }
  }
  
  private func toggleVoiceRecording() {
    if aiService.isTranscribing {
      aiService.stopTranscription()
    } else {
      requestSpeechPermissionIfNeeded()
      Task {
        do {
          try await aiService.startTranscription()
          showingAIAnalysis = true
        } catch {
          toast = Toast(message: "Voice recording failed: \(error.localizedDescription)", color: KMTheme.danger)
          print("Voice recording error: \(error)")
        }
      }
    }
  }
  
  private func requestSpeechPermissionIfNeeded() {
    guard !hasRequestedSpeechPermission else { return }
    hasRequestedSpeechPermission = true
    
    Task {
      let authorized = await aiService.requestSpeechAuthorization()
      if !authorized {
        await MainActor.run {
          toast = Toast(message: "Speech recognition permission required", color: KMTheme.warning)
        }
      }
    }
  }
  
  // Removed old submitWithAI function
  
  private func createAIAnalysisConversation() async {
    guard let analysis = imageAnalysis,
          let restaurant = appState.currentRestaurant,
          let user = appState.currentUser else {
      toast = Toast(message: "Unable to create conversation", color: KMTheme.danger)
      return
    }
    
    do {
      let conversation = try await MessagingService.shared.createAIAnalysisConversation(
        restaurantId: restaurant.id,
        userId: user.uid,
        userName: user.displayName ?? user.email ?? "Unknown User",
        analysisData: analysis,
        restaurantName: restaurant.name,
        managerName: user.displayName ?? user.email ?? "Manager"
      )
      
      await MainActor.run {
        showingConversation = conversation
      }
    } catch {
      toast = Toast(message: "Failed to create conversation: \(error.localizedDescription)", color: KMTheme.danger)
    }
  }
  
  private var locationSelectionSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Location")
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundColor(KMTheme.primaryText)
      
      Button(action: {
        // Use cached location context if available, otherwise trigger fresh detection
        if locationContext != nil {
          withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            showingLocationCard = true
          }
        } else {
          // Show immediate loading state
          withAnimation(.easeInOut(duration: 0.2)) {
            showingLocationDetection = true
          }
          // Clear any cached location context to ensure fresh results
          locationContext = nil
          // Clear the location service cache to ensure fresh business results
          magicalLocationService.clearCache()
          triggerMagicalLocationDetection()
        }
      }) {
        HStack {
          Image(systemName: "location")
            .foregroundColor(selectedRestaurant != nil ? KMTheme.accent : KMTheme.secondaryText)
          
          if let restaurant = selectedRestaurant {
            Text(restaurant.name)
              .foregroundColor(KMTheme.primaryText)
            Spacer()
            Text("\(Int(restaurant.distance)) ft away")
              .font(.caption)
              .foregroundColor(KMTheme.secondaryText)
          } else {
            Text("Select Location")
              .foregroundColor(KMTheme.secondaryText)
            Spacer()
            Image(systemName: "chevron.right")
              .font(.caption)
              .foregroundColor(KMTheme.secondaryText)
          }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(KMTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(selectedRestaurant != nil ? KMTheme.accent : KMTheme.border, lineWidth: 1)
        )
      }
      .buttonStyle(PlainButtonStyle())
    }
  }
  
  private func priorityColor(_ priority: String) -> Color {
    switch priority.lowercased() {
    case "low": return KMTheme.success
    case "normal": return KMTheme.accent
    case "high": return KMTheme.warning
    case "critical": return KMTheme.danger
    case "urgent": return KMTheme.danger // Keep for backward compatibility
    default: return KMTheme.secondaryText
    }
  }
  
  private func priorityDescription(_ priority: String) -> String {
    switch priority.lowercased() {
    case "low": return "Can wait for scheduled maintenance"
    case "normal": return "Standard repair timeline"
    case "high": return "Needs attention within 24 hours"
    case "urgent": return "Immediate action required"
    default: return "Same Day Service"
    }
  }
  
  private func priorityIcon(_ priority: String) -> String {
    switch priority.lowercased() {
    case "urgent": return "exclamationmark.triangle.fill"
    case "high": return "wrench.and.screwdriver.fill"
    case "normal": return "calendar.badge.plus"
    case "low": return "bookmark.fill"
    default: return "wrench.fill"
    }
  }
  
  private func primaryActionText(_ priority: String) -> String {
    switch priority.lowercased() {
    case "urgent": return "Emergency Service"
    case "high": return "Create Work Order"
    case "normal": return "Schedule Repair"
    case "low": return "Add to Maintenance"
    default: return "Create Work Order"
    }
  }
  
  private func mapPriority(_ uiPriority: String) -> IssuePriority {
    switch uiPriority {
    case "Low": return .low
    case "Normal": return .medium
    case "High": return .high
    default: return .medium
    }
  }
  
  // V2 priority mapping
  private func mapPriorityV2(_ uiPriority: String) -> MaintenancePriority {
    switch uiPriority {
    case "Low": return .low
    case "Normal": return .medium
    case "High": return .high
    default: return .medium
    }
  }
  
  // V2 category mapping from AI result/category string
  private func mapCategoryV2(_ category: String?) -> MaintenanceCategory {
    guard let c = category?.lowercased() else { return .other }
    if c.contains("hvac") || c.contains("air") { return .hvac }
    if c.contains("elect") { return .electrical }
    if c.contains("plumb") { return .plumbing }
    if c.contains("kitchen") { return .kitchen }
    if c.contains("door") || c.contains("window") { return .doors_windows }
    if c.contains("refrig") || c.contains("cooler") || c.contains("walk-in") { return .refrigeration }
    if c.contains("floor") { return .flooring }
    if c.contains("paint") { return .painting }
    if c.contains("clean") { return .cleaning }
    return .other
  }
  
  private func createWorkOrder(from analysis: ImageAnalysisResult) async {
    print("🔥 [ReportIssueView] createWorkOrder called")
    print("🔥 [ReportIssueView] - Analysis: \(analysis.description)")
    print("🔥 [ReportIssueView] - Selected priority: \(userSelectedPriority ?? "default")")
    print("🔥 [ReportIssueView] - Selected restaurant: \(selectedRestaurant?.name ?? "none")")
    
    guard let currentUser = appState.currentAppUser else {
      print("❌ [ReportIssueView] No current user found")
      await MainActor.run {
        toast = Toast(message: "User not found", color: KMTheme.danger)
      }
      return
    }
    
    // Use selected restaurant from location detection or fallback
    let businessId: String
    let restaurantName: String
    if let restaurant = selectedRestaurant {
      // Try to match with MasterLocationData to get consistent IDs
      if let masterLocation = MasterLocationData.findLocationByName(restaurant.name) {
        businessId = masterLocation.id
        restaurantName = masterLocation.name
        print("🔥 [ReportIssueView] Using MasterLocationData match: \(masterLocation.name) -> \(masterLocation.id)")
      } else {
        businessId = restaurant.id
        restaurantName = restaurant.name
        print("🔥 [ReportIssueView] Using detected restaurant: \(restaurant.name)")
      }
    } else if let restaurant = appState.currentRestaurant {
      businessId = restaurant.id
      restaurantName = restaurant.name
      print("🔥 [ReportIssueView] Using current restaurant: \(restaurant.name)")
    } else {
      businessId = "default"
      restaurantName = "Unknown Location"
      print("🔥 [ReportIssueView] Using default restaurant ID")
    }
    
    do {
      let request = MaintenanceRequest(
        id: UUID().uuidString,
        businessId: businessId,
        locationId: generateLocationId(for: selectedRestaurant),
        reporterId: currentUser.id,
        assigneeId: nil,
        title: analysis.summary ?? analysis.description,
        description: analysis.description,
        category: mapCategoryV2(analysis.category),
        priority: mapPriorityV2(userSelectedPriority ?? "Normal"),
        status: .reported,
        aiAnalysis: analysis,
        createdAt: Date(),
        updatedAt: Date()
      )
      
      let images = selectedImage != nil ? [selectedImage!] : []
      
      // Create location context if available
      let locationContext = createLocationContext()
      _ = locationContext // reserved for analytics/logging if needed
      
      // Create unified maintenance request (v2)
      try await MaintenanceServiceV2.shared.createRequest(request, images: images)
      print("✅ [ReportIssueView] Maintenance request created successfully: \(request.id)")
      
      // NOTIFICATION: Send urgent issue alert if high priority
      await sendUrgentIssueAlertIfNeeded(
        request: request,
        restaurantName: restaurantName,
        reportedBy: currentUser
      )
      
      if request.priority != .high {  // Only high priority gets urgent alerts
        let adminUserIds = await getAdminUserIds()
        if !adminUserIds.isEmpty {
          try? await FirebaseClient.shared.sendNotificationTrigger(
            userIds: adminUserIds,
            title: "New Issue",
            body: "\(restaurantName): \(request.title)",
            data: [
              "type": "issue_created",
              "issueId": request.id,
              "restaurantName": restaurantName
            ]
          )
        }
      }
      
      // Invalidate cache so new issue appears in lists immediately
      FirebaseCache.shared.invalidateIssuesCache()
      print("🗄️ [ReportIssueView] Invalidated issues cache for new issue")
      
      // Force refresh locations service so new location appears immediately
      appState.locationsService.forceRefresh()
      print("🗄️ [ReportIssueView] Forced locations service refresh for new issue")
      
      // Log location context for analytics
      if let context = locationContext {
        print("📍 [ReportIssueView] Location context: \(context.detectionMethod.displayName), confidence: \(context.confidence)")
      }
      
      await MainActor.run {
        // Success animation already shown in confirmLocation()
        // Just reset form state after delay
        print("✅ [ReportIssueView] Issue created successfully, resetting form")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
          resetFormWithLocation()
        }
      }
    } catch {
      print("❌ [ReportIssueView] Failed to create issue: \(error)")
      print("❌ [ReportIssueView] Error details: \(error.localizedDescription)")
      
      await MainActor.run {
        toast = Toast(
          message: "Failed to create issue: \(error.localizedDescription)",
          color: KMTheme.danger
        )
      }
    }
  }
  
  // Generate a proper location ID for the issue
  private func generateLocationId(for restaurant: NearbyBusiness?) -> String {
    guard let restaurant = restaurant else {
      return "default"
    }
    
    print("🔥 [ReportIssueView] Generating locationId for restaurant: \(restaurant.name)")
    
    // First, try to match with MasterLocationData by name to get the correct ID
    if let masterLocation = MasterLocationData.findLocationByName(restaurant.name) {
      print("✅ [ReportIssueView] Found match in MasterLocationData: \(masterLocation.name) -> \(masterLocation.id)")
      return masterLocation.id
    }
    
    // For Google Place IDs, use them directly as location IDs
    // This will allow the LocationsView to resolve them properly
    if restaurant.id.starts(with: "ChIJ") {
      print("🔥 [ReportIssueView] Using Google Place ID as locationId: \(restaurant.id)")
      return restaurant.id
    }
    
    // For regular business IDs, create a location ID
    // Use a combination of business name and address to create a unique location ID
    let businessName = restaurant.name.replacingOccurrences(of: " ", with: "_")
    let addressComponent = restaurant.address?.components(separatedBy: ",").first?.replacingOccurrences(of: " ", with: "_") ?? "unknown"
    let locationId = "\(businessName)_\(addressComponent)"
    
    print("🔥 [ReportIssueView] Generated locationId: \(locationId) for business: \(restaurant.name)")
    return locationId
  }
  
  private func createLocationContext() -> IssueLocationContext? {
    guard let context = locationContext,
          let _ = selectedRestaurant else {
      return nil
    }
    
    let detectionMethod: LocationDetectionMethod
    if context.wifiFingerprint != nil {
      detectionMethod = .wifi_gps_hybrid
    } else {
      detectionMethod = .gps_only
    }
    
    return IssueLocationContext(
      detectedAt: Date(),
      latitude: context.latitude,
      longitude: context.longitude,
      accuracy: context.accuracy,
      wifiFingerprint: context.wifiFingerprint?.fingerprint,
      detectionMethod: detectionMethod,
      confidence: detectionMethod.confidence,
      alternativeRestaurants: context.nearbyBusinesses.map { $0.id },
      userConfirmed: showingLocationCard // true if user had to manually confirm
    )
  }
  
  private func loadIssueStats() async {
    do {
      let issues: [Issue]
      if appState.currentAppUser?.role == .admin {
        // Admin sees all issues
        issues = try await FirebaseClient.shared.listIssues(restaurantId: nil)
      } else if let restaurantId = appState.currentRestaurant?.id {
        // Restaurant owner sees only their restaurant's issues
        issues = try await FirebaseClient.shared.listIssues(restaurantId: restaurantId)
      } else {
        // No restaurant context - show only issues reported by current user
        let allIssues = try await FirebaseClient.shared.listIssues(restaurantId: nil)
        issues = allIssues.filter { $0.reporterId == appState.currentAppUser?.id }
        print("👤 [ReportIssueView] No restaurant context, showing \(issues.count) issues reported by current user")
      }
      print("📊 [ReportIssueView] Loaded \(issues.count) total issues")
      
      let open = issues.filter { $0.status == .reported }.count
      let inProgress = issues.filter { $0.status == .in_progress }.count
      let completed = issues.filter { $0.status == .completed }.count
      
      print("📊 [ReportIssueView] Issue stats - Reported: \(open), In Progress: \(inProgress), Completed: \(completed)")
      
      await MainActor.run {
        self.issueStats = (open: open, inProgress: inProgress, completed: completed)
        print("✅ [ReportIssueView] Issue stats updated successfully")
        
        // Complete screen load tracking
        PerformanceMonitoringService.shared.completeScreenLoad("ReportIssueView", success: true)
      }
    } catch {
      print("❌ [ReportIssueView] Failed to load issue stats: \(error)")
      
      // Report error and complete screen load tracking
      CrashReportingService.shared.recordError(error, userInfo: ["context": "ReportIssueView.loadIssueStats"])
      PerformanceMonitoringService.shared.completeScreenLoad("ReportIssueView", success: false)
      
      // Keep default values (0, 0, 0)
      await MainActor.run {
        self.issueStats = (open: 0, inProgress: 0, completed: 0)
      }
    }
  }
  
  // Removed all location detection functions
  
  private func resetForm() {
    print("🔥 [ReportIssueView] Resetting form state")
    selectedImage = nil
    analysisResult = nil
    imageAnalysis = nil
    userSelectedPriority = nil
    photos.removeAll()
    voiceNotes = ""
    liveTranscription = ""
    isRecordingVoiceNotes = false
    
    print("✅ [ReportIssueView] Form reset completed")
  }
  
  private func resetFormWithLocation() {
    resetForm()
    
    // Reset location state
    locationContext = nil
    selectedRestaurant = nil
    showingLocationCard = false
    showingLocationDetection = false
    showingSuccessAnimation = false
    showingLocationError = false
    locationError = nil
    isLocationDetectionInProgress = false
    retryManager.reset()
    
    print("✅ [ReportIssueView] Form and location state reset completed")
  }
  
  // Removed all location selection UI sections
  
  private func analyzePhoto(_ image: UIImage) {
    print("🔥 [ReportIssueView] Starting AI analysis for photo")
    isAnalyzingImage = true
    
    Task {
      do {
        let analysis = try await aiService.analyzeImage(image, userId: appState.currentAppUser?.id, appState: appState)
        
        await MainActor.run {
          imageAnalysis = analysis
          isAnalyzingImage = false
          showingAIAnalysis = true
          
          print("✅ [ReportIssueView] AI analysis completed successfully")
          print("🔥 [ReportIssueView] Analysis: \(analysis.description)")
          
          // Don't trigger location detection automatically - let user choose location in the analysis view
        }
      } catch {
        print("❌ [ReportIssueView] AI analysis failed: \(error)")
        
        // Provide more helpful error messages
        let userFriendlyError: Error
        if error.localizedDescription.contains("AppCheck") {
          userFriendlyError = NSError(domain: "AIAnalysis", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Network configuration issue. Please try again in a moment."
          ])
        } else if error.localizedDescription.contains("timeout") || error.localizedDescription.contains("timed out") {
          userFriendlyError = NSError(domain: "AIAnalysis", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Analysis is taking too long. Please check your internet connection and try again."
          ])
        } else if error.localizedDescription.contains("API key") {
          userFriendlyError = NSError(domain: "AIAnalysis", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "AI service is temporarily unavailable. Please try again later."
          ])
        } else {
          userFriendlyError = error
        }
        
        await MainActor.run {
          imageAnalysis = nil
          isAnalyzingImage = false
          aiAnalysisError = userFriendlyError
          
          // Log the error for remote debugging
          RemoteLoggingService.shared.logAIAnalysis(
            event: .failed,
            imageSize: image.size,
            imageSizeBytes: image.jpegData(compressionQuality: 0.8)?.count,
            error: error,
            userId: appState.currentAppUser?.id
          )
          
          // Report the error automatically
          ErrorReportingService.shared.reportAIAnalysisFailure(
            error: error,
            imageSize: image.size,
            imageSizeBytes: image.jpegData(compressionQuality: 0.8)?.count,
            userFeedback: "AI analysis failed during issue reporting",
            userId: appState.currentAppUser?.id
          )
        }
      }
    }
  }
  
  // MARK: - Magical Location Detection
  private func triggerMagicalLocationDetection() {
    // Prevent multiple simultaneous location detection calls
    guard !isLocationDetectionInProgress else {
      print("⚠️ [ReportIssueView] Location detection already in progress, skipping...")
      return
    }
    
    isLocationDetectionInProgress = true
    print("🔮 [ReportIssueView] Triggering magical location detection...")
    
    // Debug: Test Google Places API connectivity
    print("🌍 [ReportIssueView] Testing Google Places API connectivity...")
    
    Task {
      let isConnected = await magicalLocationService.testGooglePlacesAPI()
      if isConnected {
        print("✅ [ReportIssueView] Google Places API is working")
      } else {
        print("❌ [ReportIssueView] Google Places API connection failed")
      }
    }
    
    continueLocationDetection()
  }
  
  private func continueLocationDetection() {
    showingLocationDetection = true
    retryManager.reset()
    
    // Track analytics
    LocationAnalyticsTracker.trackLocationDetectionAttempt(method: .gps_only)
    
    Task {
      let startTime = Date()
      
      let context = await magicalLocationService.detectLocation()
      let duration = Date().timeIntervalSince(startTime)
      
      await MainActor.run {
        showingLocationDetection = false
        
        if let context = context {
          locationContext = context
          
          // Debug: Print detected location and businesses
          print("📍 [ReportIssueView] Detected location: (\(context.latitude), \(context.longitude)) with accuracy \(context.accuracy)m")
          print("🏪 [ReportIssueView] Found \(context.nearbyBusinesses.count) nearby businesses:")
          
          // Group by business type for better readability
          let businessesByType = Dictionary(grouping: context.nearbyBusinesses, by: { $0.businessType })
          for (type, businesses) in businessesByType.sorted(by: { $0.value.count > $1.value.count }) {
            print("   \(type.icon) \(type.displayName) (\(businesses.count)):")
            for business in businesses.prefix(3) { // Show first 3 of each type
              print("      - \(business.name) - \(business.distanceText)")
            }
          }
          
          if let suggested = context.suggestedBusiness {
            print("⭐ [ReportIssueView] Suggested business: \(suggested.name) (\(suggested.businessType.displayName))")
          } else {
            print("⚠️ [ReportIssueView] No business suggestion provided")
          }
          
          // Track success
          let method: LocationDetectionMethod = context.wifiFingerprint != nil ? .wifi_gps_hybrid : .gps_only
          LocationAnalyticsTracker.trackLocationDetectionSuccess(
            method: method,
            accuracy: context.accuracy,
            duration: duration
          )
          
          // Always show location confirmation modal for user to confirm
          // This ensures users can see and verify their detected location
          withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            showingLocationCard = true
          }
          isLocationDetectionInProgress = false
          
          print("✨ [ReportIssueView] Showing location confirmation modal with \(context.nearbyBusinesses.count) businesses")
        } else {
          // Location detection failed
          print("❌ [ReportIssueView] Location detection returned nil context")
          isLocationDetectionInProgress = false
          handleLocationDetectionFailure(.locationUnavailable)
        }
        }
    }
  }
  
  private func handleLocationDetectionFailure(_ error: LocationDetectionError) {
    print("❌ [ReportIssueView] Handling location detection failure: \(error)")
    
    switch error {
    case .permissionDenied:
      showingLocationError = true
    case .noRestaurantsFound:
      showManualLocationSelection()
    case .timeout, .locationUnavailable:
      if retryManager.canRetry() {
        showingLocationError = true
      } else {
        showManualLocationSelection()
      }
    default:
      showingLocationError = true
    }
  }
  
  private func retryLocationDetection() {
    Task {
      await retryManager.performRetry {
        await triggerMagicalLocationDetection()
      }
    }
  }
  
  private func showManualLocationSelection() {
    // Create fallback context with all restaurants
    Task {
      do {
        let restaurants = try await FirebaseClient().listRestaurants()
        
        await MainActor.run {
          if let fallbackContext = LocationFallbackManager.createManualSelectionContext(restaurants: restaurants) {
            locationContext = fallbackContext
            showingLocationCard = true
            
            toast = Toast(
              message: "Please select your restaurant manually",
              color: KMTheme.warning
            )
          } else {
            toast = Toast(
              message: "No restaurants available. Please try again later.",
              color: KMTheme.danger
            )
          }
        }
      } catch {
        await MainActor.run {
          toast = Toast(
            message: "Failed to load restaurants: \(error.localizedDescription)",
            color: KMTheme.danger
          )
        }
      }
    }
  }
  
  private func confirmLocation(_ business: NearbyBusiness) {
    selectedRestaurant = business
    
    // IMMEDIATE FEEDBACK: Show success animation right away
    showingLocationCard = false
    showingSuccessAnimation = true
    
    // Success haptic feedback
    let successFeedback = UINotificationFeedbackGenerator()
    successFeedback.notificationOccurred(.success)
    
    // Track user confirmation
    if let context = locationContext {
      LocationAnalyticsTracker.trackUserLocationConfirmation(
        restaurantId: business.id,
        wasAutoDetected: business.id == context.suggestedBusiness?.id,
        alternativesShown: context.nearbyBusinesses.count - 1
      )
    }
    
    print("✅ [ReportIssueView] Location confirmed: \(business.name) (\(business.businessType.displayName))")
    print("🎬 [ReportIssueView] Showing success animation immediately")
    
    // Create the issue in the background while animation plays
    Task {
      guard let analysis = analysisResult else {
        print("❌ [ReportIssueView] No analysis result available")
        return
      }
      
      await createWorkOrder(from: analysis)
    }
  }
  
  // MARK: - Notification Functions
  
  private func sendUrgentIssueAlertIfNeeded(
    request: MaintenanceRequest,
    restaurantName: String,
    reportedBy: AppUser
  ) async {
    // Only send urgent alerts for high priority issues
    guard request.priority == .high else {
      print("🔔 Issue priority is \(request.priority.rawValue) - no urgent alert needed")
      return
    }
    
    // Get admin user IDs to notify
    let adminUserIds = await getAdminUserIds()
    
    guard !adminUserIds.isEmpty else {
      print("🔔 No admin users to notify for urgent issue")
      return
    }
    
    // Send urgent issue alert
    await NotificationService.shared.sendUrgentIssueAlert(
      to: adminUserIds,
      issueTitle: request.title,
      restaurantName: restaurantName,
      priority: request.priority.rawValue,
      issueId: request.id,
      reportedBy: reportedBy.name
    )
    
    print("🔔 Sent urgent issue alert for \(request.priority.rawValue) priority issue: \(request.title)")
  }
  
  private func getAdminUserIds() async -> [String] {
    do {
      // Get admin users from Firebase based on admin emails
      let adminEmails = AdminConfig.adminEmails
      let adminUserIds = try await FirebaseClient.shared.getAdminUserIds(adminEmails: adminEmails)
      
      print("🔔 Found \(adminUserIds.count) admin users: \(adminUserIds)")
      return adminUserIds
    } catch {
      print("❌ Failed to get admin user IDs: \(error)")
      // Fallback to hardcoded admin emails as user IDs (if using email as ID)
      return AdminConfig.adminEmails
    }
  }
}


struct MetricCard: View {
  let number: String
  let label: String
  let color: Color
  
  var body: some View {
    VStack(spacing: 4) {
      Text(number)
        .font(.title)
        .fontWeight(.bold)
        .foregroundColor(KMTheme.primaryText)
      
      Text(label)
        .font(.caption)
        .fontWeight(.medium)
        .foregroundColor(KMTheme.secondaryText)
        .textCase(.uppercase)
    }
    .frame(maxWidth: .infinity)
    .padding(16)
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(KMTheme.border, lineWidth: 0.5)
    )
  }
}

struct PhotoPickerButton: View {
  @Binding var photos: [UIImage]
  @Binding var selectedImage: UIImage?
  @Binding var imageAnalysis: ImageAnalysisResult?
  @Binding var isAnalyzingImage: Bool
  @Binding var showingAIAnalysis: Bool
  @State private var isAnalyzing = false
  @State private var selectedItems: [PhotosPickerItem] = []
  @EnvironmentObject var appState: AppState
  let onPhotoSelected: (UIImage) -> Void
  
  var body: some View {
    PhotosPicker(selection: $selectedItems, maxSelectionCount: 1, matching: .images) {
      VStack(spacing: 12) {
        Image(systemName: "photo.on.rectangle")
          .font(.system(size: 20, weight: .medium))
          .foregroundColor(KMTheme.danger)
        
        if isAnalyzing {
          ProgressView()
            .scaleEffect(0.8)
            .tint(KMTheme.aiGreen)
        } else {
          VStack(spacing: 4) {
            Text("Choose from Photos")
              .font(.headline)
              .fontWeight(.semibold)
              .foregroundColor(KMTheme.primaryText)
            
            Text("Upload from your gallery")
              .font(.subheadline)
              .foregroundColor(KMTheme.secondaryText)
          }
        }
      }
      .frame(maxWidth: .infinity)
      .frame(minHeight: 100)
      .padding(.vertical, 16)
      .padding(.horizontal, 20)
      .background(KMTheme.surfaceBackground)
      .cornerRadius(16)
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(KMTheme.border, lineWidth: 0.5)
      )
      .id(appState.currentTheme) // Force refresh on theme change
    }
    .onChange(of: selectedItems) { _, newItems in
      Task {
        for item in newItems {
          if let data = try? await item.loadTransferable(type: Data.self),
             let image = UIImage(data: data) {
            await MainActor.run {
              photos.append(image)
              selectedImage = image  // Set selectedImage for submission
              print("🔥 [PhotoPickerButton] Set selectedImage for submission")
            }
            onPhotoSelected(image)
          }
        }
        selectedItems.removeAll()
      }
    }
  }
}

