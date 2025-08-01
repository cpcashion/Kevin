import SwiftUI
import FirebaseFirestore

struct BugReportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var issueDescription = ""
    @State private var stepsToReproduce = ""
    @State private var expectedBehavior = ""
    @State private var actualBehavior = ""
    @State private var selectedCategory: BugCategory = .general
    @State private var isSubmitting = false
    @State private var showingSuccess = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    categorySection
                    descriptionSection
                    stepsSection
                    behaviorSection
                    submitButton
                }
                .padding()
            }
            .background(KMTheme.background)
            .navigationTitle("Report Bug")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(KMTheme.accent)
                }
            }
        }
        .alert("Bug Report Sent", isPresented: $showingSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Thank you for helping us improve Kevin Maint! We'll investigate this issue.")
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Help Us Fix This Issue")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(KMTheme.primaryText)
            
            Text("Your feedback helps us identify and fix problems quickly. Please provide as much detail as possible.")
                .font(.body)
                .foregroundColor(KMTheme.secondaryText)
        }
    }
    
    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Issue Category")
                .font(.headline)
                .foregroundColor(KMTheme.primaryText)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(BugCategory.allCases, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        HStack {
                            Text(category.emoji)
                            Text(category.title)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            selectedCategory == category ? KMTheme.accent : KMTheme.cardBackground
                        )
                        .foregroundColor(
                            selectedCategory == category ? .white : KMTheme.primaryText
                        )
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What happened?")
                .font(.headline)
                .foregroundColor(KMTheme.primaryText)
            
            TextEditor(text: $issueDescription)
                .foregroundColor(KMTheme.primaryText)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(12)
                .background(KMTheme.cardBackground)
                .cornerRadius(8)
                .frame(minHeight: 100)
                .overlay(
                    Group {
                        if issueDescription.isEmpty {
                            HStack {
                                VStack {
                                    Text("Describe the issue you encountered...")
                                        .foregroundColor(KMTheme.tertiaryText)
                                        .padding(.leading, 16)
                                        .padding(.top, 20)
                                    Spacer()
                                }
                                Spacer()
                            }
                        }
                    }
                )
        }
    }
    
    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Steps to Reproduce")
                .font(.headline)
                .foregroundColor(KMTheme.primaryText)
            
            Text("Help us recreate the issue")
                .font(.caption)
                .foregroundColor(KMTheme.secondaryText)
            
            TextEditor(text: $stepsToReproduce)
                .foregroundColor(KMTheme.primaryText)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .padding(12)
                .background(KMTheme.cardBackground)
                .cornerRadius(8)
                .frame(minHeight: 80)
                .overlay(
                    Group {
                        if stepsToReproduce.isEmpty {
                            HStack {
                                VStack {
                                    Text("1. I opened the app\n2. I tapped on...\n3. Then I...")
                                        .foregroundColor(KMTheme.tertiaryText)
                                        .padding(.leading, 16)
                                        .padding(.top, 20)
                                    Spacer()
                                }
                                Spacer()
                            }
                        }
                    }
                )
        }
    }
    
    private var behaviorSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Expected Behavior")
                    .font(.headline)
                    .foregroundColor(KMTheme.primaryText)
                
                TextEditor(text: $expectedBehavior)
                    .foregroundColor(KMTheme.primaryText)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(12)
                    .background(KMTheme.cardBackground)
                    .cornerRadius(8)
                    .frame(minHeight: 60)
                    .overlay(
                        Group {
                            if expectedBehavior.isEmpty {
                                HStack {
                                    VStack {
                                        Text("What should have happened?")
                                            .foregroundColor(KMTheme.tertiaryText)
                                            .padding(.leading, 16)
                                            .padding(.top, 20)
                                        Spacer()
                                    }
                                    Spacer()
                                }
                            }
                        }
                    )
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Actual Behavior")
                    .font(.headline)
                    .foregroundColor(KMTheme.primaryText)
                
                TextEditor(text: $actualBehavior)
                    .foregroundColor(KMTheme.primaryText)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(12)
                    .background(KMTheme.cardBackground)
                    .cornerRadius(8)
                    .frame(minHeight: 60)
                    .overlay(
                        Group {
                            if actualBehavior.isEmpty {
                                HStack {
                                    VStack {
                                        Text("What actually happened instead?")
                                            .foregroundColor(KMTheme.tertiaryText)
                                            .padding(.leading, 16)
                                            .padding(.top, 20)
                                        Spacer()
                                    }
                                    Spacer()
                                }
                            }
                        }
                    )
            }
        }
    }
    
    private var submitButton: some View {
        Button(action: submitBugReport) {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                
                Text(isSubmitting ? "Sending..." : "Send Bug Report")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                canSubmit ? KMTheme.accent : KMTheme.tertiaryText
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!canSubmit || isSubmitting)
    }
    
    private var canSubmit: Bool {
        !issueDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func submitBugReport() {
        guard canSubmit else { return }
        
        isSubmitting = true
        
        let bugReport = BugReport(
            category: selectedCategory,
            issueDescription: issueDescription,
            stepsToReproduce: stepsToReproduce,
            expectedBehavior: expectedBehavior,
            actualBehavior: actualBehavior,
            userId: appState.currentAppUser?.id
        )
        
        Task {
            await BugReportService.shared.submitBugReport(bugReport)
            
            await MainActor.run {
                isSubmitting = false
                showingSuccess = true
            }
        }
    }
}

// MARK: - Models

enum BugCategory: String, CaseIterable {
    case aiAnalysis = "ai_analysis"
    case camera = "camera"
    case location = "location"
    case authentication = "authentication"
    case ui = "ui"
    case performance = "performance"
    case crash = "crash"
    case general = "general"
    
    var title: String {
        switch self {
        case .aiAnalysis: return "AI Analysis"
        case .camera: return "Camera"
        case .location: return "Location"
        case .authentication: return "Sign In"
        case .ui: return "Interface"
        case .performance: return "Performance"
        case .crash: return "App Crash"
        case .general: return "Other"
        }
    }
    
    var emoji: String {
        switch self {
        case .aiAnalysis: return "🤖"
        case .camera: return "📷"
        case .location: return "📍"
        case .authentication: return "🔐"
        case .ui: return "🎨"
        case .performance: return "⚡"
        case .crash: return "💥"
        case .general: return "🐛"
        }
    }
}

struct BugReport {
    let id: String
    let timestamp: Date
    let category: BugCategory
    let issueDescription: String
    let stepsToReproduce: String
    let expectedBehavior: String
    let actualBehavior: String
    let userId: String?
    let deviceInfo: DeviceInfo
    let appInfo: AppInfo
    
    init(
        category: BugCategory,
        issueDescription: String,
        stepsToReproduce: String,
        expectedBehavior: String,
        actualBehavior: String,
        userId: String?
    ) {
        self.id = UUID().uuidString
        self.timestamp = Date()
        self.category = category
        self.issueDescription = issueDescription
        self.stepsToReproduce = stepsToReproduce
        self.expectedBehavior = expectedBehavior
        self.actualBehavior = actualBehavior
        self.userId = userId
        self.deviceInfo = DeviceInfo()
        self.appInfo = AppInfo()
    }
    
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "timestamp": Timestamp(date: timestamp),
            "category": category.rawValue,
            "issue_description": issueDescription,
            "steps_to_reproduce": stepsToReproduce,
            "expected_behavior": expectedBehavior,
            "actual_behavior": actualBehavior,
            "user_id": userId ?? "anonymous",
            "device_info": deviceInfo.toDictionary(),
            "app_info": appInfo.toDictionary()
        ]
    }
}

// MARK: - Service

class BugReportService {
    static let shared = BugReportService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    func submitBugReport(_ report: BugReport) async {
        do {
            let data = report.toDictionary()
            try await db.collection("bug_reports").document(report.id).setData(data)
            
            // Also log to remote logging
            RemoteLoggingService.shared.logEvent(
                "Bug Report Submitted",
                level: .info,
                category: .general,
                details: [
                    "category": report.category.rawValue,
                    "description_length": report.issueDescription.count
                ],
                userId: report.userId
            )
            
            print("✅ Bug report submitted successfully")
        } catch {
            print("❌ Failed to submit bug report: \(error)")
            
            ErrorReportingService.shared.reportError(
                error,
                context: "Bug Report Submission",
                userId: report.userId
            )
        }
    }
}

#Preview {
    BugReportView()
}
