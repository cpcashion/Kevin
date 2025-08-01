import SwiftUI
import PhotosUI

struct PhotoPickerView: View {
  @Binding var photos: [UIImage]
  @State private var items: [PhotosPickerItem] = []
  var body: some View {
    PhotosPicker(selection: $items,
                 maxSelectionCount: 5,
                 matching: .images) {
      Label("Add Photos", systemImage: "photo.on.rectangle")
    }
    .onChange(of: items) { _, newItems in
      Task {
        for item in newItems {
          if let data = try? await item.loadTransferable(type: Data.self),
             let img = UIImage(data: data) {
            photos.append(img)
          }
        }
      }
    }
  }
}
