import SwiftUI
import UIKit

struct AIAnalysisDebugView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var analysisSteps: [AnalysisStep] = []
    @State private var isAnalyzing = false
    @State private var finalResult: ImageAnalysisResult?
    @State private var finalError: Error?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    imageSection
                    stepsSection
                    
                    if let result = finalResult {
                        resultSection(result)
                    } else if let error = finalError {
                        errorSection(error)
                    }
                    
                    actionButtons
                }
                .padding()
            }
            .background(KMTheme.background)
            .navigationTitle("AI Analysis Debug")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(KMTheme.accent)
                }
            }
        }
        .task {
            await performDebugAnalysis()
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Analysis Debugging")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(KMTheme.primaryText)
            
            Text("This shows the step-by-step process of AI analysis to help diagnose issues.")
                .font(.body)
                .foregroundColor(KMTheme.secondaryText)
        }
    }
    
    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Image Being Analyzed")
                .font(.headline)
                .foregroundColor(KMTheme.primaryText)
            
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 200)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(KMTheme.cardBackground, lineWidth: 1)
                )
            
            HStack {
                Text("Size: \(Int(image.size.width)) × \(Int(image.size.height))")
                Spacer()
                if let jpegData = image.jpegData(compressionQuality: 0.8) {
                    Text("File Size: \(ByteCountFormatter.string(fromByteCount: Int64(jpegData.count), countStyle: .file))")
                }
            }
            .font(.caption)
            .foregroundColor(KMTheme.secondaryText)
        }
    }
    
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Analysis Steps")
                .font(.headline)
                .foregroundColor(KMTheme.primaryText)
            
            ForEach(analysisSteps.indices, id: \.self) { index in
                AnalysisStepView(step: analysisSteps[index], stepNumber: index + 1)
            }
            
            if isAnalyzing && analysisSteps.isEmpty {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: KMTheme.accent))
                        .scaleEffect(0.8)
                    
                    Text("Starting analysis...")
                        .font(.body)
                        .foregroundColor(KMTheme.secondaryText)
                }
                .padding()
            }
        }
    }
    
    private func resultSection(_ result: ImageAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analysis Result")
                .font(.headline)
                .foregroundColor(KMTheme.primaryText)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("✅ Analysis Successful")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
                
                Text("Description: \(result.description)")
                    .font(.body)
                    .foregroundColor(KMTheme.primaryText)
                
                Text("Category: \(result.category)")
                    .font(.body)
                    .foregroundColor(KMTheme.secondaryText)
                
                Text("Priority: \(result.priority)")
                    .font(.body)
                    .foregroundColor(KMTheme.secondaryText)
                
                if let confidence = result.confidence {
                    Text("Confidence: \(Int(confidence * 100))%")
                        .font(.body)
                        .foregroundColor(KMTheme.secondaryText)
                }
            }
            .padding()
            .background(KMTheme.cardBackground)
            .cornerRadius(12)
        }
    }
    
    private func errorSection(_ error: Error) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analysis Error")
                .font(.headline)
                .foregroundColor(KMTheme.primaryText)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("❌ Analysis Failed")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(KMTheme.danger)
                
                Text("Error: \(error.localizedDescription)")
                    .font(.body)
                    .foregroundColor(KMTheme.primaryText)
                
                if let aiError = error as? AIError {
                    Text("Error Type: \(aiError.errorDescription ?? "Unknown")")
                        .font(.body)
                        .foregroundColor(KMTheme.secondaryText)
                }
            }
            .padding()
            .background(KMTheme.cardBackground)
            .cornerRadius(12)
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: retryAnalysis) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Retry Analysis")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(KMTheme.accent)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(isAnalyzing)
            
            Button(action: reportIssue) {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text("Report This Issue")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(KMTheme.cardBackground)
                .foregroundColor(KMTheme.primaryText)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(KMTheme.accent, lineWidth: 1)
                )
            }
        }
    }
    
    private func performDebugAnalysis() async {
        isAnalyzing = true
        analysisSteps = []
        finalResult = nil
        finalError = nil
        
        await addStep("Validating API Configuration", status: .inProgress)
        
        // Check API configuration
        if !APIKeys.isOpenAIConfigured {
            await addStep("Validating API Configuration", status: .failed, details: "OpenAI API key not configured")
            finalError = AIError.apiRequestFailed
            isAnalyzing = false
            return
        }
        
        await addStep("Validating API Configuration", status: .completed, details: "API key configured")
        
        await addStep("Processing Image", status: .inProgress)
        
        // Convert image to JPEG
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            await addStep("Processing Image", status: .failed, details: "Failed to convert image to JPEG")
            finalError = AIError.imageProcessingFailed
            isAnalyzing = false
            return
        }
        
        await addStep("Processing Image", status: .completed, details: "Image converted to JPEG (\(ByteCountFormatter.string(fromByteCount: Int64(imageData.count), countStyle: .file)))")
        
        await addStep("Encoding Image", status: .inProgress)
        
        let base64Image = imageData.base64EncodedString()
        await addStep("Encoding Image", status: .completed, details: "Image encoded to base64 (\(base64Image.count) characters)")
        
        await addStep("Sending API Request", status: .inProgress)
        
        do {
            let result = try await OpenAIService.shared.analyzeMaintenanceImage(image, userId: appState.currentAppUser?.id)
            await addStep("Sending API Request", status: .completed, details: "Received successful response from OpenAI")
            
            await addStep("Parsing Response", status: .completed, details: "Successfully parsed AI analysis")
            
            finalResult = result
        } catch {
            await addStep("Sending API Request", status: .failed, details: "API request failed: \(error.localizedDescription)")
            finalError = error
        }
        
        isAnalyzing = false
    }
    
    private func addStep(_ title: String, status: AnalysisStepStatus, details: String? = nil) async {
        await MainActor.run {
            if let index = analysisSteps.firstIndex(where: { $0.title == title }) {
                analysisSteps[index] = AnalysisStep(title: title, status: status, details: details, timestamp: Date())
            } else {
                analysisSteps.append(AnalysisStep(title: title, status: status, details: details, timestamp: Date()))
            }
        }
        
        // Add small delay for better UX
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
    
    private func retryAnalysis() {
        Task {
            await performDebugAnalysis()
        }
    }
    
    private func reportIssue() {
        // Create detailed error report
        var additionalData: [String: Any] = [
            "analysis_steps": analysisSteps.map { step in
                [
                    "title": step.title,
                    "status": step.status.rawValue,
                    "details": step.details ?? "",
                    "timestamp": step.timestamp.timeIntervalSince1970
                ]
            },
            "image_size_width": image.size.width,
            "image_size_height": image.size.height
        ]
        
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            additionalData["image_size_bytes"] = imageData.count
        }
        
        if let error = finalError {
            ErrorReportingService.shared.reportAIAnalysisFailure(
                error: error,
                imageSize: image.size,
                imageSizeBytes: image.jpegData(compressionQuality: 0.8)?.count,
                userFeedback: "User reported AI analysis issue via debug view",
                userId: appState.currentAppUser?.id
            )
        }
        
        dismiss()
    }
}

struct AnalysisStepView: View {
    let step: AnalysisStep
    let stepNumber: Int
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step number and status icon
            ZStack {
                Circle()
                    .fill(step.status.color)
                    .frame(width: 24, height: 24)
                
                if step.status == .inProgress {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.6)
                } else {
                    Image(systemName: step.status.icon)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            
            // Step content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(step.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(KMTheme.primaryText)
                    
                    Spacer()
                    
                    Text(DateFormatter.stepFormatter.string(from: step.timestamp))
                        .font(.caption)
                        .foregroundColor(KMTheme.tertiaryText)
                }
                
                if let details = step.details {
                    Text(details)
                        .font(.caption)
                        .foregroundColor(KMTheme.secondaryText)
                }
            }
        }
        .padding()
        .background(KMTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Models

struct AnalysisStep {
    let title: String
    let status: AnalysisStepStatus
    let details: String?
    let timestamp: Date
}

enum AnalysisStepStatus: String, CaseIterable {
    case pending = "pending"
    case inProgress = "in_progress"
    case completed = "completed"
    case failed = "failed"
    
    var color: Color {
        switch self {
        case .pending: return KMTheme.tertiaryText
        case .inProgress: return KMTheme.accent
        case .completed: return .green
        case .failed: return KMTheme.danger
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .inProgress: return "clock"
        case .completed: return "checkmark"
        case .failed: return "xmark"
        }
    }
}

extension DateFormatter {
    static let stepFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

#Preview {
    AIAnalysisDebugView(image: UIImage(systemName: "photo")!)
}
