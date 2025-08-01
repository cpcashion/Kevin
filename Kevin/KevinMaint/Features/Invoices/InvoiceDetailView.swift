import SwiftUI

struct InvoiceDetailView: View {
  let invoice: Invoice
  @Environment(\.dismiss) private var dismiss
  @State private var showingPDFViewer = false
  @State private var isLoadingPDF = false
  @State private var pdfImage: UIImage?
  
  var body: some View {
    NavigationView {
      ScrollView {
        VStack(alignment: .leading, spacing: 24) {
          // Header with invoice number and status
          headerSection
          
          // PDF Thumbnail (if available)
          if let pdfUrl = invoice.pdfUrl {
            pdfThumbnailSection(pdfUrl: pdfUrl)
          }
          
          // Invoice info
          invoiceInfoSection
          
          // Line items breakdown
          lineItemsSection
          
          // Financial summary
          financialSummarySection
          
          // Payment info
          if let paymentInstructions = invoice.paymentInstructions {
            paymentInstructionsSection(paymentInstructions)
          }
          
          // Additional notes
          if let notes = invoice.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notesSection(notes)
          }
        }
        .padding()
      }
      .background(KMTheme.background)
      .navigationTitle("Invoice Details")
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
    .sheet(isPresented: $showingPDFViewer) {
      if let pdfUrl = invoice.pdfUrl {
        InvoicePDFViewerSheet(pdfUrl: pdfUrl, invoiceNumber: invoice.invoiceNumber)
      }
    }
  }
  
  // MARK: - Header Section
  
  private var headerSection: some View {
    HStack(alignment: .top, spacing: 16) {
      // Invoice icon
      Image(systemName: "doc.text.fill")
        .foregroundColor(statusColor)
        .font(.title2)
      
      VStack(alignment: .leading, spacing: 4) {
        Text(invoice.invoiceNumber)
          .font(.title3)
          .fontWeight(.bold)
          .foregroundColor(KMTheme.primaryText)
        
        // Status badge
        HStack(spacing: 4) {
          Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
          
          Text(invoice.status.displayName)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(statusColor)
        }
      }
      
      Spacer()
      
      // Total amount (prominent)
      VStack(alignment: .trailing, spacing: 2) {
        Text("Total")
          .font(.caption)
          .foregroundColor(KMTheme.secondaryText)
        
        Text("$\(String(format: "%.2f", invoice.total))")
          .font(.title2)
          .fontWeight(.bold)
          .foregroundColor(invoice.status == .paid ? .green : KMTheme.primaryText)
      }
    }
    .padding()
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
  }
  
  // MARK: - PDF Thumbnail Section
  
  private func pdfThumbnailSection(pdfUrl: String) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Invoice Document")
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(KMTheme.primaryText)
      
      Button(action: {
        showingPDFViewer = true
      }) {
        ZStack {
          // Thumbnail background
          RoundedRectangle(cornerRadius: 12)
            .fill(KMTheme.cardBackground)
            .frame(height: 200)
          
          VStack(spacing: 12) {
            // PDF icon
            Image(systemName: "doc.richtext.fill")
              .font(.system(size: 48))
              .foregroundColor(KMTheme.accent)
            
            VStack(spacing: 4) {
              Text("Tap to view invoice")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(KMTheme.primaryText)
              
              Text("PDF Document")
                .font(.caption)
                .foregroundColor(KMTheme.secondaryText)
            }
            
            // Action buttons
            HStack(spacing: 12) {
              Label("Tap to view", systemImage: "eye.fill")
                .font(.caption)
                .foregroundColor(KMTheme.accent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(KMTheme.accent.opacity(0.1))
            .cornerRadius(8)
          }
        }
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(KMTheme.accent.opacity(0.3), lineWidth: 1.5)
        )
      }
      .buttonStyle(PlainButtonStyle())
    }
    .padding()
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
  }
  
  // MARK: - Invoice Info Section
  
  private var invoiceInfoSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Business info
      VStack(alignment: .leading, spacing: 4) {
        Text("Billed To")
          .font(.caption)
          .foregroundColor(KMTheme.secondaryText)
        
        Text(invoice.businessName)
          .font(.body)
          .fontWeight(.medium)
          .foregroundColor(KMTheme.primaryText)
        
        if let address = invoice.businessAddress {
          Text(address)
            .font(.caption)
            .foregroundColor(KMTheme.secondaryText)
        }
        
        if let email = invoice.businessEmail {
          Text(email)
            .font(.caption)
            .foregroundColor(KMTheme.accent)
        }
      }
      
      Divider()
        .background(KMTheme.border)
      
      // Dates
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text("Issue Date")
            .font(.caption)
            .foregroundColor(KMTheme.secondaryText)
          
          Text(invoice.issueDate.formatted(date: .abbreviated, time: .omitted))
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.primaryText)
        }
        
        Spacer()
        
        VStack(alignment: .trailing, spacing: 4) {
          Text("Due Date")
            .font(.caption)
            .foregroundColor(KMTheme.secondaryText)
          
          Text(invoice.dueDate.formatted(date: .abbreviated, time: .omitted))
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(invoice.status == .overdue ? KMTheme.danger : KMTheme.primaryText)
        }
      }
      
      // Paid date if applicable
      if let paidDate = invoice.paidDate {
        Divider()
          .background(KMTheme.border)
        
        HStack {
          Text("Paid On")
            .font(.caption)
            .foregroundColor(KMTheme.secondaryText)
          
          Spacer()
          
          Text(paidDate.formatted(date: .abbreviated, time: .omitted))
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.green)
        }
      }
    }
    .padding()
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
  }
  
  // MARK: - Line Items Section
  
  private var lineItemsSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Line Items")
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(KMTheme.primaryText)
      
      VStack(spacing: 12) {
        // Header row
        HStack {
          Text("Description")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(KMTheme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
          
          Text("Qty")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(KMTheme.secondaryText)
            .frame(width: 40, alignment: .center)
          
          Text("Rate")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(KMTheme.secondaryText)
            .frame(width: 60, alignment: .trailing)
          
          Text("Amount")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(KMTheme.secondaryText)
            .frame(width: 70, alignment: .trailing)
        }
        .padding(.bottom, 4)
        
        Divider()
          .background(KMTheme.border)
        
        // Line items
        ForEach(invoice.lineItems) { item in
          lineItemRow(item)
        }
      }
    }
    .padding()
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
  }
  
  private func lineItemRow(_ item: InvoiceLineItem) -> some View {
    VStack(spacing: 8) {
      HStack(alignment: .top) {
        Text(item.description)
          .font(.body)
          .foregroundColor(KMTheme.primaryText)
          .frame(maxWidth: .infinity, alignment: .leading)
        
        Text(String(format: "%.0f", item.quantity))
          .font(.body)
          .foregroundColor(KMTheme.secondaryText)
          .frame(width: 40, alignment: .center)
        
        Text("$\(String(format: "%.2f", item.unitPrice))")
          .font(.body)
          .foregroundColor(KMTheme.secondaryText)
          .frame(width: 60, alignment: .trailing)
        
        Text("$\(String(format: "%.2f", item.total))")
          .font(.body)
          .fontWeight(.medium)
          .foregroundColor(KMTheme.primaryText)
          .frame(width: 70, alignment: .trailing)
      }
      
      if item != invoice.lineItems.last {
        Divider()
          .background(KMTheme.border.opacity(0.3))
      }
    }
  }
  
  // MARK: - Financial Summary Section
  
  private var financialSummarySection: some View {
    VStack(spacing: 12) {
      // Subtotal
      HStack {
        Text("Subtotal")
          .font(.body)
          .foregroundColor(KMTheme.secondaryText)
        
        Spacer()
        
        Text("$\(String(format: "%.2f", invoice.subtotal))")
          .font(.body)
          .fontWeight(.medium)
          .foregroundColor(KMTheme.primaryText)
      }
      
      // Tax
      HStack {
        Text("Tax (\(String(format: "%.1f", invoice.taxRate * 100))%)")
          .font(.body)
          .foregroundColor(KMTheme.secondaryText)
        
        Spacer()
        
        Text("$\(String(format: "%.2f", invoice.taxAmount))")
          .font(.body)
          .fontWeight(.medium)
          .foregroundColor(KMTheme.primaryText)
      }
      
      Divider()
        .background(KMTheme.border)
      
      // Total
      HStack {
        Text("Total")
          .font(.title3)
          .fontWeight(.bold)
          .foregroundColor(KMTheme.primaryText)
        
        Spacer()
        
        Text("$\(String(format: "%.2f", invoice.total))")
          .font(.title2)
          .fontWeight(.bold)
          .foregroundColor(invoice.status == .paid ? .green : KMTheme.accent)
      }
    }
    .padding()
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
  }
  
  // MARK: - Payment Instructions Section
  
  private func paymentInstructionsSection(_ instructions: String) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "creditcard.fill")
          .foregroundColor(KMTheme.accent)
          .font(.title3)
        
        Text("Payment Instructions")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
      }
      
      Text(instructions)
        .font(.body)
        .foregroundColor(KMTheme.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding()
    .background(KMTheme.accent.opacity(0.1))
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(KMTheme.accent.opacity(0.3), lineWidth: 0.5)
    )
  }
  
  // MARK: - Notes Section
  
  private func notesSection(_ notes: String) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Additional Notes")
        .font(.headline)
        .fontWeight(.semibold)
        .foregroundColor(KMTheme.primaryText)
      
      Text(notes)
        .font(.body)
        .foregroundColor(KMTheme.secondaryText)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding()
    .background(KMTheme.cardBackground)
    .cornerRadius(12)
  }
  
  // MARK: - Helpers
  
  private var statusColor: Color {
    switch invoice.status {
    case .draft:
      return Color.gray
    case .sent:
      return Color.blue
    case .paid:
      return Color.green
    case .overdue:
      return KMTheme.danger
    case .cancelled:
      return Color.gray
    }
  }
}

// MARK: - PDF Viewer Sheet

struct InvoicePDFViewerSheet: View {
  let pdfUrl: String
  let invoiceNumber: String
  @Environment(\.dismiss) private var dismiss
  @State private var isLoading = true
  @State private var errorMessage: String?
  
  var body: some View {
    NavigationView {
      ZStack {
        KMTheme.background.ignoresSafeArea()
        
        if isLoading {
          VStack(spacing: 16) {
            ProgressView()
              .scaleEffect(1.2)
            
            Text("Loading invoice...")
              .font(.subheadline)
              .foregroundColor(KMTheme.secondaryText)
          }
        } else if let error = errorMessage {
          VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
              .font(.system(size: 48))
              .foregroundColor(KMTheme.danger)
            
            Text("Failed to load PDF")
              .font(.headline)
              .foregroundColor(KMTheme.primaryText)
            
            Text(error)
              .font(.subheadline)
              .foregroundColor(KMTheme.secondaryText)
              .multilineTextAlignment(.center)
              .padding(.horizontal)
          }
        } else {
          // PDF Web View
          PDFWebView(url: pdfUrl)
        }
      }
      .navigationTitle(invoiceNumber)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Close") {
            dismiss()
          }
          .foregroundColor(KMTheme.accent)
        }
        
        ToolbarItem(placement: .navigationBarTrailing) {
          Menu {
            Button(action: downloadPDF) {
              Label("Download", systemImage: "arrow.down.circle")
            }
            
            Button(action: sharePDF) {
              Label("Share", systemImage: "square.and.arrow.up")
            }
            
            if #available(iOS 15.0, *) {
              Button(action: printPDF) {
                Label("Print", systemImage: "printer")
              }
            }
          } label: {
            Image(systemName: "ellipsis.circle")
              .foregroundColor(KMTheme.accent)
          }
        }
      }
    }
    .onAppear {
      // Simulate loading - in real implementation, verify URL is accessible
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        isLoading = false
      }
    }
  }
  
  private func downloadPDF() {
    // TODO: Implement PDF download
    print("Download PDF: \(pdfUrl)")
  }
  
  private func sharePDF() {
    // TODO: Implement PDF sharing
    print("Share PDF: \(pdfUrl)")
  }
  
  private func printPDF() {
    // TODO: Implement PDF printing
    print("Print PDF: \(pdfUrl)")
  }
}

// MARK: - PDF Web View

import WebKit

struct PDFWebView: UIViewRepresentable {
  let url: String
  
  func makeUIView(context: Context) -> WKWebView {
    let webView = WKWebView()
    webView.backgroundColor = UIColor(KMTheme.background)
    return webView
  }
  
  func updateUIView(_ webView: WKWebView, context: Context) {
    if let pdfURL = URL(string: url) {
      let request = URLRequest(url: pdfURL)
      webView.load(request)
    }
  }
}

// MARK: - Preview

#Preview {
  InvoiceDetailView(
    invoice: Invoice(
      invoiceNumber: "INV-20241028-0001",
      issueId: "test-issue",
      businessId: "test-business",
      businessName: "Davidson Village Inn",
      businessAddress: "123 Main St, Davidson, NC 28036",
      businessEmail: "manager@davidsonvillageinn.com",
      businessPhone: "(704) 555-1234",
      lineItems: [
        InvoiceLineItem(
          description: "Door handle replacement - Labor",
          quantity: 2,
          unitPrice: 75.00
        ),
        InvoiceLineItem(
          description: "Door handle hardware",
          quantity: 1,
          unitPrice: 45.00
        ),
        InvoiceLineItem(
          description: "Paint touch-up",
          quantity: 1,
          unitPrice: 30.00
        )
      ],
      taxRate: 0.08,
      status: .sent,
      pdfUrl: "https://example.com/invoice.pdf",
      createdBy: "admin-123"
    )
  )
}
