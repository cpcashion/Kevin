import SwiftUI

// MARK: - Capture Controls
struct CaptureControls: View {
    let onCameraCapture: () -> Void
    let onPhotoLibrary: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 24) {
            // Main controls row
            HStack(spacing: 40) {
                // Photo library button
                PhotoLibraryButton(action: onPhotoLibrary)
                
                // Main capture button
                MainCaptureButton(
                    action: onCameraCapture,
                    isPressed: $isPressed
                )
                
                // Spacer to balance layout (replaces voice button)
                Color.clear
                    .frame(width: 50, height: 50)
            }
            
            // Simple instruction text
            Text("Tap to capture issue")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .padding(.bottom, 80) // Optimal positioning to clear tab bar
    }
}

// MARK: - Main Capture Button
struct MainCaptureButton: View {
    let action: () -> Void
    @Binding var isPressed: Bool
    
    var body: some View {
        Button(action: {
            print("📸 [MainCaptureButton] Button pressed!")
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
            
            action()
        }) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(.white.opacity(0.3), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                // Inner button
                Circle()
                    .fill(.white)
                    .frame(width: 64, height: 64)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
            }
        }
        .buttonStyle(CaptureButtonStyle(isPressed: $isPressed))
    }
}

// MARK: - Photo Library Button
struct PhotoLibraryButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Removed voice button - voice notes are now added to work updates instead

// MARK: - Capture Button Style
struct CaptureButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { pressed in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressed
                }
            }
    }
}

// MARK: - Preview
struct CaptureControls_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                Spacer()
                
                CaptureControls(
                    onCameraCapture: { print("Camera capture") },
                    onPhotoLibrary: { print("Photo library") }
                )
            }
        }
    }
}
