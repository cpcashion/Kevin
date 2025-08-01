import SwiftUI
import PhotosUI

struct AddReceiptView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject var appState: AppState
  
  let issue: Issue
  let workOrder: WorkOrder?
  let onReceiptAdded: (() -> Void)?
  
  @State private var selectedImage: UIImage?
  @State private var showingImagePicker = false
  @State private var showingCamera = false
  @State private var isSubmitting = false
  @State private var isAnalyzing = false
  @State private var errorMessage: String?
  @State private var receiptAnalysis: ReceiptAnalysisResult?
  @State private var showingAnalysis = false
  
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          // Header
          receiptHeader
          
          // Receipt Photo Section
          receiptPhotoSection
          
          // AI Analysis Section
          if let analysis = receiptAnalysis {
            aiAnalysisSection(analysis)
          }
          
          // Submit Button
          if receiptAnalysis != nil {
            submitButton
          }
        }
        .padding(24)
      }
      .background(KMTheme.background)
      .navigationTitle("Add Receipt")
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
        analyzeReceipt(image)
      }
    }
    .fullScreenCover(isPresented: $showingCamera) {
      CameraView(selectedImage: $selectedImage)
    }
    .onChange(of: selectedImage) { _, newImage in
      if let image = newImage {
        analyzeReceipt(image)
      }
    }
  }
  
  private var receiptHeader: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "receipt")
          .foregroundColor(KMTheme.accent)
          .font(.title2)
        
        VStack(alignment: .leading, spacing: 4) {
          Text("Receipt for Issue")
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
          
          Text("Work Order: \(workOrder.id.prefix(8))")
            .font(.caption)
            .foregroundColor(KMTheme.secondaryText)
        }
      }
    }
    .padding(16)
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
  }
  
  private var receiptPhotoSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: "camera")
          .foregroundColor(KMTheme.accent)
          .font(.title3)
        
        Text("Receipt Photo")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        Spacer()
      }
      
      if let selectedImage = selectedImage {
        // Show selected image with analysis status
        VStack(spacing: 12) {
          ZStack {
            Image(uiImage: selectedImage)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(maxHeight: 200)
              .cornerRadius(8)
              .clipped()
            
            if isAnalyzing {
              Rectangle()
                .fill(.black.opacity(0.6))
                .cornerRadius(8)
              
              VStack(spacing: 8) {
                ProgressView()
                  .progressViewStyle(CircularProgressViewStyle(tint: KMTheme.aiGreen))
                  .scaleEffect(1.2)
                
                Text("AI Analyzing Receipt...")
                  .font(.subheadline)
                  .fontWeight(.medium)
                  .foregroundColor(.white)
              }
            }
          }
          
          HStack(spacing: 12) {
            Menu("Change Photo") {
              Button("📷 Take New Photo") {
                showingCamera = true
              }
              Button("📱 Choose from Gallery") {
                showingImagePicker = true
              }
            }
            .font(.subheadline)
            .foregroundColor(KMTheme.accent)
            
            if receiptAnalysis != nil {
              Button("Re-analyze") {
                analyzeReceipt(selectedImage)
              }
              .font(.subheadline)
              .foregroundColor(KMTheme.aiGreen)
            }
          }
        }
      } else {
        // Modern photo selection interface
        VStack(spacing: 16) {
          Text("Choose Photo Source")
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(KMTheme.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
          
          HStack(spacing: 16) {
            // Camera Button
            Button(action: { showingCamera = true }) {
              VStack(spacing: 12) {
                ZStack {
                  Circle()
                    .fill(KMTheme.accent.opacity(0.1))
                    .frame(width: 60, height: 60)
                  
                  Image(systemName: "camera.fill")
                    .font(.title2)
                    .foregroundColor(KMTheme.accent)
                }
                
                VStack(spacing: 4) {
                  Text("Camera")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(KMTheme.primaryText)
                  
                  Text("Take Photo")
                    .font(.caption)
                    .foregroundColor(KMTheme.secondaryText)
                }
              }
              .frame(maxWidth: .infinity)
              .padding(20)
              .background(KMTheme.cardBackground)
              .cornerRadius(16)
              .overlay(
                RoundedRectangle(cornerRadius: 16)
                  .stroke(KMTheme.accent.opacity(0.2), lineWidth: 1)
              )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Photo Library Button
            Button(action: { showingImagePicker = true }) {
              VStack(spacing: 12) {
                ZStack {
                  Circle()
                    .fill(KMTheme.success.opacity(0.1))
                    .frame(width: 60, height: 60)
                  
                  Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                    .foregroundColor(KMTheme.success)
                }
                
                VStack(spacing: 4) {
                  Text("Gallery")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(KMTheme.primaryText)
                  
                  Text("Choose Photo")
                    .font(.caption)
                    .foregroundColor(KMTheme.secondaryText)
                }
              }
              .frame(maxWidth: .infinity)
              .padding(20)
              .background(KMTheme.cardBackground)
              .cornerRadius(16)
              .overlay(
                RoundedRectangle(cornerRadius: 16)
                  .stroke(KMTheme.success.opacity(0.2), lineWidth: 1)
              )
            }
            .buttonStyle(PlainButtonStyle())
          }
          
          // AI Info Banner
          HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
              .font(.title3)
              .foregroundColor(KMTheme.aiGreen)
            
            VStack(alignment: .leading, spacing: 2) {
              Text("AI-Powered Analysis")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(KMTheme.primaryText)
              
              Text("Automatically extracts vendor, amount, date, and items")
                .font(.caption)
                .foregroundColor(KMTheme.secondaryText)
            }
            
            Spacer()
          }
          .padding(16)
          .background(KMTheme.aiGreen.opacity(0.1))
          .cornerRadius(12)
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(KMTheme.aiGreen.opacity(0.3), lineWidth: 1)
          )
        }
      }
    }
    .padding(16)
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
  }
  
  
  private var submitButton: some View {
    VStack(spacing: 12) {
      if let errorMessage = errorMessage {
        Text(errorMessage)
          .font(.subheadline)
          .foregroundColor(.red)
          .padding(.horizontal)
      }
      
      Button(action: submitReceipt) {
        HStack {
          if isSubmitting {
            ProgressView()
              .progressViewStyle(CircularProgressViewStyle(tint: .white))
              .scaleEffect(0.8)
          } else {
            Image(systemName: "checkmark.circle.fill")
              .font(.title3)
          }
          
          Text(isSubmitting ? "Submitting..." : "Submit Receipt")
            .font(.headline)
            .fontWeight(.semibold)
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(
          isFormValid ? KMTheme.accent : KMTheme.secondaryText
        )
        .cornerRadius(12)
      }
      .disabled(!isFormValid || isSubmitting)
    }
  }
  
  private var isFormValid: Bool {
    selectedImage != nil && receiptAnalysis != nil
  }
  
  
  private func submitReceipt() {
    guard isFormValid,
          let selectedImage = selectedImage,
          let analysis = receiptAnalysis,
          let currentUser = appState.currentAppUser else {
      errorMessage = "Please take a photo and wait for AI analysis"
      return
    }
    
    isSubmitting = true
    errorMessage = nil
    
    Task {
      do {
        let receipt = Receipt(
          issueId: issue.id,
          workOrderId: workOrder?.id,
          restaurantId: issue.restaurantId,
          submittedBy: currentUser.id,
          vendor: analysis.vendor,
          category: analysis.category,
          amount: analysis.totalAmount,
          taxAmount: analysis.taxAmount,
          description: analysis.description,
          purchaseDate: analysis.purchaseDate,
          receiptImageUrl: "placeholder-url" // Will be updated by FirebaseClient
        )
        
        try await FirebaseClient.shared.createReceipt(receipt, receiptImage: selectedImage)
        
        await MainActor.run {
          onReceiptAdded?()
          dismiss()
        }
      } catch {
        await MainActor.run {
          errorMessage = "Failed to submit receipt: \(error.localizedDescription)"
          isSubmitting = false
        }
      }
    }
  }
}

// MARK: - Custom Text Field Style
struct KMTextFieldStyle: TextFieldStyle {
  func _body(configuration: TextField<Self._Label>) -> some View {
    configuration
      .foregroundColor(KMTheme.inputText)
      .padding(12)
      .background(KMTheme.inputBackground)
      .cornerRadius(8)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(KMTheme.inputBorder, lineWidth: 1)
      )
  }
}

#Preview {
  AddReceiptView(
    issue: Issue(
      id: "preview-issue",
      restaurantId: "preview-restaurant",
      locationId: "preview-location",
      reporterId: "preview-user",
      title: "Broken freezer door",
      description: "The freezer door won't close properly",
      priority: .high,
      status: .in_progress,
      createdAt: Date()
    ),
    workOrder: nil,
    onReceiptAdded: nil
  )
  .environmentObject(AppState())
}

// MARK: - AI Analysis Functions

extension AddReceiptView {
  private func analyzeReceipt(_ image: UIImage) {
    print("🧾 [AddReceiptView] Starting AI receipt analysis...")
    isAnalyzing = true
    receiptAnalysis = nil
    
    Task {
      do {
        let analysis = try await OpenAIService.shared.analyzeReceiptImage(image)
        
        await MainActor.run {
          receiptAnalysis = analysis
          isAnalyzing = false
          showingAnalysis = true
          
          print("✅ [AddReceiptView] Receipt analysis completed successfully")
          print("🧾 [AddReceiptView] Vendor: \(analysis.vendor), Amount: $\(analysis.totalAmount)")
        }
      } catch {
        print("❌ [AddReceiptView] Receipt analysis failed: \(error)")
        await MainActor.run {
          receiptAnalysis = nil
          isAnalyzing = false
          errorMessage = "Failed to analyze receipt: \(error.localizedDescription)"
        }
      }
    }
  }
  
  private func aiAnalysisSection(_ analysis: ReceiptAnalysisResult) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack {
        Image(systemName: "brain.head.profile")
          .foregroundColor(KMTheme.aiGreen)
          .font(.title3)
        
        Text("AI Receipt Analysis")
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
      
      VStack(spacing: 16) {
        // Vendor Row
        VStack(alignment: .leading, spacing: 4) {
          Text("Vendor")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.secondaryText)
          
          Text(analysis.vendor)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        
        // Category and Date Row
        HStack(spacing: 16) {
          VStack(alignment: .leading, spacing: 4) {
            Text("Category")
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.secondaryText)
            
            HStack(spacing: 6) {
              Image(systemName: analysis.category.icon)
                .foregroundColor(KMTheme.accent)
                .font(.caption)
              
              Text(analysis.category.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(KMTheme.primaryText)
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          
          VStack(alignment: .trailing, spacing: 4) {
            Text("Purchase Date")
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.secondaryText)
            
            Text(analysis.purchaseDate.formatted(date: .abbreviated, time: .omitted))
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.primaryText)
          }
        }
        
        // Description
        VStack(alignment: .leading, spacing: 8) {
          Text("Description")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.secondaryText)
          
          Text(analysis.description)
            .font(.body)
            .foregroundColor(KMTheme.primaryText)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
        }
        
        // Items if available
        if !analysis.items.isEmpty {
          VStack(alignment: .leading, spacing: 8) {
            Text("Items Purchased")
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.secondaryText)
            
            VStack(alignment: .leading, spacing: 4) {
              ForEach(analysis.items.prefix(5), id: \.self) { item in
                Text("• \(item)")
                  .font(.caption)
                  .foregroundColor(KMTheme.secondaryText)
              }
              
              if analysis.items.count > 5 {
                Text("... and \(analysis.items.count - 5) more items")
                  .font(.caption2)
                  .foregroundColor(KMTheme.tertiaryText)
              }
            }
          }
        }
        
        // Amount breakdown - clear and prominent
        VStack(spacing: 12) {
          Divider()
            .background(KMTheme.border)
          
          // Subtotal
          HStack {
            Text("Subtotal")
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.secondaryText)
            
            Spacer()
            
            Text("$\(analysis.totalAmount, specifier: "%.2f")")
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.primaryText)
          }
          
          // Tax (if available)
          if let taxAmount = analysis.taxAmount, taxAmount > 0 {
            HStack {
              Text("Tax")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(KMTheme.secondaryText)
              
              Spacer()
              
              Text("$\(taxAmount, specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(KMTheme.primaryText)
            }
            
            Divider()
              .background(KMTheme.border)
            
            // Total (subtotal + tax)
            HStack {
              Text("Total")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(KMTheme.primaryText)
              
              Spacer()
              
              Text("$\(analysis.totalAmount + taxAmount, specifier: "%.2f")")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(KMTheme.success)
            }
            .padding(.vertical, 4)
          } else {
            // No tax - just show total
            Divider()
              .background(KMTheme.border)
            
            HStack {
              Text("Total")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(KMTheme.primaryText)
              
              Spacer()
              
              Text("$\(analysis.totalAmount, specifier: "%.2f")")
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
    .padding(20)
    .background(KMTheme.cardBackground)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(KMTheme.aiGreen.opacity(0.3), lineWidth: 1)
    )
  }
}
