import SwiftUI

struct QuoteAssistantView: View {
    let issue: Issue
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var quoteEstimate: QuoteEstimate
    @State private var isGeneratingAIQuote = false
    @State private var showingConfirmSend = false
    @State private var isSaving = false
    @State private var notes = ""
    @State private var validityDays = 30
    @State private var showingAddMaterial = false
    @State private var showingAddFee = false
    
    // Editing states
    @State private var editingLaborHours: String
    @State private var editingLaborRate: String
    
    init(issue: Issue) {
        self.issue = issue
        
        // Initialize with AI estimate if available, otherwise create empty structure
        let initialBreakdown = CostBreakdown(
            laborHours: 2.0,
            laborRate: 85.0,
            materials: [],
            additionalFees: []
        )
        
        let initialQuote = QuoteEstimate(
            issueId: issue.id,
            restaurantId: issue.restaurantId,
            aiAnalysisId: issue.aiAnalysis?.summary,
            costBreakdown: initialBreakdown,
            aiConfidence: issue.aiAnalysis?.confidence,
            createdBy: "" // Will be set when saving
        )
        
        self._quoteEstimate = State(initialValue: initialQuote)
        self._editingLaborHours = State(initialValue: "2.0")
        self._editingLaborRate = State(initialValue: "85.0")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                KMTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Issue Context Header
                        issueContextHeader
                        
                        // AI Analysis Summary (if available)
                        if let aiAnalysis = issue.aiAnalysis {
                            aiAnalysisSummary(aiAnalysis)
                        }
                        
                        // Cost Breakdown Section
                        costBreakdownSection
                        
                        // Quote Summary
                        quoteSummarySection
                        
                        // Notes Section
                        notesSection
                        
                        // Action Buttons
                        actionButtons
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Generate Quote")
            .navigationBarTitleDisplayMode(.inline)
            .kevinNavigationBarStyle()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(KMTheme.primaryText)
                }
                
            }
        }
        .sheet(isPresented: $showingAddMaterial) {
            AddMaterialView { material in
                quoteEstimate.costBreakdown.materials.append(material)
            }
        }
        .sheet(isPresented: $showingAddFee) {
            AddFeeView { fee in
                quoteEstimate.costBreakdown.additionalFees.append(fee)
            }
        }
        .alert("Submit Quote", isPresented: $showingConfirmSend) {
            Button("Cancel", role: .cancel) { }
            Button("Submit") {
                submitQuote()
            }
        } message: {
            Text("This will add the quote of $\(String(format: "%.2f", quoteEstimate.totalEstimate)) to the issue timeline.")
        }
        .onAppear {
            generateInitialAIQuote()
        }
    }
    
    private var issueContextHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundColor(KMTheme.accent)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(issue.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(KMTheme.primaryText)
                    
                    if let description = issue.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(KMTheme.secondaryText)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                StatusPill(status: issue.status)
            }
        }
        .padding(16)
        .background(KMTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KMTheme.border, lineWidth: 0.5)
        )
    }
    
    private func aiAnalysisSummary(_ analysis: AIAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(KMTheme.aiGreen)
                    .font(.title3)
                
                Text("AI Analysis")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(KMTheme.aiGreen)
                
                Spacer()
                
                if let confidence = analysis.confidence {
                    HStack(spacing: 4) {
                        Text("\(Int(confidence * 100))%")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(KMTheme.aiGreen)
                        
                        Text("confidence")
                            .font(.caption)
                            .foregroundColor(KMTheme.secondaryText)
                    }
                }
            }
            
            Text(analysis.description)
                .font(.body)
                .foregroundColor(KMTheme.primaryText)
            
            if let estimatedCost = analysis.estimatedCost {
                HStack {
                    Text("AI Estimated Cost:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(KMTheme.secondaryText)
                    
                    Spacer()
                    
                    Text("$\(String(format: "%.2f", estimatedCost))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(KMTheme.aiGreen)
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(KMTheme.aiGreen.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KMTheme.aiGreen.opacity(0.3), lineWidth: 0.5)
        )
    }
    
    private var costBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cost Breakdown")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(KMTheme.primaryText)
            
            // Labor Section
            laborSection
            
            // Materials Section
            materialsSection
            
            // Additional Fees Section
            additionalFeesSection
        }
        .padding(16)
        .background(KMTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KMTheme.border, lineWidth: 0.5)
        )
    }
    
    private var laborSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Labor")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(KMTheme.primaryText)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hours")
                        .font(.caption)
                        .foregroundColor(KMTheme.secondaryText)
                    
                    TextField("Hours", text: $editingLaborHours)
                        .keyboardType(.decimalPad)
                        .foregroundColor(KMTheme.inputText)
                        .padding(12)
                        .background(KMTheme.inputBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(KMTheme.inputBorder, lineWidth: 1)
                        )
                        .onChange(of: editingLaborHours) { _, newValue in
                            if let hours = Double(newValue) {
                                quoteEstimate.costBreakdown.laborHours = hours
                            }
                        }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rate/Hour")
                        .font(.caption)
                        .foregroundColor(KMTheme.secondaryText)
                    
                    TextField("Rate", text: $editingLaborRate)
                        .keyboardType(.decimalPad)
                        .foregroundColor(KMTheme.inputText)
                        .padding(12)
                        .background(KMTheme.inputBackground)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(KMTheme.inputBorder, lineWidth: 1)
                        )
                        .onChange(of: editingLaborRate) { _, newValue in
                            if let rate = Double(newValue) {
                                quoteEstimate.costBreakdown.laborRate = rate
                            }
                        }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(KMTheme.secondaryText)
                    
                    Text("$\(String(format: "%.2f", quoteEstimate.costBreakdown.totalLabor))")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(KMTheme.primaryText)
                        .frame(minWidth: 80, alignment: .trailing)
                }
            }
        }
    }
    
    private var materialsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Materials")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(KMTheme.primaryText)
                
                Spacer()
                
                Button("Add Material") {
                    showingAddMaterial = true
                }
                .font(.caption)
                .foregroundColor(KMTheme.accent)
            }
            
            if quoteEstimate.costBreakdown.materials.isEmpty {
                Text("No materials added")
                    .font(.caption)
                    .foregroundColor(KMTheme.tertiaryText)
                    .italic()
            } else {
                ForEach(quoteEstimate.costBreakdown.materials, id: \.id) { material in
                    materialRow(material)
                }
            }
            
            HStack {
                Text("Materials Total")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(KMTheme.secondaryText)
                
                Spacer()
                
                Text("$\(String(format: "%.2f", quoteEstimate.costBreakdown.totalMaterials))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(KMTheme.primaryText)
            }
        }
    }
    
    private func materialRow(_ material: MaterialCost) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(material.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(KMTheme.primaryText)
                
                Text("\(String(format: "%.1f", material.quantity)) \(material.unit) × $\(String(format: "%.2f", material.unitPrice))")
                    .font(.caption2)
                    .foregroundColor(KMTheme.secondaryText)
            }
            
            Spacer()
            
            Text("$\(String(format: "%.2f", material.totalCost))")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(KMTheme.primaryText)
            
            Button(action: {
                quoteEstimate.costBreakdown.materials.removeAll { $0.id == material.id }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(KMTheme.danger.opacity(0.7))
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var additionalFeesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Additional Fees")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(KMTheme.primaryText)
                
                Spacer()
                
                Button("Add Fee") {
                    showingAddFee = true
                }
                .font(.caption)
                .foregroundColor(KMTheme.accent)
            }
            
            if quoteEstimate.costBreakdown.additionalFees.isEmpty {
                Text("No additional fees")
                    .font(.caption)
                    .foregroundColor(KMTheme.tertiaryText)
                    .italic()
            } else {
                ForEach(quoteEstimate.costBreakdown.additionalFees, id: \.id) { fee in
                    feeRow(fee)
                }
            }
            
            HStack {
                Text("Fees Total")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(KMTheme.secondaryText)
                
                Spacer()
                
                Text("$\(String(format: "%.2f", quoteEstimate.costBreakdown.totalAdditionalFees))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(KMTheme.primaryText)
            }
        }
    }
    
    private func feeRow(_ fee: AdditionalFee) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(fee.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(KMTheme.primaryText)
                
                if let description = fee.description {
                    Text(description)
                        .font(.caption2)
                        .foregroundColor(KMTheme.secondaryText)
                }
            }
            
            Spacer()
            
            Text("$\(String(format: "%.2f", fee.amount))")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(KMTheme.primaryText)
            
            Button(action: {
                quoteEstimate.costBreakdown.additionalFees.removeAll { $0.id == fee.id }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(KMTheme.danger.opacity(0.7))
                    .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var quoteSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quote Summary")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(KMTheme.primaryText)
            
            VStack(spacing: 8) {
                summaryRow("Labor", amount: quoteEstimate.costBreakdown.totalLabor)
                summaryRow("Materials", amount: quoteEstimate.costBreakdown.totalMaterials)
                summaryRow("Additional Fees", amount: quoteEstimate.costBreakdown.totalAdditionalFees)
                
                Divider()
                    .background(KMTheme.border)
                
                HStack {
                    Text("Total Estimate")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(KMTheme.primaryText)
                    
                    Spacer()
                    
                    Text("$\(String(format: "%.2f", quoteEstimate.totalEstimate))")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(KMTheme.accent)
                }
            }
        }
        .padding(16)
        .background(KMTheme.accent.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KMTheme.accent.opacity(0.3), lineWidth: 0.5)
        )
    }
    
    private func summaryRow(_ label: String, amount: Double) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(KMTheme.secondaryText)
            
            Spacer()
            
            Text("$\(String(format: "%.2f", amount))")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(KMTheme.primaryText)
        }
    }
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes (Optional)")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(KMTheme.primaryText)
            
            TextEditor(text: $notes)
                .foregroundColor(KMTheme.primaryText)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(12)
                .background(KMTheme.background)
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(KMTheme.border, lineWidth: 0.5)
                )
                .frame(minHeight: 80)
            
            if notes.isEmpty {
                Text("Add any additional notes or terms for the customer...")
                    .font(.caption)
                    .foregroundColor(KMTheme.tertiaryText)
                    .italic()
                    .padding(.horizontal, 12)
                    .offset(y: -70)
                    .allowsHitTesting(false)
            }
        }
        .padding(16)
        .background(KMTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KMTheme.border, lineWidth: 0.5)
        )
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button("Submit Quote") {
                showingConfirmSend = true
            }
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(KMTheme.accent)
            .cornerRadius(12)
            .disabled(isSaving)
            
            Button("Save as Draft") {
                saveDraft()
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(KMTheme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(KMTheme.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(KMTheme.border, lineWidth: 0.5)
            )
            .disabled(isSaving)
        }
    }
    
    // MARK: - Actions
    
    private func generateInitialAIQuote() {
        guard let aiAnalysis = issue.aiAnalysis,
              let estimatedCost = aiAnalysis.estimatedCost else { return }
        
        // Use AI analysis to populate initial quote
        let materials = aiAnalysis.materialsNeeded?.map { materialName in
            MaterialCost(
                name: materialName,
                quantity: 1.0,
                unitPrice: estimatedCost * 0.3 / Double(aiAnalysis.materialsNeeded?.count ?? 1),
                unit: "each"
            )
        } ?? []
        
        quoteEstimate.costBreakdown.materials = materials
        
        // Adjust labor based on AI estimate
        let laborCost = estimatedCost * 0.7 // 70% labor, 30% materials
        quoteEstimate.costBreakdown.laborHours = laborCost / quoteEstimate.costBreakdown.laborRate
        editingLaborHours = String(format: "%.1f", quoteEstimate.costBreakdown.laborHours)
    }
    
    private func generateAIQuote() {
        isGeneratingAIQuote = true
        
        // Simulate AI quote generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            // This would call your AI service to generate detailed cost breakdown
            generateInitialAIQuote()
            isGeneratingAIQuote = false
        }
    }
    
    private func saveDraft() {
        isSaving = true
        
        Task {
            do {
                quoteEstimate.status = .manual_review
                quoteEstimate.notes = notes.isEmpty ? nil : notes
                quoteEstimate.createdBy = appState.currentAppUser?.id ?? ""
                quoteEstimate.validUntil = Calendar.current.date(byAdding: .day, value: validityDays, to: Date())
                
                // Save to Firebase
                try await appState.firebaseClient.saveQuoteEstimate(quoteEstimate)
                
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    // Handle error
                }
            }
        }
    }
    
    private func submitQuote() {
        isSaving = true
        
        Task {
            do {
                quoteEstimate.status = .manual_review
                quoteEstimate.notes = notes.isEmpty ? nil : notes
                quoteEstimate.createdBy = appState.currentAppUser?.id ?? ""
                quoteEstimate.validUntil = Calendar.current.date(byAdding: .day, value: validityDays, to: Date())
                
                // Save quote and create work log entry
                try await appState.firebaseClient.saveQuoteEstimate(quoteEstimate)
                
                // Send quote notification
                await sendQuoteNotification(quote: quoteEstimate)
                
                // Create work log entry for quote submission
                let workLog = WorkLog(
                    id: UUID().uuidString,
                    issueId: issue.id,
                    authorId: appState.currentAppUser?.id ?? "",
                    message: "Quote submitted: $\(String(format: "%.2f", quoteEstimate.totalEstimate)) - Labor: $\(String(format: "%.2f", quoteEstimate.costBreakdown.totalLabor)), Materials: $\(String(format: "%.2f", quoteEstimate.costBreakdown.totalMaterials))",
                    createdAt: Date()
                )
                
                try await appState.firebaseClient.createWorkLog(workLog)
                
                await MainActor.run {
                    isSaving = false
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    // Handle error
                }
            }
        }
    }
    
    // MARK: - Notification Functions
    
    private func sendQuoteNotification(quote: QuoteEstimate) async {
        // Send to issue reporter
        let formattedAmount = String(format: "$%.2f", quote.totalEstimate)
        
        await NotificationService.shared.sendQuoteNotification(
            to: [issue.reporterId],
            quoteAmount: formattedAmount,
            issueTitle: issue.title,
            restaurantName: issue.restaurantId, // TODO: Resolve to actual name
            quoteId: quote.id,
            issueId: issue.id
        )
    }
}

// MARK: - Supporting Views

struct AddMaterialView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (MaterialCost) -> Void
    
    @State private var name = ""
    @State private var quantity = "1.0"
    @State private var unitPrice = ""
    @State private var unit = "each"
    
    private let units = ["each", "sq ft", "linear ft", "gallon", "lb", "hour"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                KMTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Material Details")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(KMTheme.primaryText)
                            
                            VStack(spacing: 16) {
                                // Material Name
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Material Name")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(KMTheme.primaryText)
                                    
                                    TextField("Enter material name", text: $name)
                                        .foregroundColor(KMTheme.inputText)
                                        .padding(12)
                                        .background(KMTheme.inputBackground)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(KMTheme.inputBorder, lineWidth: 1)
                                        )
                                }
                                
                                // Quantity and Unit
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Quantity")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(KMTheme.primaryText)
                                        
                                        TextField("1.0", text: $quantity)
                                            .keyboardType(.decimalPad)
                                            .foregroundColor(KMTheme.inputText)
                                            .padding(12)
                                            .background(KMTheme.inputBackground)
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(KMTheme.inputBorder, lineWidth: 1)
                                            )
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Unit")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(KMTheme.primaryText)
                                        
                                        Menu {
                                            ForEach(units, id: \.self) { unitOption in
                                                Button(unitOption) {
                                                    unit = unitOption
                                                }
                                            }
                                        } label: {
                                            HStack {
                                                Text(unit)
                                                    .foregroundColor(KMTheme.inputText)
                                                Spacer()
                                                Image(systemName: "chevron.down")
                                                    .foregroundColor(KMTheme.secondaryText)
                                                    .font(.caption)
                                            }
                                            .padding(12)
                                            .background(KMTheme.inputBackground)
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(KMTheme.inputBorder, lineWidth: 1)
                                            )
                                        }
                                    }
                                }
                                
                                // Unit Price
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Unit Price")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(KMTheme.primaryText)
                                    
                                    TextField("Enter price per unit", text: $unitPrice)
                                        .keyboardType(.decimalPad)
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
                        }
                        .padding(20)
                        .background(KMTheme.cardBackground)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(KMTheme.border, lineWidth: 0.5)
                        )
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Add Material")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(KMTheme.cardBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(KMTheme.primaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        if let qty = Double(quantity),
                           let price = Double(unitPrice),
                           !name.isEmpty {
                            let material = MaterialCost(
                                name: name,
                                quantity: qty,
                                unitPrice: price,
                                unit: unit
                            )
                            onAdd(material)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || quantity.isEmpty || unitPrice.isEmpty)
                    .foregroundColor(KMTheme.primaryText)
                }
            }
        }
    }
}

struct AddFeeView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (AdditionalFee) -> Void
    
    @State private var name = ""
    @State private var amount = ""
    @State private var description = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                KMTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Fee Details")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(KMTheme.primaryText)
                            
                            VStack(spacing: 16) {
                                // Fee Name
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Fee Name")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(KMTheme.primaryText)
                                    
                                    TextField("Enter fee name", text: $name)
                                        .foregroundColor(KMTheme.inputText)
                                        .padding(12)
                                        .background(KMTheme.inputBackground)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(KMTheme.inputBorder, lineWidth: 1)
                                        )
                                }
                                
                                // Amount
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Amount")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(KMTheme.primaryText)
                                    
                                    TextField("Enter amount", text: $amount)
                                        .keyboardType(.decimalPad)
                                        .foregroundColor(KMTheme.inputText)
                                        .padding(12)
                                        .background(KMTheme.inputBackground)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(KMTheme.inputBorder, lineWidth: 1)
                                        )
                                }
                                
                                // Description
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Description (Optional)")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(KMTheme.primaryText)
                                    
                                    TextField("Enter description", text: $description)
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
                        }
                        .padding(20)
                        .background(KMTheme.cardBackground)
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(KMTheme.border, lineWidth: 0.5)
                        )
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Add Fee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(KMTheme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(KMTheme.primaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        if let amt = Double(amount), !name.isEmpty {
                            let fee = AdditionalFee(
                                name: name,
                                amount: amt,
                                description: description.isEmpty ? nil : description
                            )
                            onAdd(fee)
                            dismiss()
                        }
                    }
                    .disabled(name.isEmpty || amount.isEmpty)
                    .foregroundColor(KMTheme.primaryText)
                }
            }
        }
    }
}
