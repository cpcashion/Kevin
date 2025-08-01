import SwiftUI
import PDFKit

struct PDFPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let pdfData: Data
    
    var body: some View {
        NavigationStack {
            PDFKitView(data: pdfData)
                .navigationTitle("Invoice Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(KMTheme.accent)
                    }
                    
                    ToolbarItem(placement: .navigationBarLeading) {
                        ShareLink(item: pdfData, preview: SharePreview("Invoice", image: Image(systemName: "doc.text"))) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(KMTheme.accent)
                        }
                    }
                }
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .systemBackground
        
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
        
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        // No updates needed
    }
}

// Make Data conform to Transferable for ShareLink
extension Data: @unchecked Sendable {}
