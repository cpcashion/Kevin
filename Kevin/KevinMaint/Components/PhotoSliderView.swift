import SwiftUI

struct PhotoSliderView: View {
    let photos: [IssuePhoto]
    let initialIndex: Int
    @Binding var isPresented: Bool
    @State private var currentIndex: Int
    
    init(photos: [IssuePhoto], initialIndex: Int = 0, isPresented: Binding<Bool>) {
        self.photos = photos
        self.initialIndex = initialIndex
        self._isPresented = isPresented
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isPresented = false
                    }
                }
            
            VStack {
                // Header with close button and counter
                HStack {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    if photos.count > 1 {
                        Text("\(currentIndex + 1) of \(photos.count)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(16)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                
                Spacer()
                
                // Photo display area with zoomable images
                TabView(selection: $currentIndex) {
                    ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                        ZoomableImageView(imageURL: URL(string: photo.url))
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
                
                Spacer()
                
                // Navigation dots (only show if more than 1 photo)
                if photos.count > 1 {
                    HStack(spacing: 8) {
                        ForEach(0..<photos.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? Color.white : Color.white.opacity(0.4))
                                .frame(width: 8, height: 8)
                                .onTapGesture {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        currentIndex = index
                                    }
                                }
                        }
                    }
                    .padding(.bottom, 50)
                }
            }
        }
        .statusBarHidden()
        .onAppear {
            currentIndex = initialIndex
        }
    }
}

// Preview
struct PhotoSliderView_Previews: PreviewProvider {
    static var previews: some View {
        PhotoSliderView(
            photos: [
                IssuePhoto(id: "1", issueId: "test", url: "https://via.placeholder.com/400", thumbUrl: "https://via.placeholder.com/400", takenAt: Date()),
                IssuePhoto(id: "2", issueId: "test", url: "https://via.placeholder.com/400", thumbUrl: "https://via.placeholder.com/400", takenAt: Date()),
                IssuePhoto(id: "3", issueId: "test", url: "https://via.placeholder.com/400", thumbUrl: "https://via.placeholder.com/400", takenAt: Date())
            ],
            initialIndex: 0,
            isPresented: .constant(true)
        )
    }
}
