import SwiftUI
import MessageUI

struct EmailInvoiceView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    
    let pdfData: Data
    let recipientEmail: String
    let recipientName: String
    let invoiceNumber: String
    let receiptPhotos: [UIImage]
    let onEmailSent: (() -> Void)?
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        
        // Set recipients
        if !recipientEmail.isEmpty {
            composer.setToRecipients([recipientEmail])
        }
        
        // Set subject
        composer.setSubject("Invoice \(invoiceNumber) from Kevin")
        
        // Set body
        let body = """
        Hi \(recipientName.isEmpty ? "there" : recipientName),
        
        Please find attached invoice \(invoiceNumber) for the recent maintenance work completed at your location.
        
        If you have any questions about this invoice, please don't hesitate to reach out.
        
        Thank you for your business!
        
        Best regards,
        Kevin Team
        """
        composer.setMessageBody(body, isHTML: false)
        
        // Attach PDF
        composer.addAttachmentData(pdfData, mimeType: "application/pdf", fileName: "Invoice-\(invoiceNumber).pdf")
        
        // Attach receipt photos
        for (index, photo) in receiptPhotos.enumerated() {
            if let imageData = photo.jpegData(compressionQuality: 0.8) {
                composer.addAttachmentData(imageData, mimeType: "image/jpeg", fileName: "Receipt-\(index + 1).jpg")
            }
        }
        
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let parent: EmailInvoiceView
        
        init(_ parent: EmailInvoiceView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            if let error = error {
                print("Error sending email: \(error.localizedDescription)")
            }
            
            switch result {
            case .sent:
                print("Invoice email sent successfully")
                parent.onEmailSent?()
            case .saved:
                print("Invoice email saved as draft")
            case .cancelled:
                print("Invoice email cancelled")
            case .failed:
                print("Invoice email failed to send")
            @unknown default:
                break
            }
            
            parent.dismiss()
        }
    }
}

// MARK: - Email Availability Check

struct EmailInvoiceWrapper: View {
    @Environment(\.dismiss) private var dismiss
    
    let pdfData: Data
    let recipientEmail: String
    let recipientName: String
    let invoiceNumber: String
    let receiptPhotos: [UIImage]
    let onEmailSent: (() -> Void)?
    
    var body: some View {
        Group {
            if MFMailComposeViewController.canSendMail() {
                EmailInvoiceView(
                    pdfData: pdfData,
                    recipientEmail: recipientEmail,
                    recipientName: recipientName,
                    invoiceNumber: invoiceNumber,
                    receiptPhotos: receiptPhotos,
                    onEmailSent: onEmailSent
                )
            } else {
                emailNotAvailableView
            }
        }
    }
    
    private var emailNotAvailableView: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "envelope.badge.fill")
                    .font(.system(size: 60))
                    .foregroundColor(KMTheme.accent)
                
                Text("Email Not Available")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(KMTheme.primaryText)
                
                Text("Please configure an email account in your device settings to send invoices.")
                    .font(.system(size: 16))
                    .foregroundColor(KMTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: { dismiss() }) {
                    Text("OK")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(KMTheme.accent)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 20)
            }
            .padding()
            .background(KMTheme.background)
        }
    }
}
