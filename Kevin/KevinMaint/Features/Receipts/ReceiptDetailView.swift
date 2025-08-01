import SwiftUI

struct ReceiptDetailView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var appState: AppState
  
  @State var receipt: Receipt
  @State private var showingFullImage = false
  @State private var showingStatusUpdate = false
  @State private var reviewNotes = ""
  @State private var isUpdating = false
  
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          // Receipt Image
          receiptImageSection
          
          // Receipt Details
          receiptDetailsSection
          
          // Status Section
          statusSection
          
          // Review Section (for admins)
          if canReviewReceipts {
            reviewSection
          }
        }
        .padding(24)
      }
      .background(KMTheme.background)
      .navigationTitle("Receipt Details")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden()
      .kevinNavigationBarStyle()
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Close") {
            dismiss()
          }
          .foregroundColor(KMTheme.accent)
        }
      }
    }
    .fullScreenCover(isPresented: $showingFullImage) {
      ReceiptImageViewer(imageUrl: receipt.receiptImageUrl)
    }
    // TODO: Add ReceiptStatusUpdateView when needed
  }
  
  private var receiptImageSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: "photo")
          .foregroundColor(KMTheme.accent)
          .font(.title3)
        
        Text("Receipt Image")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        Spacer()
      }
      
      Button(action: { showingFullImage = true }) {
        AsyncImage(url: URL(string: receipt.thumbnailUrl ?? receipt.receiptImageUrl)) { image in
          image
            .resizable()
            .aspectRatio(contentMode: .fit)
        } placeholder: {
          Rectangle()
            .fill(KMTheme.cardBackground)
            .overlay(
              ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: KMTheme.accent))
            )
        }
        .frame(maxHeight: 200)
        .cornerRadius(12)
        .clipped()
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(KMTheme.inputBorder, lineWidth: 1)
        )
      }
      
      Text("Tap to view full size")
        .font(.caption)
        .foregroundColor(KMTheme.secondaryText)
        .frame(maxWidth: .infinity, alignment: .center)
    }
    .padding(16)
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
  }
  
  private var receiptDetailsSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: "doc.text")
          .foregroundColor(KMTheme.accent)
          .font(.title3)
        
        Text("Receipt Details")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        Spacer()
      }
      
      VStack(spacing: 16) {
        // Vendor and Category
        HStack {
          DetailRow(
            icon: "storefront",
            label: "Vendor",
            value: receipt.vendor
          )
          
          Spacer()
          
          DetailRow(
            icon: receipt.category.icon,
            label: "Category",
            value: receipt.category.displayName
          )
        }
        
        Divider()
          .background(KMTheme.inputBorder)
        
        // Amount Details
        VStack(spacing: 8) {
          HStack {
            Text("Amount")
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.primaryText)
            
            Spacer()
            
            Text("$\(receipt.amount, specifier: "%.2f")")
              .font(.subheadline)
              .foregroundColor(KMTheme.primaryText)
          }
          
          if let taxAmount = receipt.taxAmount, taxAmount > 0 {
            HStack {
              Text("Tax")
                .font(.subheadline)
                .foregroundColor(KMTheme.secondaryText)
              
              Spacer()
              
              Text("$\(taxAmount, specifier: "%.2f")")
                .font(.subheadline)
                .foregroundColor(KMTheme.secondaryText)
            }
            
            Divider()
              .background(KMTheme.inputBorder)
            
            HStack {
              Text("Total")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(KMTheme.primaryText)
              
              Spacer()
              
              Text("$\(receipt.totalAmount, specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(KMTheme.primaryText)
            }
          }
        }
        
        Divider()
          .background(KMTheme.inputBorder)
        
        // Purchase Date
        DetailRow(
          icon: "calendar",
          label: "Purchase Date",
          value: receipt.purchaseDate.formatted(date: .abbreviated, time: .omitted)
        )
        
        // Description
        VStack(alignment: .leading, spacing: 8) {
          HStack {
            Image(systemName: "text.alignleft")
              .foregroundColor(KMTheme.accent)
              .font(.subheadline)
            
            Text("Description")
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.primaryText)
          }
          
          Text(receipt.description)
            .font(.subheadline)
            .foregroundColor(KMTheme.secondaryText)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(KMTheme.inputBackground)
            .cornerRadius(8)
        }
      }
    }
    .padding(16)
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
  }
  
  private var statusSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: receipt.status.icon)
          .foregroundColor(KMTheme.accent)
          .font(.title3)
        
        Text("Status")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        Spacer()
        
        if canReviewReceipts && receipt.status == .pending {
          Button("Update") {
            showingStatusUpdate = true
          }
          .font(.subheadline)
          .foregroundColor(KMTheme.accent)
        }
      }
      
      VStack(spacing: 12) {
        HStack {
          Text(receipt.status.displayName)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(receipt.status.color))
            .clipShape(Capsule())
          
          Spacer()
        }
        
        if let reviewedBy = receipt.reviewedBy,
           let reviewedAt = receipt.reviewedAt {
          VStack(alignment: .leading, spacing: 4) {
            Text("Reviewed by: \(reviewedBy)")
              .font(.caption)
              .foregroundColor(KMTheme.secondaryText)
            
            Text("On: \(reviewedAt.formatted(date: .abbreviated, time: .shortened))")
              .font(.caption)
              .foregroundColor(KMTheme.secondaryText)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        
        if let reviewNotes = receipt.reviewNotes, !reviewNotes.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Review Notes:")
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.primaryText)
            
            Text(reviewNotes)
              .font(.caption)
              .foregroundColor(KMTheme.secondaryText)
              .padding(8)
              .background(KMTheme.inputBackground)
              .cornerRadius(6)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        
        if receipt.status == .reimbursed,
           let reimbursedAt = receipt.reimbursedAt {
          HStack {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(.green)
              .font(.caption)
            
            Text("Reimbursed on \(reimbursedAt.formatted(date: .abbreviated, time: .omitted))")
              .font(.caption)
              .foregroundColor(KMTheme.secondaryText)
          }
        }
      }
    }
    .padding(16)
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
  }
  
  private var reviewSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: "checkmark.shield")
          .foregroundColor(KMTheme.accent)
          .font(.title3)
        
        Text("Admin Review")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        Spacer()
      }
      
      if receipt.status == .pending {
        VStack(spacing: 12) {
          TextField("Add review notes (optional)", text: $reviewNotes, axis: .vertical)
            .lineLimit(3...6)
            .textFieldStyle(KMTextFieldStyle())
          
          HStack(spacing: 12) {
            Button("Approve") {
              updateReceiptStatus(.approved)
            }
            .buttonStyle(PrimaryButtonStyle(color: .green))
            
            Button("Reject") {
              updateReceiptStatus(.rejected)
            }
            .buttonStyle(PrimaryButtonStyle(color: .red))
          }
        }
      } else {
        Text("Receipt has been reviewed")
          .font(.subheadline)
          .foregroundColor(KMTheme.secondaryText)
      }
    }
    .padding(16)
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
  }
  
  private var canReviewReceipts: Bool {
    guard let currentUser = appState.currentAppUser else { return false }
    return currentUser.role == .admin
  }
  
  private func updateReceiptStatus(_ status: ReceiptStatus) {
    guard let currentUser = appState.currentAppUser else { return }
    
    isUpdating = true
    
    Task {
      do {
        try await FirebaseClient.shared.updateReceiptStatus(
          receipt.id,
          status: status,
          reviewedBy: currentUser.id,
          reviewNotes: reviewNotes.isEmpty ? nil : reviewNotes
        )
        
        // NOTIFICATION: Send receipt status notification
        await sendReceiptStatusNotification(
          newStatus: status,
          reviewedBy: currentUser,
          reviewNotes: reviewNotes.isEmpty ? nil : reviewNotes
        )
        
        await MainActor.run {
          receipt.status = status
          receipt.reviewedBy = currentUser.id
          receipt.reviewedAt = Date()
          if !reviewNotes.isEmpty {
            receipt.reviewNotes = reviewNotes
          }
          isUpdating = false
        }
      } catch {
        print("❌ Failed to update receipt status: \(error)")
        await MainActor.run {
          isUpdating = false
        }
      }
    }
  }
  
  // MARK: - Notification Functions
  
  private func sendReceiptStatusNotification(
    newStatus: ReceiptStatus,
    reviewedBy: AppUser,
    reviewNotes: String?
  ) async {
    // Notify the receipt submitter (if different from reviewer)
    var userIdsToNotify: [String] = []
    
    if receipt.submittedBy != reviewedBy.id {
      userIdsToNotify.append(receipt.submittedBy)
    }
    
    guard !userIdsToNotify.isEmpty else {
      print("🔔 No users to notify for receipt status change")
      return
    }
    
    // Get issue title and restaurant name for context
    // In a real implementation, we'd fetch this from the database
    let issueTitle = "Issue #\(receipt.issueId)" // Placeholder
    let restaurantName = "Restaurant" // Placeholder
    
    // Format amount for display
    let formattedAmount = String(format: "$%.2f", receipt.amount)
    
    // Send notification
    await NotificationService.shared.sendReceiptStatusNotification(
      to: userIdsToNotify,
      receiptAmount: formattedAmount,
      issueTitle: issueTitle,
      restaurantName: restaurantName,
      status: newStatus.rawValue,
      receiptId: receipt.id,
      reviewNotes: reviewNotes
    )
  }
}

struct DetailRow: View {
  let icon: String
  let label: String
  let value: String
  
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Image(systemName: icon)
          .foregroundColor(KMTheme.accent)
          .font(.caption)
        
        Text(label)
          .font(.caption)
          .fontWeight(.medium)
          .foregroundColor(KMTheme.primaryText)
      }
      
      Text(value)
        .font(.subheadline)
        .foregroundColor(KMTheme.secondaryText)
    }
  }
}

struct PrimaryButtonStyle: ButtonStyle {
  let color: Color
  
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.subheadline)
      .fontWeight(.medium)
      .foregroundColor(.white)
      .frame(maxWidth: .infinity)
      .padding(12)
      .background(color.opacity(configuration.isPressed ? 0.8 : 1.0))
      .cornerRadius(8)
  }
}

#Preview {
  ReceiptDetailView(receipt: Receipt(
    issueId: "test",
    restaurantId: "test",
    submittedBy: "test",
    vendor: "Home Depot",
    category: .materials,
    amount: 45.99,
    taxAmount: 3.68,
    description: "Replacement door handle and screws",
    purchaseDate: Date(),
    receiptImageUrl: "https://example.com/receipt.jpg"
  ))
  .environmentObject(AppState())
}
