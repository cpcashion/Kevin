import SwiftUI

struct ReceiptsListView: View {
  let issue: Issue
  @State private var receipts: [Receipt] = []
  @State private var documents: [IssueDocument] = []
  @State private var isLoading = true
  @State private var showingAddReceipt = false
  @State private var selectedReceipt: Receipt?
  @State private var selectedDocument: IssueDocument?
  @EnvironmentObject var appState: AppState
  
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Header
      receiptsHeader
      
      if isLoading {
        loadingView
      } else if receipts.isEmpty && documents.isEmpty {
        emptyStateView
      } else {
        receiptsContent
      }
    }
    .task {
      await loadReceipts()
    }
    .sheet(isPresented: $showingAddReceipt) {
      AddDocumentView(
        issue: issue,
        workOrder: nil, // TODO: Pass actual work order if available
        onDocumentAdded: {
          Task {
            await loadReceipts()
          }
        }
      )
    }
    .sheet(item: $selectedReceipt) { receipt in
      ReceiptDetailView(receipt: receipt)
    }
    .sheet(item: $selectedDocument) { document in
      DocumentDetailView(document: document)
    }
  }
  
  private var receiptsHeader: some View {
    HStack {
      Image(systemName: "doc.fill")
        .foregroundColor(KMTheme.accent)
        .font(.title3)
      
      VStack(alignment: .leading, spacing: 2) {
        Text("Documents")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        let totalCount = receipts.count + documents.count
        if totalCount > 0 {
          Text("\(totalCount) document\(totalCount == 1 ? "" : "s")")
            .font(.caption)
            .foregroundColor(KMTheme.secondaryText)
        }
      }
      
      Spacer()
      
      // Add Document Button
      if canAddReceipts {
        Button(action: { showingAddReceipt = true }) {
          Image(systemName: "plus.circle.fill")
            .foregroundColor(KMTheme.accent)
            .font(.title2)
        }
      }
    }
  }
  
  private var loadingView: some View {
    HStack {
      ProgressView()
        .progressViewStyle(CircularProgressViewStyle(tint: KMTheme.accent))
        .scaleEffect(0.8)
      
      Text("Loading documents...")
        .font(.subheadline)
        .foregroundColor(KMTheme.secondaryText)
    }
    .frame(maxWidth: .infinity)
    .padding(24)
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
  }
  
  private var emptyStateView: some View {
    VStack(spacing: 12) {
      Image(systemName: "doc.fill")
        .font(.largeTitle)
        .foregroundColor(KMTheme.secondaryText)
      
      Text("No documents yet")
        .font(.headline)
        .foregroundColor(KMTheme.primaryText)
      
      Text("Add invoices, receipts, quotes, or photos for this issue")
        .font(.subheadline)
        .foregroundColor(KMTheme.secondaryText)
        .multilineTextAlignment(.center)
      
      if canAddReceipts {
        Button("Add First Document") {
          showingAddReceipt = true
        }
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundColor(KMTheme.accent)
        .padding(.top, 8)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(24)
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
  }
  
  private var receiptsContent: some View {
    VStack(spacing: 12) {
      // Show legacy receipts
      ForEach(receipts) { receipt in
        ReceiptRowView(receipt: receipt) {
          selectedReceipt = receipt
        }
      }
      
      // Show new documents
      ForEach(documents) { document in
        Button(action: {
          selectedDocument = document
        }) {
          DocumentRowView(document: document)
        }
        .buttonStyle(PlainButtonStyle())
      }
    }
  }
  
  private var canAddReceipts: Bool {
    // Allow techs and admins to add receipts
    guard let currentUser = appState.currentAppUser else { return false }
    return currentUser.role == .tech || currentUser.role == .admin
  }
  
  private func loadReceipts() async {
    isLoading = true
    
    do {
      // Load legacy receipts
      let loadedReceipts = try await FirebaseClient.shared.getReceipts(for: issue.id)
      
      // Load new documents
      let loadedDocuments = try await FirebaseClient.shared.fetchDocuments(for: issue.id)
      
      await MainActor.run {
        self.receipts = loadedReceipts
        self.documents = loadedDocuments
        self.isLoading = false
        
        print("📄 [ReceiptsListView] Loaded \(loadedReceipts.count) receipts and \(loadedDocuments.count) documents")
      }
    } catch {
      print("❌ Failed to load receipts/documents: \(error)")
      await MainActor.run {
        self.isLoading = false
      }
    }
  }
}

// MARK: - Document Row View
struct DocumentRowView: View {
  let document: IssueDocument
  
  var body: some View {
    HStack(spacing: 12) {
      // Document type icon
      Image(systemName: document.type.icon)
        .foregroundColor(KMTheme.accent)
        .font(.title3)
        .frame(width: 24, height: 24)
      
      VStack(alignment: .leading, spacing: 4) {
        // Vendor/Title and Amount
        HStack {
          Text(document.aiAnalysis?.vendor ?? document.type.displayName)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.primaryText)
          
          Spacer()
          
          if let total = document.aiAnalysis?.total {
            Text("$\(total, specifier: "%.2f")")
              .font(.subheadline)
              .fontWeight(.semibold)
              .foregroundColor(KMTheme.primaryText)
          }
        }
        
        // Description
        if let description = document.aiAnalysis?.description {
          Text(description)
            .font(.caption)
            .foregroundColor(KMTheme.secondaryText)
            .lineLimit(1)
        }
        
        // Date and Type
        HStack {
          if let date = document.aiAnalysis?.date {
            Text(date, style: .date)
              .font(.caption)
              .foregroundColor(KMTheme.tertiaryText)
          }
          
          Spacer()
          
          Text(document.type.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(KMTheme.accent)
            .clipShape(Capsule())
        }
      }
      
      // Chevron
      Image(systemName: "chevron.right")
        .foregroundColor(KMTheme.tertiaryText)
        .font(.caption)
    }
    .padding(12)
    .background(KMTheme.cardBackground)
    .cornerRadius(8)
  }
}

struct ReceiptRowView: View {
  let receipt: Receipt
  let onTap: () -> Void
  
  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        // Category Icon
        Image(systemName: receipt.category.icon)
          .foregroundColor(KMTheme.accent)
          .font(.title3)
          .frame(width: 24, height: 24)
        
        VStack(alignment: .leading, spacing: 4) {
          // Vendor and Amount
          HStack {
            Text(receipt.vendor)
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.primaryText)
            
            Spacer()
            
            Text("$\(receipt.totalAmount, specifier: "%.2f")")
              .font(.subheadline)
              .fontWeight(.semibold)
              .foregroundColor(KMTheme.primaryText)
          }
          
          // Description and Category
          HStack {
            Text(receipt.description)
              .font(.caption)
              .foregroundColor(KMTheme.secondaryText)
              .lineLimit(1)
            
            Spacer()
            
            Text(receipt.category.displayName)
              .font(.caption)
              .foregroundColor(KMTheme.secondaryText)
          }
          
          // Date and Status
          HStack {
            Text(receipt.purchaseDate, style: .date)
              .font(.caption)
              .foregroundColor(KMTheme.tertiaryText)
            
            Spacer()
            
            Text(receipt.status.displayName)
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(.white)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color(receipt.status.color))
              .clipShape(Capsule())
          }
        }
        
        // Chevron
        Image(systemName: "chevron.right")
          .foregroundColor(KMTheme.tertiaryText)
          .font(.caption)
      }
      .padding(12)
      .background(KMTheme.cardBackground)
      .cornerRadius(8)
    }
    .buttonStyle(PlainButtonStyle())
  }
}

#Preview {
  ReceiptsListView(issue: Issue(
    id: "preview-issue",
    restaurantId: "preview-restaurant",
    locationId: "preview-location",
    reporterId: "preview-user",
    title: "Broken freezer door",
    description: "The freezer door won't close properly",
    priority: .high,
    status: .in_progress,
    createdAt: Date()
  ))
    .environmentObject(AppState())
    .padding()
    .background(KMTheme.background)
}
