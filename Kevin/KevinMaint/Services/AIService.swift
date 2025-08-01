import Foundation
import Speech
import AVFoundation
import UIKit

// Using AIAnalysis from Entities.swift instead of separate ImageAnalysisResult
// This alias maintains backward compatibility
typealias ImageAnalysisResult = AIAnalysis

final class AIService: ObservableObject {
    static let shared = AIService()
    
    @Published var isTranscribing = false
    @Published var transcriptionText = ""
    @Published var aiAnalysis = ""
    @Published var confidenceScore: Double = 0.0
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?
    
    private init() {
        // Lazy initialization - don't create heavy objects until needed
    }
    
    private func initializeSpeechComponents() {
        guard speechRecognizer == nil else { return }
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        audioEngine = AVAudioEngine()
    }
    
    // MARK: - Voice Transcription
    
    func requestSpeechAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
    
    func startTranscription() async throws {
        initializeSpeechComponents()
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw AIError.speechRecognitionUnavailable
        }
        
        guard let audioEngine = audioEngine else {
            throw AIError.unableToCreateRequest
        }
        
        // Cancel any previous task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw AIError.unableToCreateRequest
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        await MainActor.run {
            isTranscribing = true
            transcriptionText = ""
        }
        
        // Start recognition
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                if let result = result {
                    self?.transcriptionText = result.bestTranscription.formattedString
                    
                    if result.isFinal {
                        self?.stopTranscription()
                        await self?.analyzeTranscription(result.bestTranscription.formattedString)
                    }
                }
                
                if error != nil {
                    self?.stopTranscription()
                }
            }
        }
    }
    
    func stopTranscription() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        Task { @MainActor in
            isTranscribing = false
        }
    }
    
    // MARK: - AI Analysis
    
    private func analyzeTranscription(_ text: String) async {
        // Simulate AI analysis with realistic delay
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        await MainActor.run {
            let analysis = generateAnalysis(for: text)
            self.aiAnalysis = analysis.text
            self.confidenceScore = analysis.confidence
        }
    }
    
    func analyzeImage(_ image: UIImage, userId: String? = nil, appState: AppState? = nil) async throws -> ImageAnalysisResult {
        print("🔍 Starting AI image analysis...")
        
        // Check if OpenAI is configured
        guard APIKeys.isOpenAIConfigured else {
            print("❌ OpenAI API key not configured")
            throw AIError.apiRequestFailed
        }
        
        print("🔍 [AIService] Using OpenAI Vision API for analysis")
        
        // Use the OpenAI service to analyze the image
        return try await OpenAIService.shared.analyzeMaintenanceImage(image, userId: userId)
    }
    
    
    func generateIssueSummary(title: String, transcription: String, voiceNotes: String = "", imageAnalysis: ImageAnalysisResult?) -> IssueSummary {
        var summary = "Issue: \(title)\n\n"
        
        if !transcription.isEmpty {
            summary += "Description: \(transcription)\n\n"
        }
        
        if !voiceNotes.isEmpty {
            summary += "Additional Notes: \(voiceNotes)\n\n"
        }
        
        if let imageAnalysis = imageAnalysis {
            summary += "AI Visual Analysis: \(imageAnalysis.description)\n\n"
            summary += "Recommendations:\n"
            for recommendation in imageAnalysis.recommendations ?? [] {
                summary += "• \(recommendation)\n"
            }
            summary += "\nEstimated Time: \(imageAnalysis.estimatedTime)\n"
            summary += "Priority: \(imageAnalysis.priority)"
        }
        
        return IssueSummary(
            text: summary,
            suggestedPriority: imageAnalysis?.priority ?? determinePriority(from: transcription),
            estimatedTime: imageAnalysis?.estimatedTime ?? "Unknown",
            confidence: imageAnalysis?.confidence ?? confidenceScore
        )
    }
    
    // MARK: - Private Helpers
    
    private func generateAnalysis(for text: String) -> (text: String, confidence: Double) {
        let lowercased = text.lowercased()
        
        if lowercased.contains("door") || lowercased.contains("hinge") {
            return ("Based on your description, this appears to be a door mechanism issue. Likely causes include hinge wear, alignment problems, or hardware failure. Recommend immediate inspection.", 0.87)
        } else if lowercased.contains("wall") || lowercased.contains("paint") {
            return ("This sounds like a wall surface issue. Could involve paint damage, drywall repair, or structural concerns. Assess extent of damage before proceeding.", 0.74)
        } else if lowercased.contains("electrical") || lowercased.contains("outlet") || lowercased.contains("light") {
            return ("Electrical issue detected. Safety priority - recommend immediate professional inspection. Do not attempt repairs without qualified technician.", 0.91)
        } else if lowercased.contains("water") || lowercased.contains("leak") || lowercased.contains("plumbing") {
            return ("Plumbing-related issue identified. Check for water damage and source of problem. May require immediate attention to prevent further damage.", 0.83)
        } else {
            return ("General maintenance issue detected. Recommend on-site inspection to determine appropriate repair approach and priority level.", 0.65)
        }
    }
    
    private func determinePriority(from text: String) -> String {
        let lowercased = text.lowercased()
        
        if lowercased.contains("urgent") || lowercased.contains("emergency") || lowercased.contains("electrical") || lowercased.contains("water") || lowercased.contains("leak") {
            return "Urgent"
        } else if lowercased.contains("door") || lowercased.contains("safety") || lowercased.contains("broken") {
            return "High"
        } else if lowercased.contains("paint") || lowercased.contains("cosmetic") {
            return "Low"
        } else {
            return "Normal"
        }
    }
}

// MARK: - Models

struct ReceiptAnalysisResult: Codable {
    let vendor: String
    let totalAmount: Double
    let taxAmount: Double?
    let purchaseDate: Date
    let items: [String]
    let category: ReceiptCategory
    let description: String
    let confidence: Double
}

struct IssueSummary {
    let text: String
    let suggestedPriority: String
    let estimatedTime: String
    let confidence: Double
}


enum AIError: Error, LocalizedError {
    case speechRecognitionUnavailable
    case unableToCreateRequest
    case authorizationDenied
    case imageProcessingFailed
    case apiRequestFailed
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .speechRecognitionUnavailable:
            return "Speech recognition is not available"
        case .unableToCreateRequest:
            return "Unable to create speech recognition request"
        case .authorizationDenied:
            return "Speech recognition authorization denied"
        case .imageProcessingFailed:
            return "Failed to process image"
        case .apiRequestFailed:
            return "API request failed"
        case .invalidResponse:
            return "Invalid API response"
        }
    }
}