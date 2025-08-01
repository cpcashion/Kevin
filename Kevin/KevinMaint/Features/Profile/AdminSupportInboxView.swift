import SwiftUI

struct AdminSupportInboxView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var messages: [SupportMessage] = []
    @State private var isLoading = true
    @State private var selectedFilter: MessageFilter = .all
    @State private var selectedMessage: SupportMessage?
    @State private var showingMessageDetail = false
    
    enum MessageFilter: String, CaseIterable {
        case all = "All"
        case new = "New"
        case inProgress = "In Progress"
        case resolved = "Resolved"
        
        var statusFilter: SupportMessageStatus? {
            switch self {
            case .all: return nil
            case .new: return .new
            case .inProgress: return .inProgress
            case .resolved: return .resolved
            }
        }
    }
    
    var filteredMessages: [SupportMessage] {
        if let status = selectedFilter.statusFilter {
            return messages.filter { $0.status == status }
        }
        return messages
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(MessageFilter.allCases, id: \.self) { filter in
                            FilterButton(
                                title: filter.rawValue,
                                count: countForFilter(filter),
                                isSelected: selectedFilter == filter
                            ) {
                                selectedFilter = filter
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(KMTheme.background)
                
                Divider()
                    .background(KMTheme.border)
                
                // Messages List
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: KMTheme.accent))
                    Spacer()
                } else if filteredMessages.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "tray")
                            .font(.system(size: 60))
                            .foregroundColor(KMTheme.tertiaryText)
                        
                        Text("No Messages")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(KMTheme.primaryText)
                        
                        Text("Support messages will appear here")
                            .font(.subheadline)
                            .foregroundColor(KMTheme.secondaryText)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredMessages) { message in
                                SupportMessageCard(message: message) {
                                    selectedMessage = message
                                    showingMessageDetail = true
                                }
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .background(KMTheme.background)
            .navigationTitle("Support Inbox")
            .navigationBarTitleDisplayMode(.inline)
            .kevinNavigationBarStyle()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(KMTheme.accent)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await loadMessages()
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .foregroundColor(KMTheme.accent)
                    }
                }
            }
            .sheet(isPresented: $showingMessageDetail) {
                if let message = selectedMessage {
                    SupportMessageDetailView(message: message) {
                        Task {
                            await loadMessages()
                        }
                    }
                }
            }
        }
        .task {
            await loadMessages()
        }
    }
    
    private func countForFilter(_ filter: MessageFilter) -> Int {
        if let status = filter.statusFilter {
            return messages.filter { $0.status == status }.count
        }
        return messages.count
    }
    
    private func loadMessages() async {
        isLoading = true
        
        do {
            messages = try await FirebaseClient.shared.fetchAllSupportMessages()
            isLoading = false
        } catch {
            print("❌ [AdminSupportInboxView] Error loading messages: \(error)")
            isLoading = false
        }
    }
}

struct FilterButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(count)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(isSelected ? .white.opacity(0.2) : KMTheme.tertiaryText.opacity(0.2))
                    .cornerRadius(8)
            }
            .foregroundColor(isSelected ? .white : KMTheme.secondaryText)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? KMTheme.accent : KMTheme.cardBackground)
            .cornerRadius(20)
        }
    }
}

struct SupportMessageCard: View {
    let message: SupportMessage
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: message.category.icon)
                        .font(.system(size: 20))
                        .foregroundColor(KMTheme.accent)
                        .frame(width: 32, height: 32)
                        .background(KMTheme.accent.opacity(0.1))
                        .cornerRadius(8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message.subject)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundColor(KMTheme.primaryText)
                            .lineLimit(1)
                        
                        Text(message.userName)
                            .font(.caption)
                            .foregroundColor(KMTheme.secondaryText)
                    }
                    
                    Spacer()
                    
                    StatusBadge(status: message.status)
                }
                
                // Message Preview
                Text(message.message)
                    .font(.subheadline)
                    .foregroundColor(KMTheme.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Footer
                HStack {
                    Label(message.category.displayName, systemImage: "tag")
                        .font(.caption)
                        .foregroundColor(KMTheme.tertiaryText)
                    
                    Spacer()
                    
                    Text(message.createdAt.timeAgoDisplay())
                        .font(.caption)
                        .foregroundColor(KMTheme.tertiaryText)
                }
            }
            .padding(16)
            .background(KMTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(message.status == .new ? KMTheme.accent.opacity(0.3) : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StatusBadge: View {
    let status: SupportMessageStatus
    
    var backgroundColor: Color {
        switch status {
        case .new: return .orange
        case .inProgress: return .blue
        case .resolved: return .green
        case .closed: return .gray
        }
    }
    
    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(6)
    }
}

struct SupportMessageDetailView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    let message: SupportMessage
    let onUpdate: () -> Void
    
    @State private var selectedStatus: SupportMessageStatus
    @State private var adminNotes: String
    @State private var isSaving = false
    @State private var showingSuccessAlert = false
    
    init(message: SupportMessage, onUpdate: @escaping () -> Void) {
        self.message = message
        self.onUpdate = onUpdate
        _selectedStatus = State(initialValue: message.status)
        _adminNotes = State(initialValue: message.adminNotes ?? "")
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // User Info Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(KMTheme.accent)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(message.userName)
                                    .font(.headline)
                                    .foregroundColor(KMTheme.primaryText)
                                
                                if let email = message.userEmail {
                                    Text(email)
                                        .font(.subheadline)
                                        .foregroundColor(KMTheme.secondaryText)
                                }
                            }
                            
                            Spacer()
                        }
                        
                        Divider()
                        
                        HStack {
                            Label(message.category.displayName, systemImage: message.category.icon)
                                .font(.subheadline)
                                .foregroundColor(KMTheme.secondaryText)
                            
                            Spacer()
                            
                            Text(message.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(KMTheme.tertiaryText)
                        }
                    }
                    .padding(16)
                    .background(KMTheme.cardBackground)
                    .cornerRadius(12)
                    
                    // Subject & Message
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Subject")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(KMTheme.tertiaryText)
                            .textCase(.uppercase)
                        
                        Text(message.subject)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(KMTheme.primaryText)
                        
                        Divider()
                        
                        Text("Message")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(KMTheme.tertiaryText)
                            .textCase(.uppercase)
                        
                        Text(message.message)
                            .font(.body)
                            .foregroundColor(KMTheme.primaryText)
                    }
                    .padding(16)
                    .background(KMTheme.cardBackground)
                    .cornerRadius(12)
                    
                    // Status Update
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Status")
                            .font(.headline)
                            .foregroundColor(KMTheme.primaryText)
                        
                        VStack(spacing: 8) {
                            ForEach([SupportMessageStatus.new, .inProgress, .resolved, .closed], id: \.self) { status in
                                StatusButton(
                                    status: status,
                                    isSelected: selectedStatus == status
                                ) {
                                    selectedStatus = status
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(KMTheme.cardBackground)
                    .cornerRadius(12)
                    
                    // Admin Notes
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Admin Notes")
                            .font(.headline)
                            .foregroundColor(KMTheme.primaryText)
                        
                        ZStack(alignment: .topLeading) {
                            if adminNotes.isEmpty {
                                Text("Add internal notes about this support request...")
                                    .foregroundColor(KMTheme.inputPlaceholder)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                            }
                            
                            TextEditor(text: $adminNotes)
                                .foregroundColor(KMTheme.inputText)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 120)
                                .padding(8)
                        }
                        .background(KMTheme.inputBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(KMTheme.inputBorder, lineWidth: 1)
                        )
                    }
                    .padding(16)
                    .background(KMTheme.cardBackground)
                    .cornerRadius(12)
                    
                    // Save Button
                    Button(action: saveChanges) {
                        HStack {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save Changes")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(KMTheme.accent)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isSaving)
                }
                .padding(20)
            }
            .background(KMTheme.background)
            .navigationTitle("Message Details")
            .navigationBarTitleDisplayMode(.inline)
            .kevinNavigationBarStyle()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(KMTheme.accent)
                }
            }
            .alert("Changes Saved", isPresented: $showingSuccessAlert) {
                Button("OK") {
                    onUpdate()
                    dismiss()
                }
            } message: {
                Text("Support message has been updated successfully.")
            }
        }
    }
    
    private func saveChanges() {
        guard let currentUser = appState.currentAppUser else { return }
        
        isSaving = true
        
        Task {
            do {
                try await FirebaseClient.shared.updateSupportMessage(
                    messageId: message.id,
                    status: selectedStatus,
                    adminNotes: adminNotes.isEmpty ? nil : adminNotes,
                    respondedBy: currentUser.id
                )
                
                await MainActor.run {
                    isSaving = false
                    showingSuccessAlert = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    print("❌ [SupportMessageDetailView] Error saving: \(error)")
                }
            }
        }
    }
}

struct StatusButton: View {
    let status: SupportMessageStatus
    let isSelected: Bool
    let action: () -> Void
    
    var statusColor: Color {
        switch status {
        case .new: return .orange
        case .inProgress: return .blue
        case .resolved: return .green
        case .closed: return .gray
        }
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                
                Text(status.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : KMTheme.primaryText)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                }
            }
            .padding(16)
            .background(isSelected ? KMTheme.accent : KMTheme.background)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : KMTheme.border, lineWidth: 1)
            )
        }
    }
}

// Helper extension for time ago display
extension Date {
    func timeAgoDisplay() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#Preview {
    AdminSupportInboxView()
        .environmentObject(AppState())
}
