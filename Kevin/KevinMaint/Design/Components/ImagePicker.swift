import SwiftUI
import UIKit

struct AIImagePicker: UIViewControllerRepresentable {
    @Binding var photos: [UIImage]
    @Binding var selectedImage: UIImage?
    @Binding var imageAnalysis: ImageAnalysisResult?
    @Binding var isAnalyzingImage: Bool
    @Binding var showingAIAnalysis: Bool
    @Environment(\.presentationMode) var presentationMode
    
    let sourceType: UIImagePickerController.SourceType
    let onPhotoSelected: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: AIImagePicker
        
        init(_ parent: AIImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.photos.append(image)
                parent.selectedImage = image  // Set selectedImage for submission
                print("🔥 [ImagePicker] Set selectedImage from camera for submission")
                parent.onPhotoSelected(image)
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
    
}

struct CameraButton: View {
    @Binding var photos: [UIImage]
    @Binding var selectedImage: UIImage?
    @Binding var imageAnalysis: ImageAnalysisResult?
    @Binding var isAnalyzingImage: Bool
    @Binding var showingAIAnalysis: Bool
    @State private var showingImagePicker = false
    @EnvironmentObject var appState: AppState
    let onPhotoSelected: (UIImage) -> Void
    
    var body: some View {
        Button(action: {
            showingImagePicker = true
        }) {
            VStack(spacing: 16) {
                Image(systemName: "camera")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(KMTheme.accent)
                
                VStack(spacing: 4) {
                    Text("Tap to Take Photo")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(KMTheme.primaryText)
                    
                    Text("AI analysis happens automatically")
                        .font(.subheadline)
                        .foregroundColor(KMTheme.secondaryText)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .background(KMTheme.surfaceBackground)
            .cornerRadius(16)
            .id(appState.currentTheme) // Force refresh on theme change
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingImagePicker) {
            AIImagePicker(
                photos: $photos,
                selectedImage: $selectedImage,
                imageAnalysis: $imageAnalysis,
                isAnalyzingImage: $isAnalyzingImage,
                showingAIAnalysis: $showingAIAnalysis,
                sourceType: UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary,
                onPhotoSelected: onPhotoSelected
            )
        }
    }
}
