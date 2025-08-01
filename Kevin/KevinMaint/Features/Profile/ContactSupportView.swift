import SwiftUI
import MessageUI

struct ContactSupportView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var subject = ""
    @State private var message = ""
    @State private var selectedCategory: SupportCategory = .general
    @State private var showingSuccessAlert = false
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var isSending = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    categorySection
                    subjectField
                    messageField
                    accountInfoBanner
                    sendButton
                }
                .padding(20)
            }
            .background(KMTheme.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(KMTheme.accent)
                }
            }
        }
        .alert("Message Sent", isPresented: $showingSuccessAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your message has been sent to Kevin's support team. We'll get back to you soon!")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(KMTheme.accent)
            
            Text("Contact Kevin's Team")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(KMTheme.primaryText)
            
            Text("We typically respond within 24 hours")
                .font(.subheadline)
                .foregroundColor(KMTheme.secondaryText)
        }
        .padding(.top, 20)
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Category")
                .font(.headline)
                .foregroundColor(KMTheme.primaryText)
            
            VStack(spacing: 8) {
                ForEach(SupportCategory.allCases, id: \.rawValue) { category in
                    CategoryButton(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        selectedCategory = category
                    }
                }
            }
        }
    }
    
    private var subjectField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subject")
                .font(.headline)
                .foregroundColor(KMTheme.primaryText)
            
            TextField("Brief description of your issue", text: $subject)
                .padding(12)
                .background(KMTheme.inputBackground)
                .foregroundColor(KMTheme.inputText)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(KMTheme.inputBorder, lineWidth: 1)
                )
        }
    }
    
    private var messageField: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Message")
                .font(.headline)
                .foregroundColor(KMTheme.primaryText)
            
            ZStack(alignment: .topLeading) {
                if message.isEmpty {
                    Text("Please describe your question or issue in detail...")
                        .foregroundColor(KMTheme.inputPlaceholder)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                
                TextEditor(text: $message)
                    .foregroundColor(KMTheme.inputText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 150)
                    .padding(8)
            }
            .background(KMTheme.inputBackground)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(KMTheme.inputBorder, lineWidth: 1)
            )
        }
    }
    
    private var accountInfoBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(KMTheme.accent)
                
                Text("Your account information will be included automatically")
                    .font(.caption)
                    .foregroundColor(KMTheme.secondaryText)
            }
        }
        .padding(12)
        .background(KMTheme.cardBackground)
        .cornerRadius(8)
    }
    
    private var sendButton: some View {
        Button(action: sendMessage) {
            HStack {
                if isSending {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("Send Message")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(canSend ? KMTheme.accent : KMTheme.accent.opacity(0.5))
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canSend || isSending)
    }
    
    private var canSend: Bool {
        !subject.isEmpty && !message.isEmpty
    }
    
    private func sendMessage() {
        guard let currentUser = appState.currentAppUser else {
            errorMessage = "Unable to identify user. Please try again."
            showingErrorAlert = true
            return
        }
        
        isSending = true
        
        let supportMessage = SupportMessage(
            userId: currentUser.id,
            userName: currentUser.name,
            userEmail: currentUser.email,
            category: selectedCategory,
            subject: subject,
            message: message,
            status: .new
        )
        
        Task {
            do {
                try await FirebaseClient.shared.createSupportMessage(supportMessage)
                
                await MainActor.run {
                    isSending = false
                    showingSuccessAlert = true
                    
                    // Reset form
                    subject = ""
                    message = ""
                    selectedCategory = .general
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    errorMessage = "Failed to send message: \(error.localizedDescription)"
                    showingErrorAlert = true
                }
            }
        }
    }
}

struct CategoryButton: View {
    let category: SupportCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : KMTheme.accent)
                    .frame(width: 24)
                
                Text(category.displayName)
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
            .background(isSelected ? KMTheme.accent : KMTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.clear : KMTheme.border, lineWidth: 1)
            )
        }
    }
}

#Preview {
    ContactSupportView()
        .environmentObject(AppState())
}
