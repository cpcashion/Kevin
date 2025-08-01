import SwiftUI

struct ReceiptImageViewer: View {
  @Environment(\.dismiss) private var dismiss
  let imageUrl: String
  @State private var scale: CGFloat = 1.0
  @State private var offset: CGSize = .zero
  @State private var lastOffset: CGSize = .zero
  
  var body: some View {
    NavigationStack {
      ZStack {
        Color.black
          .ignoresSafeArea()
        
        AsyncImage(url: URL(string: imageUrl)) { image in
          image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
              SimultaneousGesture(
                MagnificationGesture()
                  .onChanged { value in
                    scale = max(1.0, min(value, 4.0))
                  },
                DragGesture()
                  .onChanged { value in
                    offset = CGSize(
                      width: lastOffset.width + value.translation.width,
                      height: lastOffset.height + value.translation.height
                    )
                  }
                  .onEnded { _ in
                    lastOffset = offset
                  }
              )
            )
            .onTapGesture(count: 2) {
              withAnimation(.easeInOut(duration: 0.3)) {
                if scale > 1.0 {
                  scale = 1.0
                  offset = .zero
                  lastOffset = .zero
                } else {
                  scale = 2.0
                }
              }
            }
        } placeholder: {
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle(tint: .white))
            .scaleEffect(1.5)
        }
      }
      .navigationTitle("Receipt")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden()
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Done") {
            dismiss()
          }
          .foregroundColor(.white)
        }
      }
      .preferredColorScheme(.dark)
    }
  }
}

#Preview {
  ReceiptImageViewer(imageUrl: "https://example.com/receipt.jpg")
}
