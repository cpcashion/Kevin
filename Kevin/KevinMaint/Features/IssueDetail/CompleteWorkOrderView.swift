import SwiftUI

struct CompleteWorkOrderView: View {
  let issue: Issue
  let workOrder: WorkOrder?
  let onComplete: (String, [UIImage]) -> Void
  @Environment(\.dismiss) private var dismiss
  
  @State private var completionNotes = ""
  @State private var beforeAfterPhotos: [UIImage] = []
  @State private var selectedImage: UIImage? = nil
  @State private var isSubmitting = false
  @State private var showingImagePicker = false
  
  private var canComplete: Bool {
    !completionNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  
  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 24) {
          // Header
          headerSection
          
          // Completion Notes
          notesSection
          
          // Before/After Photos
          photosSection
          
          // Complete Button
          completeButton
        }
        .padding(24)
      }
      .background(KMTheme.background)
      .navigationTitle("Complete Work")
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden()
      .toolbarBackground(KMTheme.background, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
      .toolbarColorScheme(.dark, for: .navigationBar)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button("Cancel") {
            dismiss()
          }
          .foregroundColor(KMTheme.accent)
        }
      }
    }
  }
  
  private var headerSection: some View {
    VStack(spacing: 12) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 48))
        .foregroundColor(KMTheme.success)
      
      Text("Mark Work as Complete")
        .font(.title2)
        .fontWeight(.bold)
        .foregroundColor(KMTheme.primaryText)
      
      Text(issue.title)
        .font(.body)
        .foregroundColor(KMTheme.secondaryText)
        .multilineTextAlignment(.center)
    }
    .padding(.vertical, 8)
  }
  
  private var notesSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "note.text")
          .foregroundColor(KMTheme.accent)
          .font(.title3)
        
        Text("Completion Summary")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        Spacer()
        
        Text("Required")
          .font(.caption)
          .fontWeight(.medium)
          .foregroundColor(KMTheme.danger)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(KMTheme.danger.opacity(0.1))
          .cornerRadius(4)
      }
      
      VStack(alignment: .leading, spacing: 8) {
        ZStack(alignment: .topLeading) {
          if completionNotes.isEmpty {
            Text("Describe what was completed, any issues encountered, or follow-up needed")
              .foregroundColor(KMTheme.tertiaryText.opacity(0.6))
              .padding(.horizontal, 16)
              .padding(.vertical, 20)
              .allowsHitTesting(false)
          }
          
          TextEditor(text: $completionNotes)
            .font(.body)
            .foregroundColor(KMTheme.primaryText)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .frame(minHeight: 100)
            .padding(12)
            .background(KMTheme.background)
            .cornerRadius(8)
            .overlay(
              RoundedRectangle(cornerRadius: 8)
                .stroke(completionNotes.isEmpty ? KMTheme.danger.opacity(0.3) : KMTheme.border, lineWidth: 1)
            )
        }
        
      }
    }
    .padding(20)
    .background(KMTheme.cardBackground)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(KMTheme.border, lineWidth: 0.5)
    )
  }
  
  private var photosSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Image(systemName: "camera")
          .foregroundColor(KMTheme.accent)
          .font(.title3)
        
        Text("Completion Photos")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(KMTheme.primaryText)
        
        Spacer()
        
        Text("Optional")
          .font(.caption)
          .fontWeight(.medium)
          .foregroundColor(KMTheme.tertiaryText)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(KMTheme.borderSecondary)
          .cornerRadius(4)
      }
      
      if beforeAfterPhotos.isEmpty {
        Button(action: { showingImagePicker = true }) {
          VStack(spacing: 12) {
            Image(systemName: "camera.fill")
              .font(.title)
              .foregroundColor(KMTheme.accent)
            
            Text("Add Before/After Photos")
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundColor(KMTheme.accent)
            
            Text("Show the completed work")
              .font(.caption)
              .foregroundColor(KMTheme.tertiaryText)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 32)
          .background(KMTheme.accent.opacity(0.05))
          .cornerRadius(12)
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(KMTheme.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
          )
        }
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 12) {
            ForEach(Array(beforeAfterPhotos.enumerated()), id: \.offset) { index, photo in
              Image(uiImage: photo)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .cornerRadius(8)
                .clipped()
                .overlay(
                  Button(action: {
                    beforeAfterPhotos.remove(at: index)
                  }) {
                    Image(systemName: "xmark.circle.fill")
                      .font(.title3)
                      .foregroundColor(.white)
                      .background(Circle().fill(KMTheme.background.opacity(0.6)))
                  }
                  .offset(x: 8, y: -8),
                  alignment: .topTrailing
                )
            }
            
            Button(action: { showingImagePicker = true }) {
              VStack(spacing: 4) {
                Image(systemName: "plus")
                  .font(.title2)
                  .foregroundColor(KMTheme.accent)
                
                Text("Add")
                  .font(.caption)
                  .foregroundColor(KMTheme.accent)
              }
              .frame(width: 100, height: 100)
              .background(KMTheme.accent.opacity(0.1))
              .cornerRadius(8)
              .overlay(
                RoundedRectangle(cornerRadius: 8)
                  .stroke(KMTheme.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3]))
              )
            }
          }
          .padding(.horizontal, 4)
        }
      }
    }
    .padding(20)
    .background(KMTheme.cardBackground)
    .cornerRadius(16)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(KMTheme.border, lineWidth: 0.5)
    )
    .sheet(isPresented: $showingImagePicker) {
      NavigationView {
        VStack {
          Text("Add Photos")
            .font(.title2)
            .fontWeight(.bold)
            .padding()
          
          CameraButton(
            photos: $beforeAfterPhotos,
            selectedImage: $selectedImage,
            imageAnalysis: .constant(nil),
            isAnalyzingImage: .constant(false),
            showingAIAnalysis: .constant(false),
            onPhotoSelected: { _ in }
          )
          
          Spacer()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .navigationBarTrailing) {
            Button("Done") {
              showingImagePicker = false
            }
          }
        }
      }
    }
  }
  
  private var completeButton: some View {
    Button(action: {
      Task {
        await completeWork()
      }
    }) {
      HStack(spacing: 8) {
        Image(systemName: "checkmark")
          .font(.headline)
          .fontWeight(.semibold)
        Text("Complete Work Order")
          .font(.headline)
          .fontWeight(.semibold)
      }
      .foregroundColor(canComplete ? KMTheme.primaryText : KMTheme.success)
      .frame(maxWidth: .infinity)
      .padding()
      .background(canComplete ? KMTheme.success : KMTheme.success.opacity(0.15))
      .cornerRadius(12)
    }
    .disabled(!canComplete || isSubmitting)
    .animation(.easeInOut(duration: 0.2), value: canComplete)
  }
  
  private func completeWork() {
    guard canComplete else { return }
    
    isSubmitting = true
    
    // Add haptic feedback
    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    impactFeedback.impactOccurred()
    
    // Call completion handler
    onComplete(completionNotes, beforeAfterPhotos)
    
    // Dismiss after short delay for better UX
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      dismiss()
    }
  }
}
