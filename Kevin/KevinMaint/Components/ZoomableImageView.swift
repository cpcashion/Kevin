import SwiftUI

/// A zoomable image view that supports pinch-to-zoom and double-tap gestures
struct ZoomableImageView: View {
    let imageURL: URL?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @GestureState private var magnifyBy: CGFloat = 1.0
    
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    
    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .scaleEffect(scale * magnifyBy)
                        .offset(x: offset.width, y: offset.height)
                        .gesture(
                            MagnificationGesture()
                                .updating($magnifyBy) { currentState, gestureState, _ in
                                    gestureState = currentState
                                }
                                .onEnded { value in
                                    let newScale = scale * value
                                    scale = min(max(newScale, minScale), maxScale)
                                    
                                    // Reset offset if zoomed out to minimum
                                    if scale == minScale {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            offset = .zero
                                            lastOffset = .zero
                                        }
                                    }
                                }
                        )
                        .gesture(
                            // Only add drag gesture when zoomed in to allow TabView swiping when at 1x
                            scale > minScale ? DragGesture()
                                .onChanged { value in
                                    let newOffset = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                    offset = limitOffset(newOffset, in: geometry.size)
                                }
                                .onEnded { _ in
                                    lastOffset = offset
                                } : nil
                        )
                        .onTapGesture(count: 2) {
                            // Double tap to zoom in/out
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if scale > minScale {
                                    // Zoom out
                                    scale = minScale
                                    offset = .zero
                                    lastOffset = .zero
                                } else {
                                    // Zoom in to 2x
                                    scale = 2.0
                                }
                            }
                        }
                    
                case .failure:
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("Failed to load image")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        )
                    
                case .empty:
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay(
                            ProgressView()
                                .tint(.white)
                        )
                    
                @unknown default:
                    EmptyView()
                }
            }
        }
    }
    
    /// Limits the offset to prevent dragging the image too far off screen
    private func limitOffset(_ offset: CGSize, in size: CGSize) -> CGSize {
        // Calculate the maximum allowed offset based on scale
        let maxOffsetX = (size.width * (scale - 1)) / 2
        let maxOffsetY = (size.height * (scale - 1)) / 2
        
        return CGSize(
            width: min(max(offset.width, -maxOffsetX), maxOffsetX),
            height: min(max(offset.height, -maxOffsetY), maxOffsetY)
        )
    }
}

// Preview
struct ZoomableImageView_Previews: PreviewProvider {
    static var previews: some View {
        ZoomableImageView(imageURL: URL(string: "https://via.placeholder.com/800"))
            .background(Color.black)
    }
}
