import SwiftUI
import PhotosUI

struct AddDocumentView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var appState: AppState
  
  let issue: Issue
  let workOrder: WorkOrder?
  let onDocumentAdded: (() -> Void)?
  
  @State private var selectedImage: UIImage?
  @State private var showingImagePicker = false
  @State private var showingCamera = false
  @State private var isSubmitting = false
  @State private var isAnalyzing = false
  @State private var errorMessage: String?
  @State private var documentAnalysis: DocumentAnalysisResult?
  @State private var showingAnalysis = false
  @State private var notes: String = ""
  
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          // Header
          documentHeader
          
          // Document Photo Section
          documentPhotoSection
          
          // AI Analysis Section
          if let analysis = documentAnalysis {
            aiAnalysisSection(analysis)
          }
          
          // Optional Notes
          if documentAnalysis != nil {
            notesSection
          }
          
          // Submit Button
          if documentAnalysis != nil {
            submitButton
          }
        }
        .padding(24)
      }
      .background(KMTheme.background)
      .navigationTitle("Add Document")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden()
      .kevinNavigationBarStyle()
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundColor(KMTheme.accent)
        }
      }
    }
    .sheet(isPresented: $showingImagePicker) {
      SimpleImagePicker { image in
        selectedImage = image
        analyzeDocument(image)
      }
    }
    .fullScreenCover(isPresented: $showingCamera) {
      CameraView(selectedImage: $selectedImage)
    }
    .onChange(of: selectedImage) { _, newImage in
      if let image = newImage {
        analyzeDocument(image)
      }
    }
  }
  
  private var documentHeader: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "doc.fill")
          .foregroundColor(KMTheme.accent)
          .font(.title2)
        
        VStack(alignment: .leading, spacing: 4) {
          Text("Document for Issue")
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(KMTheme.primaryText)
          
          Text(issue.title)
            .font(.subheadline)
            .foregroundColor(KMTheme.secondaryText)
            .lineLimit(2)
        }
        
        Spacer()
      }
      
      if let workOrder = workOrder {
        HStack {
          Image(systemName: "clipboard")
            .foregroundColor(KMTheme.secondaryText)
            .font(.caption)
          
          Text("Work Order: \(workOrder.id)")
            .font(.caption)
            .foregroundColor(KMTheme.secondaryText)
        }
      }
      
      Text("Upload invoices, receipts, quotes, photos, or any related documents")
        .font(.caption)
        .foregroundColor(KMTheme.tertiaryText)
    }
    .padding(20)
    .background(KMTheme.cardBackground)
    .cornerRadius(16)
  }
  
  private var documentPhotoSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: "camera.fill")
          .foregroundColor(KMTheme.accent)
        
        Text("Document Photo")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
      }
      
      if let image = selectedImage {
        ZStack(alignment: .topTrailing) {
          Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .stroke(KMTheme.border, lineWidth: 1)
            )
          
          // Change/Remove buttons
          HStack(spacing: 8) {
            Button("Change Photo") {
              showingImagePicker = true
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(KMTheme.accent)
            .cornerRadius(8)
            
            if documentAnalysis != nil, let image = selectedImage {
              Button("Re-analyze") {
                analyzeDocument(image)
              }
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(.white)
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .background(KMTheme.aiGreen)
              .cornerRadius(8)
            }
          }
          .padding(12)
        }
        
        // Analysis loading state
        if isAnalyzing {
          HStack(spacing: 12) {
            ProgressView()
              .tint(KMTheme.aiGreen)
            
            Text("AI is analyzing your document...")
              .font(.subheadline)
              .foregroundColor(KMTheme.secondaryText)
          }
          .padding(16)
          .frame(maxWidth: .infinity)
          .background(KMTheme.aiGreen.opacity(0.1))
          .cornerRadius(12)
        }
      } else {
        // Upload options
        VStack(spacing: 12) {
          Button(action: { showingCamera = true }) {
            HStack(spacing: 12) {
              Image(systemName: "camera.fill")
                .font(.title3)
              
              VStack(alignment: .leading, spacing: 4) {
                Text("Take Photo")
                  .font(.headline)
                  .fontWeight(.semibold)
                
                Text("Capture document with camera")
                  .font(.caption)
                  .foregroundColor(KMTheme.secondaryText)
              }
              
              Spacer()
              
              Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(KMTheme.tertiaryText)
            }
            .foregroundColor(KMTheme.primaryText)
            .padding(16)
            .background(KMTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .stroke(KMTheme.accent.opacity(0.3), lineWidth: 1)
            )
          }
          
          Button(action: { showingImagePicker = true }) {
            HStack(spacing: 12) {
              Image(systemName: "photo.fill")
                .font(.title3)
              
              VStack(alignment: .leading, spacing: 4) {
                Text("Choose from Photos")
                  .font(.headline)
                  .fontWeight(.semibold)
                
                Text("Select from photo library")
                  .font(.caption)
                  .foregroundColor(KMTheme.secondaryText)
              }
              
              Spacer()
              
              Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(KMTheme.tertiaryText)
            }
            .foregroundColor(KMTheme.primaryText)
            .padding(16)
            .background(KMTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
              RoundedRectangle(cornerRadius: 12)
                .stroke(KMTheme.accent.opacity(0.3), lineWidth: 1)
            )
          }
        }
      }
    }
    .padding(20)
    .background(KMTheme.cardBackground)
    .cornerRadius(16)
  }
  
  private func aiAnalysisSection(_ analysis: DocumentAnalysisResult) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: "brain.head.profile")
          .foregroundColor(KMTheme.aiGreen)
          .font(.title3)
        
        Text("AI Document Analysis")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        Spacer()
        
        HStack(spacing: 4) {
          Text("\(Int(analysis.confidence * 100))%")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.aiGreen)
          
          Text("confident")
            .font(.caption)
            .foregroundColor(KMTheme.secondaryText)
        }
      }
      
      // Document Type Badge
      HStack(spacing: 8) {
        Image(systemName: analysis.documentType.icon)
          .foregroundColor(KMTheme.accent)
          .font(.caption)
        
        Text(analysis.documentType.displayName)
          .font(.subheadline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        Spacer()
      }
      .padding(12)
      .background(KMTheme.accent.opacity(0.1))
      .cornerRadius(8)
      
      VStack(spacing: 16) {
        // Dynamic content based on document type
        switch analysis.documentType {
        case .invoice, .receipt:
          financialDocumentContent(analysis)
        case .quote:
          quoteDocumentContent(analysis)
        case .workOrder:
          workOrderDocumentContent(analysis)
        case .photo:
          photoDocumentContent(analysis)
        default:
          genericDocumentContent(analysis)
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
  
  private func financialDocumentContent(_ analysis: DocumentAnalysisResult) -> some View {
    VStack(spacing: 16) {
      // Vendor
      if let vendor = analysis.vendor {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Vendor")
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.secondaryText)
            
            Text(vendor)
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.primaryText)
          }
          
          Spacer()
          
          if let date = analysis.date {
            VStack(alignment: .trailing, spacing: 4) {
              Text("Date")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(KMTheme.secondaryText)
              
              Text(date.formatted(date: .abbreviated, time: .omitted))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(KMTheme.primaryText)
            }
          }
        }
      }
      
      // Description
      if let description = analysis.description {
        VStack(alignment: .leading, spacing: 8) {
          Text("Description")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.secondaryText)
          
          Text(description)
            .font(.body)
            .foregroundColor(KMTheme.primaryText)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      
      // Items if available
      if let items = analysis.items, !items.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Items")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.secondaryText)
          
          VStack(alignment: .leading, spacing: 4) {
            ForEach(items.prefix(5), id: \.self) { item in
              Text("• \(item)")
                .font(.caption)
                .foregroundColor(KMTheme.secondaryText)
            }
            
            if items.count > 5 {
              Text("... and \(items.count - 5) more items")
                .font(.caption2)
                .foregroundColor(KMTheme.tertiaryText)
            }
          }
        }
      }
      
      // Invoice/PO Numbers
      if let invoiceNumber = analysis.invoiceNumber {
        HStack {
          Text("Invoice #")
            .font(.caption)
            .foregroundColor(KMTheme.secondaryText)
          Spacer()
          Text(invoiceNumber)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.primaryText)
        }
      }
      
      if let poNumber = analysis.purchaseOrderNumber {
        HStack {
          Text("PO #")
            .font(.caption)
            .foregroundColor(KMTheme.secondaryText)
          Spacer()
          Text(poNumber)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.primaryText)
        }
      }
      
      // Amount breakdown
      VStack(spacing: 12) {
        Divider()
          .background(KMTheme.border)
        
        // Subtotal
        if let subtotal = analysis.subtotal {
          HStack {
            Text("Subtotal")
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.secondaryText)
            
            Spacer()
            
            Text("$\(subtotal, specifier: "%.2f")")
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.primaryText)
          }
        }
        
        // Tax
        if let tax = analysis.tax, tax > 0 {
          HStack {
            Text("Tax")
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.secondaryText)
            
            Spacer()
            
            Text("$\(tax, specifier: "%.2f")")
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.primaryText)
          }
        }
        
        // Total
        if let total = analysis.total {
          Divider()
            .background(KMTheme.border)
          
          HStack {
            Text("Total")
              .font(.headline)
              .fontWeight(.bold)
              .foregroundColor(KMTheme.primaryText)
            
            Spacer()
            
            Text("$\(total, specifier: "%.2f")")
              .font(.title2)
              .fontWeight(.bold)
              .foregroundColor(KMTheme.success)
          }
          .padding(.vertical, 4)
        }
      }
      .padding(.top, 8)
    }
  }
  
  private func quoteDocumentContent(_ analysis: DocumentAnalysisResult) -> some View {
    VStack(spacing: 16) {
      if let vendor = analysis.vendor {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Vendor")
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.secondaryText)
            
            Text(vendor)
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.primaryText)
          }
          
          Spacer()
        }
      }
      
      if let estimatedCost = analysis.estimatedCost {
        HStack {
          Text("Estimated Cost")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.secondaryText)
          
          Spacer()
          
          Text(estimatedCost)
            .font(.title3)
            .fontWeight(.bold)
            .foregroundColor(KMTheme.accent)
        }
      }
      
      if let validUntil = analysis.validUntil {
        HStack {
          Text("Valid Until")
            .font(.caption)
            .foregroundColor(KMTheme.secondaryText)
          Spacer()
          Text(validUntil.formatted(date: .abbreviated, time: .omitted))
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.primaryText)
        }
      }
      
      if let scope = analysis.scope {
        VStack(alignment: .leading, spacing: 8) {
          Text("Scope of Work")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.secondaryText)
          
          Text(scope)
            .font(.body)
            .foregroundColor(KMTheme.primaryText)
        }
      }
    }
  }
  
  private func workOrderDocumentContent(_ analysis: DocumentAnalysisResult) -> some View {
    VStack(spacing: 16) {
      if let contractor = analysis.contractor {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text("Contractor")
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.secondaryText)
            
            Text(contractor)
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.primaryText)
          }
          
          Spacer()
        }
      }
      
      if let scope = analysis.scope {
        VStack(alignment: .leading, spacing: 8) {
          Text("Scope of Work")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.secondaryText)
          
          Text(scope)
            .font(.body)
            .foregroundColor(KMTheme.primaryText)
        }
      }
      
      if let timeline = analysis.timeline {
        HStack {
          Text("Timeline")
            .font(.caption)
            .foregroundColor(KMTheme.secondaryText)
          Spacer()
          Text(timeline)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.primaryText)
        }
      }
    }
  }
  
  private func photoDocumentContent(_ analysis: DocumentAnalysisResult) -> some View {
    VStack(spacing: 16) {
      if let description = analysis.description {
        VStack(alignment: .leading, spacing: 8) {
          Text("Photo Description")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.secondaryText)
          
          Text(description)
            .font(.body)
            .foregroundColor(KMTheme.primaryText)
        }
      }
      
      if let date = analysis.date {
        HStack {
          Text("Date Taken")
            .font(.caption)
            .foregroundColor(KMTheme.secondaryText)
          Spacer()
          Text(date.formatted(date: .abbreviated, time: .omitted))
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.primaryText)
        }
      }
    }
  }
  
  private func genericDocumentContent(_ analysis: DocumentAnalysisResult) -> some View {
    VStack(spacing: 16) {
      if let vendor = analysis.vendor {
        HStack {
          Text("Source")
            .font(.caption)
            .foregroundColor(KMTheme.secondaryText)
          Spacer()
          Text(vendor)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.primaryText)
        }
      }
      
      if let description = analysis.description {
        VStack(alignment: .leading, spacing: 8) {
          Text("Description")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.secondaryText)
          
          Text(description)
            .font(.body)
            .foregroundColor(KMTheme.primaryText)
        }
      }
      
      if let date = analysis.date {
        HStack {
          Text("Date")
            .font(.caption)
            .foregroundColor(KMTheme.secondaryText)
          Spacer()
          Text(date.formatted(date: .abbreviated, time: .omitted))
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.primaryText)
        }
      }
    }
  }
  
  private var notesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "note.text")
          .foregroundColor(KMTheme.accent)
        
        Text("Additional Notes (Optional)")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
      }
      
      TextEditor(text: $notes)
        .font(.body)
        .foregroundColor(KMTheme.primaryText)
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .frame(minHeight: 100)
        .padding(12)
        .background(KMTheme.background)
        .cornerRadius(8)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(KMTheme.border, lineWidth: 1)
        )
    }
    .padding(20)
    .background(KMTheme.cardBackground)
    .cornerRadius(16)
  }
  
  private var submitButton: some View {
    Button(action: submitDocument) {
      HStack(spacing: 12) {
        if isSubmitting {
          ProgressView()
            .tint(.white)
        } else {
          Image(systemName: "checkmark.circle.fill")
            .font(.title3)
        }
        
        Text(isSubmitting ? "Uploading..." : "Submit Document")
          .font(.headline)
          .fontWeight(.semibold)
      }
      .foregroundColor(.white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 16)
      .background(isSubmitting ? KMTheme.accent.opacity(0.6) : KMTheme.accent)
      .cornerRadius(12)
    }
    .disabled(isSubmitting)
    .padding(.horizontal, 20)
  }
}

// MARK: - AI Analysis Functions

extension AddDocumentView {
  private func analyzeDocument(_ image: UIImage) {
    print("📄 [AddDocumentView] Starting AI document analysis...")
    isAnalyzing = true
    documentAnalysis = nil
    
    Task {
      do {
        let analysis = try await OpenAIService.shared.analyzeDocument(image)
        
        await MainActor.run {
          documentAnalysis = analysis
          isAnalyzing = false
          
          print("✅ [AddDocumentView] Document analysis complete")
          print("📄 Document Type: \(analysis.documentType.displayName)")
          print("📄 Confidence: \(Int(analysis.confidence * 100))%")
          
          // Haptic feedback
          let generator = UINotificationFeedbackGenerator()
          generator.notificationOccurred(.success)
        }
      } catch {
        await MainActor.run {
          isAnalyzing = false
          errorMessage = "Failed to analyze document: \(error.localizedDescription)"
          
          print("❌ [AddDocumentView] Document analysis failed: \(error)")
          
          // Haptic feedback for error
          let generator = UINotificationFeedbackGenerator()
          generator.notificationOccurred(.error)
        }
      }
    }
  }
  
  private func submitDocument() {
    guard let image = selectedImage,
          let analysis = documentAnalysis,
          let userId = appState.currentAppUser?.id else {
      print("❌ [AddDocumentView] Missing required data for submission")
      return
    }
    
    print("📤 [AddDocumentView] Submitting document...")
    isSubmitting = true
    
    Task {
      do {
        // Upload image to Firebase Storage
        let documentId = UUID().uuidString
        let fileName = "\(documentId)_\(analysis.documentType.rawValue).jpg"
        // Use maintenance-photos path which has existing permissions
        let storagePath = "maintenance-photos/\(issue.id)/documents/\(fileName)"
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
          throw NSError(domain: "AddDocumentView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])
        }
        
        print("📤 Uploading to: \(storagePath)")
        let fileUrl = try await FirebaseClient.shared.uploadFile(data: imageData, path: storagePath)
        
        // Create document object
        let document = IssueDocument(
          id: documentId,
          issueId: issue.id,
          type: analysis.documentType,
          category: analysis.documentType.category,
          fileUrl: fileUrl,
          thumbnailUrl: nil,
          fileName: fileName,
          fileSize: imageData.count,
          aiAnalysis: DocumentAnalysis(
            vendor: analysis.vendor,
            date: analysis.date,
            description: analysis.description,
            subtotal: analysis.subtotal,
            tax: analysis.tax,
            total: analysis.total,
            invoiceNumber: analysis.invoiceNumber,
            purchaseOrderNumber: analysis.purchaseOrderNumber,
            estimatedCost: analysis.estimatedCost,
            validUntil: analysis.validUntil,
            contractor: analysis.contractor,
            scope: analysis.scope,
            timeline: analysis.timeline,
            items: analysis.items,
            expenseCategory: analysis.expenseCategory
          ),
          confidence: analysis.confidence,
          uploadedBy: userId,
          uploadedAt: Date(),
          notes: notes.isEmpty ? nil : notes
        )
        
        // Save to Firestore
        try await FirebaseClient.shared.saveDocument(document)
        
        // Create timeline entry for document upload
        let vendor = analysis.vendor ?? "Document"
        var message = "Uploaded \(analysis.documentType.displayName): \(vendor)"
        
        // Only add price if document has financial information
        if let total = analysis.total, total > 0 {
          message += " - $\(String(format: "%.2f", total))"
        }
        
        let timelineEntry = WorkLog(
          id: UUID().uuidString,
          issueId: issue.id,
          authorId: userId,
          message: message,
          createdAt: Date()
        )
        
        try await FirebaseClient.shared.addWorkLog(timelineEntry)
        print("✅ [AddDocumentView] Timeline entry created for document upload")
        
        await MainActor.run {
          print("✅ [AddDocumentView] Document uploaded successfully")
          
          // Success haptic
          let generator = UINotificationFeedbackGenerator()
          generator.notificationOccurred(.success)
          
          // Call completion handler
          onDocumentAdded?()
          
          // Dismiss view
          dismiss()
        }
      } catch {
        await MainActor.run {
          isSubmitting = false
          errorMessage = "Failed to upload document: \(error.localizedDescription)"
          
          print("❌ [AddDocumentView] Upload failed: \(error)")
          
          // Error haptic
          let generator = UINotificationFeedbackGenerator()
          generator.notificationOccurred(.error)
        }
      }
    }
  }
}
