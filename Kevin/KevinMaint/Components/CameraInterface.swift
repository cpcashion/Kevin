import SwiftUI
import AVFoundation

// MARK: - Camera Interface
struct CameraInterface: View {
    let onCapture: (UIImage) -> Void
    let isAnalyzing: Bool
    
    @StateObject private var cameraManager = CameraManager()
    @State private var showingPermissionAlert = false
    @State private var focusPoint: CGPoint?
    @State private var showFocusIndicator = false
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreview(cameraManager: cameraManager)
                .onAppear {
                    Task {
                        await cameraManager.requestPermission()
                        if cameraManager.isAuthorized {
                            await cameraManager.startSession()
                        } else {
                            showingPermissionAlert = true
                        }
                    }
                }
                .onDisappear {
                    cameraManager.stopSession()
                }
            
            // Instruction overlay when not analyzing
            if !isAnalyzing {
                CameraInstructionOverlay()
            }
            
            // Focus indicator
            if showFocusIndicator, let focusPoint = focusPoint {
                FocusIndicator()
                    .position(focusPoint)
            }
            
            // Analysis overlay
            if isAnalyzing {
                AnalysisOverlay()
            }
            
            // Tap gesture for focus (not capture)
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { location in
                    focusCamera(at: location)
                }
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TriggerCameraCapture"))) { _ in
                    print("📸 [CameraInterface] Received camera capture notification")
                    // Provide immediate haptic feedback
                    let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                    impactFeedback.impactOccurred()
                    capturePhoto()
                }
        }
        .alert("Camera Permission Required", isPresented: $showingPermissionAlert) {
            Button("Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable camera access in Settings to capture photos for analysis.")
        }
    }
    
    private func focusCamera(at location: CGPoint) {
        print("📸 [CameraInterface] Focus requested at: \(location)")
        
        // Show focus indicator
        focusPoint = location
        showFocusIndicator = true
        
        // Focus the camera
        Task {
            await cameraManager.focusCamera(at: location)
            
            // Hide focus indicator after a delay
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            await MainActor.run {
                showFocusIndicator = false
            }
        }
    }
    
    private func capturePhoto() {
        print("📸 [CameraInterface] capturePhoto() called")
        print("📸 [CameraInterface] isAnalyzing: \(isAnalyzing)")
        print("📸 [CameraInterface] cameraManager.isAuthorized: \(cameraManager.isAuthorized)")
        print("📸 [CameraInterface] cameraManager.isSessionRunning: \(cameraManager.isSessionRunning)")
        
        guard !isAnalyzing else { 
            print("📸 [CameraInterface] Skipping capture - currently analyzing")
            return 
        }
        
        // Check if session stopped unexpectedly and restart if needed
        if !cameraManager.isSessionRunning && cameraManager.isAuthorized {
            print("📸 [CameraInterface] Session stopped unexpectedly, restarting...")
            Task {
                await cameraManager.startSession()
                // Try capture again after restart
                await attemptCapture()
            }
        } else {
            Task {
                await attemptCapture()
            }
        }
    }
    
    private func attemptCapture() async {
        print("📸 [CameraInterface] Starting capture task...")
        if let image = await cameraManager.capturePhoto() {
            print("📸 [CameraInterface] Successfully captured image")
            
            await MainActor.run {
                onCapture(image)
            }
        } else {
            print("❌ [CameraInterface] Failed to capture image")
        }
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    @ObservedObject var cameraManager: CameraManager
    
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        
        // Add preview layer
        if let previewLayer = cameraManager.previewLayer {
            view.videoPreviewLayer = previewLayer
        }
        
        return view
    }
    
    func updateUIView(_ uiView: PreviewView, context: Context) {
        // Preview layer frame is automatically updated by PreviewView's layoutSubviews
    }
    
    // Custom UIView subclass to properly handle preview layer
    class PreviewView: UIView {
        var videoPreviewLayer: AVCaptureVideoPreviewLayer? {
            didSet {
                if let layer = videoPreviewLayer {
                    layer.videoGravity = .resizeAspectFill
                    self.layer.addSublayer(layer)
                    setNeedsLayout()
                }
            }
        }
        
        override func layoutSubviews() {
            super.layoutSubviews()
            videoPreviewLayer?.frame = bounds
        }
    }
}

// MARK: - Camera Instruction Overlay
struct CameraInstructionOverlay: View {
    var body: some View {
        // Clean camera view with no text overlays
        EmptyView()
    }
}

// MARK: - Focus Indicator
struct FocusIndicator: View {
    @State private var scaleAnimation = false
    
    var body: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.yellow, lineWidth: 2)
                .frame(width: 80, height: 80)
                .scaleEffect(scaleAnimation ? 1.2 : 1.0)
                .opacity(scaleAnimation ? 0.0 : 1.0)
            
            // Inner crosshair
            Group {
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: 20, height: 2)
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: 2, height: 20)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.6)) {
                scaleAnimation = true
            }
        }
    }
}

// MARK: - Analysis Overlay
struct AnalysisOverlay: View {
    @State private var scanlinePosition: CGFloat = 0
    
    var body: some View {
        ZStack {
            // Subtle themed overlay
            KMTheme.background.opacity(0.4)
            
            // Scanning effect
            VStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, KMTheme.accent.opacity(0.8), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 3)
                    .offset(y: scanlinePosition)
                    .animation(.linear(duration: 2.5).repeatForever(autoreverses: false), value: scanlinePosition)
                    .onAppear {
                        scanlinePosition = UIScreen.main.bounds.height
                    }
                
                Spacer()
            }
            
            // Analysis status
            VStack {
                Spacer()
                
                VStack(spacing: 12) {
                    // AI icon with pulse
                    ZStack {
                        Circle()
                            .fill(KMTheme.accent.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulseAnimation)
                        
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(KMTheme.accent)
                    }
                    .onAppear {
                        pulseAnimation = true
                    }
                    
                    Text("Analyzing...")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(KMTheme.primaryText)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    
                    Text("Kevin's AI is examining the issue")
                        .font(.subheadline)
                        .foregroundColor(KMTheme.secondaryText)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 20)
                .background(KMTheme.cardBackground.opacity(0.9))
                .cornerRadius(16)
                .padding(.bottom, 140)
            }
        }
    }
    
    @State private var pulseAnimation = false
}
// MARK: - Camera Manager
@MainActor
class CameraManager: NSObject, ObservableObject {
    private let captureSession = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    
    @Published var isAuthorized = false
    @Published var isSessionRunning = false
    
    lazy var previewLayer: AVCaptureVideoPreviewLayer? = {
        let layer = AVCaptureVideoPreviewLayer(session: captureSession)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()
    
    private var photoContinuation: CheckedContinuation<UIImage?, Never>?
    
    override init() {
        super.init()
        setupSession()
        setupSessionMonitoring()
    }
    
    private func setupSessionMonitoring() {
        // Monitor session interruptions
        NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionWasInterrupted,
            object: captureSession,
            queue: .main
        ) { [weak self] notification in
            print("⚠️ [CameraManager] Session was interrupted")
            if let reason = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? AVCaptureSession.InterruptionReason {
                print("⚠️ [CameraManager] Interruption reason: \(reason)")
            }
            self?.isSessionRunning = false
        }
        
        NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionInterruptionEnded,
            object: captureSession,
            queue: .main
        ) { [weak self] _ in
            print("✅ [CameraManager] Session interruption ended")
            Task {
                await self?.startSession()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .AVCaptureSessionRuntimeError,
            object: captureSession,
            queue: .main
        ) { [weak self] notification in
            print("❌ [CameraManager] Session runtime error")
            if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? Error {
                print("❌ [CameraManager] Runtime error: \(error.localizedDescription)")
            }
            self?.isSessionRunning = false
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func requestPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default:
            isAuthorized = false
        }
    }
    
    private func setupSession() {
        print("📸 [CameraManager] Setting up camera session...")
        captureSession.beginConfiguration()
        
        // Configure session
        captureSession.sessionPreset = .photo
        print("📸 [CameraManager] Session preset set to .photo")
        
        // Add video input - with simulator fallback
        var videoDevice: AVCaptureDevice?
        
        // Try back camera first (real device)
        videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        
        // Fallback to any available camera (simulator support)
        if videoDevice == nil {
            videoDevice = AVCaptureDevice.default(for: .video)
            print("📸 [CameraManager] No back camera found, using default camera")
        }
        
        guard let device = videoDevice else {
            print("❌ [CameraManager] No camera found at all")
            captureSession.commitConfiguration()
            return
        }
        
        print("📸 [CameraManager] Found camera: \(device.localizedName)")
        
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: device) else {
            print("❌ [CameraManager] Failed to create video device input")
            captureSession.commitConfiguration()
            return
        }
        
        guard captureSession.canAddInput(videoDeviceInput) else {
            print("❌ [CameraManager] Cannot add video input to session")
            captureSession.commitConfiguration()
            return
        }
        
        captureSession.addInput(videoDeviceInput)
        self.videoDeviceInput = videoDeviceInput
        print("📸 [CameraManager] Added video input to session")
        
        // Add photo output
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
            print("📸 [CameraManager] Added photo output to session")
        } else {
            print("❌ [CameraManager] Cannot add photo output to session")
        }
        
        captureSession.commitConfiguration()
        print("📸 [CameraManager] Camera session setup complete")
    }
    
    func startSession() async {
        print("📸 [CameraManager] startSession() called")
        print("📸 [CameraManager] isAuthorized: \(isAuthorized)")
        print("📸 [CameraManager] isSessionRunning: \(isSessionRunning)")
        
        guard isAuthorized && !isSessionRunning else { 
            print("📸 [CameraManager] Skipping session start - not authorized or already running")
            return 
        }
        
        print("📸 [CameraManager] Starting capture session...")
        
        await Task.detached { [weak self] in
            self?.captureSession.startRunning()
            await MainActor.run {
                self?.isSessionRunning = self?.captureSession.isRunning ?? false
                print("📸 [CameraManager] Session started - isRunning: \(self?.isSessionRunning ?? false)")
            }
        }.value
        
        // Give the camera a moment to fully initialize and verify it's still running
        print("📸 [CameraManager] Waiting for camera to initialize...")
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Double-check session state after initialization
        await MainActor.run {
            isSessionRunning = captureSession.isRunning
            print("📸 [CameraManager] Post-initialization check - isRunning: \(isSessionRunning)")
        }
        
        print("📸 [CameraManager] Camera initialization complete")
    }
    
    func stopSession() {
        guard isSessionRunning else { return }
        
        captureSession.stopRunning()
        isSessionRunning = false
    }
    
    private func restartSession() async {
        print("🔄 [CameraManager] Restarting camera session...")
        
        // Stop if running
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
        
        // Wait a moment for cleanup
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Start again
        await Task.detached { [weak self] in
            self?.captureSession.startRunning()
            await MainActor.run {
                self?.isSessionRunning = self?.captureSession.isRunning ?? false
                print("🔄 [CameraManager] Session restarted - isRunning: \(self?.isSessionRunning ?? false)")
            }
        }.value
        
        // Give it a moment to stabilize
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
    }
    
    func focusCamera(at point: CGPoint) async {
        print("📸 [CameraManager] focusCamera(at:) called with point: \(point)")
        
        guard let device = videoDeviceInput?.device else {
            print("❌ [CameraManager] No video device available for focusing")
            return
        }
        
        guard device.isFocusPointOfInterestSupported else {
            print("❌ [CameraManager] Focus point of interest not supported")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            // Convert UI coordinates to device coordinates (0.0 to 1.0)
            let devicePoint = CGPoint(
                x: point.y / UIScreen.main.bounds.height, // Note: x and y are swapped for camera orientation
                y: 1.0 - (point.x / UIScreen.main.bounds.width)
            )
            
            print("📸 [CameraManager] Setting focus point to device coordinates: \(devicePoint)")
            
            device.focusPointOfInterest = devicePoint
            device.focusMode = .autoFocus
            
            // Also set exposure if supported
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
            print("✅ [CameraManager] Focus and exposure set successfully")
            
        } catch {
            print("❌ [CameraManager] Failed to set focus: \(error.localizedDescription)")
        }
    }
    
    func capturePhoto() async -> UIImage? {
        print("📸 [CameraManager] capturePhoto() called")
        print("📸 [CameraManager] isSessionRunning: \(isSessionRunning)")
        print("📸 [CameraManager] captureSession.isRunning: \(captureSession.isRunning)")
        
        // CRITICAL FIX: Always use the actual session state, not our cached property
        let actualSessionRunning = captureSession.isRunning
        isSessionRunning = actualSessionRunning
        
        // If session stopped unexpectedly, restart it immediately
        if !actualSessionRunning && isAuthorized {
            print("🔄 [CameraManager] Session stopped unexpectedly, restarting immediately...")
            await restartSession()
            // Check again after restart
            if !captureSession.isRunning {
                print("❌ [CameraManager] Failed to restart session")
                return nil
            }
        }
        
        // No simulator fallback - camera must work properly
        
        // Final check - use actual session state
        let finalSessionCheck = captureSession.isRunning
        isSessionRunning = finalSessionCheck
        
        guard finalSessionCheck else { 
            print("❌ [CameraManager] Camera session not running (final check)")
            return nil 
        }
        
        // Check if we have an active video connection
        guard let connection = photoOutput.connection(with: .video) else {
            print("❌ [CameraManager] No video connection found")
            return nil
        }
        
        print("📸 [CameraManager] Video connection - enabled: \(connection.isEnabled), active: \(connection.isActive)")
        
        guard connection.isEnabled, connection.isActive else {
            print("❌ [CameraManager] Video connection not enabled or active")
            return nil
        }
        
        print("📸 [CameraManager] Starting photo capture...")
        
        return await withCheckedContinuation { continuation in
            photoContinuation = continuation
            
            let settings = AVCapturePhotoSettings()
            settings.isHighResolutionPhotoEnabled = true
            
            print("📸 [CameraManager] Calling photoOutput.capturePhoto...")
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }
    
}

// MARK: - Photo Capture Delegate
extension CameraManager: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer { photoContinuation = nil }
        
        print("📸 [CameraManager] Photo capture delegate called")
        
        if let error = error {
            print("❌ [CameraManager] Photo capture error: \(error.localizedDescription)")
            photoContinuation?.resume(returning: nil)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            print("❌ [CameraManager] Failed to get image data from photo")
            photoContinuation?.resume(returning: nil)
            return
        }
        
        guard let image = UIImage(data: imageData) else {
            print("❌ [CameraManager] Failed to create UIImage from data")
            photoContinuation?.resume(returning: nil)
            return
        }
        
        print("✅ [CameraManager] Successfully created UIImage from captured photo")
        photoContinuation?.resume(returning: image)
    }
}
