import SwiftUI
import FirebaseFirestore
struct ExpandableIssueCard: View {
    let conversation: Conversation
    let startExpanded: Bool
    @State private var isExpanded = false
    @State private var issue: Issue?
    @State private var photos: [IssuePhoto] = []
    @State private var receipts: [Receipt] = []
    @State private var threadMessages: [ThreadMessage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingPhotoSlider = false
    @State private var selectedPhotoIndex = 0
    @State private var showingIssueDetail = false
    
    init(conversation: Conversation, startExpanded: Bool = false) {
        self.conversation = conversation
        self.startExpanded = startExpanded
        // Don't expand immediately - wait for data to load first
        self._isExpanded = State(initialValue: false)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Collapsed card content
            collapsedCard
            
            // Expanded content
            if isExpanded {
                expandedContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity.combined(with: .move(edge: .top))
                    ))
            }
        }
        .background(KMTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KMTheme.border, lineWidth: 0.5)
        )
        .onAppear {
            loadIssueData()
        }
        .fullScreenCover(isPresented: $showingPhotoSlider) {
            PhotoSliderView(
                photos: photos,
                initialIndex: selectedPhotoIndex,
                isPresented: $showingPhotoSlider
            )
        }
        .sheet(isPresented: $showingIssueDetail) {
            if let issue = issue {
                NavigationStack {
                    IssueDetailView(issue: .constant(issue))
                }
            }
        }
    }
    
    private var collapsedCard: some View {
        VStack(spacing: 0) {
            // Main header - tappable to expand/collapse
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    // Status indicator
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        // Issue title - shortened summary
                        Text(shortenedTitle)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(KMTheme.primaryText)
                            .lineLimit(1)
                        
                        // Issue metadata
                        HStack(spacing: 12) {
                            if let issue = issue {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.triangle")
                                        .font(.caption2)
                                        .foregroundColor(priorityColor(issue.priority.rawValue))
                                    
                                    Text(issue.priority.rawValue.capitalized)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(priorityColor(issue.priority.rawValue))
                                }
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(statusColor)
                                    
                                    Text(issue.status.rawValue.replacingOccurrences(of: "_", with: " ").capitalized)
                                        .font(.caption)
                                        .foregroundColor(KMTheme.secondaryText)
                                }
                            }
                            
                            Spacer()
                            
                            // Content indicators
                            HStack(spacing: 12) {
                                // Photo count indicator
                                if !photos.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "photo")
                                            .font(.caption2)
                                            .foregroundColor(KMTheme.accent)
                                        
                                        Text("\(photos.count)")
                                            .font(.caption)
                                            .foregroundColor(KMTheme.accent)
                                    }
                                }
                                
                                // Receipt count indicator
                                if !receipts.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.text")
                                            .font(.caption2)
                                            .foregroundColor(KMTheme.success)
                                        
                                        Text("\(receipts.count)")
                                            .font(.caption)
                                            .foregroundColor(KMTheme.success)
                                    }
                                }
                                
                                // Voice message count indicator - only real transcriptions
                                let voiceMessages = threadMessages.filter { message in
                                    message.type == .voice && 
                                    !message.message.isEmpty &&
                                    !message.message.contains("Voice note recorded at") &&
                                    !message.message.contains("📸 **Photo Analysis**") &&
                                    !message.message.contains("**Photo Analysis**") &&
                                    !message.message.contains("**Assessment:**") &&
                                    !message.message.contains("**Document Type:**")
                                }
                                if !voiceMessages.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "waveform")
                                            .font(.caption2)
                                            .foregroundColor(KMTheme.progress)
                                        
                                        Text("\(voiceMessages.count)")
                                            .font(.caption)
                                            .foregroundColor(KMTheme.progress)
                                    }
                                }
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Expand/collapse indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(KMTheme.secondaryText)
                }
                .padding(16)
            }
            .buttonStyle(PlainButtonStyle())
            
        }
    }
    
    @ViewBuilder
    private var expandedContent: some View {
        if let issue = issue {
            VStack(alignment: .leading, spacing: 12) {
                Divider()
                    .background(KMTheme.border)
                
                VStack(alignment: .leading, spacing: 10) {
                    // Compact metadata row
                    HStack(spacing: 16) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                                .foregroundColor(KMTheme.tertiaryText)
                            Text(issue.createdAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(KMTheme.secondaryText)
                        }
                        
                        if let type = issue.type {
                            HStack(spacing: 4) {
                                Image(systemName: "tag")
                                    .font(.caption2)
                                    .foregroundColor(KMTheme.tertiaryText)
                                Text(type.replacingOccurrences(of: "_", with: " ").capitalized)
                                    .font(.caption)
                                    .foregroundColor(KMTheme.secondaryText)
                            }
                        }
                        
                        Spacer()
                        
                        // Thumbnails section
                        HStack(spacing: 8) {
                            // Photo thumbnail if available
                            if !photos.isEmpty {
                                Button(action: {
                                    selectedPhotoIndex = 0
                                    showingPhotoSlider = true
                                }) {
                                    HStack(spacing: 4) {
                                        AsyncImage(url: URL(string: photos[0].url)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Rectangle()
                                                .fill(KMTheme.borderSecondary)
                                        }
                                        .frame(width: 40, height: 40)
                                        .cornerRadius(6)
                                        .clipped()
                                        
                                        if photos.count > 1 {
                                            Text("+\(photos.count - 1)")
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(KMTheme.accent)
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // Receipt thumbnail if available
                            if !receipts.isEmpty {
                                Button(action: {
                                    showingIssueDetail = true
                                }) {
                                    HStack(spacing: 4) {
                                        AsyncImage(url: URL(string: receipts[0].thumbnailUrl ?? receipts[0].receiptImageUrl)) { image in
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Rectangle()
                                                .fill(KMTheme.borderSecondary)
                                                .overlay(
                                                    Image(systemName: "doc.text")
                                                        .foregroundColor(KMTheme.accent)
                                                )
                                        }
                                        .frame(width: 40, height: 40)
                                        .cornerRadius(6)
                                        .clipped()
                                        
                                        if receipts.count > 1 {
                                            Text("+\(receipts.count - 1)")
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(KMTheme.accent)
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            
                            // Voice message indicator if available - only real transcriptions
                            let voiceMessages = threadMessages.filter { message in
                                message.type == .voice && 
                                !message.message.isEmpty &&
                                !message.message.contains("Voice note recorded at") &&
                                !message.message.contains("📸 **Photo Analysis**") &&
                                !message.message.contains("**Photo Analysis**") &&
                                !message.message.contains("**Assessment:**") &&
                                !message.message.contains("**Document Type:**")
                            }
                            if !voiceMessages.isEmpty {
                                Button(action: {
                                    showingIssueDetail = true
                                }) {
                                    HStack(spacing: 4) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(KMTheme.accent.opacity(0.1))
                                                .frame(width: 40, height: 40)
                                            
                                            Image(systemName: "waveform")
                                                .foregroundColor(KMTheme.accent)
                                                .font(.system(size: 16))
                                        }
                                        
                                        if voiceMessages.count > 1 {
                                            Text("+\(voiceMessages.count - 1)")
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(KMTheme.accent)
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                    }
                    
                    // Compact AI Analysis - single line
                    if let aiAnalysis = issue.aiAnalysis {
                        HStack(spacing: 6) {
                            Image(systemName: "brain.head.profile")
                                .font(.caption2)
                                .foregroundColor(KMTheme.aiGreen)
                            
                            Text(aiAnalysis.estimatedTime.isEmpty || aiAnalysis.estimatedTime == "Unknown" ? "AI analyzed" : "Est: \(aiAnalysis.estimatedTime)")
                                .font(.caption)
                                .foregroundColor(KMTheme.secondaryText)
                            
                            Spacer()
                            
                            Button(action: {
                                showingIssueDetail = true
                            }) {
                                HStack(spacing: 4) {
                                    Text("Details")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    Image(systemName: "chevron.right")
                                        .font(.caption2)
                                }
                                .foregroundColor(KMTheme.accent)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // Voice transcriptions preview - only real transcriptions
                    let voiceMessages = threadMessages.filter { message in
                        message.type == .voice && 
                        !message.message.isEmpty &&
                        !message.message.contains("Voice note recorded at") &&
                        !message.message.contains("📸 **Photo Analysis**") &&
                        !message.message.contains("**Photo Analysis**") &&
                        !message.message.contains("**Assessment:**") &&
                        !message.message.contains("**Document Type:**")
                    }
                    if !voiceMessages.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "waveform")
                                    .font(.caption2)
                                    .foregroundColor(KMTheme.accent)
                                
                                Text("Voice Notes")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(KMTheme.primaryText)
                                
                                Spacer()
                                
                                Text("\(voiceMessages.count)")
                                    .font(.caption2)
                                    .foregroundColor(KMTheme.secondaryText)
                            }
                            
                            // Show preview of first voice message
                            if let firstVoice = voiceMessages.first {
                                Text(firstVoice.message)
                                    .font(.caption)
                                    .foregroundColor(KMTheme.secondaryText)
                                    .lineLimit(2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(KMTheme.background.opacity(0.5))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        } else if isLoading {
            VStack {
                Divider()
                    .background(KMTheme.border)
                
                HStack {
                    ProgressView()
                        .tint(KMTheme.accent)
                        .scaleEffect(0.8)
                    
                    Text("Loading issue details...")
                        .font(.caption)
                        .foregroundColor(KMTheme.secondaryText)
                    
                    Spacer()
                }
                .padding(16)
            }
        } else {
            // Issue not found - show error state with conversation info
            VStack(spacing: 12) {
                Divider()
                    .background(KMTheme.border)
                
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundColor(KMTheme.warning)
                    
                    Text("Issue Not Found")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(KMTheme.primaryText)
                    
                    Text("This issue may have been deleted or is no longer available.")
                        .font(.caption)
                        .foregroundColor(KMTheme.secondaryText)
                        .multilineTextAlignment(.center)
                    
                    // Show conversation details as fallback
                    if let title = conversation.title {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Conversation Details:")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(KMTheme.primaryText)
                            
                            Text(title)
                                .font(.caption)
                                .foregroundColor(KMTheme.secondaryText)
                                .lineLimit(3)
                        }
                        .padding(12)
                        .background(KMTheme.cardBackground.opacity(0.5))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(KMTheme.border, lineWidth: 1)
                        )
                    }
                    
                    // Debug info for development
                    if let issueId = conversation.issueId {
                        Text("Issue ID: \(issueId)")
                            .font(.caption2)
                            .foregroundColor(KMTheme.tertiaryText)
                            .opacity(0.7)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
            }
        }
    }
    
    // Shortened title - extract first sentence or first 50 chars
    private var shortenedTitle: String {
        let title = conversation.title ?? "Issue Discussion"
        
        // Try to get first sentence
        if let firstSentence = title.components(separatedBy: ". ").first, firstSentence.count < 80 {
            return firstSentence
        }
        
        // Otherwise truncate to 50 chars
        if title.count > 50 {
            return String(title.prefix(50)) + "..."
        }
        
        return title
    }
    
    private var statusColor: Color {
        guard let issue = issue else { return KMTheme.secondaryText }
        
        switch issue.status {
        case .reported: return KMTheme.warning
        case .in_progress: return KMTheme.progress
        case .completed: return KMTheme.success
        }
    }
    
    private func priorityColor(_ priority: String) -> Color {
        switch priority.lowercased() {
        case "urgent": return KMTheme.danger
        case "high": return KMTheme.warning
        case "normal": return KMTheme.accent
        case "low": return KMTheme.success
        default: return KMTheme.secondaryText
        }
    }
    
    private func loadIssueData() {
        guard let issueId = conversation.issueId else {
            print("⚠️ [ExpandableIssueCard] No issueId in conversation")
            isLoading = false
            return
        }
        
        print("🔄 [ExpandableIssueCard] Loading issue data for: \(issueId)")
        print("🔄 [ExpandableIssueCard] Conversation ID: \(conversation.id)")
        print("🔄 [ExpandableIssueCard] Conversation title: \(conversation.title ?? "nil")")
        print("🔄 [ExpandableIssueCard] startExpanded: \(startExpanded)")
        isLoading = true
        
        Task {
            do {
                // First try direct lookup
                async let issueData = FirebaseClient.shared.fetchIssue(byId: issueId)
                async let photoData = FirebaseClient.shared.fetchIssuePhotos(issueId: issueId)
                async let receiptData = FirebaseClient.shared.getReceipts(for: issueId)
                async let threadData = loadThreadMessages(for: issueId)
                
                let (foundIssue, loadedPhotos, loadedReceipts, loadedThreadMessages) = try await (issueData, photoData, receiptData, threadData)
                
                if let foundIssue = foundIssue {
                    print("✅ [ExpandableIssueCard] Found issue: \(foundIssue.title)")
                    print("📸 [ExpandableIssueCard] Loaded \(loadedPhotos.count) photos from issuePhotos collection")
                    
                    // Combine photos from issuePhotos collection + legacy photoUrls
                    var allPhotos = loadedPhotos
                    if let photoUrls = foundIssue.photoUrls {
                        print("📸 [ExpandableIssueCard] Found \(photoUrls.count) legacy photoUrls in issue")
                        for (index, url) in photoUrls.enumerated() {
                            // Check if this URL is already in the photos array
                            if !allPhotos.contains(where: { $0.url == url }) {
                                let legacyPhoto = IssuePhoto(
                                    id: "legacy-\(index)",
                                    issueId: issueId,
                                    url: url,
                                    thumbUrl: url,
                                    takenAt: foundIssue.createdAt
                                )
                                allPhotos.append(legacyPhoto)
                                print("📸 [ExpandableIssueCard] Added legacy photo: \(url)")
                            }
                        }
                    }
                    print("📸 [ExpandableIssueCard] Total photos (including legacy): \(allPhotos.count)")
                    
                    await MainActor.run {
                        self.issue = foundIssue
                        self.photos = allPhotos
                        self.receipts = loadedReceipts
                        self.threadMessages = loadedThreadMessages
                        self.isLoading = false
                        
                        print("🔄 [ExpandableIssueCard] Data loaded, checking auto-expand...")
                        print("🔄 [ExpandableIssueCard] - startExpanded: \(self.startExpanded)")
                        print("🔄 [ExpandableIssueCard] - isExpanded: \(self.isExpanded)")
                        
                        // Auto-expand if startExpanded is true
                        if self.startExpanded && !self.isExpanded {
                            print("✅ [ExpandableIssueCard] Auto-expanding card")
                            withAnimation(.easeInOut(duration: 0.3)) {
                                self.isExpanded = true
                            }
                        } else {
                            print("⚠️ [ExpandableIssueCard] NOT auto-expanding: startExpanded=\(self.startExpanded), isExpanded=\(self.isExpanded)")
                        }
                    }
                } else {
                    print("❌ [ExpandableIssueCard] Issue not found in issues collection: \(issueId)")
                    print("🔍 [ExpandableIssueCard] Trying maintenance_requests collection...")
                    
                    // Try the old maintenance_requests collection
                    do {
                        let maintenanceRequest = try await FirebaseClient.shared.fetchMaintenanceRequest(id: issueId)
                        let requestPhotos = try await FirebaseClient.shared.fetchIssuePhotos(issueId: issueId)
                        let requestReceipts = try await FirebaseClient.shared.getReceipts(for: issueId)
                        let requestThreadMessages = try await loadThreadMessages(for: issueId)
                        
                        print("✅ [ExpandableIssueCard] Found in maintenance_requests collection")
                        
                        // Convert MaintenanceRequest to Issue for display
                        // Map RequestStatus to IssueStatus
                        let issueStatus: IssueStatus
                        switch maintenanceRequest.status {
                        case .reported: issueStatus = .reported
                        case .in_progress: issueStatus = .in_progress
                        case .completed: issueStatus = .completed
                        }
                        
                        // Map MaintenancePriority to IssuePriority
                        let issuePriority: IssuePriority
                        switch maintenanceRequest.priority {
                        case .low: issuePriority = .low
                        case .medium: issuePriority = .medium
                        case .high: issuePriority = .high
                        }
                        
                        let convertedIssue = Issue(
                            id: maintenanceRequest.id,
                            restaurantId: maintenanceRequest.businessId,
                            locationId: maintenanceRequest.locationId ?? "",
                            reporterId: maintenanceRequest.reporterId,
                            title: maintenanceRequest.title,
                            description: maintenanceRequest.description,
                            type: maintenanceRequest.category.rawValue,
                            priority: issuePriority,
                            status: issueStatus,
                            photoUrls: maintenanceRequest.photoUrls,
                            aiAnalysis: maintenanceRequest.aiAnalysis,
                            createdAt: maintenanceRequest.createdAt,
                            updatedAt: maintenanceRequest.updatedAt
                        )
                        
                        // Combine photos from issuePhotos collection + legacy photoUrls
                        var allPhotos = requestPhotos
                        if let photoUrls = maintenanceRequest.photoUrls {
                            print("📸 [ExpandableIssueCard] Found \(photoUrls.count) legacy photoUrls in maintenance_request")
                            for (index, url) in photoUrls.enumerated() {
                                if !allPhotos.contains(where: { $0.url == url }) {
                                    let legacyPhoto = IssuePhoto(
                                        id: "legacy-\(index)",
                                        issueId: issueId,
                                        url: url,
                                        thumbUrl: url,
                                        takenAt: maintenanceRequest.createdAt
                                    )
                                    allPhotos.append(legacyPhoto)
                                    print("📸 [ExpandableIssueCard] Added legacy photo: \(url)")
                                }
                            }
                        }
                        print("📸 [ExpandableIssueCard] Total photos (including legacy): \(allPhotos.count)")
                        
                        await MainActor.run {
                            self.issue = convertedIssue
                            self.photos = allPhotos
                            self.receipts = requestReceipts
                            self.threadMessages = requestThreadMessages
                            self.isLoading = false
                            
                            if self.startExpanded && !self.isExpanded {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    self.isExpanded = true
                                }
                            }
                        }
                    } catch {
                        print("❌ [ExpandableIssueCard] Not found in maintenance_requests either: \(error)")
                        await MainActor.run {
                            self.isLoading = false
                            self.errorMessage = "Issue not found. It may have been deleted."
                        }
                    }
                }
            } catch {
                print("❌ [ExpandableIssueCard] Failed to load issue data: \(error)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func findBestMatchingIssue(conversationTitle: String, allIssues: [Issue]) -> Issue? {
        let searchText = conversationTitle.lowercased()
        
        // Extract key words from conversation title (remove common words)
        let commonWords = Set(["the", "image", "shows", "depicts", "a", "an", "is", "are", "with", "of", "in", "on", "at", "to", "for", "and", "or", "but"])
        let titleWords = searchText.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { !$0.isEmpty && !commonWords.contains($0) && $0.count > 2 }
        
        print("🔍 [ExpandableIssueCard] Key words from conversation: \(titleWords)")
        
        var bestMatch: Issue?
        var bestScore = 0
        
        for issue in allIssues {
            let issueTitle = issue.title.lowercased()
            let issueDesc = (issue.description ?? "").lowercased()
            let combinedText = "\(issueTitle) \(issueDesc)"
            
            var score = 0
            
            // Score based on word matches
            for word in titleWords {
                if combinedText.contains(word) {
                    score += word.count // Longer words get higher scores
                }
            }
            
            // Bonus for exact phrase matches
            if titleWords.count >= 3 {
                let phrase = titleWords.prefix(3).joined(separator: " ")
                if combinedText.contains(phrase) {
                    score += 20
                }
            }
            
            if score > bestScore && score >= 10 { // Minimum threshold
                bestScore = score
                bestMatch = issue
                print("🔍 [ExpandableIssueCard] New best match (score: \(score)): \(issue.title.prefix(50))")
            }
        }
        
        return bestMatch
    }
    
    private func loadThreadMessages(for issueId: String) async throws -> [ThreadMessage] {
        do {
            // Try to fetch thread messages from the maintenance_requests collection
            let snapshot = try await Firestore.firestore()
                .collection("maintenance_requests")
                .document(issueId)
                .collection("thread_messages")
                .order(by: "createdAt", descending: false)
                .getDocuments()
            
            return snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let id = data["id"] as? String,
                      let requestId = data["requestId"] as? String,
                      let authorId = data["authorId"] as? String,
                      let authorTypeRaw = data["authorType"] as? String,
                      let authorType = ThreadAuthorType(rawValue: authorTypeRaw),
                      let message = data["message"] as? String,
                      let typeRaw = data["type"] as? String,
                      let type = ThreadMessageType(rawValue: typeRaw),
                      let createdAtTs = data["createdAt"] as? Timestamp else { return nil }
                
                let attachmentUrl = data["attachmentUrl"] as? String
                let attachmentThumbUrl = data["attachmentThumbUrl"] as? String
                
                return ThreadMessage(
                    id: id,
                    requestId: requestId,
                    authorId: authorId,
                    authorType: authorType,
                    message: message,
                    type: type,
                    attachmentUrl: attachmentUrl,
                    attachmentThumbUrl: attachmentThumbUrl,
                    proposalAccepted: data["proposalAccepted"] as? Bool,
                    createdAt: createdAtTs.dateValue()
                )
            }
        } catch {
            print("⚠️ [ExpandableIssueCard] Failed to load thread messages: \(error)")
            return []
        }
    }
}

// Preview
struct ExpandableIssueCard_Previews: PreviewProvider {
    static var previews: some View {
        ExpandableIssueCard(
            conversation: Conversation(
                id: "test",
                restaurantId: "test",
                type: .issue_specific,
                issueId: "test-issue",
                workOrderId: nil,
                participantIds: [],
                title: "The image shows a section of molding or trim with a noticeable joint separation. The paint appears chipped.",
                createdAt: Date(),
                updatedAt: Date(),
                isActive: true,
                lastMessageAt: Date(),
                unreadCount: [:],
                priority: nil,
                restaurantName: nil,
                restaurantAddress: nil,
                managerName: nil,
                contextData: nil
            ),
            startExpanded: true
        )
        .padding()
        .background(KMTheme.background)
    }
}
