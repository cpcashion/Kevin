import SwiftUI
import UIKit

struct CameraView: UIViewControllerRepresentable {
  @Environment(\.dismiss) private var dismiss
  @Binding var selectedImage: UIImage?
  
  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.delegate = context.coordinator
    picker.sourceType = .camera
    picker.allowsEditing = true
    return picker
  }
  
  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
  
  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }
  
  class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let parent: CameraView
    
    init(_ parent: CameraView) {
      self.parent = parent
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
      if let editedImage = info[.editedImage] as? UIImage {
        parent.selectedImage = editedImage
      } else if let originalImage = info[.originalImage] as? UIImage {
        parent.selectedImage = originalImage
      }
      
      parent.dismiss()
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      parent.dismiss()
    }
  }
}

#Preview {
  CameraView(selectedImage: .constant(nil))
}
