import SwiftUI

struct DocumentDetailView: View {
  let document: IssueDocument
  @Environment(\.dismiss) private var dismiss
  @State private var showingFullImage = false
  
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          // Document Image
          documentImageSection
          
          // AI Analysis Section
          if let analysis = document.aiAnalysis {
            aiAnalysisSection(analysis)
          }
          
          // Notes Section
          if let notes = document.notes, !notes.isEmpty {
            notesSection(notes)
          }
          
          // Metadata Section
          metadataSection
        }
        .padding(24)
      }
      .background(KMTheme.background)
      .navigationTitle(document.type.displayName)
      .navigationBarTitleDisplayMode(.inline)
      .kevinNavigationBarStyle()
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
          .foregroundColor(KMTheme.accent)
        }
      }
    }
    .fullScreenCover(isPresented: $showingFullImage) {
      DocumentImageViewer(imageUrl: document.fileUrl)
    }
  }
  
  private var documentImageSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "photo")
          .foregroundColor(KMTheme.accent)
        
        Text("Document Image")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
      }
      
      Button(action: { showingFullImage = true }) {
        AsyncImage(url: URL(string: document.fileUrl)) { phase in
          switch phase {
          case .empty:
            ProgressView()
              .frame(maxWidth: .infinity)
              .frame(height: 300)
          case .success(let image):
            image
              .resizable()
              .aspectRatio(contentMode: .fill)
              .frame(maxWidth: .infinity)
              .frame(height: 300)
              .clipShape(RoundedRectangle(cornerRadius: 12))
          case .failure:
            VStack {
              Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(KMTheme.secondaryText)
              Text("Failed to load image")
                .font(.caption)
                .foregroundColor(KMTheme.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 300)
          @unknown default:
            EmptyView()
          }
        }
      }
      .buttonStyle(PlainButtonStyle())
    }
    .padding(20)
    .background(KMTheme.cardBackground)
    .cornerRadius(16)
  }
  
  private func aiAnalysisSection(_ analysis: DocumentAnalysis) -> some View {
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
        
        if let confidence = document.confidence, confidence > 0 {
          HStack(spacing: 4) {
            Text("\(Int(confidence * 100))%")
              .font(.caption)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.aiGreen)
            
            Text("confident")
              .font(.caption)
              .foregroundColor(KMTheme.secondaryText)
          }
        }
      }
      
      // Vendor
      if let vendor = analysis.vendor {
        infoRow(label: "Vendor", value: vendor)
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
        }
      }
      
      // Date
      if let date = analysis.date {
        infoRow(label: "Date", value: date.formatted(date: .abbreviated, time: .omitted))
      }
      
      // Financial Information
      if analysis.subtotal != nil || analysis.tax != nil || analysis.total != nil {
        Divider()
          .background(KMTheme.border)
        
        VStack(spacing: 12) {
          if let subtotal = analysis.subtotal {
            HStack {
              Text("Subtotal")
                .font(.subheadline)
                .foregroundColor(KMTheme.secondaryText)
              Spacer()
              Text("$\(subtotal, specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(KMTheme.primaryText)
            }
          }
          
          if let tax = analysis.tax, tax > 0 {
            HStack {
              Text("Tax")
                .font(.subheadline)
                .foregroundColor(KMTheme.secondaryText)
              Spacer()
              Text("$\(tax, specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(KMTheme.primaryText)
            }
          }
          
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
          }
        }
      }
      
      // Invoice/PO Numbers
      if let invoiceNumber = analysis.invoiceNumber {
        infoRow(label: "Invoice #", value: invoiceNumber)
      }
      
      if let poNumber = analysis.purchaseOrderNumber {
        infoRow(label: "PO #", value: poNumber)
      }
      
      // Items
      if let items = analysis.items, !items.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("Items")
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.secondaryText)
          
          VStack(alignment: .leading, spacing: 4) {
            ForEach(items.prefix(10), id: \.self) { item in
              Text("• \(item)")
                .font(.caption)
                .foregroundColor(KMTheme.secondaryText)
            }
            
            if items.count > 10 {
              Text("... and \(items.count - 10) more items")
                .font(.caption2)
                .foregroundColor(KMTheme.tertiaryText)
            }
          }
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
  
  private func notesSection(_ notes: String) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "note.text")
          .foregroundColor(KMTheme.accent)
        
        Text("Notes")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
      }
      
      Text(notes)
        .font(.body)
        .foregroundColor(KMTheme.primaryText)
    }
    .padding(20)
    .background(KMTheme.cardBackground)
    .cornerRadius(16)
  }
  
  private var metadataSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "info.circle")
          .foregroundColor(KMTheme.accent)
        
        Text("Document Info")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
      }
      
      infoRow(label: "Type", value: document.type.displayName)
      infoRow(label: "Category", value: document.category.displayName)
      infoRow(label: "Uploaded", value: document.uploadedAt.formatted(date: .abbreviated, time: .shortened))
      
      if let fileSize = formatFileSize(document.fileSize) {
        infoRow(label: "File Size", value: fileSize)
      }
    }
    .padding(20)
    .background(KMTheme.cardBackground)
    .cornerRadius(16)
  }
  
  private func infoRow(label: String, value: String) -> some View {
    HStack {
      Text(label)
        .font(.caption)
        .foregroundColor(KMTheme.secondaryText)
      Spacer()
      Text(value)
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundColor(KMTheme.primaryText)
    }
  }
  
  private func formatFileSize(_ bytes: Int?) -> String? {
    guard let bytes = bytes else { return nil }
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: Int64(bytes))
  }
}

// MARK: - Document Image Viewer
struct DocumentImageViewer: View {
  let imageUrl: String
  @Environment(\.dismiss) private var dismiss
  @State private var scale: CGFloat = 1.0
  @State private var lastScale: CGFloat = 1.0
  
  var body: some View {
    ZStack {
      Color.black.ignoresSafeArea()
      
      AsyncImage(url: URL(string: imageUrl)) { phase in
        switch phase {
        case .empty:
          ProgressView()
            .tint(.white)
        case .success(let image):
          image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale)
            .gesture(
              MagnificationGesture()
                .onChanged { value in
                  scale = lastScale * value
                }
                .onEnded { _ in
                  lastScale = scale
                  // Limit scale
                  if scale < 1 {
                    withAnimation {
                      scale = 1
                      lastScale = 1
                    }
                  } else if scale > 4 {
                    withAnimation {
                      scale = 4
                      lastScale = 4
                    }
                  }
                }
            )
            .onTapGesture(count: 2) {
              withAnimation {
                if scale > 1 {
                  scale = 1
                  lastScale = 1
                } else {
                  scale = 2
                  lastScale = 2
                }
              }
            }
        case .failure:
          VStack {
            Image(systemName: "exclamationmark.triangle")
              .font(.largeTitle)
              .foregroundColor(.white)
            Text("Failed to load image")
              .foregroundColor(.white)
          }
        @unknown default:
          EmptyView()
        }
      }
      
      VStack {
        HStack {
          Spacer()
          Button(action: { dismiss() }) {
            Image(systemName: "xmark.circle.fill")
              .font(.title)
              .foregroundColor(.white)
              .padding()
          }
        }
        Spacer()
      }
    }
  }
}
