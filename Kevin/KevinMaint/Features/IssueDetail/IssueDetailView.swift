import Foundation
import SwiftUI

enum AttachmentType {
  case photo, receipt, invoice, voice
}

enum TimelineEventType {
  case issueReported
  case statusUpdate
  case message
  case aiAnalysis
  case photoAdded
  case receiptAdded
  case voiceNote
  case invoiceAdded
}

// Global helper so multiple views in this file can access it
func priorityColor(_ priority: String) -> Color {
  switch priority.lowercased() {
  case "critical": return KMTheme.danger
  case "urgent": return KMTheme.danger // Keep for backward compatibility
  case "high": return KMTheme.warning
  case "medium": return KMTheme.accent
  case "normal": return KMTheme.accent
  case "low": return KMTheme.success
  default: return KMTheme.secondaryText
  }
}

struct IssueDetailView: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var issue: Issue
  @State private var photos: [IssuePhoto] = []
  @State private var workLogs: [WorkLog] = []
  @State private var workOrders: [WorkOrder] = []
  @State private var receipts: [Receipt] = []
  @State private var isLoadingData = false
  @State private var localIssueStatus: IssueStatus
  @State private var isUpdatingStatus = false
  @State private var newUpdate = ""
  @State private var isLoading = false
  @State private var restaurant: Restaurant?
  @State private var businessName: String = "Loading..."
  @State private var showingChat = false
  @State private var chatConversation: Conversation?
  @State private var showingImagePicker = false
  @State private var showingPhotoOptions = false
  @State private var showingPhotoSlider = false
  @State private var selectedPhotoIndex = 0
  @State private var showingLocationMap = false
  @State private var showingAddUpdate = false
  @State private var showingCompleteWork = false
  @State private var mapLocation: SimpleLocation? = nil
  @State private var isLoadingMapLocation = false
  @State private var userCache: [String: AppUser] = [:]
  @State private var isVoiceNoteExpanded = false
  @State private var threadService = ThreadService()
  @State private var newMessage = ""
  @State private var showingAttachmentMenu = false
  @State private var showingVoiceRecorder = false
  @State private var showingQuickReplies = false
  @State private var attachmentType: AttachmentType = .photo
  @State private var cameraSourceType: UIImagePickerController.SourceType = .photoLibrary
  @State private var cachedTimelineEvents: [TimelineEventWrapper] = []
  @State private var timelineRefreshID = UUID()
  @State private var expandedDayGroups: Set<String> = ["Today"]
  @State private var voiceTranscription: String = ""
  @State private var selectedVoiceNote: String?
  @State private var selectedDetailImageUrl: String?
  @State private var showingVoiceDetail = false
  @State private var selectedVoiceTimestamp: Date?
  @State private var selectedAIAnalysis: String?
  @State private var selectedAITimestamp: Date?
  @State private var showingAIDetail = false
  @State private var selectedTextDetail: String?
  @State private var selectedTextTitle: String?
  @State private var selectedTextTimestamp: Date?
  @State private var showingTextDetail = false
  @State private var showingQuoteGenerator = false
  @State private var isTimelineExpanded = true
  @State private var timelineViewMode: TimelineViewMode = .detailed
  @State private var showingQuoteDetail = false
  @State private var selectedQuoteData: QuoteData?
  @State private var selectedQuoteTimestamp: Date?
  @State private var selectedQuoteAuthor: String?
  @State private var showingInvoiceDetail = false
  @State private var selectedInvoiceData: InvoiceData?
  @State private var selectedInvoiceTimestamp: Date?
  @State private var selectedInvoiceAuthor: String?
  @State private var selectedInvoice: Invoice?
  @State private var invoices: [Invoice] = []
  @State private var isUploadingPhoto = false
  @State private var uploadProgress: String = ""
  @EnvironmentObject var appState: AppState
  let onIssueUpdated: (() -> Void)?
  @State private var timelineFilter: String = "All"
  private var filterOptions: [String] = ["All", "Updates", "Status Changes", "AI"]
  @State private var showingThreadSheet = false
  @State private var selectedThreadMessage: ThreadMessage? = nil
  @State private var showingInvoiceBuilder = false
  @FocusState private var isMessageFieldFocused: Bool
  @State private var mentionableUsers: [AppUser] = []
  @State private var filteredMentionUsers: [AppUser] = []
  @State private var showingMentionAutocomplete = false
  @State private var currentMentionQuery = ""
  
  init(issue: Binding<Issue>, onIssueUpdated: (() -> Void)? = nil) {
    self._issue = issue
    self._localIssueStatus = State(initialValue: issue.wrappedValue.status)
    self.onIssueUpdated = onIssueUpdated
  }
  
  var body: some View {
    ZStack {
      VStack(spacing: 0) {
        ScrollView {
          VStack(spacing: 24) {
            // Issue Header with Photos
            issueHeaderWithPhotos
            
            // AI Analysis
            aiAnalysisSection
            
            // Voice Note Section (if exists)
            if let voiceNote = extractVoiceTranscription(from: issue.description) {
              voiceNoteSection(voiceNote: voiceNote)
            }
            
            // Status Update Section (Admin only)
            if AdminConfig.isAdmin(email: appState.currentAppUser?.email) {
              statusUpdateSection
            }
            
            // Unified Timeline
            timelineSection
            
            // Bottom spacer for chat composer
            Spacer()
              .frame(height: 80)
          }
          .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        
        // Inline Chat Composer
        chatComposer
      }
      .background(KMTheme.background)
      .navigationTitle("Issue")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: { dismiss() }) {
            HStack(spacing: 4) {
              Image(systemName: "chevron.left")
                .font(.system(size: 17, weight: .semibold))
              Text("Back")
                .font(.system(size: 17))
            }
            .foregroundColor(KMTheme.accent)
          }
        }
        
      }
    }
    .task {
        await loadData()
        // Start listening to thread messages
        if let maintenanceRequest = convertToMaintenanceRequest() {
          threadService.startListening(requestId: maintenanceRequest.id)
          // Mark thread as read for current user
          if let uid = appState.currentAppUser?.id {
            await ThreadService.shared.markThreadAsRead(requestId: maintenanceRequest.id, userId: uid)
          }
        }
        // Fetch message authors
        await fetchMessageAuthors()
        // Load mentionable users
        await loadMentionableUsers()
        // Refresh timeline cache when messages change
        refreshTimelineCache()
      }
      .onChange(of: threadService.messages.count) { _ in
        // Refresh timeline cache whenever messages change
        refreshTimelineCache()
        // Mark as read when new messages arrive while viewing this screen
        if let maintenanceRequest = convertToMaintenanceRequest(), let uid = appState.currentAppUser?.id {
          Task { await ThreadService.shared.markThreadAsRead(requestId: maintenanceRequest.id, userId: uid) }
        }
        // Fetch user data for message authors
        Task {
          await fetchMessageAuthors()
        }
      }
      .onChange(of: threadService.isLoadingMessages) { _ in
        // Refresh timeline when loading state changes
        refreshTimelineCache()
      }
      .sheet(isPresented: $showingLocationMap) {
        if let location = mapLocation {
          SimpleLocationsMapView(locations: [location], locationStats: [:])
            .environmentObject(appState)
        } else {
          VStack(spacing: 16) {
            ProgressView()
            Text("Loading location...")
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .background(KMTheme.background)
        }
      }
      .sheet(isPresented: $showingImagePicker) {
        SimpleImagePicker(sourceType: cameraSourceType) { selectedImage in
          print("📸 [DEBUG] Image selected from \(cameraSourceType == .camera ? "camera" : "library")")
          uploadPhoto(selectedImage)
        }
        .onAppear {
          print("📸 [DEBUG] SimpleImagePicker sheet appeared!")
        }
      }
    .sheet(isPresented: $showingVoiceRecorder) {
      NavigationView {
        VStack(spacing: 0) {
          // Navigation bar area
          HStack {
            Button("Cancel") {
              showingVoiceRecorder = false
            }
            .foregroundColor(KMTheme.accent)
            
            Spacer()
            
            Text("Voice Note")
              .font(.headline)
              .fontWeight(.semibold)
              .foregroundColor(KMTheme.primaryText)
            
            Spacer()
            
            if !voiceTranscription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
              Button("Send") {
                let text = voiceTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
                handleVoiceNote(text)
                voiceTranscription = ""
                showingVoiceRecorder = false
              }
              .foregroundColor(KMTheme.accent)
              .fontWeight(.semibold)
            } else {
              // Invisible button for balance when there's nothing to send
              Button("Send") {}
                .foregroundColor(KMTheme.accent)
                .opacity(0)
            }
          }
          .padding()
          .background(KMTheme.cardBackground)
          
          // Main content area
          ScrollView {
            VStack(spacing: 20) {
              VoiceDescriptionButton(
                transcribedText: $voiceTranscription,
                onTranscriptionComplete: { transcription in
                  // Do not auto-send; allow user to confirm via Send button
                  voiceTranscription = transcription
                }
              )
            }
            .padding()
          }
          .background(KMTheme.background)
        }
      }
      .onAppear {
        print("🎤 [DEBUG] VoiceDescriptionButton sheet appeared!")
      }
      .onDisappear {
        // Clear any pending transcription when dismissing
        voiceTranscription = ""
      }
    }
    .sheet(isPresented: $showingCompleteWork) {
      CompleteWorkOrderView(
        issue: issue,
        workOrder: workOrders.first
      ) { completionNotes, completionPhotos in
        Task {
          guard let workOrder = workOrders.first else {
            print("❌ No work order found to complete")
            return
          }
          
          do {
            try await FirebaseClient.shared.completeWorkOrder(
              workOrder.id,
              completionNotes: completionNotes,
              completionPhotos: completionPhotos
            )
            
            await MainActor.run {
              showingCompleteWork = false
            }
            
            await refreshIssueData()
          } catch {
            print("❌ Error completing work order: \(error)")
          }
        }
      }
    }
    .sheet(isPresented: $showingVoiceDetail) {
      if let voiceNote = selectedVoiceNote, let ts = selectedVoiceTimestamp {
        VoiceNoteDetailView(transcription: voiceNote, imageUrl: selectedDetailImageUrl, timestamp: ts)
      }
    }
    .sheet(isPresented: $showingAIDetail) {
      if let analysis = selectedAIAnalysis, let ts = selectedAITimestamp {
        AIAnalysisDetailView(analysisText: analysis, imageUrl: selectedDetailImageUrl, timestamp: ts)
      }
    }
    .sheet(isPresented: $showingTextDetail) {
      if let text = selectedTextDetail, let ts = selectedTextTimestamp {
        TextDetailView(title: selectedTextTitle ?? "Update", text: text, timestamp: ts)
      }
    }
    .sheet(isPresented: $showingQuoteGenerator) {
      QuoteGeneratorView(issue: issue)
        .environmentObject(appState)
    }
    .sheet(isPresented: $showingQuoteDetail) {
      if let quoteData = selectedQuoteData,
         let timestamp = selectedQuoteTimestamp,
         let author = selectedQuoteAuthor {
        QuoteDetailView(
          laborHours: quoteData.laborHours,
          laborRate: quoteData.laborRate,
          laborCost: quoteData.laborCost,
          materialsCost: quoteData.materialsCost,
          total: quoteData.total,
          timestamp: timestamp,
          author: author,
          additionalNotes: quoteData.notes.isEmpty ? nil : quoteData.notes
        )
      }
    }
    .sheet(isPresented: $showingInvoiceDetail) {
      if let invoiceData = selectedInvoiceData {
        InvoiceFromTimelineView(invoiceData: invoiceData)
      }
    }
    .sheet(isPresented: $showingThreadSheet) {
      if let threadMessage = selectedThreadMessage,
         let maintenanceRequest = convertToMaintenanceRequest() {
        ThreadSheetView(
          parentMessage: threadMessage,
          requestId: maintenanceRequest.id,
          onSendReply: { replyText in
            Task {
              try await threadService.sendMessage(
                requestId: maintenanceRequest.id,
                authorId: appState.currentAppUser?.id ?? "",
                message: replyText,
                parentMessageId: threadMessage.id
              )
            }
          },
          getUserDisplayName: getUserDisplayName
        )
        .environmentObject(appState)
      }
    }
    .sheet(isPresented: $showingInvoiceBuilder) {
      InvoiceBuilderView(issue: issue, business: restaurant)
        .environmentObject(appState)
    }
    .sheet(isPresented: $showingInvoiceDetail) {
      if let invoice = selectedInvoice {
        InvoiceDetailView(invoice: invoice)
      }
    }
    .sheet(isPresented: $isUploadingPhoto) {
      PhotoUploadProgressView(uploadProgress: uploadProgress)
        .presentationDetents([.height(200)])
        .presentationDragIndicator(.hidden)
        .interactiveDismissDisabled()
    }
    .fullScreenCover(isPresented: $showingPhotoSlider) {
      PhotoSliderView(
        photos: photos,
        initialIndex: selectedPhotoIndex,
        isPresented: $showingPhotoSlider
      )
      .onAppear {
        print("🖼️ [DEBUG] PhotoSliderView fullScreenCover appeared!")
      }
    }
  }
}

// MARK: - IssueDetailView Extensions

extension IssueDetailView {
  
  private var statusUpdateSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: "arrow.triangle.2.circlepath")
          .foregroundColor(KMTheme.accent)
          .font(.title3)
        
        Text("Update Status")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        Spacer()
      }
      
      StatusSelector(selectedStatus: $localIssueStatus) { newStatus in
        updateIssueStatus(newStatus)
      }
    }
    .padding(20)
    .background(KMTheme.cardBackground)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(KMTheme.border, lineWidth: 0.5)
    )
  }
  
  private var issueHeaderWithPhotos: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Photo carousel (if photos exist)
      if !photos.isEmpty {
        photoCarousel
      }
      
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(generateIssueSummary())
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(KMTheme.primaryText)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
          
          Text("Reported \(issue.createdAt.formatted(date: .abbreviated, time: .shortened))")
            .font(.caption)
            .foregroundColor(KMTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        
        StatusPill(status: localIssueStatus)
          .fixedSize()
      }
      
      HStack(spacing: 16) {
        InfoChip(icon: "exclamationmark.triangle", label: issue.priority.rawValue.capitalized, color: priorityColor(issue.priority.rawValue))
        
        // Tappable location chip
        Button(action: {
          Task {
            await loadLocationForMap()
          }
        }) {
          HStack(spacing: 4) {
            if isLoadingMapLocation {
              ProgressView()
                .scaleEffect(0.8)
            }
            InfoChip(icon: "building.2", label: getLocationDisplayName(), color: KMTheme.accent)
          }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoadingMapLocation)
        
        InfoChip(icon: "person", label: getReporterName(), color: KMTheme.secondaryText)
      }
    }
    .padding(20)
    .background(KMTheme.cardBackground)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(KMTheme.border, lineWidth: 0.5)
    )
  }
  
  private var photoCarousel: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
          Button(action: {
            print("🖼️ [DEBUG] Photo tapped - Index: \(index), URL: \(photo.url)")
            selectedPhotoIndex = index
            showingPhotoSlider = true
            print("🖼️ [DEBUG] PhotoSlider should show - selectedIndex: \(selectedPhotoIndex), showing: \(showingPhotoSlider)")
          }) {
            AsyncImage(url: URL(string: photo.url)) { image in
              image
                .resizable()
                .aspectRatio(contentMode: .fill)
            } placeholder: {
              Rectangle()
                .fill(KMTheme.borderSecondary)
                .overlay(ProgressView())
            }
            .frame(width: 120, height: 120)
            .cornerRadius(12)
            .clipped()
          }
        }
      }
      .padding(.horizontal, 4)
    }
  }
  
  private var issueHeader: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(generateIssueSummary())
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(KMTheme.primaryText)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
          
          Text("Reported \(issue.createdAt.formatted(date: .abbreviated, time: .shortened))")
            .font(.caption)
            .foregroundColor(KMTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        
        StatusPill(status: localIssueStatus)
          .fixedSize()
      }
      
      HStack(spacing: 16) {
        InfoChip(icon: "exclamationmark.triangle", label: issue.priority.rawValue.capitalized, color: priorityColor(issue.priority.rawValue))
        
        // Tappable location chip
        Button(action: {
          Task {
            await loadLocationForMap()
          }
        }) {
          HStack(spacing: 4) {
            if isLoadingMapLocation {
              ProgressView()
                .scaleEffect(0.8)
            }
            InfoChip(icon: "building.2", label: getLocationDisplayName(), color: KMTheme.accent)
          }
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoadingMapLocation)
        
        InfoChip(icon: "person", label: getReporterName(), color: KMTheme.secondaryText)
      }
    }
    .padding(20)
    .background(KMTheme.cardBackground)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(KMTheme.border, lineWidth: 0.5)
    )
  }
  
  
  
  private func voiceNoteSection(voiceNote: String) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      Button(action: {
        withAnimation(.spring(response: 0.3)) {
          isVoiceNoteExpanded.toggle()
        }
      }) {
        HStack(spacing: 8) {
          Image(systemName: "waveform.badge.mic")
            .foregroundColor(KMTheme.accent)
            .font(.title3)
          
          Text("Voice Note")
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(KMTheme.primaryText)
          
          Spacer()
          
          Image(systemName: isVoiceNoteExpanded ? "chevron.up" : "chevron.down")
            .foregroundColor(KMTheme.secondaryText)
            .font(.caption)
        }
      }
      .buttonStyle(PlainButtonStyle())
      
      // Preview (first sentence) or full text
      Text(isVoiceNoteExpanded ? voiceNote : getPreviewText(voiceNote))
        .font(.body)
        .foregroundColor(KMTheme.primaryText)
        .lineLimit(isVoiceNoteExpanded ? nil : 2)
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.leading)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KMTheme.accent.opacity(0.1))
        .cornerRadius(12)
        .animation(.easeInOut(duration: 0.2), value: isVoiceNoteExpanded)
    }
    .padding(20)
    .background(KMTheme.cardBackground)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(KMTheme.accent.opacity(0.3), lineWidth: 1)
    )
  }
  
  private func getPreviewText(_ text: String) -> String {
    // Get first sentence or first 100 characters
    let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
    if let firstSentence = sentences.first, !firstSentence.isEmpty {
      return firstSentence.trimmingCharacters(in: .whitespacesAndNewlines) + "..."
    }
    
    // Fallback to first 100 characters
    if text.count > 100 {
      return String(text.prefix(100)) + "..."
    }
    
    return text
  }
  
  @ViewBuilder
  private var voiceNotesSection: some View {
    if let voiceNotes = issue.voiceNotes, !voiceNotes.isEmpty {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Image(systemName: "mic.badge.plus")
            .foregroundColor(KMTheme.accent)
            .font(.title3)
          
          Text("Voice Notes")
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(KMTheme.primaryText)
          
          Spacer()
        }
        
        Text(voiceNotes)
          .font(.body)
          .foregroundColor(KMTheme.secondaryText)
          .lineLimit(nil)
          .fixedSize(horizontal: false, vertical: true)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(20)
      .background(KMTheme.cardBackground)
      .cornerRadius(16)
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(KMTheme.border, lineWidth: 0.5)
      )
    }
  }
  
  private var photosSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: "photo.on.rectangle")
          .foregroundColor(KMTheme.accent)
          .font(.title3)
        
        Text("Photos")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        Spacer()
        
        Text("\(photos.count)")
          .font(.caption)
          .fontWeight(.medium)
          .foregroundColor(KMTheme.secondaryText)
      }
      
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 12) {
          ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
            AsyncImage(url: URL(string: photo.url)) { image in
              image
                .resizable()
                .aspectRatio(contentMode: .fill)
            } placeholder: {
              Rectangle()
                .fill(KMTheme.borderSecondary)
                .overlay(
                  ProgressView()
                    .tint(KMTheme.accent)
                )
            }
            .frame(width: 120, height: 120)
            .cornerRadius(12)
            .clipped()
            .onTapGesture {
              selectedPhotoIndex = index
              showingPhotoSlider = true
            }
          }
          
          // Add Photo Button - always show
          Button(action: {
            showingPhotoOptions = true
          }) {
            VStack(spacing: 8) {
              Image(systemName: "plus")
                .font(.title2)
                .foregroundColor(KMTheme.accent)
              
              Text("Add Photo")
                .font(.caption2)
                .foregroundColor(KMTheme.secondaryText)
            }
            .frame(width: 120, height: 120)
            .background(KMTheme.cardBackground.opacity(0.3))
            .cornerRadius(12)
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .stroke(KMTheme.accent.opacity(0.5), lineWidth: 1)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
            )
          }
        }
        .padding(.horizontal, 4)
      }
    }
    .padding(20)
    .background(KMTheme.cardBackground)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(KMTheme.border, lineWidth: 0.5)
    )
  }
  
  @ViewBuilder
  private var aiAnalysisSection: some View {
    if let analysis = issue.aiAnalysis {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Image(systemName: "brain.head.profile")
            .foregroundColor(KMTheme.aiGreen)
            .font(.title3)
          
          Text("AI Analysis")
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(KMTheme.primaryText)
          
          Spacer()
          
          HStack(spacing: 4) {
            let confidenceValue = analysis.confidence ?? 0.0
            let confidencePercent = Int(confidenceValue * 100)
            
            Text("\(confidencePercent)%")
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.aiGreen)
            
            Text("confidence")
              .font(.caption)
              .foregroundColor(KMTheme.secondaryText)
          }
        }
        
        VStack(alignment: .leading, spacing: 12) {
          Text(analysis.description)
            .font(.body)
            .foregroundColor(KMTheme.secondaryText)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.leading)
          
          if !(analysis.recommendations?.isEmpty ?? true) {
            VStack(alignment: .leading, spacing: 8) {
              Text("Recommended Actions:")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(KMTheme.primaryText)
              
              VStack(alignment: .leading, spacing: 4) {
                ForEach(analysis.recommendations ?? [], id: \.self) { recommendation in
                  RecommendationItem(text: recommendation)
                }
              }
            }
          }
          
          
          HStack {
            Text("Estimated Time:")
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.primaryText)
            
            Text(analysis.estimatedTime)
              .font(.caption)
              .foregroundColor(KMTheme.accent)
            
            Spacer()
            
            Text("Priority:")
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.primaryText)
            
            Text(analysis.priority)
              .font(.caption)
              .foregroundColor(priorityColor(analysis.priority))
          }
        }
      }
      .padding(20)
      .background(KMTheme.cardBackground)
      .cornerRadius(16)
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(KMTheme.aiGreen.opacity(0.3), lineWidth: 1)
      )
    }
  }
  
  // Extract voice transcription from AI analysis description
  private func extractVoiceTranscription(from description: String?) -> String? {
    guard let description = description else { return nil }
    
    // Look for the voice transcription marker used by AI analysis
    let marker = "🎤 Additional Details:"
    guard let range = description.range(of: marker) else { return nil }
    
    // Extract everything after the marker
    let voiceNote = String(description[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    
    return voiceNote.isEmpty ? nil : voiceNote
  }
  
  private var receiptsSection: some View {
    ReceiptsListView(issue: issue)
      .padding(16)
      .background(KMTheme.cardBackground)
      .cornerRadius(12)
  }
  
  
  
  private func loadData() async {
    await MainActor.run {
      self.isLoading = true
    }

    do {
      print("🔄 Loading data for issue: \(issue.id)")
      print("🔍 [IssueDetailView] Issue has photoUrls: \(issue.photoUrls?.count ?? 0)")
      print("🔍 [IssueDetailView] Issue photoUrls: \(issue.photoUrls ?? [])")
      print("🔍 [IssueDetailView] Issue status: \(issue.status)")
      print("🔍 [IssueDetailView] Issue title: \(issue.title)")
      print("🔍 [IssueDetailView] Issue description: \(issue.description ?? "nil")")
      print("🔍 [IssueDetailView] Issue restaurantId: \(issue.restaurantId)")
      print("🔍 [IssueDetailView] Issue createdAt: \(issue.createdAt)")
      
      // Load photos, work logs, work orders, and restaurant data in parallel
      async let photos = FirebaseClient.shared.fetchIssuePhotos(issueId: issue.id)
      async let logs = FirebaseClient.shared.fetchWorkLogs(issueId: issue.id)
      async let orders = FirebaseClient.shared.fetchWorkOrders()
      async let restaurantData = fetchLocationName()
      
      let (loadedPhotos, loadedLogs, allWorkOrders, _) = try await (photos, logs, orders, restaurantData)
      
      // Fetch restaurant data for invoices
      var loadedRestaurant: Restaurant? = nil
      if issue.restaurantId.starts(with: "ChIJ") {
        // For Google Places businesses, create a Restaurant object from Google Places data
        do {
          let placeDetails = try await GooglePlacesService.shared.getPlaceDetails(placeId: issue.restaurantId)
          loadedRestaurant = Restaurant(
            id: issue.restaurantId,
            name: placeDetails.name,
            businessType: getBusinessTypeFromPlace(placeDetails),
            address: placeDetails.formattedAddress ?? placeDetails.vicinity,
            phone: placeDetails.formattedPhoneNumber ?? placeDetails.internationalPhoneNumber,
            website: placeDetails.website,
            logoUrl: nil,
            placeId: issue.restaurantId,
            latitude: placeDetails.geometry.location.lat,
            longitude: placeDetails.geometry.location.lng,
            businessHours: nil,
            category: placeDetails.types.first,
            priceLevel: placeDetails.priceLevel,
            rating: placeDetails.rating,
            totalRatings: placeDetails.userRatingsTotal,
            ownerId: "",
            createdAt: Date(),
            isActive: true,
            verificationStatus: .pending
          )
        } catch {
          print("❌ [IssueDetailView] Failed to fetch Google Place details for invoice: \(error)")
        }
      } else if !issue.restaurantId.isEmpty {
        // This is a Firebase restaurant ID - fetch normally
        loadedRestaurant = try? await FirebaseClient.shared.fetchRestaurant(id: issue.restaurantId)
      }
      
      let issueWorkOrders = allWorkOrders.filter { $0.issueId == issue.id }
      
      // Combine photos from both sources: issuePhotos collection + issue.photoUrls
      var allPhotos = loadedPhotos
      
      // Add photos from issue.photoUrls if they exist and aren't already in the collection
      if let photoUrls = issue.photoUrls, !photoUrls.isEmpty {
        print("🔍 [IssueDetailView] Found \(photoUrls.count) photos in issue.photoUrls")
        for (index, photoUrl) in photoUrls.enumerated() {
          // Check if this URL is already in the loaded photos to avoid duplicates
          let alreadyExists = loadedPhotos.contains { $0.url == photoUrl }
          if !alreadyExists {
            let legacyPhoto = IssuePhoto(
              id: "legacy_\(issue.id)_\(index)",
              issueId: issue.id,
              url: photoUrl,
              thumbUrl: photoUrl,
              takenAt: issue.createdAt // Use issue creation date as fallback
            )
            allPhotos.append(legacyPhoto)
            print("📸 [IssueDetailView] Added legacy photo: \(photoUrl)")
          }
        }
      }
      
      print("📸 Loaded \(loadedPhotos.count) photos from issuePhotos collection for issue \(issue.id)")
      print("📸 Total photos (including legacy): \(allPhotos.count) for issue \(issue.id)")
      print("📝 Loaded \(loadedLogs.count) work logs for issue \(issue.id)")
      print("🔧 Loaded \(issueWorkOrders.count) work orders for issue \(issue.id)")
      
      // Debug: Print all photo URLs
      for photo in allPhotos {
        print("📸 Photo URL: \(photo.url)")
      }
      
      // Load invoices (non-blocking - don't fail if index isn't ready)
      var loadedInvoices: [Invoice] = []
      do {
        loadedInvoices = try await FirebaseClient.shared.fetchInvoices(issueId: issue.id)
      } catch {
        print("⚠️ [IssueDetailView] Failed to load invoices (index may be building): \(error.localizedDescription)")
      }
      
      await MainActor.run {
        self.photos = allPhotos // Use allPhotos to include legacy photos from issue.photoUrls
        self.workLogs = loadedLogs.sorted { $0.createdAt > $1.createdAt }
        self.workOrders = issueWorkOrders
        self.invoices = loadedInvoices.sorted { $0.createdAt > $1.createdAt }
        self.restaurant = loadedRestaurant
        print("🏢 [IssueDetailView] Loaded restaurant: \(String(describing: loadedRestaurant?.name))")
        print("🏢 [IssueDetailView] Restaurant address: \(String(describing: loadedRestaurant?.address))")
        print("🏢 [IssueDetailView] Restaurant phone: \(String(describing: loadedRestaurant?.phone))")
        self.isLoading = false
        self.refreshTimelineCache()
      }
      print("✅ [IssueDetailView] Data loaded successfully - Photos: \(allPhotos.count), WorkLogs: \(loadedLogs.count)")
    } catch {
      print("❌ Failed to load issue data: \(error)")
      await MainActor.run {
        self.isLoading = false
      }
    }
  }
  
  private func refreshIssueData() async {
    do {
      // Refresh issue status
      let issues = try await FirebaseClient.shared.fetchIssues()
      if let updatedIssue = issues.first(where: { $0.id == issue.id }) {
        DispatchQueue.main.async {
          self.issue = updatedIssue
          self.localIssueStatus = updatedIssue.status
        }
      }
      
      // Refresh work logs
      let logs = try await FirebaseClient.shared.fetchWorkLogs(issueId: issue.id)
      
      // Refresh invoices
      let invoices = try await FirebaseClient.shared.fetchInvoices(issueId: issue.id)
      
      DispatchQueue.main.async {
        self.workLogs = logs.sorted { $0.createdAt > $1.createdAt }
        self.invoices = invoices.sorted { $0.createdAt > $1.createdAt }
      }
    } catch {
      print("❌ Error refreshing issue data: \(error)")
    }
  }
  
  private func updateIssueStatus(_ newStatus: IssueStatus) {
    // Prevent multiple simultaneous updates
    guard !isUpdatingStatus else {
      print("⚠️ Status update already in progress, ignoring duplicate request")
      return
    }
    
    Task {
      // Set updating flag
      await MainActor.run {
        isUpdatingStatus = true
      }
      
      do {
        print("🔄 Updating issue status from \(localIssueStatus) to \(newStatus)")
        
        // Convert IssueStatus to RequestStatus
        let requestStatus: RequestStatus
        switch newStatus {
        case .reported: requestStatus = .reported
        case .in_progress: requestStatus = .in_progress
        case .completed: requestStatus = .completed
        }
        
        // Update using MaintenanceServiceV2 (new collection)
        try await MaintenanceServiceV2.shared.updateStatus(requestId: issue.id, to: requestStatus)
        
        // Update local state immediately for better UX
        await MainActor.run {
          self.issue.status = newStatus
          self.localIssueStatus = newStatus
          self.onIssueUpdated?()
        }
        
        // Create an update entry for the status change
        if let currentUser = appState.currentAppUser {
          let statusChangeMessage = "Status updated to \(newStatus.displayName)"
          let update = RequestUpdate(
            id: UUID().uuidString,
            requestId: issue.id,
            authorId: currentUser.id,
            message: statusChangeMessage,
            createdAt: Date()
          )
          
          try await MaintenanceServiceV2.shared.addUpdate(update)
          
          // NOTIFICATION: Send status change notification
          await sendStatusChangeNotification(
            oldStatus: localIssueStatus,
            newStatus: newStatus,
            updatedBy: currentUser
          )
          
          // Refresh work logs to show the new entry
          await refreshIssueData()
        }
        
        print("✅ Issue status updated successfully")
      } catch {
        print("❌ Error updating issue status: \(error)")
        // Revert local status on error
        DispatchQueue.main.async {
          self.localIssueStatus = self.issue.status
        }
      }
      
      // Always clear the updating flag
      await MainActor.run {
        isUpdatingStatus = false
      }
    }
  }
  
  private func getOrCreateWorkOrder() async throws -> String {
    // Check if there's already a work order for this issue
    if let existingWorkOrder = workOrders.first {
      return existingWorkOrder.id
    }
    
    // Create a new work order
    let workOrder = WorkOrder(
      id: UUID().uuidString,
      restaurantId: issue.restaurantId,
      issueId: issue.id,
      assigneeId: appState.currentAppUser?.id,
      status: .in_progress,
      scheduledAt: nil,
      startedAt: Date(),
      completedAt: nil,
      estimatedCost: nil,
      actualCost: nil,
      notes: nil,
      createdAt: Date()
    )
    
    try await FirebaseClient.shared.createWorkOrder(workOrder)
    
    await MainActor.run {
      workOrders.append(workOrder)
    }
    
    return workOrder.id
  }
  
  private func sendWorkUpdateNotification(workLog: WorkLog) async {
    // Get all relevant users to notify
    var userIdsToNotify: [String] = []
    
    guard let currentUser = appState.currentAppUser else { return }
    
    // Always notify the issue reporter (if different from current user)
    if issue.reporterId != currentUser.id {
      userIdsToNotify.append(issue.reporterId)
    }
    
    // Notify admins
    let adminUserIds = await getAdminUserIds()
    userIdsToNotify.append(contentsOf: adminUserIds.filter { $0 != currentUser.id })
    
    // Remove duplicates
    userIdsToNotify = Array(Set(userIdsToNotify))
    
    // Send notification to all users
    guard !userIdsToNotify.isEmpty else { return }
    
    do {
      try await FirebaseClient.shared.sendNotificationTrigger(
        userIds: userIdsToNotify,
        title: "Work Update: \(generateIssueSummary())",
        body: workLog.message,
        data: [
          "type": "work_update",
          "issueId": issue.id,
          "workLogId": workLog.id,
          "restaurantId": issue.restaurantId
        ]
      )
    } catch {
      print("❌ Failed to send work update notification: \(error)")
    }
  }
  
  // MARK: - Notification Functions
  
  private func sendPhotoUploadNotification(photoCount: Int) async {
    guard let currentUser = appState.currentAppUser else { return }
    
    // Get all participants
    var recipients: Set<String> = [issue.reporterId]
    
    // Add admins
    let adminIds = await getAdminUserIds()
    recipients.formUnion(adminIds)
    
    // Remove current user
    recipients.remove(currentUser.id)
    
    guard !recipients.isEmpty else { return }
    
    await NotificationService.shared.sendPhotoUploadNotification(
      to: Array(recipients),
      issueTitle: issue.title,
      restaurantName: getLocationDisplayName(),
      photoCount: photoCount,
      issueId: issue.id,
      uploadedBy: currentUser.name.isEmpty ? (currentUser.email ?? "User") : currentUser.name
    )
  }
  
  private func sendStatusChangeNotification(
    oldStatus: IssueStatus,
    newStatus: IssueStatus,
    updatedBy: AppUser
  ) async {
    // Get all relevant users to notify
    var userIdsToNotify: [String] = []
    
    // Always notify the issue reporter (if different from current user)
    if issue.reporterId != updatedBy.id {
      userIdsToNotify.append(issue.reporterId)
    }
    
    // Notify admins
    let adminUserIds = await getAdminUserIds()
    userIdsToNotify.append(contentsOf: adminUserIds.filter { $0 != updatedBy.id })
    
    // Remove duplicates
    userIdsToNotify = Array(Set(userIdsToNotify))
    
    guard !userIdsToNotify.isEmpty else {
      print("🔔 No users to notify for status change")
      return
    }
    
    // Send notification
    await NotificationService.shared.sendIssueStatusChangeNotification(
      to: userIdsToNotify,
      issueTitle: issue.title,
      restaurantName: businessName,
      oldStatus: oldStatus.displayName,
      newStatus: newStatus.displayName,
      issueId: issue.id,
      updatedBy: updatedBy.name
    )
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
  
  
  private func generateIssueSummary() -> String {
    // Create a concise 1-sentence summary from the issue title and description
    let title = issue.title.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // If title is already concise (under 60 characters), use it
    if title.count <= 60 {
      return title
    }
    
    // If we have AI analysis with a summary, use that
    if let aiSummary = issue.aiAnalysis?.summary, !aiSummary.isEmpty {
      return aiSummary
    }
    
    // Otherwise, create a summary from the title and description
    if let description = issue.description, !description.isEmpty {
      let combinedText = "\(title). \(description)"
      let words = combinedText.components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
      
      // Take first 10-12 words to create a concise summary
      let summaryWords = Array(words.prefix(12))
      var summary = summaryWords.joined(separator: " ")
      
      // Add ellipsis if we truncated
      if words.count > 12 {
        summary += "..."
      }
      
      return summary
    }
    
    // Fallback: truncate the title
    return String(title.prefix(60)) + (title.count > 60 ? "..." : "")
  }
  
  private func openChatWithAdmin() {
    Task {
      do {
        guard let currentUser = appState.currentAppUser else {
          print("❌ No current user found")
          return
        }
        
        let conversation = try await MessagingService.shared.createIssueConversation(
          for: issue,
          userId: currentUser.id,
          userName: currentUser.name.isEmpty ? (currentUser.email ?? "Unknown") : currentUser.name
        )
        
        await MainActor.run {
          self.chatConversation = conversation
          self.showingChat = true
        }
      } catch {
        print("❌ Failed to create conversation: \(error)")
      }
    }
  }
  
  private func getLocationDisplayName() -> String {
    // Handle empty restaurant ID (older issues)
    if issue.restaurantId.isEmpty {
      return "Legacy Location"
    }
    
    if issue.restaurantId.starts(with: "ChIJ") {
      // This is a Google Places ID - use the fetched business name
      return businessName
    } else {
      // This is a Firebase restaurant ID
      return restaurant?.name ?? "Loading..."
    }
  }
  
  private func getReporterName() -> String {
    // Try to get the reporter name from current app user if it matches
    if let currentUser = appState.currentAppUser {
      if currentUser.id == issue.reporterId {
        return currentUser.name.isEmpty ? (currentUser.email?.components(separatedBy: "@").first ?? "Unknown User") : currentUser.name
      }
    }
    
    // Try to map known user IDs to names
    return getUserDisplayName(for: issue.reporterId)
  }
  
  private func loadLocationForMap() async {
    await MainActor.run {
      isLoadingMapLocation = true
    }
    
    do {
      let location = await createLocationFromIssueAsync()
      await MainActor.run {
        mapLocation = location
        isLoadingMapLocation = false
        showingLocationMap = true
      }
    } catch {
      print("❌ [IssueDetailView] Failed to load location for map: \(error)")
      await MainActor.run {
        isLoadingMapLocation = false
      }
    }
  }
  
  private func createLocationFromIssueAsync() async -> SimpleLocation? {
    // Create a Location object from the current issue for map display
    let locationName = getLocationDisplayName()
    
    // Try to get coordinates from the restaurant if available
    var latitude: Double? = nil
    var longitude: Double? = nil
    var address: String? = nil
    
    if let restaurant = restaurant {
      latitude = restaurant.latitude
      longitude = restaurant.longitude
      address = restaurant.address
    }
    
    // Always fetch fresh coordinates from Google Places API for accurate location data
    if issue.restaurantId.starts(with: "ChIJ") {
      print("🗺️ [IssueDetailView] Fetching fresh coordinates from Google Places for: \(issue.restaurantId)")
      do {
        let placeDetails = try await GooglePlacesService.shared.fetchPlaceDetails(placeId: issue.restaurantId)
        // Update coordinates with fresh Google Places data
        latitude = placeDetails.geometry.location.lat
        longitude = placeDetails.geometry.location.lng
        address = placeDetails.formattedAddress
        print("🗺️ [IssueDetailView] Updated with fresh Google Places coordinates: (\(latitude ?? 0), \(longitude ?? 0))")
      } catch {
        print("❌ [IssueDetailView] Failed to fetch place details: \(error)")
      }
    } else {
      // For non-Google Place IDs, check cached data but don't use hardcoded fallbacks
      if let cachedLocation = appState.locationsService.locations.first(where: { 
        $0.name.lowercased() == locationName.lowercased() || $0.id == issue.restaurantId 
      }), cachedLocation.latitude != nil && cachedLocation.longitude != nil {
        latitude = cachedLocation.latitude
        longitude = cachedLocation.longitude
        address = cachedLocation.address
        print("🗺️ [IssueDetailView] Using cached location data for \(locationName): (\(latitude ?? 0), \(longitude ?? 0))")
      } else {
        print("🗺️ [IssueDetailView] No real coordinates available for \(locationName)")
      }
    }
    
    // If still no address, generate one
    if address == nil {
      address = generateAddressForBusiness(locationName)
    }
    
    print("🗺️ [IssueDetailView] Created location for map: \(locationName) at (\(latitude ?? 0), \(longitude ?? 0))")
    
    return SimpleLocation(
      id: issue.restaurantId,
      name: locationName,
      address: address ?? "Address not available",
      latitude: latitude,
      longitude: longitude,
      businessType: .restaurant,
      phone: nil,
      email: nil
    )
  }
  
  private func createLocationFromIssue() -> Location? {
    // Create a Location object from the current issue for map display
    let locationName = getLocationDisplayName()
    
    // Try to get coordinates from the restaurant if available
    var latitude: Double? = nil
    var longitude: Double? = nil
    var address: String? = nil
    
    if let restaurant = restaurant {
      latitude = restaurant.latitude
      longitude = restaurant.longitude
      address = restaurant.address
    }
    
    // Always fetch fresh coordinates from Google Places API for accurate location data
    if issue.restaurantId.starts(with: "ChIJ") {
      print("🗺️ [IssueDetailView] Fetching fresh coordinates from Google Places for: \(issue.restaurantId)")
      Task {
        do {
          let placeDetails = try await GooglePlacesService.shared.fetchPlaceDetails(placeId: issue.restaurantId)
          await MainActor.run {
            // Update coordinates with fresh Google Places data
            latitude = placeDetails.geometry.location.lat
            longitude = placeDetails.geometry.location.lng
            address = placeDetails.formattedAddress
            print("🗺️ [IssueDetailView] Updated with fresh Google Places coordinates: (\(latitude ?? 0), \(longitude ?? 0))")
            
            // Trigger a refresh to update the map
            appState.locationsService.forceRefresh()
          }
        } catch {
          print("❌ [IssueDetailView] Failed to fetch place details: \(error)")
        }
      }
    } else {
      // For non-Google Place IDs, check cached data but don't use hardcoded fallbacks
      if let cachedLocation = appState.locationsService.locations.first(where: { 
        $0.name.lowercased() == locationName.lowercased() || $0.id == issue.restaurantId 
      }), cachedLocation.latitude != nil && cachedLocation.longitude != nil {
        latitude = cachedLocation.latitude
        longitude = cachedLocation.longitude
        address = cachedLocation.address
        print("🗺️ [IssueDetailView] Using cached location data for \(locationName): (\(latitude ?? 0), \(longitude ?? 0))")
      } else {
        print("🗺️ [IssueDetailView] No real coordinates available for \(locationName)")
      }
    }
    
    // If still no address, generate one
    if address == nil {
      address = generateAddressForBusiness(locationName)
    }
    
    print("🗺️ [IssueDetailView] Created location for map: \(locationName) at (\(latitude ?? 0), \(longitude ?? 0))")
    
    return Location(
      id: issue.restaurantId,
      restaurantId: issue.restaurantId,
      name: locationName,
      address: address,
      latitude: latitude,
      longitude: longitude
    )
  }
  
  private func getCoordinatesForBusiness(_ businessName: String) -> (lat: Double, lng: Double)? {
    // No hardcoded coordinates - only use real Google Places API data
    return nil
  }
  
  private func generateAddressForBusiness(_ businessName: String) -> String {
    // No hardcoded addresses - only use real Google Places API data
    return "Address not available"
  }
  
  private func fetchLocationName() async throws -> String {
    // Handle empty restaurant ID (older issues from early September)
    if issue.restaurantId.isEmpty {
      print("🔍 [IssueDetailView] Issue has empty restaurantId - this is an older issue from early September")
      await MainActor.run {
        businessName = "Legacy Location"
      }
      return "Legacy Location"
    }
    
    // For Google Places businesses, fetch the name using Google Places API
    if issue.restaurantId.starts(with: "ChIJ") {
      // Fetch real name from Google Places API
      do {
        let placeDetails = try await GooglePlacesService.shared.getPlaceDetails(placeId: issue.restaurantId)
        await MainActor.run {
          businessName = placeDetails.name
        }
        return placeDetails.name
      } catch {
        print("❌ [IssueDetailView] Failed to fetch place details: \(error)")
        await MainActor.run {
          businessName = "Business Location"
        }
        return "Business Location"
      }
    } else {
      // This is a Firebase restaurant ID - fetch normally
      let restaurant = try await FirebaseClient.shared.fetchRestaurant(id: issue.restaurantId)
      return restaurant?.name ?? "Unknown Location"
    }
  }
  
  private func getWorkLogUserName(_ workLog: WorkLog) -> String {
    // Try to get the user who created this work log
    if let currentUser = appState.currentAppUser {
      if currentUser.id == workLog.authorId {
        return currentUser.name.isEmpty ? (currentUser.email?.components(separatedBy: "@").first ?? "Unknown User") : currentUser.name
      }
    }
    
    // Try to map known user IDs to names
    return getUserDisplayName(for: workLog.authorId)
  }
  
  private func fetchMessageAuthors() async {
    // Get unique author IDs from messages
    let authorIds = Set(threadService.messages.map { $0.authorId })
    
    // Fetch user data for each author not in cache
    for authorId in authorIds {
      // Skip if already cached or is AI
      if userCache[authorId] != nil || authorId == "ai" {
        continue
      }
      
      // Skip if it's the current user (already have that data)
      if authorId == appState.currentAppUser?.id {
        if let currentUser = appState.currentAppUser {
          await MainActor.run {
            userCache[authorId] = currentUser
          }
        }
        continue
      }
      
      // Fetch user from Firestore
      do {
        if let user = try await FirebaseClient.shared.fetchUser(userId: authorId) {
          await MainActor.run {
            userCache[authorId] = user
          }
          print("✅ [IssueDetailView] Fetched user: \(user.name) for ID: \(authorId)")
        }
      } catch {
        print("❌ [IssueDetailView] Failed to fetch user \(authorId): \(error)")
      }
    }
  }
  
  private func getUserDisplayName(for userId: String) -> String {
    // Special handling for AI messages
    if userId == "ai" {
      return "Kevin AI"
    }
    
    // Use UserLookupService which fetches from Firestore
    return UserLookupService.shared.getUserDisplayName(for: userId, currentUser: appState.currentAppUser)
  }
  
  private func getBusinessTypeFromPlace(_ place: GooglePlace) -> BusinessType {
    // Categorize based on Google Place types
    let types = place.types
    if types.contains("restaurant") || types.contains("food") || types.contains("meal_takeaway") {
      return .restaurant
    } else if types.contains("cafe") || types.contains("coffee_shop") {
      return .cafe
    } else if types.contains("bar") || types.contains("night_club") {
      return .bar
    } else if types.contains("gas_station") {
      return .gasStation
    } else if types.contains("grocery_or_supermarket") || types.contains("supermarket") {
      return .grocery
    } else if types.contains("pharmacy") {
      return .pharmacy
    } else if types.contains("hospital") || types.contains("doctor") {
      return .healthcare
    } else if types.contains("bank") || types.contains("atm") {
      return .financial
    } else if types.contains("lodging") {
      return .hotel
    } else if types.contains("shopping_mall") || types.contains("store") {
      return .retail
    } else if types.contains("gym") || types.contains("spa") {
      return .gym
    } else if types.contains("beauty_salon") || types.contains("hair_care") {
      return .salon
    } else if types.contains("dentist") || types.contains("physiotherapist") {
      return .clinic
    } else if types.contains("car_repair") || types.contains("car_wash") {
      return .automotive
    } else {
      return .other
    }
  }
  
  // MARK: - Timeline Section
  
  enum TimelineViewMode {
    case compact
    case detailed
  }
  
  struct TimelineEventWrapper: Identifiable {
    let id: String
    let timestamp: Date
    let eventType: TimelineEventType
    let view: AnyView
  }
  
  // Helper to get replies for a message
  private func getRepliesFor(messageId: String) -> [ThreadMessage] {
    return threadService.messages.filter { $0.parentMessageId == messageId }
  }
  
  // Helper to create timeline card with threading support
  private func createMessageCard(
    message: ThreadMessage,
    icon: String,
    iconColor: Color,
    title: String,
    isReply: Bool = false,
    onTap: @escaping () -> Void
  ) -> some View {
    TimelineCard(
      icon: icon,
      iconColor: iconColor,
      title: title,
      preview: message.message,
      timestamp: message.createdAt,
      author: getUserDisplayName(for: message.authorId),
      lineLimit: timelineViewMode == .compact ? 1 : 2,
      onTap: onTap,
      replyCount: message.replyCount,
      isReply: isReply,
      readReceipts: message.readReceipts,
      currentUserId: appState.currentAppUser?.id
    )
  }
  
  private func getAllTimelineEvents() -> [TimelineEventWrapper] {
    var events: [TimelineEventWrapper] = []
    
    // Add work logs
    for workLog in workLogs {
      events.append(TimelineEventWrapper(
        id: "worklog-\(workLog.id)",
        timestamp: workLog.createdAt,
        eventType: .statusUpdate,
        view: AnyView(
          VStack(alignment: .leading, spacing: 8) {
            TimelineCard(
              icon: "checkmark.circle.fill",
              iconColor: Color.green,
              title: "Status Update",
              preview: workLog.message,
              timestamp: workLog.createdAt,
              author: getWorkLogUserName(workLog),
              lineLimit: timelineViewMode == .compact ? 1 : 2,
              onTap: {
                selectedTextTitle = "Status Update"
                selectedTextDetail = workLog.message
                selectedTextTimestamp = workLog.createdAt
                showingTextDetail = true
              }
            )
          }
        )
      ))
    }
    
    // Add invoices
    for invoice in invoices {
      let statusColor: Color = {
        switch invoice.status {
        case .paid: return .green
        case .sent: return .blue
        case .overdue: return KMTheme.danger
        case .draft: return .gray
        case .cancelled: return .gray
        }
      }()
      
      events.append(TimelineEventWrapper(
        id: "invoice-\(invoice.id)",
        timestamp: invoice.createdAt,
        eventType: .invoiceAdded,
        view: AnyView(
          TimelineCard(
            icon: "doc.text.fill",
            iconColor: statusColor,
            title: "Invoice \(invoice.status.displayName)",
            preview: "\(invoice.invoiceNumber) • $\(String(format: "%.2f", invoice.total))",
            timestamp: invoice.createdAt,
            author: "Kevin",
            lineLimit: 1,
            onTap: {
              selectedInvoice = invoice
              showingInvoiceDetail = true
            }
          )
        )
      ))
    }
    
    // Add thread messages (only top-level, not replies)
    let topLevelMessages = threadService.messages.filter { $0.parentMessageId == nil }
    for message in topLevelMessages {
      // Check if this is a quote message
      if message.message.hasPrefix("QUOTE_DATA:") {
        if let quoteData = parseQuoteData(from: message.message) {
          events.append(TimelineEventWrapper(
            id: "message-\(message.id)",
            timestamp: message.createdAt,
            eventType: .message,
            view: AnyView(
              TimelineCard(
                icon: "dollarsign.circle.fill",
                iconColor: .green,
                title: "Quote Submitted",
                preview: "$\(String(format: "%.2f", quoteData.total))",
                timestamp: message.createdAt,
                author: getUserDisplayName(for: message.authorId),
                lineLimit: 1,
                onTap: {
                  selectedQuoteData = quoteData
                  selectedQuoteTimestamp = message.createdAt
                  selectedQuoteAuthor = getUserDisplayName(for: message.authorId)
                  showingQuoteDetail = true
                }
              )
            )
          ))
        }
        continue // Skip other processing for quote messages
      }
      
      // Check if this is an invoice message
      if message.message.hasPrefix("INVOICE_DATA:") {
        if let invoiceData = parseInvoiceData(from: message.message, attachmentUrl: message.attachmentUrl) {
          events.append(TimelineEventWrapper(
            id: "message-\(message.id)",
            timestamp: message.createdAt,
            eventType: .message,
            view: AnyView(
              TimelineCard(
                icon: "doc.text.fill",
                iconColor: .blue,
                title: "Invoice Created",
                preview: "\(invoiceData.invoiceNumber) • $\(String(format: "%.2f", invoiceData.total))",
                timestamp: message.createdAt,
                author: getUserDisplayName(for: message.authorId),
                lineLimit: 1,
                onTap: {
                  selectedInvoiceData = invoiceData
                  selectedInvoiceTimestamp = message.createdAt
                  selectedInvoiceAuthor = getUserDisplayName(for: message.authorId)
                  showingInvoiceDetail = true
                },
                thumbnailUrl: invoiceData.pdfUrl
              )
            )
          ))
        }
        continue // Skip other processing for invoice messages
      }
      
      // DISABLED: Skip ALL AI chat messages until we improve the UX
      // TODO: Re-enable when AI chat experience is improved
      if message.authorType == .ai {
        continue
      }
      
      // DISABLED: AI content detection (unreachable now that we skip all AI messages)
      let isAIContent = false
      // let isGenericAIMessage = message.authorType == .ai && (
      //   message.message.contains("Message analyzed. Progress update noted.") ||
      //   message.message.contains("Continue monitoring for completion.") ||
      //   message.message.contains("Message analyzed.") ||
      //   message.message.contains("Progress update noted.") ||
      //   message.message == "Message analyzed. Progress update noted. Continue monitoring for completion." ||
      //   (message.message.count < 150 && !message.message.contains("**") && !message.message.contains("Photo Analysis"))
      // )
      // let isAIContent = (message.authorType == .ai || 
      //                   message.message.contains("📸 Photo Analysis") ||
      //                   message.message.contains("Assessment:") ||
      //                   message.message.contains("Document Type:")) &&
      //                   !isGenericAIMessage
      
      if isAIContent {
        // Check if this is a receipt/invoice analysis
        let isReceiptAnalysis = message.message.contains("📸 Photo Analysis") && 
                                (message.message.contains("Document Type: Receipt") || 
                                 message.message.contains("Document Type: Invoice"))
        
        let (icon, iconColor, title) = isReceiptAnalysis 
          ? ("doc.text.magnifyingglass", Color.orange, "Receipt Analysis")
          : ("photo", KMTheme.accent, "Photo")
        
        events.append(TimelineEventWrapper(
          id: "message-\(message.id)",
          timestamp: message.createdAt,
          eventType: isReceiptAnalysis ? .receiptAdded : .aiAnalysis,
          view: AnyView(
            VStack(alignment: .leading, spacing: 8) {
              TimelineCard(
                icon: icon,
                iconColor: iconColor,
                title: title,
                preview: extractPreview(from: message.message),
                timestamp: message.createdAt,
                author: "Kevin AI",
                lineLimit: timelineViewMode == .compact ? 1 : 2,
                onTap: {
                  selectedAIAnalysis = message.message
                  selectedAITimestamp = message.createdAt
                  selectedDetailImageUrl = message.attachmentUrl ?? message.attachmentThumbUrl ?? findAttachmentForAIMessage(message)
                  showingAIDetail = true
                }
              )
              
              if let proposal = message.aiProposal, message.proposalAccepted == nil {
                AIProposalTimelineCard(
                  proposal: proposal,
                  onAccept: {
                    Task {
                      await acceptProposal(messageId: message.id, proposal: proposal)
                    }
                  },
                  onDismiss: {
                    Task {
                      await dismissProposal(messageId: message.id)
                    }
                  }
                )
              }
            }
          )
        ))
      } else {
        // Real user messages
        let isVoice = message.type == .voice
        let hasAttachment = message.attachmentUrl != nil
        
        if isVoice {
          // Only show real voice transcriptions, not old placeholder messages or AI analysis
          let isRealTranscription = !message.message.contains("Voice note recorded at") && 
                                   !message.message.contains("📸 **Photo Analysis**") &&
                                   !message.message.contains("**Photo Analysis**") &&
                                   !message.message.contains("**Assessment:**") &&
                                   !message.message.contains("**Document Type:**") &&
                                   !message.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
          
          if isRealTranscription {
            events.append(TimelineEventWrapper(
              id: "message-\(message.id)",
              timestamp: message.createdAt,
              eventType: .voiceNote,
              view: AnyView(
                TimelineCard(
                  icon: "waveform",
                  iconColor: Color.purple,
                  title: "Voice Note",
                  preview: message.message,
                  timestamp: message.createdAt,
                  author: getUserDisplayName(for: message.authorId),
                  lineLimit: timelineViewMode == .compact ? 1 : 2,
                  onTap: {
                    selectedVoiceNote = message.message
                    selectedDetailImageUrl = message.attachmentUrl ?? message.attachmentThumbUrl
                    selectedVoiceTimestamp = message.createdAt
                    showingVoiceDetail = true
                  }
                )
              )
            ))
          }
        } else if hasAttachment {
          events.append(TimelineEventWrapper(
            id: "message-\(message.id)",
            timestamp: message.createdAt,
            eventType: .photoAdded,
            view: AnyView(
              TimelineCard(
                icon: "photo.fill",
                iconColor: Color.blue,
                title: "Photo Added",
                preview: message.message.isEmpty ? "Tap to view photo" : message.message,
                timestamp: message.createdAt,
                author: getUserDisplayName(for: message.authorId),
                lineLimit: timelineViewMode == .compact ? 1 : 2,
                onTap: {
                  if let attachmentUrl = message.attachmentUrl,
                     let photoIndex = photos.firstIndex(where: { $0.url == attachmentUrl }) {
                    selectedPhotoIndex = photoIndex
                    showingPhotoSlider = true
                  }
                },
                readReceipts: message.readReceipts,
                currentUserId: appState.currentAppUser?.id,
                thumbnailUrl: message.attachmentThumbUrl ?? message.attachmentUrl
              )
            )
          ))
        } else {
          // Text message - tap to open thread sheet
          events.append(TimelineEventWrapper(
            id: "message-\(message.id)",
            timestamp: message.createdAt,
            eventType: .message,
            view: AnyView(
              createMessageCard(
                message: message,
                icon: "text.bubble.fill",
                iconColor: KMTheme.accent,
                title: "Update",
                onTap: {
                  // Always open thread sheet for messages
                  selectedThreadMessage = message
                  showingThreadSheet = true
                }
              )
            )
          ))
        }
      }
    }
    
    // Add initial issue report
    events.append(TimelineEventWrapper(
      id: "issue-\(issue.id)",
      timestamp: issue.createdAt,
      eventType: .issueReported,
      view: AnyView(
        TimelineCard(
          icon: "exclamationmark.triangle.fill",
          iconColor: priorityColor(issue.priority.rawValue),
          title: "Issue Reported",
          preview: issue.title,
          timestamp: issue.createdAt,
          author: getReporterName(),
          lineLimit: timelineViewMode == .compact ? 1 : 2,
          onTap: {
            if let desc = issue.description, !desc.isEmpty {
              selectedTextDetail = desc
            } else {
              selectedTextDetail = "Issue reported: \(issue.title)"
            }
            selectedTextTitle = "Issue Reported"
            selectedTextTimestamp = issue.createdAt
            showingTextDetail = true
          }
        )
      )
    ))
    
    return events.sorted { $0.timestamp < $1.timestamp }
  }
  
  // Extract a clean preview from AI analysis text
  private func extractPreview(from text: String) -> String {
    // Try to extract vendor for receipts
    if text.contains("**Vendor:**") {
      if let vendorRange = text.range(of: "**Vendor:**") {
        let tail = text[vendorRange.upperBound...]
        if let line = tail.split(separator: "\n").first {
          let vendor = line.trimmingCharacters(in: .whitespaces)
          if !vendor.isEmpty && vendor != "Unknown" {
            return vendor
          }
        }
      }
    }
    
    // Try to extract assessment
    if let assessmentRange = text.range(of: "**Assessment:**") {
      let tail = text[assessmentRange.upperBound...]
      if let line = tail.split(separator: "\n").first {
        return line.trimmingCharacters(in: .whitespaces)
      }
    }
    
    // Fallback: first line of text
    if let firstLine = text.split(separator: "\n").first {
      let cleaned = firstLine.replacingOccurrences(of: "📸", with: "")
                             .replacingOccurrences(of: "**", with: "")
                             .trimmingCharacters(in: .whitespaces)
      return cleaned.isEmpty ? "Tap to view details" : cleaned
    }
    
    return "Tap to view details"
  }

  // Associate AI analysis cards with the nearest prior attachment (e.g., receipt photo)
  private func findAttachmentForAIMessage(_ aiMessage: ThreadMessage) -> String? {
    if let direct = aiMessage.attachmentThumbUrl ?? aiMessage.attachmentUrl { return direct }
    let before = threadService.messages
      .filter { $0.createdAt <= aiMessage.createdAt && $0.id != aiMessage.id }
      .sorted { $0.createdAt > $1.createdAt }
    for m in before {
      if let url = m.attachmentThumbUrl ?? m.attachmentUrl { return url }
    }
    let forwardWindow: TimeInterval = 180
    let after = threadService.messages
      .filter { $0.createdAt >= aiMessage.createdAt && $0.id != aiMessage.id }
      .sorted { $0.createdAt < $1.createdAt }
    for m in after {
      if m.createdAt.timeIntervalSince(aiMessage.createdAt) <= forwardWindow,
         let url = m.attachmentThumbUrl ?? m.attachmentUrl { return url }
    }
    return nil
  }
  
  private func refreshTimelineCache() {
    cachedTimelineEvents = getAllTimelineEvents()
    timelineRefreshID = UUID() // Force SwiftUI to re-render timeline
  }
  
  private func parseQuoteData(from message: String) -> QuoteData? {
    guard message.hasPrefix("QUOTE_DATA:") else { return nil }
    
    let jsonString = String(message.dropFirst("QUOTE_DATA:".count))
    guard let jsonData = jsonString.data(using: .utf8),
          let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: String] else {
      return nil
    }
    
    guard let laborHours = Double(dict["laborHours"] ?? "0"),
          let laborRate = Double(dict["laborRate"] ?? "0"),
          let laborCost = Double(dict["laborCost"] ?? "0"),
          let materialsCost = Double(dict["materialsCost"] ?? "0"),
          let total = Double(dict["total"] ?? "0") else {
      return nil
    }
    
    return QuoteData(
      laborHours: laborHours,
      laborRate: laborRate,
      laborCost: laborCost,
      materialsCost: materialsCost,
      total: total,
      notes: dict["notes"] ?? ""
    )
  }
  
  private func parseInvoiceId(from message: String) -> String? {
    guard message.hasPrefix("INVOICE_DATA:") else { return nil }
    
    let jsonString = String(message.dropFirst("INVOICE_DATA:".count))
    guard let jsonData = jsonString.data(using: .utf8),
          let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
          let invoiceId = dict["invoiceId"] as? String else {
      return nil
    }
    
    return invoiceId
  }
  
  private func parseInvoiceData(from message: String, attachmentUrl: String? = nil) -> InvoiceData? {
    guard message.hasPrefix("INVOICE_DATA:") else { return nil }
    
    let jsonString = String(message.dropFirst("INVOICE_DATA:".count))
    guard let jsonData = jsonString.data(using: .utf8),
          let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
      return nil
    }
    
    guard let invoiceId = dict["invoiceId"] as? String,
          let invoiceNumber = dict["invoiceNumber"] as? String,
          let status = dict["status"] as? String else {
      return nil
    }
    
    let total = (dict["total"] as? Double) ?? 0.0
    
    return InvoiceData(
      invoiceId: invoiceId,
      invoiceNumber: invoiceNumber,
      total: total,
      status: status,
      pdfUrl: attachmentUrl
    )
  }
  
  private var timelineSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      VStack(alignment: .leading, spacing: 16) {
        // Existing HStack for title and buttons...
        HStack {
          Image(systemName: "clock.arrow.circlepath")
            .foregroundColor(KMTheme.accent)
            .font(.title3)
          
          Text("Timeline")
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(KMTheme.primaryText)
          
          Spacer()
          
          // View mode toggle
          Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
              timelineViewMode = timelineViewMode == .detailed ? .compact : .detailed
            }
          }) {
            Image(systemName: timelineViewMode == .detailed ? "list.bullet" : "list.bullet.rectangle")
              .font(.caption)
              .foregroundColor(KMTheme.accent)
              .padding(6)
              .background(KMTheme.accent.opacity(0.1))
              .cornerRadius(6)
          }
          
          // Removed "Show All"; sections below handle compactness via collapsible days
        }
      }
      
      // Timeline with visual connectors
      VStack(spacing: 0) {
        let groups = groupEventsByDay()
        ForEach(groups, id: \.0) { label, groupEvents in
          // Group header
          Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
              if expandedDayGroups.contains(label) {
                expandedDayGroups.remove(label)
              } else {
                expandedDayGroups.insert(label)
              }
            }
          }) {
            HStack(spacing: 8) {
              Image(systemName: expandedDayGroups.contains(label) ? "chevron.down" : "chevron.right")
                .font(.caption)
                .foregroundColor(KMTheme.accent)
              Text(label)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(KMTheme.primaryText)
              Spacer()
              Text("\(groupEvents.count)")
                .font(.caption2)
                .foregroundColor(KMTheme.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(KMTheme.accent.opacity(0.1))
                .cornerRadius(6)
            }
            .padding(.vertical, 6)
          }
          .buttonStyle(PlainButtonStyle())
          .padding(.leading, 20)
          
          if expandedDayGroups.contains(label) {
            ForEach(Array(groupEvents.enumerated()), id: \.element.id) { index, event in
              HStack(alignment: .top, spacing: 12) {
                // Timeline connector within group
                VStack(spacing: 0) {
                  if index > 0 {
                    Rectangle()
                      .fill(KMTheme.border)
                      .frame(width: 2, height: 12)
                  } else {
                    Spacer()
                      .frame(height: 12)
                  }
                  Circle()
                    .fill(getEventColor(event.eventType))
                    .frame(width: 12, height: 12)
                    .overlay(
                      Circle()
                        .stroke(KMTheme.cardBackground, lineWidth: 2)
                    )
                  if index < groupEvents.count - 1 {
                    Rectangle()
                      .fill(KMTheme.border)
                      .frame(width: 2)
                  }
                }
                .frame(width: 12)
                
                // Event card
                event.view
                  .frame(maxWidth: .infinity)
                  .padding(.bottom, index < groupEvents.count - 1 ? (timelineViewMode == .compact ? 8 : 12) : 0)
              }
            }
          }
        }
        
        // Show loading indicator only if messages are still loading AND we have no events
        if threadService.isLoadingMessages && cachedTimelineEvents.isEmpty {
          HStack {
            ProgressView()
              .scaleEffect(0.8)
            Text("Loading timeline...")
              .font(.caption)
              .foregroundColor(KMTheme.secondaryText)
          }
          .padding(.vertical, 8)
        }
      }
      .id(timelineRefreshID) // Force re-render when timeline updates
    }
    .padding(20)
    .background(KMTheme.cardBackground)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(KMTheme.border, lineWidth: 0.5)
    )
  }
  
  private func shouldShowDaySeparator(for event: TimelineEventWrapper, at index: Int, in events: [TimelineEventWrapper]) -> Bool {
    guard index > 0 else { return true }
    let previousEvent = events[index - 1]
    return !Calendar.current.isDate(event.timestamp, inSameDayAs: previousEvent.timestamp)
  }
  
  private func groupEventsByDay() -> [(String, [TimelineEventWrapper])] {
    let grouped = Dictionary(grouping: cachedTimelineEvents) { event in
      Calendar.current.startOfDay(for: event.timestamp)
    }
    return grouped.sorted { $0.key < $1.key }
      .map { (formatDateForGroup($0.key), $0.value) }
  }
  
  private func formatDateForGroup(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
      return "Today"
    } else if calendar.isDateInYesterday(date) {
      return "Yesterday"
    } else {
      let formatter = DateFormatter()
      formatter.dateFormat = "MMMM d, yyyy"
      return formatter.string(from: date)
    }
  }
  
  private func getEventColor(_ eventType: TimelineEventType) -> Color {
    switch eventType {
    case .issueReported:
      return KMTheme.warning
    case .statusUpdate:
      return .green
    case .message:
      return KMTheme.accent
    case .aiAnalysis:
      return KMTheme.aiGreen
    case .photoAdded:
      return .blue
    case .receiptAdded:
      return .orange
    case .voiceNote:
      return .purple
    case .invoiceAdded:
      return .green
    }
  }
  
  // MARK: - Chat Composer
  
  private var chatComposer: some View {
    VStack(spacing: 0) {
      Divider()
        .background(KMTheme.border)
      
      // Mention autocomplete
      if showingMentionAutocomplete {
        MentionAutocompleteView(
          users: filteredMentionUsers,
          onSelectUser: { user in
            insertMention(user)
          }
        )
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }
      
      if showingQuickReplies {
        quickRepliesView
      }
      
      HStack(spacing: 12) {
        // Attachment button
        Button(action: {
          print("➕ [DEBUG] Attachment button tapped")
          showingAttachmentMenu = true
          print("➕ [DEBUG] showingAttachmentMenu set to: \(showingAttachmentMenu)")
        }) {
          Image(systemName: "plus.circle.fill")
            .font(.title2)
            .foregroundColor(KMTheme.accent)
        }
        
        .sheet(isPresented: $showingAttachmentMenu) {
          AttachmentMenuView(
            isAdmin: AdminConfig.isAdmin(email: appState.currentAppUser?.email),
            onPhotoSelected: {
              showingAttachmentMenu = false
              cameraSourceType = .photoLibrary
              showingImagePicker = true
            },
            onVoiceSelected: {
              showingAttachmentMenu = false
              showingVoiceRecorder = true
            },
            onQuoteSelected: {
              showingAttachmentMenu = false
              showingQuoteGenerator = true
            },
            onInvoiceSelected: {
              showingAttachmentMenu = false
              showingInvoiceBuilder = true
            },
            onDismiss: {
              showingAttachmentMenu = false
            }
          )
          .presentationDetents([.height(350)])
          .presentationDragIndicator(.visible)
        }
        
        // Message input
        TextField("Add update...", text: $newMessage, axis: .vertical)
          .textFieldStyle(PlainTextFieldStyle())
          .focused($isMessageFieldFocused)
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .background(KMTheme.background)
          .cornerRadius(20)
          .overlay(
            RoundedRectangle(cornerRadius: 20)
              .stroke(KMTheme.border, lineWidth: 1)
          )
          .lineLimit(1...4)
          .onChange(of: newMessage) { newValue in
            handleMessageTextChange(newValue)
          }
        
        // Send button
        Button(action: {
          print("📤 [DEBUG] Send button tapped - Message: '\(newMessage)'")
          sendMessage()
        }) {
          Image(systemName: "arrow.up.circle.fill")
            .font(.title2)
            .foregroundColor(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? KMTheme.tertiaryText : KMTheme.accent)
        }
        .disabled(newMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(KMTheme.cardBackground)
    }
  }
  
  private func sendMessage() {
    let message = newMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    print("📤 [DEBUG] sendMessage called with: '\(message)'")
    
    guard !message.isEmpty else { 
      print("❌ [DEBUG] Message is empty, not sending")
      return 
    }
    
    // Dismiss keyboard and clear input immediately for better UX
    isMessageFieldFocused = false
    newMessage = ""
    
    Task {
      do {
        print("📤 [DEBUG] Converting to maintenance request...")
        if let maintenanceRequest = convertToMaintenanceRequest() {
          print("📤 [DEBUG] Maintenance request ID: \(maintenanceRequest.id)")
          print("📤 [DEBUG] Author ID: \(appState.currentAppUser?.id ?? "nil")")
          print("📤 [DEBUG] Calling threadService.sendMessage...")
          
          try await threadService.sendMessage(
            requestId: maintenanceRequest.id,
            authorId: appState.currentAppUser?.id ?? "",
            message: message
          )
          
          print("📤 [DEBUG] Message sent successfully")
          
          // Notify mentioned users
          await notifyMentionedUsers(in: message)
          
          await notifyThreadUpdate(updateType: "message", preview: message)
        } else {
          print("❌ [DEBUG] Failed to convert to maintenance request")
        }
      } catch {
        print("❌ [DEBUG] Error sending message: \(error)")
        // Restore message on error
        await MainActor.run {
          newMessage = message
        }
      }
    }
  }
  
  private func handleVoiceNote(_ transcription: String) {
    print("🎤 [DEBUG] Voice note transcription: '\(transcription)'")
    
    // Don't send empty transcriptions
    guard !transcription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      print("⚠️ [DEBUG] Voice note transcription is empty, not sending")
      return
    }
    
    Task {
      do {
        if let maintenanceRequest = convertToMaintenanceRequest() {
          try await threadService.sendMessage(
            requestId: maintenanceRequest.id,
            authorId: appState.currentAppUser?.id ?? "",
            message: transcription,
            type: .voice
          )
          print("🎤 [DEBUG] Voice note sent successfully")
          await MainActor.run {
            refreshTimelineCache()
          }
          await notifyThreadUpdate(updateType: "voice", preview: transcription)
        }
      } catch {
        print("❌ [DEBUG] Error sending voice note: \(error)")
      }
    }
  }
  
  private func uploadPhoto(_ image: UIImage) {
    Task {
      await MainActor.run {
        isUploadingPhoto = true
        uploadProgress = "Uploading photo..."
      }
      
      do {
        print("📸 Uploading photo for issue: \(issue.id)")
        
        let photoId = UUID().uuidString
        let photoUrl = try await FirebaseClient.shared.uploadIssuePhoto(
          issueId: issue.id,
          photoId: photoId,
          image: image
        )
        
        await MainActor.run {
          uploadProgress = "Processing image..."
        }
        
        let newPhoto = IssuePhoto(
          id: photoId,
          issueId: issue.id,
          url: photoUrl,
          thumbUrl: photoUrl,
          takenAt: Date()
        )
        
        await MainActor.run {
          self.photos.append(newPhoto)
        }
        
        // Send photo upload notification
        await sendPhotoUploadNotification(photoCount: 1)
        
        // Automatically trigger AI analysis
        await MainActor.run {
          uploadProgress = "Analyzing image..."
        }
        
        print("🤖 Starting AI analysis of uploaded photo...")
        do {
          let analysisResult = try await OpenAIService.shared.analyzeDocument(image)
          print("✅ AI analysis completed successfully")
          print("📊 Document type: \(analysisResult.documentType.displayName)")
          print("💰 Subtotal: \(analysisResult.subtotal ?? 0), Tax: \(analysisResult.tax ?? 0), Total: \(analysisResult.total ?? 0)")
          
          // Send AI analysis to timeline
          if let maintenanceRequest = convertToMaintenanceRequest() {
            // Build comprehensive message based on document type
            var aiMessage = """
            📸 Photo Analysis
            
            Document Type: \(analysisResult.documentType.displayName)
            """
            
            // Add vendor if available
            if let vendor = analysisResult.vendor {
              aiMessage += "\nVendor: \(vendor)"
            }
            
            // Add financial details for receipts and invoices
            if analysisResult.documentType == .receipt || analysisResult.documentType == .invoice {
              aiMessage += "\n\n💰 Financial Details:"
              if let subtotal = analysisResult.subtotal {
                aiMessage += "\n• Subtotal: $\(String(format: "%.2f", subtotal))"
              }
              if let tax = analysisResult.tax {
                aiMessage += "\n• Tax: $\(String(format: "%.2f", tax))"
              }
              if let total = analysisResult.total {
                aiMessage += "\n• Total: $\(String(format: "%.2f", total))"
              }
              
              // Check if we have any financial data
              let hasFinancialData = analysisResult.subtotal != nil || analysisResult.tax != nil || analysisResult.total != nil
              if !hasFinancialData {
                aiMessage += "\n• ⚠️ Unable to extract financial amounts - please verify manually"
              }
              
              // Add items if available
              if let items = analysisResult.items, !items.isEmpty {
                aiMessage += "\n\n📋 Items:"
                for item in items.prefix(5) {
                  aiMessage += "\n• \(item)"
                }
                if items.count > 5 {
                  aiMessage += "\n• ...and \(items.count - 5) more"
                }
              }
              
              // Add expense category
              if let category = analysisResult.expenseCategory {
                aiMessage += "\n\n🏷️ Category: \(category.capitalized)"
              }
            }
            
            // Add description/assessment
            if let description = analysisResult.description {
              aiMessage += "\n\nAssessment: \(description)"
            }
            
            // Add confidence with visual indicator
            let confidencePercent = Int(analysisResult.confidence * 100)
            let confidenceEmoji = confidencePercent >= 90 ? "🟢" : confidencePercent >= 70 ? "🟡" : "🔴"
            aiMessage += "\n\n\(confidenceEmoji) Confidence: \(confidencePercent)%"
            
            try await threadService.sendMessage(
              requestId: maintenanceRequest.id,
              authorId: "ai",
              message: aiMessage,
              type: .text,
              attachmentUrl: newPhoto.url, // Include photo URL so users can view the receipt
              attachmentThumbUrl: newPhoto.thumbUrl
            )
            print("✅ AI analysis added to timeline with full financial details and photo attachment")
            await MainActor.run {
              refreshTimelineCache()
              uploadProgress = "Complete!"
            }
            
            // Success haptic and auto-hide
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
              isUploadingPhoto = false
            }
          }
          
        } catch {
          print("❌ AI analysis failed: \(error)")
          // Still send basic photo message if AI fails
          if let maintenanceRequest = convertToMaintenanceRequest() {
            try await threadService.sendMessage(
              requestId: maintenanceRequest.id,
              authorId: appState.currentAppUser?.id ?? "",
              message: "📸 Added photo",
              type: .photo,
              attachmentUrl: newPhoto.url,
              attachmentThumbUrl: newPhoto.thumbUrl
            )
            await MainActor.run {
              refreshTimelineCache()
              uploadProgress = "Photo added!"
            }
            
            // Success haptic and auto-hide
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
              isUploadingPhoto = false
            }
            
            await notifyThreadUpdate(updateType: "photo", preview: "Added photo")
          }
        }
        
        await refreshIssueData()
        
      } catch {
        print("❌ Failed to upload photo: \(error)")
        await MainActor.run {
          uploadProgress = "Upload failed"
          
          // Error haptic
          let errorFeedback = UINotificationFeedbackGenerator()
          errorFeedback.notificationOccurred(.error)
          
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isUploadingPhoto = false
          }
        }
      }
    }
  }

  private var quickRepliesView: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(getQuickReplies(), id: \.self) { reply in
          Button(reply) {
            newMessage = reply
            withAnimation(.easeInOut(duration: 0.15)) { showingQuickReplies = false }
          }
          .font(.caption)
          .foregroundColor(KMTheme.accent)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(KMTheme.accent.opacity(0.1))
          .cornerRadius(16)
        }
      }
      .padding(.horizontal, 16)
    }
    .padding(.vertical, 8)
    .background(KMTheme.cardBackground)
  }
  
  private func getQuickReplies() -> [String] {
    guard let role = appState.currentAppUser?.role else { return [] }
    return SmartReplyTemplate.getRepliesFor(role: role, conversationType: .issue_specific)
  }
  
  private func notifyThreadUpdate(updateType: String, preview: String) async {
    guard let currentUser = appState.currentAppUser else { return }
    do {
      let adminIds = try await FirebaseClient.shared.getAdminUserIds(adminEmails: AdminConfig.adminEmails)
      var recipients = Set(adminIds)
      if !issue.reporterId.isEmpty { recipients.insert(issue.reporterId) }
      // Exclude current user
      recipients.remove(currentUser.id)
      let updatedBy = currentUser.name.isEmpty ? (currentUser.email ?? "User") : currentUser.name
      await NotificationService.shared.sendWorkUpdateNotification(
        to: Array(recipients),
        issueTitle: issue.title,
        restaurantName: getLocationDisplayName(),
        updateType: updateType,
        issueId: issue.id,
        updatedBy: updatedBy
      )
    } catch {
      print("⚠️ Failed to send thread update notification: \(error)")
    }
  }
  
  // MARK: - AI Proposal Actions
  
  private func acceptProposal(messageId: String, proposal: AIProposal) async {
    guard let maintenanceRequest = convertToMaintenanceRequest() else { return }
    
    do {
      // Accept the proposal in the thread
      try await threadService.acceptProposal(requestId: maintenanceRequest.id, messageId: messageId)
      
      // Apply the proposed changes to the actual issue
      await applyProposalToIssue(proposal: proposal)
      
    } catch {
      print("❌ Error accepting proposal: \(error)")
    }
  }
  
  private func dismissProposal(messageId: String) async {
    guard let maintenanceRequest = convertToMaintenanceRequest() else { return }
    
    do {
      try await threadService.dismissProposal(requestId: maintenanceRequest.id, messageId: messageId)
    } catch {
      print("❌ Error dismissing proposal: \(error)")
    }
  }
  
  private func applyProposalToIssue(proposal: AIProposal) async {
    var updatedIssue = issue
    var hasChanges = false
    
    // Apply status change
    if let proposedStatus = proposal.proposedStatus {
      let newStatus: IssueStatus
      switch proposedStatus {
      case .reported: newStatus = .reported
      case .in_progress: newStatus = .in_progress
      case .completed: newStatus = .completed
      }
      
      if updatedIssue.status != newStatus {
        updatedIssue.status = newStatus
        localIssueStatus = newStatus
        hasChanges = true
      }
    }
    
    // Apply priority change
    if let proposedPriority = proposal.proposedPriority {
      let newPriority: IssuePriority
      switch proposedPriority {
      case .low: newPriority = .low
      case .medium: newPriority = .medium
      case .high: newPriority = .high
      }
      
      if updatedIssue.priority != newPriority {
        updatedIssue.priority = newPriority
        hasChanges = true
      }
    }
    
    // Save changes if any
    if hasChanges {
      do {
        try await FirebaseClient.shared.updateIssue(updatedIssue)
        await MainActor.run {
          issue = updatedIssue
        }
        
        // Create work log for the change
        if let nextAction = proposal.nextAction {
          let workLog = WorkLog(
            id: UUID().uuidString,
            issueId: issue.id,
            authorId: appState.currentAppUser?.id ?? "",
            message: "AI proposal accepted: \(nextAction)",
            createdAt: Date()
          )
          
          try await FirebaseClient.shared.createWorkLog(workLog)
          await refreshWorkLogs()
        }
        
      } catch {
        print("❌ Error applying proposal to issue: \(error)")
      }
    }
  }
  
  private func refreshWorkLogs() async {
    do {
      let logs = try await FirebaseClient.shared.fetchWorkLogs(issueId: issue.id)
      await MainActor.run {
        workLogs = logs
      }
    } catch {
      print("❌ Error refreshing work logs: \(error)")
    }
  }
  
  // Convert Issue to MaintenanceRequest for thread view
  private func convertToMaintenanceRequest() -> MaintenanceRequest? {
    // Map category from type string
    let category: MaintenanceCategory
    if let type = issue.type?.lowercased() {
      switch type {
      case let t where t.contains("hvac"): category = .hvac
      case let t where t.contains("electric"): category = .electrical
      case let t where t.contains("plumb"): category = .plumbing
      case let t where t.contains("kitchen"): category = .kitchen
      case let t where t.contains("door"), let t where t.contains("window"): category = .doors_windows
      case let t where t.contains("refriger"): category = .refrigeration
      case let t where t.contains("floor"): category = .flooring
      case let t where t.contains("paint"): category = .painting
      case let t where t.contains("clean"): category = .cleaning
      default: category = .other
      }
    } else {
      category = .other
    }
    
    // Map priority
    let priority: MaintenancePriority
    switch issue.priority {
    case .low: priority = .low
    case .medium: priority = .medium
    case .high: priority = .high
    }
    
    // Map status
    let status: RequestStatus
    switch issue.status {
    case .reported: status = .reported
    case .in_progress: status = .in_progress
    case .completed: status = .completed
    }
    
    return MaintenanceRequest(
      id: issue.id,
      businessId: issue.restaurantId,
      locationId: issue.locationId,
      reporterId: issue.reporterId,
      title: issue.title,
      description: issue.description ?? "",
      category: category,
      priority: priority,
      status: status,
      aiAnalysis: issue.aiAnalysis,
      photoUrls: issue.photoUrls,
      createdAt: issue.createdAt,
      updatedAt: issue.updatedAt
    )
  }
  
  // MARK: - Mention Functions
  
  private func loadMentionableUsers() async {
    do {
      let users = try await UserProfileService.shared.getMentionableUsers(
        locationId: issue.locationId,
        currentUser: appState.currentAppUser
      )
      
      await MainActor.run {
        mentionableUsers = users
      }
    } catch {
      print("❌ [Mentions] Failed to load mentionable users: \(error)")
    }
  }
  
  private func handleMessageTextChange(_ newValue: String) {
    // Detect if user is typing a mention
    if let lastAtIndex = newValue.lastIndex(of: "@") {
      let afterAt = String(newValue[newValue.index(after: lastAtIndex)...])
      
      // Check if there's a space after @ (which would end the mention)
      if !afterAt.contains(" ") && !afterAt.contains("\n") {
        // User is typing a mention
        currentMentionQuery = afterAt
        filteredMentionUsers = UserProfileService.shared.findUsersForMention(
          query: currentMentionQuery,
          in: mentionableUsers
        )
        
        withAnimation {
          showingMentionAutocomplete = !filteredMentionUsers.isEmpty
        }
      } else {
        // Space or newline after @, hide autocomplete
        withAnimation {
          showingMentionAutocomplete = false
        }
      }
    } else {
      // No @ in message, hide autocomplete
      withAnimation {
        showingMentionAutocomplete = false
      }
    }
  }
  
  private func insertMention(_ user: AppUser) {
    // Find the last @ symbol
    if let lastAtIndex = newMessage.lastIndex(of: "@") {
      // Replace from @ to end with the mention
      let beforeAt = String(newMessage[..<lastAtIndex])
      let mention = user.mentionText
      newMessage = beforeAt + mention + " "
      
      // Hide autocomplete
      withAnimation {
        showingMentionAutocomplete = false
      }
    }
  }
  
  private func notifyMentionedUsers(in message: String) async {
    // Extract mentions from message
    let mentions = UserProfileService.shared.extractMentions(from: message)
    
    guard !mentions.isEmpty else { return }
    
    // Resolve mentions to user IDs
    let mentionedUserIds = UserProfileService.shared.resolveMentions(
      mentions: mentions,
      from: mentionableUsers
    )
    
    guard !mentionedUserIds.isEmpty,
          let currentUser = appState.currentAppUser else { return }
    
    // Send notifications to mentioned users
    await NotificationService.shared.sendMentionNotification(
      to: mentionedUserIds,
      issueTitle: issue.title,
      restaurantName: issue.restaurantId,
      message: message,
      issueId: issue.id,
      mentionedBy: currentUser.name
    )
  }
  
}

// MARK: - Photo Upload Progress View

struct PhotoUploadProgressView: View {
  let uploadProgress: String
  @State private var animationProgress: CGFloat = 0
  
  var body: some View {
    VStack(spacing: 24) {
      // Compact icon
      Image(systemName: "photo.badge.plus")
        .font(.system(size: 24, weight: .medium))
        .foregroundColor(KMTheme.accent)
      
      VStack(spacing: 12) {
        Text(uploadProgress)
          .font(.headline)
          .foregroundColor(KMTheme.primaryText)
          .multilineTextAlignment(.center)
        
        // Animated progress bar
        ZStack(alignment: .leading) {
          RoundedRectangle(cornerRadius: 2)
            .fill(Color.gray.opacity(0.3))
            .frame(height: 4)
          
          RoundedRectangle(cornerRadius: 2)
            .fill(KMTheme.accent)
            .frame(width: animationProgress * 280, height: 4)
            .animation(.easeInOut(duration: 0.5), value: animationProgress)
        }
        .frame(width: 280)
      }
    }
    .padding(32)
    .onAppear {
      // Animate progress bar
      withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
        animationProgress = 1.0
      }
    }
  }
}

struct AIProposalTimelineCard: View {
  let proposal: AIProposal
  let onAccept: () -> Void
  let onDismiss: () -> Void
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header
      HStack {
        Image(systemName: "lightbulb.fill")
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(.orange)
        
        Text("AI Recommendation")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(KMTheme.primaryText)
        
        Spacer()
        
        // Confidence indicator
        HStack(spacing: 4) {
          Circle()
            .fill(confidenceColor)
            .frame(width: 6, height: 6)
          Text("\(Int(proposal.confidence * 100))%")
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(KMTheme.tertiaryText)
        }
      }
      
      // Proposal details
      VStack(alignment: .leading, spacing: 8) {
        if let proposedStatus = proposal.proposedStatus {
          proposalRow(label: "Status", value: proposedStatus.rawValue.capitalized, color: .blue)
        }
        
        if let proposedPriority = proposal.proposedPriority {
          proposalRow(label: "Priority", value: proposedPriority.rawValue.capitalized, color: priorityColor(proposedPriority.rawValue))
        }
        
        if let cost = proposal.extractedCost {
          proposalRow(label: "Cost", value: "$\(String(format: "%.2f", cost))", color: .green)
        }
        
        if let vendor = proposal.extractedVendor {
          proposalRow(label: "Vendor", value: vendor, color: KMTheme.secondaryText)
        }
        
        if let nextAction = proposal.nextAction {
          proposalRow(label: "Next Action", value: nextAction, color: KMTheme.accent)
        }
      }
      
      // Reasoning
      if !proposal.reasoning.isEmpty {
        Text(proposal.reasoning)
          .font(.system(size: 13))
          .foregroundColor(KMTheme.secondaryText)
          .padding(.top, 4)
      }
      
      // Action buttons
      HStack(spacing: 12) {
        Button(action: onAccept) {
          HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 14))
            Text("Accept")
              .font(.system(size: 14, weight: .medium))
          }
          .foregroundColor(.white)
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .background(.green)
          .cornerRadius(8)
        }
        
        Button(action: onDismiss) {
          HStack(spacing: 6) {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 14))
            Text("Dismiss")
              .font(.system(size: 14, weight: .medium))
          }
          .foregroundColor(KMTheme.secondaryText)
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .background(KMTheme.background)
          .cornerRadius(8)
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(KMTheme.border, lineWidth: 1)
          )
        }
        
        Spacer()
      }
      .padding(.top, 8)
    }
    .padding(16)
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(.orange.opacity(0.3), lineWidth: 1)
    )
  }
  
  private var confidenceColor: Color {
    if proposal.confidence >= 0.8 { return .green }
    if proposal.confidence >= 0.6 { return .orange }
    return .red
  }
  
  private func proposalRow(label: String, value: String, color: Color) -> some View {
    HStack {
      Text(label)
        .font(.system(size: 12))
        .foregroundColor(KMTheme.tertiaryText)
      Image(systemName: "arrow.right")
        .font(.system(size: 10))
        .foregroundColor(KMTheme.tertiaryText)
      Text(value)
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(color)
    }
  }
}

struct InfoChip: View {
  let icon: String
  let label: String
  let color: Color
  
  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: icon)
        .font(.caption2)
        .foregroundColor(color)
      
      Text(label)
        .font(.caption2)
        .fontWeight(.medium)
        .foregroundColor(color)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(color.opacity(0.1))
    .cornerRadius(6)
  }
}

struct RecommendationItem: View {
  let text: String
  
  var body: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(KMTheme.aiGreen)
        .frame(width: 4, height: 4)
      
      Text(text)
        .font(.caption)
        .foregroundColor(KMTheme.secondaryText)
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.leading)
      
      Spacer()
    }
  }
}

struct WorkUpdateItem: View {
  let workLog: WorkLog
  let userCache: [String: AppUser]
  @EnvironmentObject var appState: AppState
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(getWorkLogUserName(workLog))
          .font(.caption)
          .fontWeight(.medium)
          .foregroundColor(KMTheme.primaryText)
        
        Spacer()
        
        Text(workLog.createdAt.formatted(date: .abbreviated, time: .shortened))
          .font(.caption2)
          .foregroundColor(KMTheme.tertiaryText)
      }
      
      Text(workLog.message)
        .font(.caption)
        .foregroundColor(KMTheme.secondaryText)
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(12)
    .background(KMTheme.background)
    .cornerRadius(8)
  }
  
  private func getWorkLogUserName(_ workLog: WorkLog) -> String {
    // Try to get the user who created this work log
    if let currentUser = appState.currentAppUser {
      if currentUser.id == workLog.authorId {
        return currentUser.name.isEmpty ? (currentUser.email?.components(separatedBy: "@").first ?? "Unknown User") : currentUser.name
      }
    }
    
    // Try to map known user IDs to names
    return getUserDisplayName(for: workLog.authorId)
  }
  
  private func getUserDisplayName(for userId: String) -> String {
    // Special handling for AI messages
    if userId == "ai" {
      return "Kevin AI"
    }
    
    // Use UserLookupService which fetches from Firestore
    return UserLookupService.shared.getUserDisplayName(for: userId, currentUser: appState.currentAppUser)
  }
}


struct SimpleImagePicker: UIViewControllerRepresentable {
  let onImageSelected: (UIImage) -> Void
  let sourceType: UIImagePickerController.SourceType
  @Environment(\.dismiss) private var dismiss
  
  init(sourceType: UIImagePickerController.SourceType = .photoLibrary, onImageSelected: @escaping (UIImage) -> Void) {
    self.sourceType = sourceType
    self.onImageSelected = onImageSelected
  }
  
  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.delegate = context.coordinator
    picker.sourceType = sourceType
    picker.allowsEditing = true
    
    // Check if camera is available for camera source type
    if sourceType == .camera && !UIImagePickerController.isSourceTypeAvailable(.camera) {
      picker.sourceType = .photoLibrary
    }
    
    return picker
  }
  
  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
  
  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }
  
  class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let parent: SimpleImagePicker
    
    init(_ parent: SimpleImagePicker) {
      self.parent = parent
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
      if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
        parent.onImageSelected(image)
      }
      parent.dismiss()
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      parent.dismiss()
    }
  }
}

// MARK: - Detail Views

struct ReceiptData {
  let vendor: String?
  let subtotal: Double?
  let tax: Double?
  let total: Double?
  let items: [String]
  let category: String?
  let description: String?
  let confidence: Double
}

// Shared helper to parse receipt analysis text (supports multiple AI formats)
private func parseReceiptData(from transcription: String) -> ReceiptData {
  var vendor: String?
  var subtotal: Double?
  var tax: Double?
  var total: Double?
  var items: [String] = []
  var category: String?
  var description: String?
  var confidence: Double = 0.95

  // Vendor
  if let vendorRange = transcription.range(of: "**Vendor:**") {
    let tail = transcription[vendorRange.upperBound...]
    if let line = tail.split(separator: "\n").first {
      vendor = line.trimmingCharacters(in: .whitespaces)
      if vendor == "Unknown" { vendor = nil }
    }
  }

  // Amounts via robust regex patterns supporting both colon inside and outside bold
  func extractAmount(_ label: String) -> Double? {
    let patterns = [
      "\\*\\*\\Q\(label)\\E\\*\\*:?\\s*\\$?([0-9]+(?:\\.[0-9]{1,2})?)", // **Label**: 12.34
      "\\*\\*\\Q\(label):\\E\\*\\*\\s*\\$?([0-9]+(?:\\.[0-9]{1,2})?)", // **Label:** 12.34
      "\\Q\(label)\\E:?\\s*\\$?([0-9]+(?:\\.[0-9]{1,2})?)"                // Label: 12.34
    ]
    let fullRange = NSRange(transcription.startIndex..<transcription.endIndex, in: transcription)
    for p in patterns {
      if let regex = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) {
        if let match = regex.firstMatch(in: transcription, options: [], range: fullRange), match.numberOfRanges >= 2,
           let r = Range(match.range(at: 1), in: transcription) {
          return Double(transcription[r])
        }
      }
    }
    return nil
  }
  subtotal = extractAmount("Subtotal")
  tax = extractAmount("Tax")
  total = extractAmount("Total")

  // Items section
  if let itemsHeader = transcription.range(of: "**📋 Items:**") {
    let tail = transcription[itemsHeader.upperBound...]
    for line in tail.split(separator: "\n") {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.hasPrefix("**") { break } // next section reached
      if trimmed.hasPrefix("• ") {
        items.append(String(trimmed.dropFirst(2)))
      }
    }
  }

  // Category
  if let categoryHeader = transcription.range(of: "**🏷️ Category:**") {
    let tail = transcription[categoryHeader.upperBound...]
    if let line = tail.split(separator: "\n").first {
      category = line.trimmingCharacters(in: .whitespaces)
    }
  }

  // Description
  if let assessmentHeader = transcription.range(of: "**Assessment:**") {
    let tail = transcription[assessmentHeader.upperBound...]
    if let line = tail.split(separator: "\n").first {
      description = line.trimmingCharacters(in: .whitespaces)
    }
  }

  // Confidence (robust parsing of N%)
  if let confHeader = transcription.range(of: "Confidence", options: .caseInsensitive) {
    let tail = transcription[confHeader.upperBound...]
    let tailStr = String(tail)
    if let regex = try? NSRegularExpression(pattern: "([0-9]{1,3})%", options: []) {
      let range = NSRange(tailStr.startIndex..<tailStr.endIndex, in: tailStr)
      if let match = regex.firstMatch(in: tailStr, options: [], range: range), match.numberOfRanges >= 2,
         let r = Range(match.range(at: 1), in: tailStr), let num = Double(tailStr[r]) {
        confidence = min(1.0, max(0.0, num / 100.0))
      }
    }
  }

  return ReceiptData(
    vendor: vendor,
    subtotal: subtotal,
    tax: tax,
    total: total,
    items: items,
    category: category,
    description: description,
    confidence: confidence
  )
}

struct VoiceNoteDetailView: View {
  let transcription: String
  let imageUrl: String?
  let timestamp: Date
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    NavigationView {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Image(systemName: "waveform")
            .foregroundColor(KMTheme.accent)
            .font(.title2)
          
          Text("Voice Note")
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(KMTheme.primaryText)
          
          Spacer()
        }
        
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            // Voice note info
            VStack(alignment: .leading, spacing: 8) {
              HStack(spacing: 8) {
                Image(systemName: "waveform")
                  .foregroundColor(KMTheme.accent)
                  .font(.title3)
                
                Text("Voice Note")
                  .font(.subheadline)
                  .fontWeight(.semibold)
                  .foregroundColor(KMTheme.primaryText)
              }
              
              Text("Recorded at \(timestamp.formatted(date: .omitted, time: .shortened))")
                .font(.caption)
                .foregroundColor(KMTheme.secondaryText)
            }
            .padding()
            .background(KMTheme.cardBackground.opacity(0.5))
            .cornerRadius(8)
            
            // Optional image preview
            if let imageUrl, let url = URL(string: imageUrl) {
              AsyncImage(url: url) { image in
                image
                  .resizable()
                  .aspectRatio(contentMode: .fit)
              } placeholder: {
                Rectangle().fill(KMTheme.cardBackground).overlay(ProgressView())
              }
              .frame(maxWidth: .infinity)
              .cornerRadius(12)
            }
            
            // Transcription content
            VStack(alignment: .leading, spacing: 8) {
              Text("Transcription")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(KMTheme.primaryText)
              
              Text(transcription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No transcription available" : transcription)
                .font(.body)
                .foregroundColor(KMTheme.secondaryText)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(KMTheme.cardBackground)
            .cornerRadius(12)
          }
        }
        
        Spacer()
      }
      .padding()
      .background(KMTheme.background)
      .navigationTitle("Voice Note")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
  }
}

// Dedicated detail view for AI analyses (receipt/invoice and general AI text)
struct AIAnalysisDetailView: View {
  let analysisText: String
  let imageUrl: String?
  let timestamp: Date
  @Environment(\.dismiss) private var dismiss

  private var isReceiptAnalysis: Bool {
    analysisText.contains("**Photo Analysis**") && (analysisText.contains("**Document Type:** Receipt") || analysisText.contains("**Document Type:** Invoice"))
  }

  private var receiptView: some View {
    VStack(alignment: .leading, spacing: 16) {
      if let imageUrl, let url = URL(string: imageUrl) {
        AsyncImage(url: url) { image in
          image
            .resizable()
            .aspectRatio(contentMode: .fit)
        } placeholder: {
          Rectangle().fill(KMTheme.cardBackground).overlay(ProgressView())
        }
        .frame(maxWidth: .infinity)
        .cornerRadius(12)
      }

      let receiptData = parseReceiptData(from: analysisText)

      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Image(systemName: "doc.text.magnifyingglass")
            .foregroundColor(.orange)
            .font(.title3)
          Text("Receipt Analysis")
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(KMTheme.primaryText)
          Spacer()
          Text("\(Int(receiptData.confidence * 100))% Confidence")
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.orange.opacity(0.2))
            .foregroundColor(.orange)
            .cornerRadius(8)
        }
        if let vendor = receiptData.vendor {
          Text(vendor)
            .font(.subheadline)
            .foregroundColor(KMTheme.secondaryText)
        }
      }
      .padding()
      .background(KMTheme.cardBackground)
      .cornerRadius(12)

      VStack(alignment: .leading, spacing: 12) {
        Text("Financial Details")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        VStack(spacing: 8) {
          if let subtotal = receiptData.subtotal {
            HStack { Text("Subtotal").foregroundColor(KMTheme.secondaryText); Spacer(); Text("$\(String(format: "%.2f", subtotal))").fontWeight(.medium).foregroundColor(KMTheme.primaryText) }
          }
          if let tax = receiptData.tax {
            HStack { Text("Tax").foregroundColor(KMTheme.secondaryText); Spacer(); Text("$\(String(format: "%.2f", tax))").fontWeight(.medium).foregroundColor(KMTheme.primaryText) }
          }
          if let total = receiptData.total {
            Divider()
            HStack { Text("Total").font(.headline).fontWeight(.bold).foregroundColor(KMTheme.primaryText); Spacer(); Text("$\(String(format: "%.2f", total))").font(.headline).fontWeight(.bold).foregroundColor(KMTheme.accent) }
          }
        }
      }
      .padding()
      .background(KMTheme.cardBackground)
      .cornerRadius(12)

      if !receiptData.items.isEmpty {
        VStack(alignment: .leading, spacing: 12) {
          Text("Items Purchased").font(.headline).fontWeight(.semibold).foregroundColor(KMTheme.primaryText)
          VStack(alignment: .leading, spacing: 6) {
            ForEach(receiptData.items, id: \.self) { item in
              HStack {
                Image(systemName: "circle.fill").font(.system(size: 4)).foregroundColor(KMTheme.accent)
                Text(item).font(.body).foregroundColor(KMTheme.primaryText)
                Spacer()
              }
            }
          }
        }
        .padding()
        .background(KMTheme.cardBackground)
        .cornerRadius(12)
      }

      VStack(alignment: .leading, spacing: 12) {
        Text("Details").font(.headline).fontWeight(.semibold).foregroundColor(KMTheme.primaryText)
        VStack(alignment: .leading, spacing: 8) {
          if let category = receiptData.category {
            HStack { Text("Category:").foregroundColor(KMTheme.secondaryText); Text(category.capitalized).fontWeight(.medium).foregroundColor(KMTheme.primaryText); Spacer() }
          }
          if let description = receiptData.description {
            VStack(alignment: .leading, spacing: 4) { Text("Description:").foregroundColor(KMTheme.secondaryText); Text(description).foregroundColor(KMTheme.primaryText) }
          }
        }
      }
      .padding()
      .background(KMTheme.cardBackground)
      .cornerRadius(12)
    }
  }

  private var genericAIView: some View {
    VStack(alignment: .leading, spacing: 16) {
      if let imageUrl, let url = URL(string: imageUrl) {
        AsyncImage(url: url) { image in
          image.resizable().aspectRatio(contentMode: .fit)
        } placeholder: { Rectangle().fill(KMTheme.cardBackground).overlay(ProgressView()) }
        .frame(maxWidth: .infinity)
        .cornerRadius(12)
      }
      VStack(alignment: .leading, spacing: 8) {
        Text("Analysis").font(.subheadline).fontWeight(.semibold).foregroundColor(KMTheme.primaryText)
        Text(analysisText).font(.body).foregroundColor(KMTheme.secondaryText)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding()
      .background(KMTheme.cardBackground)
      .cornerRadius(12)
    }
  }

  var body: some View {
    NavigationView {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Image(systemName: isReceiptAnalysis ? "doc.text.magnifyingglass" : "sparkles")
            .foregroundColor(isReceiptAnalysis ? .orange : KMTheme.aiGreen)
            .font(.title2)
          Text(isReceiptAnalysis ? "Receipt Analysis" : "AI Analysis")
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(KMTheme.primaryText)
          Spacer()
        }
        ScrollView { isReceiptAnalysis ? AnyView(receiptView) : AnyView(genericAIView) }
        Spacer()
      }
      .padding()
      .background(KMTheme.background)
      .navigationTitle(isReceiptAnalysis ? "Receipt Analysis" : "AI Analysis")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
    }
  }
}

// Minimal detail view for plain text updates and status changes
struct TextDetailView: View {
  let title: String
  let text: String
  let timestamp: Date
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationView {
      VStack(alignment: .leading, spacing: 16) {
        HStack {
          Image(systemName: "text.bubble.fill")
            .foregroundColor(KMTheme.accent)
            .font(.title2)
          Text(title)
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(KMTheme.primaryText)
          Spacer()
        }

        ScrollView {
          VStack(alignment: .leading, spacing: 12) {
            Text("Updated at \(timestamp.formatted(date: .abbreviated, time: .shortened))")
              .font(.caption)
              .foregroundColor(KMTheme.secondaryText)

            VStack(alignment: .leading, spacing: 8) {
              Text(text)
                .font(.body)
                .foregroundColor(KMTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .background(KMTheme.cardBackground)
            .cornerRadius(12)
          }
        }

        Spacer()
      }
      .padding()
      .background(KMTheme.background)
      .navigationTitle(title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
    }
  }
}

struct QuoteGeneratorView: View {
  let issue: Issue
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var appState: AppState
  @State private var laborHours: String = ""
  @State private var laborRate: String = "75"
  @State private var materialCost: String = ""
  @State private var additionalNotes: String = ""
  @State private var isGenerating = false
  @State private var showingSuccess = false
  @State private var errorMessage: String?

  private var totalCost: Double {
    let labor = (Double(laborHours) ?? 0) * (Double(laborRate) ?? 0)
    let materials = Double(materialCost) ?? 0
    return labor + materials
  }

  var body: some View {
    NavigationView {
      ZStack {
        KMTheme.background.ignoresSafeArea()

        VStack(spacing: 0) {
          ScrollView {
            VStack(spacing: 24) {
              // Labor Section
              VStack(alignment: .leading, spacing: 16) {
                Text("Labor")
                  .font(.headline)
                  .fontWeight(.semibold)
                  .foregroundColor(KMTheme.primaryText)
                
                VStack(spacing: 12) {
                  HStack {
                    Text("Hours")
                      .foregroundColor(KMTheme.primaryText)
                    Spacer()
                    TextField("0", text: $laborHours)
                      .keyboardType(.decimalPad)
                      .multilineTextAlignment(.trailing)
                      .foregroundColor(KMTheme.primaryText)
                      .padding(12)
                      .frame(width: 100)
                      .background(KMTheme.background)
                      .cornerRadius(8)
                  }
                  
                  HStack {
                    Text("Rate per hour")
                      .foregroundColor(KMTheme.primaryText)
                    Spacer()
                    TextField("75", text: $laborRate)
                      .keyboardType(.decimalPad)
                      .multilineTextAlignment(.trailing)
                      .foregroundColor(KMTheme.primaryText)
                      .padding(12)
                      .frame(width: 100)
                      .background(KMTheme.background)
                      .cornerRadius(8)
                  }
                }
              }
              .padding(20)
              .background(KMTheme.cardBackground)
              .cornerRadius(16)
              
              // Materials Section
              VStack(alignment: .leading, spacing: 16) {
                Text("Materials")
                  .font(.headline)
                  .fontWeight(.semibold)
                  .foregroundColor(KMTheme.primaryText)
                
                HStack {
                  Text("Material cost")
                    .foregroundColor(KMTheme.primaryText)
                  Spacer()
                  TextField("0", text: $materialCost)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(KMTheme.primaryText)
                    .padding(12)
                    .frame(width: 120)
                    .background(KMTheme.background)
                    .cornerRadius(8)
                }
              }
              .padding(20)
              .background(KMTheme.cardBackground)
              .cornerRadius(16)
              
              // Additional Notes Section
              VStack(alignment: .leading, spacing: 16) {
                Text("Additional Notes")
                  .font(.headline)
                  .fontWeight(.semibold)
                  .foregroundColor(KMTheme.primaryText)
                
                TextField("Optional notes...", text: $additionalNotes, axis: .vertical)
                  .foregroundColor(KMTheme.primaryText)
                  .padding(12)
                  .background(KMTheme.background)
                  .cornerRadius(8)
                  .lineLimit(3...6)
              }
              .padding(20)
              .background(KMTheme.cardBackground)
              .cornerRadius(16)
              
              // Quote Summary Section
              VStack(alignment: .leading, spacing: 16) {
                Text("Quote Summary")
                  .font(.headline)
                  .fontWeight(.semibold)
                  .foregroundColor(KMTheme.primaryText)
                
                VStack(spacing: 12) {
                  HStack {
                    Text("Labor")
                      .foregroundColor(KMTheme.secondaryText)
                    Spacer()
                    Text("$\(String(format: "%.2f", (Double(laborHours) ?? 0) * (Double(laborRate) ?? 0)))")
                      .fontWeight(.medium)
                      .foregroundColor(KMTheme.primaryText)
                  }
                  
                  HStack {
                    Text("Materials")
                      .foregroundColor(KMTheme.secondaryText)
                    Spacer()
                    Text("$\(String(format: "%.2f", Double(materialCost) ?? 0))")
                      .fontWeight(.medium)
                      .foregroundColor(KMTheme.primaryText)
                  }
                  
                  Divider()
                    .background(KMTheme.border)
                  
                  HStack {
                    Text("Total")
                      .font(.title3)
                      .fontWeight(.bold)
                      .foregroundColor(KMTheme.primaryText)
                    Spacer()
                    Text("$\(String(format: "%.2f", totalCost))")
                      .font(.title3)
                      .fontWeight(.bold)
                      .foregroundColor(KMTheme.accent)
                  }
                }
              }
              .padding(20)
              .background(KMTheme.cardBackground)
              .cornerRadius(16)
              
              // Bottom spacer for button
              Spacer()
                .frame(height: 100)
            }
            .padding(24)
          }
          
          // Bottom Generate Button
          VStack(spacing: 0) {
            Divider()
              .background(KMTheme.border)
            
            Button(action: {
              generateQuote()
            }) {
              Text("Generate")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(laborHours.isEmpty || totalCost <= 0 || isGenerating ? KMTheme.accent.opacity(0.3) : KMTheme.accent)
                .cornerRadius(12)
            }
            .disabled(laborHours.isEmpty || totalCost <= 0 || isGenerating)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(KMTheme.background)
          }
        }
        .navigationTitle("Generate Quote")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .navigationBarLeading) {
            Button("Cancel") {
              dismiss()
            }
            .foregroundColor(KMTheme.accent)
          }
        }

        if isGenerating {
          Color.black.opacity(0.3)
            .ignoresSafeArea()

          VStack(spacing: 16) {
            ProgressView()
              .scaleEffect(1.2)
            Text("Generating quote...")
              .font(.headline)
              .foregroundColor(KMTheme.primaryText)
          }
          .padding(32)
          .background(KMTheme.cardBackground)
          .cornerRadius(16)
          .shadow(radius: 10)
        }
        
        if showingSuccess {
          Color.black.opacity(0.3)
            .ignoresSafeArea()
          
          QuoteSuccessView()
        }
      }
      .alert("Error", isPresented: .constant(errorMessage != nil)) {
        Button("OK") {
          errorMessage = nil
        }
      } message: {
        Text(errorMessage ?? "")
      }
    }
  }
  
  private func generateQuote() {
    isGenerating = true
    
    Task {
      do {
        let laborCost = (Double(laborHours) ?? 0) * (Double(laborRate) ?? 0)
        let materialsCost = Double(materialCost) ?? 0
        let total = laborCost + materialsCost
        
        // Create structured quote message that can be parsed by timeline
        let quoteData = [
          "type": "quote",
          "laborHours": String(Double(laborHours) ?? 0),
          "laborRate": String(Double(laborRate) ?? 0),
          "laborCost": String(format: "%.2f", laborCost),
          "materialsCost": String(format: "%.2f", materialsCost),
          "total": String(format: "%.2f", total),
          "notes": additionalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        ]
        
        // Convert to JSON string for storage
        let jsonData = try JSONSerialization.data(withJSONObject: quoteData)
        let quoteMessage = "QUOTE_DATA:" + String(data: jsonData, encoding: .utf8)!
        
        // Only send to thread service (not WorkLog to avoid duplicates)
        try await ThreadService.shared.sendMessage(
          requestId: issue.id,
          authorId: appState.currentAppUser?.id ?? "unknown",
          message: quoteMessage,
          type: .text
        )
        
        await MainActor.run {
          isGenerating = false
          showingSuccess = true
        }
        
        // Auto-dismiss after success animation
        await MainActor.run {
          DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            dismiss()
          }
        }
      } catch {
        print("❌ Error generating quote: \(error)")
        await MainActor.run {
          isGenerating = false
          errorMessage = "Failed to generate quote. Please try again."
        }
      }
    }
  }
}

// MARK: - Success Animation View

struct QuoteSuccessView: View {
  @State private var checkmarkScale: CGFloat = 0
  @State private var checkmarkOpacity: Double = 0
  @State private var circleScale: CGFloat = 0
  @State private var showingText = false
  
  var body: some View {
    VStack(spacing: 24) {
      ZStack {
        // Background circle
        Circle()
          .fill(.green.opacity(0.1))
          .frame(width: 100, height: 100)
          .scaleEffect(circleScale)
        
        // Checkmark
        Image(systemName: "checkmark")
          .font(.system(size: 40, weight: .bold))
          .foregroundColor(.green)
          .scaleEffect(checkmarkScale)
          .opacity(checkmarkOpacity)
      }
      
      if showingText {
        VStack(spacing: 8) {
          Text("Quote Generated!")
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(KMTheme.primaryText)
          
          Text("Added to timeline")
            .font(.subheadline)
            .foregroundColor(KMTheme.secondaryText)
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
      }
    }
    .padding(40)
    .background(KMTheme.cardBackground)
    .cornerRadius(20)
    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    .onAppear {
      // Trigger haptic feedback
      let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
      impactFeedback.impactOccurred()
      
      // Animate circle
      withAnimation(.easeOut(duration: 0.3)) {
        circleScale = 1.0
      }
      
      // Animate checkmark with delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
          checkmarkScale = 1.0
          checkmarkOpacity = 1.0
        }
        
        // Success haptic
        let successFeedback = UINotificationFeedbackGenerator()
        successFeedback.notificationOccurred(.success)
      }
      
      // Show text with delay
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
        withAnimation(.easeOut(duration: 0.3)) {
          showingText = true
        }
      }
    }
  }
}

// MARK: - Quote Data Structure

struct QuoteData {
  let laborHours: Double
  let laborRate: Double
  let laborCost: Double
  let materialsCost: Double
  let total: Double
  let notes: String
}

struct InvoiceData {
  let invoiceId: String
  let invoiceNumber: String
  let total: Double
  let status: String
  let pdfUrl: String?
}

// MARK: - Timeline Support Components

struct QuoteDetailView: View {
  let laborHours: Double
  let laborRate: Double
  let laborCost: Double
  let materialsCost: Double
  let total: Double
  let timestamp: Date
  let author: String
  let additionalNotes: String?
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    NavigationView {
      VStack(alignment: .leading, spacing: 24) {
        // Header
        HStack {
          Image(systemName: "dollarsign.circle.fill")
            .foregroundColor(.green)
            .font(.title2)
          
          Text("Quote Details")
            .font(.title2)
            .fontWeight(.semibold)
            .foregroundColor(KMTheme.primaryText)
          
          Spacer()
        }
        
        ScrollView {
          VStack(spacing: 20) {
            // Quote info
            VStack(alignment: .leading, spacing: 8) {
              Text("Submitted by \(author)")
                .font(.subheadline)
                .foregroundColor(KMTheme.secondaryText)
              Text(timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundColor(KMTheme.tertiaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(KMTheme.cardBackground)
            .cornerRadius(12)
            
            // Quote breakdown
            VStack(spacing: 16) {
              Text("Cost Breakdown")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(KMTheme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
              
              VStack(spacing: 12) {
                // Labor breakdown
                HStack {
                  Text("Labor")
                    .font(.body)
                    .foregroundColor(KMTheme.secondaryText)
                  Spacer()
                  Text("\(String(format: "%.1f", laborHours)) hrs × $\(String(format: "%.0f", laborRate))")
                    .font(.body)
                    .foregroundColor(KMTheme.secondaryText)
                  Text("$\(String(format: "%.2f", laborCost))")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(KMTheme.primaryText)
                }
                
                // Materials
                if materialsCost > 0 {
                  HStack {
                    Text("Materials")
                      .font(.body)
                      .foregroundColor(KMTheme.secondaryText)
                    Spacer()
                    Text("$\(String(format: "%.2f", materialsCost))")
                      .font(.body)
                      .fontWeight(.medium)
                      .foregroundColor(KMTheme.primaryText)
                  }
                }
                
                // Divider
                Divider()
                  .background(KMTheme.border)
                
                // Total
                HStack {
                  Text("Total Quote")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(KMTheme.primaryText)
                  Spacer()
                  Text("$\(String(format: "%.2f", total))")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                }
              }
            }
            .padding()
            .background(KMTheme.cardBackground)
            .cornerRadius(12)
            
            // Additional notes if any
            if let notes = additionalNotes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
              VStack(alignment: .leading, spacing: 12) {
                Text("Additional Notes")
                  .font(.headline)
                  .fontWeight(.semibold)
                  .foregroundColor(KMTheme.primaryText)
                  .frame(maxWidth: .infinity, alignment: .leading)
                
                Text(notes)
                  .font(.body)
                  .foregroundColor(KMTheme.secondaryText)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
              .padding()
              .background(KMTheme.cardBackground)
              .cornerRadius(12)
            }
          }
        }
        
        Spacer()
      }
      .padding()
      .background(KMTheme.background)
      .navigationTitle("Quote Details")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
          .foregroundColor(KMTheme.accent)
        }
      }
    }
  }
}

struct InvoiceFromTimelineView: View {
  let invoiceData: InvoiceData
  @State private var invoice: Invoice?
  @State private var isLoading = true
  @State private var errorMessage: String?
  
  var body: some View {
    Group {
      if isLoading {
        VStack {
          ProgressView("Loading invoice...")
            .padding()
        }
      } else if let invoice = invoice {
        InvoiceDetailView(invoice: invoice)
      } else {
        VStack {
          Text("Failed to load invoice")
            .foregroundColor(.red)
          if let error = errorMessage {
            Text(error)
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
        .padding()
      }
    }
    .onAppear {
      loadInvoice()
    }
  }
  
  private func loadInvoice() {
    Task {
      do {
        let loadedInvoice = try await FirebaseClient.shared.getInvoice(invoiceData.invoiceId)
        await MainActor.run {
          self.invoice = loadedInvoice
          self.isLoading = false
        }
      } catch {
        await MainActor.run {
          self.errorMessage = error.localizedDescription
          self.isLoading = false
        }
      }
    }
  }
}

struct DaySeparator: View {
    let date: Date

    var body: some View {
      HStack(spacing: 12) {
        Rectangle()
          .fill(KMTheme.border.opacity(0.3))
          .frame(height: 1)

        Text(formatDate(date))
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(KMTheme.tertiaryText)
          .padding(.horizontal, 12)
          .padding(.vertical, 4)
          .background(KMTheme.cardBackground)
          .cornerRadius(12)
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(KMTheme.border.opacity(0.3), lineWidth: 1)
          )

        Rectangle()
          .fill(KMTheme.border.opacity(0.3))
          .frame(height: 1)
      }
    }

    private func formatDate(_ date: Date) -> String {
      let calendar = Calendar.current
      if calendar.isDateInToday(date) {
        return "Today"
      } else if calendar.isDateInYesterday(date) {
        return "Yesterday"
      } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
      } else {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: date)
      }
    }
  }

struct EventTypeBadge: View {
    let eventType: TimelineEventType

    var body: some View {
      HStack(spacing: 4) {
        Image(systemName: badgeIcon)
          .font(.system(size: 8, weight: .bold))

        Text(badgeText)
          .font(.system(size: 10, weight: .semibold))
      }
      .foregroundColor(badgeColor)
      .padding(.horizontal, 6)
      .padding(.vertical, 3)
      .background(badgeColor.opacity(0.15))
      .cornerRadius(4)
    }

    private var badgeIcon: String {
      switch eventType {
      case .issueReported:
        return "exclamationmark.triangle.fill"
      case .statusUpdate:
        return "checkmark.circle.fill"
      case .message:
        return "bubble.left.fill"
      case .aiAnalysis:
        return "brain.head.profile"
      case .photoAdded:
        return "photo.fill"
      case .receiptAdded:
        return "doc.text.fill"
      case .voiceNote:
        return "waveform"
      case .invoiceAdded:
        return "doc.text.fill"
      }
    }

    private var badgeText: String {
      switch eventType {
      case .issueReported:
        return "REPORTED"
      case .statusUpdate:
        return "STATUS"
      case .message:
        return "UPDATE"
      case .aiAnalysis:
        return "AI"
      case .photoAdded:
        return "PHOTO"
      case .receiptAdded:
        return "RECEIPT"
      case .voiceNote:
        return "VOICE"
      case .invoiceAdded:
        return "INVOICE"
      }
    }

    private var badgeColor: Color {
      switch eventType {
      case .issueReported:
        return KMTheme.warning
      case .statusUpdate:
        return .green
      case .message:
        return KMTheme.accent
      case .aiAnalysis:
        return KMTheme.aiGreen
      case .photoAdded:
        return .blue
      case .receiptAdded:
        return .orange
      case .voiceNote:
        return .purple
      case .invoiceAdded:
        return .green
      }
    }
  }

// MARK: - Unified Timeline Card

struct TimelineCard: View {
    let icon: String
    let iconColor: Color
    let title: String
    let preview: String
    let timestamp: Date
    let author: String
    let lineLimit: Int
    let onTap: () -> Void
    var replyCount: Int? = nil
    var isReply: Bool = false
    var readReceipts: [ReadReceipt]? = nil
    var currentUserId: String? = nil
    var thumbnailUrl: String? = nil

    var body: some View {
      Button(action: onTap) {
        HStack(alignment: .top, spacing: 12) {
          // Icon
          ZStack {
            Circle()
              .fill(iconColor.opacity(0.15))
              .frame(width: 28, height: 28)

            Image(systemName: icon)
              .font(.system(size: 12, weight: .semibold))
              .foregroundColor(iconColor)
          }

          VStack(alignment: .leading, spacing: 4) {
            // Header with title and timestamp
            HStack(alignment: .firstTextBaseline) {
              Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(KMTheme.primaryText)

              Spacer()

              Text(formatRelativeTime(timestamp))
                .font(.system(size: 11))
                .foregroundColor(KMTheme.tertiaryText)
            }
            
            // Thumbnail image if available
            if let thumbnailUrl = thumbnailUrl, !thumbnailUrl.isEmpty, let url = URL(string: thumbnailUrl) {
              if thumbnailUrl.contains(".pdf") {
                // Invoice PDF thumbnail
                HStack(spacing: 12) {
                  // Invoice icon with better styling
                  ZStack {
                    RoundedRectangle(cornerRadius: 8)
                      .fill(KMTheme.accent.opacity(0.1))
                      .frame(width: 50, height: 50)
                    
                    Image(systemName: "doc.text.fill")
                      .font(.system(size: 24))
                      .foregroundColor(KMTheme.accent)
                  }
                  
                  VStack(alignment: .leading, spacing: 4) {
                    Text("Invoice PDF")
                      .font(.system(size: 14, weight: .semibold))
                      .foregroundColor(KMTheme.primaryText)
                    Text("Tap to view invoice")
                      .font(.system(size: 12))
                      .foregroundColor(KMTheme.secondaryText)
                  }
                  Spacer()
                }
                .padding(8)
                .background(KMTheme.cardBackground)
                .cornerRadius(8)
                .overlay(
                  RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
              } else {
                // Regular image thumbnail
                AsyncImage(url: url) { image in
                  image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                } placeholder: {
                  Rectangle()
                    .fill(KMTheme.borderSecondary)
                    .overlay(ProgressView())
                }
                .frame(width: 60, height: 60)
                .cornerRadius(8)
                .clipped()
              }
            }

            // Preview text (density-controlled)
            Text(preview)
              .font(.system(size: 13))
              .foregroundColor(KMTheme.secondaryText)
              .lineLimit(lineLimit)
              .multilineTextAlignment(.leading)

            // Author, read receipts, and reply count row
            HStack(spacing: 8) {
              Text(author)
                .font(.system(size: 11))
                .foregroundColor(KMTheme.tertiaryText)
              
              // Read receipt indicator
              if let receipts = readReceipts, !receipts.isEmpty {
                HStack(spacing: 2) {
                  Image(systemName: receipts.count > 1 ? "checkmark.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(KMTheme.accent.opacity(0.7))
                  Text("Read")
                    .font(.system(size: 10))
                    .foregroundColor(KMTheme.tertiaryText)
                }
              } else if currentUserId != nil {
                // Show delivered indicator if no read receipts yet
                HStack(spacing: 2) {
                  Image(systemName: "checkmark")
                    .font(.system(size: 10))
                    .foregroundColor(KMTheme.tertiaryText.opacity(0.5))
                  Text("Delivered")
                    .font(.system(size: 10))
                    .foregroundColor(KMTheme.tertiaryText.opacity(0.7))
                }
              }
              
              Spacer()
              
              // Reply count badge
              if let count = replyCount, count > 0 {
                HStack(spacing: 4) {
                  Image(systemName: "bubble.left.fill")
                    .font(.system(size: 9))
                  Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(KMTheme.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(KMTheme.accent.opacity(0.1))
                .cornerRadius(8)
              }
            }
          }
        }
        .padding(12)
        .background(isReply ? KMTheme.background : KMTheme.cardBackground)
        .cornerRadius(10)
        .overlay(
          RoundedRectangle(cornerRadius: 10)
            .stroke(isReply ? KMTheme.accent.opacity(0.2) : KMTheme.border.opacity(0.3), lineWidth: isReply ? 1.5 : 0.5)
        )
      }
      .buttonStyle(PlainButtonStyle())
    }

    private func formatRelativeTime(_ date: Date) -> String {
      let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: Date())
      if let day = components.day, day > 0 {
        return day == 1 ? "Yesterday" : (day < 7 ? "\(day)d ago" : date.formatted(date: .abbreviated, time: .omitted))
      } else if let hour = components.hour, hour > 0 {
        return "\(hour)h ago"
      } else if let minute = components.minute, minute > 0 {
        return "\(minute)m ago"
      }
      return "Just now"
    }
  }

// MARK: - Attachment Menu

struct AttachmentMenuView: View {
    let isAdmin: Bool
    let onPhotoSelected: () -> Void
    let onVoiceSelected: () -> Void
    let onQuoteSelected: () -> Void
    let onInvoiceSelected: () -> Void
    let onDismiss: () -> Void

    var body: some View {
      VStack(spacing: 0) {
        // Add top padding for proper spacing from handle bar
        Spacer()
          .frame(height: 20)

        // Menu items
        VStack(spacing: 0) {
          // Photo option
          AttachmentMenuItem(
            icon: "photo",
            title: "Photo",
            subtitle: "Add a photo update",
            color: .blue,
            onTap: onPhotoSelected
          )

          Divider()
            .padding(.leading, 60)

          // Voice option
          AttachmentMenuItem(
            icon: "waveform",
            title: "Voice Note",
            subtitle: "Record a voice message",
            color: .purple,
            onTap: onVoiceSelected
          )

          // Quote option (admin only)
          if isAdmin {
            Divider()
              .padding(.leading, 60)

            AttachmentMenuItem(
              icon: "dollarsign.circle",
              title: "Generate Quote",
              subtitle: "Create a cost estimate",
              color: .green,
              onTap: onQuoteSelected
            )
            
            Divider()
              .padding(.leading, 60)

            AttachmentMenuItem(
              icon: "doc.text",
              title: "Create Invoice",
              subtitle: "Generate an invoice",
              color: .orange,
              onTap: onInvoiceSelected
            )
          }
        }
        .padding(.horizontal, 16)

        // Add bottom padding for safe area
        Spacer()
          .frame(height: 20)
      }
    }
  }

struct AttachmentMenuItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let onTap: () -> Void

    var body: some View {
      Button(action: onTap) {
        HStack(spacing: 16) {
          // Icon
          ZStack {
            Circle()
              .fill(color.opacity(0.15))
              .frame(width: 44, height: 44)

            Image(systemName: icon)
              .font(.system(size: 20, weight: .medium))
              .foregroundColor(color)
          }

          // Text
          VStack(alignment: .leading, spacing: 2) {
            Text(title)
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(KMTheme.primaryText)

            Text(subtitle)
              .font(.system(size: 13))
              .foregroundColor(KMTheme.secondaryText)
          }

          Spacer()

          // Chevron
          Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(KMTheme.tertiaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
      }
      .buttonStyle(PlainButtonStyle())
    }
  }

