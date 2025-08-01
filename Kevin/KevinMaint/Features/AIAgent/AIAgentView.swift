import SwiftUI

/// Chat interface for conversing with the AI agent about a work order
struct AIAgentView: View {
    let workOrderId: String
    let context: WorkOrderContext
    
    @StateObject private var aiService = AIAssistantService.shared
    @StateObject private var contextService = AIContextService.shared
    
    @State private var messages: [AIAgentMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var showingSuggestions = true
    @State private var proactiveSuggestions: [AIAgentSuggestion] = []
    
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Suggestions (if available and not dismissed)
            if showingSuggestions && !proactiveSuggestions.isEmpty {
                suggestionsView
            }
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            AIMessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        if isLoading {
                            LoadingIndicator()
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) { _ in
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Input
            inputView
        }
        .background(KMTheme.background)
        .task {
            await loadConversation()
            await generateProactiveSuggestions()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(KMTheme.accent)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Kevin AI")
                        .font(.headline)
                        .foregroundColor(KMTheme.primaryText)
                    
                    Text(context.locationName)
                        .font(.caption)
                        .foregroundColor(KMTheme.secondaryText)
                }
                
                Spacer()
                
                if aiService.isProcessing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
            
            Divider()
        }
        .background(KMTheme.cardBackground)
    }
    
    // MARK: - Suggestions
    
    private var suggestionsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                    .font(.caption)
                
                Text("AI Suggestions")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(KMTheme.secondaryText)
                
                Spacer()
                
                Button(action: { showingSuggestions = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(KMTheme.tertiaryText)
                        .font(.caption)
                }
            }
            
            ForEach(proactiveSuggestions) { suggestion in
                SuggestionCard(suggestion: suggestion) {
                    handleSuggestionTap(suggestion)
                }
            }
        }
        .padding()
        .background(KMTheme.cardBackground.opacity(0.5))
    }
    
    // MARK: - Input
    
    private var inputView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 12) {
                TextField("Ask Kevin AI...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .foregroundColor(KMTheme.primaryText)
                    .padding(12)
                    .background(KMTheme.inputBackground)
                    .cornerRadius(20)
                    .focused($isInputFocused)
                    .lineLimit(1...5)
                
                Button(action: {
                    Task {
                        await sendMessage()
                    }
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(inputText.isEmpty ? KMTheme.tertiaryText : KMTheme.accent)
                }
                .disabled(inputText.isEmpty || isLoading)
            }
            .padding()
        }
        .background(KMTheme.cardBackground)
    }
    
    // MARK: - Actions
    
    private func loadConversation() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Load existing messages from thread
            // For now, start with a welcome message
            let welcomeMessage = AIAgentMessage(
                id: UUID().uuidString,
                role: .assistant,
                content: generateWelcomeMessage(),
                timestamp: Date(),
                metadata: nil
            )
            
            await MainActor.run {
                messages = [welcomeMessage]
            }
        }
    }
    
    private func generateWelcomeMessage() -> String {
        var message = "Hi! I'm Kevin AI. "
        
        // Analyze context and provide proactive message
        if !context.detectedIntents.isEmpty {
            let unfulfilled = context.detectedIntents.filter { !$0.fulfilled }
            if !unfulfilled.isEmpty {
                let intent = unfulfilled.first!
                switch intent.type {
                case .requestQuote:
                    message += "I see \(context.reporterName) is asking for a quote. "
                    if let cost = context.businessState.estimatedCost {
                        message += "Based on the photo analysis, I estimate $\(Int(cost))-\(Int(cost * 1.2)) for this repair. Would you like me to create a quote?"
                    } else {
                        message += "What should I quote for this work?"
                    }
                case .reportUrgency:
                    message += "This issue is marked as urgent. Should I prioritize scheduling?"
                default:
                    message += "How can I help you with this work order?"
                }
            } else {
                message += "How can I help you with this work order?"
            }
        } else {
            message += "How can I help you with this work order?"
        }
        
        return message
    }
    
    private func sendMessage() async {
        guard !inputText.isEmpty else { return }
        
        let userMessage = AIAgentMessage(
            id: UUID().uuidString,
            role: .user,
            content: inputText,
            timestamp: Date(),
            metadata: nil
        )
        
        await MainActor.run {
            messages.append(userMessage)
            inputText = ""
            isLoading = true
        }
        
        do {
            // Get or create thread
            let threadId = try await aiService.getOrCreateThread(for: workOrderId, context: context)
            
            // Add user message to thread
            try await aiService.addMessage(threadId: threadId, content: userMessage.content)
            
            // Get assistant ID
            let assistantId = try await aiService.getOrCreateAssistant()
            
            // Run assistant and get response
            let response = try await aiService.runAssistant(
                threadId: threadId,
                assistantId: assistantId,
                context: context
            )
            
            let assistantMessage = AIAgentMessage(
                id: UUID().uuidString,
                role: .assistant,
                content: response,
                timestamp: Date(),
                metadata: nil
            )
            
            await MainActor.run {
                messages.append(assistantMessage)
                isLoading = false
            }
            
        } catch {
            print("❌ Error sending message: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func generateProactiveSuggestions() async {
        // Generate suggestions based on context
        var suggestions: [AIAgentSuggestion] = []
        
        // Check for quote request
        if context.detectedIntents.contains(where: { $0.type == .requestQuote && !$0.fulfilled }) {
            if let estimatedCost = context.businessState.estimatedCost {
                suggestions.append(AIAgentSuggestion(
                    id: UUID().uuidString,
                    title: "Create Quote",
                    description: "Generate a quote for $\(Int(estimatedCost))-\(Int(estimatedCost * 1.2))",
                    actionType: .createQuote,
                    parameters: ["amount": "\(Int(estimatedCost))"],
                    priority: .high
                ))
            }
        }
        
        // Check for scheduling needs
        if context.businessState.quoteApproved == true && context.businessState.scheduledDate == nil {
            suggestions.append(AIAgentSuggestion(
                id: UUID().uuidString,
                title: "Schedule Work",
                description: "Quote approved - schedule the repair",
                actionType: .scheduleWork,
                parameters: [:],
                priority: .high
            ))
        }
        
        await MainActor.run {
            proactiveSuggestions = suggestions
        }
    }
    
    private func handleSuggestionTap(_ suggestion: AIAgentSuggestion) {
        // Auto-fill input with suggestion
        inputText = suggestion.title.lowercased()
        isInputFocused = true
    }
}

// MARK: - AI Message Bubble

struct AIMessageBubble: View {
    let message: AIAgentMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer()
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(message.role == .user ? .white : KMTheme.primaryText)
                    .padding(12)
                    .background(message.role == .user ? KMTheme.accent : KMTheme.cardBackground)
                    .cornerRadius(16)
                
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(KMTheme.tertiaryText)
            }
            .frame(maxWidth: 280, alignment: message.role == .user ? .trailing : .leading)
            
            if message.role == .assistant {
                Spacer()
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Suggestion Card

struct SuggestionCard: View {
    let suggestion: AIAgentSuggestion
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: iconForAction(suggestion.actionType))
                    .font(.title3)
                    .foregroundColor(colorForPriority(suggestion.priority))
                    .frame(width: 32, height: 32)
                    .background(colorForPriority(suggestion.priority).opacity(0.15))
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(suggestion.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(KMTheme.primaryText)
                    
                    Text(suggestion.description)
                        .font(.caption)
                        .foregroundColor(KMTheme.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(KMTheme.tertiaryText)
            }
            .padding(12)
            .background(KMTheme.cardBackground)
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private func iconForAction(_ actionType: AIAgentAction.ActionType) -> String {
        switch actionType {
        case .createQuote: return "doc.text.fill"
        case .sendQuote: return "paperplane.fill"
        case .scheduleWork: return "calendar"
        case .sendMessage: return "message.fill"
        case .updateStatus: return "arrow.triangle.2.circlepath"
        case .estimateCost: return "dollarsign.circle.fill"
        case .generateInvoice: return "doc.plaintext.fill"
        }
    }
    
    private func colorForPriority(_ priority: AIAgentSuggestion.SuggestionPriority) -> Color {
        switch priority {
        case .high: return .orange
        case .medium: return .blue
        case .low: return .gray
        }
    }
}

// MARK: - Loading Indicator

struct LoadingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(KMTheme.tertiaryText)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .padding()
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview

struct AIAgentView_Previews: PreviewProvider {
    static var previews: some View {
        AIAgentView(
            workOrderId: "test-123",
            context: WorkOrderContext(
                workOrderId: "test-123",
                locationId: "loc-1",
                locationName: "Summit Coffee",
                reporterId: "user-1",
                reporterName: "Sarah",
                reporterRole: "Owner",
                events: [],
                aiAnalyses: [],
                detectedIntents: [
                    UserIntent(
                        id: "intent-1",
                        type: .requestQuote,
                        confidence: 0.95,
                        detectedAt: Date(),
                        details: "Wants quote for bathroom trim repair",
                        fulfilled: false
                    )
                ],
                businessState: BusinessState(),
                createdAt: Date(),
                updatedAt: Date()
            )
        )
    }
}
