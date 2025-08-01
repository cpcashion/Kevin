import SwiftUI
import FirebaseStorage

struct InvoiceBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    
    let issue: Issue
    let business: Restaurant?
    
    @State private var businessName: String = ""
    @State private var businessAddress: String = ""
    @State private var businessPhone: String = ""
    @State private var businessEmail: String = ""
    @State private var lineItems: [InvoiceLineItem] = []
    @State private var taxRate: Double = 0.08
    @State private var paymentInstructions: String = "Payment due within 30 days. Please make checks payable to Kevin Inc."
    @State private var notes: String = ""
    @State private var dueDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    
    @State private var showingAddLineItem = false
    @State private var isGenerating = false
    @State private var generatedPDFData: Data?
    @State private var showingEmailSheet = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingPDFPreview = false
    @State private var generatedInvoice: Invoice?
    
    // New line item form
    @State private var newItemDescription = ""
    @State private var newItemQuantity = "1"
    @State private var newItemPrice = ""
    
    // Receipt photos
    @State private var receiptPhotos: [UIImage] = []
    @State private var showingImagePicker = false
    @State private var showingPhotoOptions = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .camera
    
    private var subtotal: Double {
        lineItems.reduce(0) { $0 + $1.total }
    }
    
    private var taxAmount: Double {
        subtotal * taxRate
    }
    
    private var total: Double {
        subtotal + taxAmount
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Invoice header info
                    invoiceInfoSection
                    
                    // Line items
                    lineItemsSection
                    
                    // Add line item button
                    Button(action: { showingAddLineItem = true }) {
                        Label("Add Line Item", systemImage: "plus.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(KMTheme.accent)
                    }
                    .padding(.vertical, 8)
                    
                    // Totals
                    totalsSection
                    
                    // Payment instructions
                    paymentInstructionsSection
                    
                    // Notes
                    notesSection
                    
                    // Receipt photos
                    receiptPhotosSection
                    
                    // Action buttons
                    actionButtons
                }
                .padding()
            }
            .background(KMTheme.background)
            .navigationTitle("Create Invoice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(KMTheme.secondaryText)
                }
            }
            .sheet(isPresented: $showingAddLineItem) {
                addLineItemSheet
            }
            .sheet(isPresented: $showingEmailSheet) {
                if let pdfData = generatedPDFData, let invoice = generatedInvoice {
                    EmailInvoiceWrapper(
                        pdfData: pdfData,
                        recipientEmail: businessEmail,
                        recipientName: businessName,
                        invoiceNumber: invoice.invoiceNumber,
                        receiptPhotos: receiptPhotos,
                        onEmailSent: {
                            // Update invoice status to sent in Firebase and post to timeline
                            Task {
                                // Use the generated invoice which has receipt URLs
                                if var sentInvoice = generatedInvoice {
                                    sentInvoice.status = .sent
                                    try? await FirebaseClient.shared.updateInvoice(sentInvoice)
                                    
                                    // Update local state
                                    await MainActor.run {
                                        generatedInvoice = sentInvoice
                                    }
                                    
                                    // Post to timeline when invoice is actually sent
                                    await postInvoiceToTimeline(invoice: sentInvoice)
                                }
                            }
                        }
                    )
                }
            }
            .sheet(isPresented: $showingPDFPreview) {
                if let pdfData = generatedPDFData {
                    PDFPreviewView(pdfData: pdfData)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingPhotoOptions) {
                NavigationStack {
                    VStack(spacing: 20) {
                        Text("Add Receipt Photo")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .padding(.top)
                        
                        VStack(spacing: 16) {
                            Button(action: {
                                imagePickerSourceType = .camera
                                showingPhotoOptions = false
                                showingImagePicker = true
                            }) {
                                HStack {
                                    Image(systemName: "camera.fill")
                                        .font(.title2)
                                    Text("Take Photo")
                                        .font(.headline)
                                    Spacer()
                                }
                                .padding()
                                .background(KMTheme.cardBackground)
                                .cornerRadius(12)
                            }
                            .foregroundColor(KMTheme.primaryText)
                            
                            Button(action: {
                                imagePickerSourceType = .photoLibrary
                                showingPhotoOptions = false
                                showingImagePicker = true
                            }) {
                                HStack {
                                    Image(systemName: "photo.fill")
                                        .font(.title2)
                                    Text("Choose from Library")
                                        .font(.headline)
                                    Spacer()
                                }
                                .padding()
                                .background(KMTheme.cardBackground)
                                .cornerRadius(12)
                            }
                            .foregroundColor(KMTheme.primaryText)
                        }
                        .padding(.horizontal)
                        
                        Spacer()
                    }
                    .background(KMTheme.background)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Cancel") {
                                showingPhotoOptions = false
                            }
                        }
                    }
                }
                .presentationDetents([.height(300)])
            }
            .sheet(isPresented: $showingImagePicker) {
                SimpleImagePicker(
                    sourceType: imagePickerSourceType,
                    onImageSelected: { image in
                        receiptPhotos.append(image)
                    }
                )
            }
        }
        .onAppear {
            loadReceiptsAsLineItems()
            loadBusinessInfo()
        }
    }
    
    // MARK: - Sections
    
    private var invoiceInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Invoice Information")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(KMTheme.primaryText)
            
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Business Name:")
                        .font(.system(size: 12))
                        .foregroundColor(KMTheme.secondaryText)
                    TextField("Business Name", text: $businessName)
                        .padding(8)
                        .background(KMTheme.inputBackground)
                        .foregroundColor(KMTheme.inputText)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(KMTheme.inputBorder, lineWidth: 1)
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Business Address:")
                        .font(.system(size: 12))
                        .foregroundColor(KMTheme.secondaryText)
                    TextField("Business Address", text: $businessAddress)
                        .padding(8)
                        .background(KMTheme.inputBackground)
                        .foregroundColor(KMTheme.inputText)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(KMTheme.inputBorder, lineWidth: 1)
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Business Phone:")
                        .font(.system(size: 12))
                        .foregroundColor(KMTheme.secondaryText)
                    TextField("Business Phone", text: $businessPhone)
                        .padding(8)
                        .background(KMTheme.inputBackground)
                        .foregroundColor(KMTheme.inputText)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(KMTheme.inputBorder, lineWidth: 1)
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Business Email:")
                        .font(.system(size: 12))
                        .foregroundColor(KMTheme.secondaryText)
                    TextField("Business Email", text: $businessEmail)
                        .padding(8)
                        .background(KMTheme.inputBackground)
                        .foregroundColor(KMTheme.inputText)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(KMTheme.inputBorder, lineWidth: 1)
                        )
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }
                
                HStack {
                    Text("Issue:")
                        .foregroundColor(KMTheme.secondaryText)
                    Spacer()
                    Text(issue.title)
                        .foregroundColor(KMTheme.primaryText)
                        .fontWeight(.medium)
                        .lineLimit(1)
                }
                
                HStack {
                    Text("Due Date:")
                        .foregroundColor(KMTheme.secondaryText)
                    Spacer()
                    DatePicker("", selection: $dueDate, displayedComponents: .date)
                        .labelsHidden()
                }
            }
            .padding()
            .background(KMTheme.cardBackground)
            .cornerRadius(12)
        }
    }
    
    private var lineItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Line Items")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(KMTheme.primaryText)
            
            if lineItems.isEmpty {
                Text("No line items added yet")
                    .foregroundColor(KMTheme.tertiaryText)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(KMTheme.cardBackground)
                    .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(lineItems) { item in
                        LineItemRow(item: item) {
                            deleteLineItem(item)
                        }
                    }
                }
            }
        }
    }
    
    private var totalsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Subtotal:")
                    .foregroundColor(KMTheme.secondaryText)
                Spacer()
                Text("$\(subtotal, specifier: "%.2f")")
                    .foregroundColor(KMTheme.primaryText)
                    .fontWeight(.medium)
            }
            
            HStack {
                Text("Tax (\(Int(taxRate * 100))%):")
                    .foregroundColor(KMTheme.secondaryText)
                Spacer()
                Text("$\(taxAmount, specifier: "%.2f")")
                    .foregroundColor(KMTheme.primaryText)
                    .fontWeight(.medium)
            }
            
            Divider()
                .background(KMTheme.border)
            
            HStack {
                Text("Total:")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(KMTheme.primaryText)
                Spacer()
                Text("$\(total, specifier: "%.2f")")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(KMTheme.accent)
            }
        }
        .padding()
        .background(KMTheme.cardBackground)
        .cornerRadius(12)
    }
    
    private var paymentInstructionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Payment Instructions")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(KMTheme.primaryText)
            
            TextEditor(text: $paymentInstructions)
                .frame(height: 80)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(KMTheme.cardBackground)
                .foregroundColor(KMTheme.primaryText)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(KMTheme.accent.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes (Optional)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(KMTheme.primaryText)
            
            TextEditor(text: $notes)
                .frame(height: 80)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(KMTheme.cardBackground)
                .foregroundColor(KMTheme.primaryText)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(KMTheme.accent.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    private var receiptPhotosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Receipt Photos")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(KMTheme.primaryText)
            
            if receiptPhotos.isEmpty {
                Button(action: {
                    showingPhotoOptions = true
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "camera.circle")
                            .font(.system(size: 32))
                            .foregroundColor(KMTheme.tertiaryText)
                        Text("No receipt photos added")
                            .font(.system(size: 14))
                            .foregroundColor(KMTheme.tertiaryText)
                        Text("Tap anywhere to attach receipts to this invoice")
                            .font(.system(size: 12))
                            .foregroundColor(KMTheme.tertiaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(KMTheme.cardBackground)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(KMTheme.border.opacity(0.5), lineWidth: 1)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5]))
                    )
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(receiptPhotos.enumerated()), id: \.offset) { index, photo in
                            ZStack(alignment: .topTrailing) {
                                Image(uiImage: photo)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .background(KMTheme.cardBackground)
                                    .cornerRadius(8)
                                    .clipped()
                                
                                Button(action: {
                                    receiptPhotos.remove(at: index)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(.red)
                                        .background(Color.white)
                                        .clipShape(Circle())
                                }
                                .offset(x: 8, y: -8)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
                
                Text("\(receiptPhotos.count) receipt photo\(receiptPhotos.count == 1 ? "" : "s") attached")
                    .font(.system(size: 12))
                    .foregroundColor(KMTheme.secondaryText)
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: generateAndEmailInvoice) {
                if isGenerating {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Label("Generate & Email Invoice", systemImage: "envelope.fill")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(lineItems.isEmpty ? Color.gray : KMTheme.accent)
            .foregroundColor(.white)
            .cornerRadius(12)
            .disabled(lineItems.isEmpty || isGenerating)
            
            Button(action: previewInvoice) {
                Label("Preview Invoice", systemImage: "eye.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(KMTheme.accent)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(KMTheme.cardBackground)
            .cornerRadius(12)
            .disabled(lineItems.isEmpty)
        }
    }
    
    private var addLineItemSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Item Details")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(KMTheme.secondaryText)
                        .padding(.top, 20)
                    
                    VStack(spacing: 16) {
                        TextField("Description", text: $newItemDescription)
                            .padding(12)
                            .background(KMTheme.cardBackground)
                            .foregroundColor(KMTheme.primaryText)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(KMTheme.accent.opacity(0.3), lineWidth: 1)
                            )
                        
                        TextField("Quantity", text: $newItemQuantity)
                            .keyboardType(.decimalPad)
                            .padding(12)
                            .background(KMTheme.cardBackground)
                            .foregroundColor(KMTheme.primaryText)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(KMTheme.accent.opacity(0.3), lineWidth: 1)
                            )
                        
                        TextField("Unit Price", text: $newItemPrice)
                            .keyboardType(.decimalPad)
                            .padding(12)
                            .background(KMTheme.cardBackground)
                            .foregroundColor(KMTheme.primaryText)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(KMTheme.accent.opacity(0.3), lineWidth: 1)
                            )
                    }
                    
                    if let qty = Double(newItemQuantity), let price = Double(newItemPrice) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Total")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(KMTheme.secondaryText)
                            
                            HStack {
                                Text("Line Item Total:")
                                    .foregroundColor(KMTheme.primaryText)
                                Spacer()
                                Text("$\(qty * price, specifier: "%.2f")")
                                    .fontWeight(.bold)
                                    .foregroundColor(KMTheme.accent)
                            }
                            .padding()
                            .background(KMTheme.cardBackground)
                            .cornerRadius(8)
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 16)
            }
            .background(KMTheme.background)
            .navigationTitle("Add Line Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        resetNewItemForm()
                        showingAddLineItem = false
                    }
                    .foregroundColor(KMTheme.secondaryText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addLineItem()
                    }
                    .disabled(newItemDescription.isEmpty || newItemQuantity.isEmpty || newItemPrice.isEmpty)
                    .foregroundColor(newItemDescription.isEmpty || newItemQuantity.isEmpty || newItemPrice.isEmpty ? KMTheme.tertiaryText : KMTheme.accent)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadReceiptsAsLineItems() {
        Task {
            do {
                let receipts = try await FirebaseClient.shared.fetchReceipts(issueId: issue.id)
                
                for receipt in receipts where receipt.status == .approved {
                    let lineItem = InvoiceLineItem(
                        description: "\(receipt.description) - \(receipt.vendor)",
                        quantity: 1.0,
                        unitPrice: receipt.totalAmount,
                        receiptId: receipt.id
                    )
                    lineItems.append(lineItem)
                }
            } catch {
                print("Error loading receipts: \(error)")
            }
        }
    }
    
    private func addLineItem() {
        guard let quantity = Double(newItemQuantity),
              let price = Double(newItemPrice),
              !newItemDescription.isEmpty else {
            return
        }
        
        let item = InvoiceLineItem(
            description: newItemDescription,
            quantity: quantity,
            unitPrice: price
        )
        
        lineItems.append(item)
        resetNewItemForm()
        showingAddLineItem = false
    }
    
    private func deleteLineItem(_ item: InvoiceLineItem) {
        lineItems.removeAll { $0.id == item.id }
    }
    
    private func resetNewItemForm() {
        newItemDescription = ""
        newItemQuantity = "1"
        newItemPrice = ""
    }
    
    private func generateAndEmailInvoice() {
        guard !lineItems.isEmpty else { return }
        
        isGenerating = true
        
        Task {
            do {
                let invoice = createInvoice()
                
                // Generate PDF
                guard let pdfData = InvoicePDFGenerator.generatePDF(for: invoice) else {
                    throw NSError(domain: "InvoiceBuilder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to generate PDF"])
                }
                
                // Save invoice to Firebase
                try await FirebaseClient.shared.createInvoice(invoice)
                
                // Save PDF to Firebase Storage
                let pdfUrl = try await FirebaseClient.shared.uploadInvoicePDF(pdfData, invoiceId: invoice.id)
                
                // Upload receipt photos if any
                var receiptUrls: [String] = []
                if !receiptPhotos.isEmpty {
                    for (index, photo) in receiptPhotos.enumerated() {
                        let receiptUrl = try await uploadReceiptPhoto(photo, invoiceId: invoice.id, index: index)
                        receiptUrls.append(receiptUrl)
                    }
                }
                
                // Update invoice with PDF URL and receipt URLs
                var updatedInvoice = invoice
                updatedInvoice.pdfUrl = pdfUrl
                updatedInvoice.receiptUrls = receiptUrls
                try await FirebaseClient.shared.updateInvoice(updatedInvoice)
                
                // Only post to timeline when invoice is sent, not draft
                if updatedInvoice.status != .draft {
                    await postInvoiceToTimeline(invoice: updatedInvoice)
                }
                
                // Send invoice notification
                await sendInvoiceNotification(invoice: updatedInvoice)
                
                await MainActor.run {
                    generatedPDFData = pdfData
                    generatedInvoice = updatedInvoice
                    isGenerating = false
                    showingEmailSheet = true
                }
            } catch {
                await MainActor.run {
                    isGenerating = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func previewInvoice() {
        let invoice = createInvoice()
        
        if let pdfData = InvoicePDFGenerator.generatePDF(for: invoice) {
            generatedPDFData = pdfData
            showingPDFPreview = true
            print("PDF generated successfully, size: \(pdfData.count) bytes")
        } else {
            errorMessage = "Failed to generate PDF preview"
            showingError = true
        }
    }
    
    private func createInvoice() -> Invoice {
        Invoice(
            invoiceNumber: InvoiceNumberGenerator.generate(),
            issueId: issue.id,
            businessId: business?.id ?? issue.restaurantId,
            businessName: businessName,
            businessAddress: businessAddress.isEmpty ? nil : businessAddress,
            businessEmail: businessEmail.isEmpty ? nil : businessEmail,
            businessPhone: businessPhone.isEmpty ? nil : businessPhone,
            lineItems: lineItems,
            dueDate: dueDate,
            taxRate: taxRate,
            paymentInstructions: paymentInstructions.isEmpty ? nil : paymentInstructions,
            notes: notes.isEmpty ? nil : notes,
            createdBy: appState.currentAppUser?.id ?? ""
        )
    }
    
    private func loadBusinessInfo() {
        print("🏢 [InvoiceBuilder] Loading business info")
        print("🏢 [InvoiceBuilder] Business object: \(String(describing: business))")
        print("🏢 [InvoiceBuilder] Business name: \(business?.name ?? "nil")")
        print("🏢 [InvoiceBuilder] Business address: \(business?.address ?? "nil")")
        print("🏢 [InvoiceBuilder] Business phone: \(business?.phone ?? "nil")")
        
        businessName = business?.name ?? "Unknown Business"
        businessAddress = business?.address ?? ""
        businessPhone = business?.phone ?? ""
        // Business email needs to be entered manually as it's not stored in the Business model
        businessEmail = ""
        
        print("🏢 [InvoiceBuilder] Set businessName to: \(businessName)")
        print("🏢 [InvoiceBuilder] Set businessAddress to: \(businessAddress)")
        print("🏢 [InvoiceBuilder] Set businessPhone to: \(businessPhone)")
    }
    
    // MARK: - Notification Functions
    
    private func sendInvoiceNotification(invoice: Invoice) async {
        await NotificationService.shared.sendInvoiceNotification(
            to: [issue.reporterId],
            invoiceNumber: invoice.invoiceNumber,
            amount: invoice.total,
            restaurantName: business?.name ?? "Unknown Business",
            issueTitle: issue.title,
            invoiceId: invoice.id,
            issueId: invoice.issueId
        )
    }
    
    private func uploadReceiptPhoto(_ image: UIImage, invoiceId: String, index: Int) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "InvoiceBuilder", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to data"])
        }
        
        let fileName = "receipt_\(index).jpg"
        let path = "invoices/\(invoiceId)/receipts/\(fileName)"
        
        let storageRef = Storage.storage().reference().child(path)
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        print("✅ Receipt photo uploaded: \(downloadURL.absoluteString)")
        return downloadURL.absoluteString
    }
    
    private func postInvoiceToTimeline(invoice: Invoice) {
        Task {
            do {
                // Use INVOICE_DATA prefix like we do for quotes so it can be detected and handled specially
                let invoiceData = """
                INVOICE_DATA:{
                  "invoiceId": "\(invoice.id)",
                  "invoiceNumber": "\(invoice.invoiceNumber)",
                  "total": \(invoice.total),
                  "status": "\(invoice.status.rawValue)"
                }
                """
                
                // Create message with PDF attachment only
                try await ThreadService.shared.sendMessage(
                    requestId: issue.id,
                    authorId: appState.currentAppUser?.id ?? "",
                    message: invoiceData,
                    attachmentUrl: invoice.pdfUrl,
                    attachmentThumbUrl: invoice.pdfUrl
                )
                
                print("✅ Invoice posted to timeline with PDF attachment")
                
                // Dismiss back to issue detail
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("❌ Error posting invoice to timeline: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Line Item Row

struct LineItemRow: View {
    let item: InvoiceLineItem
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(KMTheme.primaryText)
                
                Text("\(Int(item.quantity)) × $\(item.unitPrice, specifier: "%.2f")")
                    .font(.system(size: 12))
                    .foregroundColor(KMTheme.secondaryText)
            }
            
            Spacer()
            
            Text("$\(item.total, specifier: "%.2f")")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(KMTheme.primaryText)
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .font(.system(size: 14))
            }
        }
        .padding()
        .background(KMTheme.cardBackground)
        .cornerRadius(8)
    }
}
