import SwiftUI
import AVFoundation
import Speech

// MARK: - Voice Description Button
struct VoiceDescriptionButton: View {
    @Binding var transcribedText: String
    let onTranscriptionComplete: (String) -> Void
    
    @State private var isRecording = false
    @State private var isTranscribing = false
    @State private var recordingTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var liveTranscription = ""
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "waveform.badge.mic")
                    .foregroundColor(KMTheme.accent)
                    .font(.title3)
                Text("Add Voice Description")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(KMTheme.primaryText)
                Spacer()
            }
            
            Text("Describe additional details about the issue location, urgency, or context")
                .font(.caption)
                .foregroundColor(KMTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // State-based interface
            if isRecording {
                recordingInterface
            } else if isTranscribing {
                transcribingInterface
            } else if !transcribedText.isEmpty {
                transcriptionPreview
            } else {
                recordButton
            }
        }
        .padding(16)
        .background(KMTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KMTheme.border, lineWidth: 1)
        )
        .alert("Microphone Unavailable", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var recordButton: some View {
        Button(action: startRecording) {
            HStack(spacing: 12) {
                Image(systemName: "mic.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(KMTheme.accent)
                
                Text("Tap to Record")
                    .fontWeight(.medium)
                    .foregroundColor(KMTheme.primaryText)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(KMTheme.secondaryText)
            }
            .padding(16)
            .background(KMTheme.background)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(KMTheme.accent.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    private var recordingInterface: some View {
        VStack(spacing: 20) {
            // Wave animation - larger and more prominent
            HStack(spacing: 6) {
                ForEach(0..<7) { index in
                    VoiceWaveBar(index: index, isAnimating: isRecording)
                }
            }
            .frame(height: 60)
            
            // Status text
            Text("Listening...")
                .font(.headline)
                .foregroundColor(KMTheme.primaryText)
            
            // Timer
            Text(timeString(from: recordingTime))
                .font(.title3)
                .fontWeight(.medium)
                .foregroundColor(KMTheme.secondaryText)
                .monospacedDigit()
            
            // Stop button - always visible, fixed position
            Button(action: stopRecording) {
                HStack(spacing: 8) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 20))
                    Text("Stop Recording")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(KMTheme.danger)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .padding(20)
        .background(KMTheme.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KMTheme.danger.opacity(0.3), lineWidth: 2)
        )
    }
    
    private var transcribingInterface: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(KMTheme.accent)
            
            Text("Transcribing...")
                .font(.headline)
                .foregroundColor(KMTheme.primaryText)
            
            Text("Processing your voice recording")
                .font(.caption)
                .foregroundColor(KMTheme.secondaryText)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(KMTheme.cardBackground)
        .cornerRadius(12)
    }
    
    private var transcriptionPreview: some View {
        VStack(spacing: 16) {
            // Success header with icon
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(KMTheme.success.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(KMTheme.success)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Voice Note Ready")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(KMTheme.primaryText)
                    
                    Text("Will be attached to this issue")
                        .font(.caption)
                        .foregroundColor(KMTheme.secondaryText)
                }
                
                Spacer()
            }
            
            // Transcription text with subtle background
            Text(transcribedText)
                .font(.body)
                .foregroundColor(KMTheme.primaryText)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(KMTheme.background.opacity(0.5))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(KMTheme.success.opacity(0.2), lineWidth: 1)
                )
            
            // Action buttons - Remove only (Edit removed as requested)
            HStack(spacing: 12) {
                // Re-record button
                Button(action: {
                    clearTranscription()
                    startRecording()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                        Text("Re-record")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(KMTheme.accent.opacity(0.1))
                    .foregroundColor(KMTheme.accent)
                    .cornerRadius(6)
                }
                
                // Remove button
                Button(action: clearTranscription) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.caption)
                        Text("Remove")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(KMTheme.danger.opacity(0.1))
                    .foregroundColor(KMTheme.danger)
                    .cornerRadius(6)
                }
                
                Spacer()
            }
        }
        .padding(16)
        .background(KMTheme.success.opacity(0.08))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(KMTheme.success.opacity(0.3), lineWidth: 1.5)
        )
    }
    
    private func startRecording() {
        liveTranscription = ""
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                if authStatus == .authorized {
                    do {
                        try startSpeechRecognition()
                        withAnimation {
                            isRecording = true
                        }
                        startTimer()
                        
                        // Haptic feedback
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    } catch {
                        print("❌ Failed to start speech recognition: \(error)")
                        errorMessage = error.localizedDescription
                        showingError = true
                        
                        // Haptic feedback for error
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.error)
                    }
                } else {
                    errorMessage = "Microphone permission is required for voice descriptions. Please enable it in Settings."
                    showingError = true
                }
            }
        }
    }
    
    private func stopRecording() {
        print("🎤 [VoiceButton] stopRecording called")
        print("🎤 [VoiceButton] Current liveTranscription: '\(liveTranscription)'")
        
        // Show transcribing state
        withAnimation {
            isRecording = false
            isTranscribing = true
        }
        
        // Stop audio engine and end recognition request
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        if audioEngine.inputNode.numberOfOutputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // End the recognition request to get final result
        recognitionRequest?.endAudio()
        
        // Wait for final transcription result before showing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🎤 [VoiceButton] Final liveTranscription after delay: '\(self.liveTranscription)'")
            
            // Cancel the task and cleanup
            self.recognitionTask?.cancel()
            self.recognitionTask = nil
            self.recognitionRequest = nil
            
            // Deactivate audio session
            do {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("❌ Failed to deactivate audio session: \(error)")
            }
            
            withAnimation {
                self.isTranscribing = false
                self.transcribedText = self.liveTranscription
            }
            
            self.stopTimer()
            
            print("🎤 [VoiceButton] About to call onTranscriptionComplete with: '\(self.transcribedText)'")
            print("🎤 [VoiceButton] transcribedText isEmpty: \(self.transcribedText.isEmpty)")
            
            if !self.transcribedText.isEmpty {
                self.onTranscriptionComplete(self.transcribedText)
                print("✅ [VoiceButton] onTranscriptionComplete called successfully")
                
                // Haptic feedback
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            } else {
                print("⚠️ [VoiceButton] transcribedText was empty, not calling completion handler")
            }
        }
    }
    
    private func clearTranscription() {
        transcribedText = ""
        liveTranscription = ""
        onTranscriptionComplete("")
    }
    
    private func cleanupRecording() {
        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Remove tap safely
        if audioEngine.inputNode.numberOfOutputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // End recognition
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        withAnimation {
            isRecording = false
        }
        stopTimer()
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Failed to deactivate audio session: \(error)")
        }
    }
    
    private func startSpeechRecognition() throws {
        // Cancel any previous task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Create a fresh audio engine to avoid format issues
        audioEngine = AVAudioEngine()
        
        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "VoiceDescriptionButton", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create recognition request"])
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Get audio input node
        let inputNode = audioEngine.inputNode
        
        // Configure audio tap BEFORE starting recognition task
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()
        
        // Start recognition task AFTER audio engine is running
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    liveTranscription = result.bestTranscription.formattedString
                }
            }
            
            if error != nil {
                DispatchQueue.main.async {
                    stopRecording()
                }
            }
        }
    }
    
    private func startTimer() {
        recordingTime = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            recordingTime += 0.1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        recordingTime = 0
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Voice Wave Bar
struct VoiceWaveBar: View {
    let index: Int
    let isAnimating: Bool
    @State private var height: CGFloat = 8
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(KMTheme.danger)
            .frame(width: 4, height: height)
            .onAppear {
                if isAnimating {
                    startAnimation()
                }
            }
            .onChange(of: isAnimating) { _, newValue in
                if newValue {
                    startAnimation()
                } else {
                    stopAnimation()
                }
            }
    }
    
    private func startAnimation() {
        withAnimation(
            .easeInOut(duration: 0.5)
            .repeatForever(autoreverses: true)
            .delay(Double(index) * 0.1)
        ) {
            height = CGFloat.random(in: 8...32)
        }
    }
    
    private func stopAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            height = 8
        }
    }
}

// MARK: - Preview
struct VoiceDescriptionButton_Previews: PreviewProvider {
    static var previews: some View {
        VoiceDescriptionButton(
            transcribedText: .constant(""),
            onTranscriptionComplete: { text in
                print("Transcription: \(text)")
            }
        )
        .padding()
        .background(KMTheme.background)
    }
}
