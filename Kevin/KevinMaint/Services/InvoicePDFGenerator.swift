import Foundation
import PDFKit
import UIKit

class InvoicePDFGenerator {
    
    // MARK: - Company Information
    private struct CompanyInfo {
        static let name = "Kevin Inc."
        static let address = "Charlotte, NC"
        static let phone = "(704) 591-1719"
        static let email = "info@kevinmaint.com"
    }
    
    // MARK: - PDF Generation
    
    static func generatePDF(for invoice: Invoice) -> Data? {
        let pageWidth: CGFloat = 612 // 8.5 inches at 72 DPI
        let pageHeight: CGFloat = 792 // 11 inches at 72 DPI
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        let data = renderer.pdfData { context in
            context.beginPage()
            
            var yPosition: CGFloat = 50
            let margin: CGFloat = 50
            let contentWidth = pageWidth - (margin * 2)
            
            // Draw header
            yPosition = drawHeader(in: context.cgContext, yPosition: yPosition, margin: margin, contentWidth: contentWidth)
            
            // Draw invoice info
            yPosition = drawInvoiceInfo(invoice: invoice, in: context.cgContext, yPosition: yPosition, margin: margin, contentWidth: contentWidth)
            
            // Draw bill to section
            yPosition = drawBillTo(invoice: invoice, in: context.cgContext, yPosition: yPosition, margin: margin, contentWidth: contentWidth)
            
            // Draw line items table
            yPosition = drawLineItems(invoice: invoice, in: context.cgContext, yPosition: yPosition, margin: margin, contentWidth: contentWidth)
            
            // Draw totals
            yPosition = drawTotals(invoice: invoice, in: context.cgContext, yPosition: yPosition, margin: margin, contentWidth: contentWidth)
            
            // Draw payment instructions
            if let instructions = invoice.paymentInstructions {
                yPosition = drawPaymentInstructions(instructions: instructions, in: context.cgContext, yPosition: yPosition, margin: margin, contentWidth: contentWidth)
            }
            
            // Draw notes
            if let notes = invoice.notes {
                yPosition = drawNotes(notes: notes, in: context.cgContext, yPosition: yPosition, margin: margin, contentWidth: contentWidth)
            }
            
            // Draw receipt photos
            if let receiptUrls = invoice.receiptUrls, !receiptUrls.isEmpty {
                yPosition = drawReceiptPhotos(receiptUrls: receiptUrls, in: context.cgContext, yPosition: yPosition, margin: margin, contentWidth: contentWidth)
            }
            
            // Draw footer
            drawFooter(in: context.cgContext, pageHeight: pageHeight, margin: margin, contentWidth: contentWidth)
        }
        
        return data
    }
    
    // MARK: - Drawing Methods
    
    private static func drawHeader(in context: CGContext, yPosition: CGFloat, margin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var y = yPosition
        
        // Company logo
        if let logo = UIImage(named: "kevin-wordmark-letters-ai-light") {
            let logoHeight: CGFloat = 60
            let logoAspectRatio = logo.size.width / logo.size.height
            let logoWidth = logoHeight * logoAspectRatio
            let logoRect = CGRect(x: margin, y: y, width: logoWidth, height: logoHeight)
            logo.draw(in: logoRect)
            y += logoHeight + 15
        } else {
            // Fallback to text if logo not found
            let companyNameFont = UIFont.systemFont(ofSize: 24, weight: .bold)
            let companyNameAttrs: [NSAttributedString.Key: Any] = [
                .font: companyNameFont,
                .foregroundColor: UIColor.black
            ]
            let companyNameText = CompanyInfo.name as NSString
            companyNameText.draw(at: CGPoint(x: margin, y: y), withAttributes: companyNameAttrs)
            y += 30
        }
        
        // FROM section
        let fromFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
        let fromAttrs: [NSAttributedString.Key: Any] = [
            .font: fromFont,
            .foregroundColor: UIColor.black
        ]
        
        ("FROM:" as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: fromAttrs)
        y += 20
        
        // Company details
        let detailsFont = UIFont.systemFont(ofSize: 10)
        let detailsAttrs: [NSAttributedString.Key: Any] = [
            .font: detailsFont,
            .foregroundColor: UIColor.darkGray
        ]
        
        (CompanyInfo.address as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: detailsAttrs)
        y += 14
        (CompanyInfo.phone as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: detailsAttrs)
        y += 14
        (CompanyInfo.email as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: detailsAttrs)
        y += 20
        
        // Horizontal line
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: margin, y: y))
        context.addLine(to: CGPoint(x: margin + contentWidth, y: y))
        context.strokePath()
        y += 30
        
        return y
    }
    
    private static func drawInvoiceInfo(invoice: Invoice, in context: CGContext, yPosition: CGFloat, margin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var y = yPosition
        
        // "INVOICE" title - left aligned
        let titleFont = UIFont.systemFont(ofSize: 28, weight: .bold)
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        let titleText = "INVOICE" as NSString
        titleText.draw(at: CGPoint(x: margin, y: y), withAttributes: titleAttrs)
        
        // Invoice details on the left
        let detailsFont = UIFont.systemFont(ofSize: 11)
        let labelFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
        
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: UIColor.darkGray
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: detailsFont,
            .foregroundColor: UIColor.black
        ]
        
        y += 35
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        // Invoice number
        let invoiceNumLabel = "Invoice #: " as NSString
        let invoiceNumValue = invoice.invoiceNumber as NSString
        let invoiceNumLabelWidth = invoiceNumLabel.size(withAttributes: labelAttrs).width
        invoiceNumLabel.draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
        invoiceNumValue.draw(at: CGPoint(x: margin + invoiceNumLabelWidth, y: y), withAttributes: valueAttrs)
        y += 18
        
        // Issue date
        let issueDateLabel = "Issue Date: " as NSString
        let issueDateValue = dateFormatter.string(from: invoice.issueDate) as NSString
        let issueDateLabelWidth = issueDateLabel.size(withAttributes: labelAttrs).width
        issueDateLabel.draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
        issueDateValue.draw(at: CGPoint(x: margin + issueDateLabelWidth, y: y), withAttributes: valueAttrs)
        y += 18
        
        // Due date
        let dueDateLabel = "Due Date: " as NSString
        let dueDateValue = dateFormatter.string(from: invoice.dueDate) as NSString
        let dueDateLabelWidth = dueDateLabel.size(withAttributes: labelAttrs).width
        dueDateLabel.draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
        dueDateValue.draw(at: CGPoint(x: margin + dueDateLabelWidth, y: y), withAttributes: valueAttrs)
        y += 50
        
        return y
    }
    
    private static func drawBillTo(invoice: Invoice, in context: CGContext, yPosition: CGFloat, margin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var y = yPosition
        
        let labelFont = UIFont.systemFont(ofSize: 12, weight: .bold)
        let detailsFont = UIFont.systemFont(ofSize: 11)
        
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: UIColor.black
        ]
        let detailsAttrs: [NSAttributedString.Key: Any] = [
            .font: detailsFont,
            .foregroundColor: UIColor.darkGray
        ]
        
        // "Bill To" label
        let billToLabel = "BILL TO:" as NSString
        billToLabel.draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
        y += 20
        
        // Business name
        let businessName = invoice.businessName as NSString
        businessName.draw(at: CGPoint(x: margin, y: y), withAttributes: detailsAttrs)
        y += 16
        
        // Address
        if let address = invoice.businessAddress {
            let addressText = address as NSString
            addressText.draw(at: CGPoint(x: margin, y: y), withAttributes: detailsAttrs)
            y += 16
        }
        
        // Email
        if let email = invoice.businessEmail {
            let emailText = email as NSString
            emailText.draw(at: CGPoint(x: margin, y: y), withAttributes: detailsAttrs)
            y += 16
        }
        
        // Phone
        if let phone = invoice.businessPhone {
            let phoneText = phone as NSString
            phoneText.draw(at: CGPoint(x: margin, y: y), withAttributes: detailsAttrs)
            y += 16
        }
        
        y += 20
        
        return y
    }
    
    private static func drawLineItems(invoice: Invoice, in context: CGContext, yPosition: CGFloat, margin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var y = yPosition
        
        let headerFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
        let cellFont = UIFont.systemFont(ofSize: 10)
        
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: UIColor.white
        ]
        let cellAttrs: [NSAttributedString.Key: Any] = [
            .font: cellFont,
            .foregroundColor: UIColor.black
        ]
        
        // Table header background - using app's dark blue
        let darkBlue = UIColor(red: 0x1A/255.0, green: 0x1F/255.0, blue: 0x2D/255.0, alpha: 1.0) // #1A1F2D
        context.setFillColor(darkBlue.cgColor)
        context.fill(CGRect(x: margin, y: y, width: contentWidth, height: 25))
        
        // Table headers with better spacing
        let descX = margin + 10
        let qtyX = margin + contentWidth - 180  // More space for description
        let priceX = margin + contentWidth - 120
        let totalX = margin + contentWidth - 60
        
        y += 8
        ("Description" as NSString).draw(at: CGPoint(x: descX, y: y), withAttributes: headerAttrs)
        ("Qty" as NSString).draw(at: CGPoint(x: qtyX, y: y), withAttributes: headerAttrs)
        ("Unit Price" as NSString).draw(at: CGPoint(x: priceX, y: y), withAttributes: headerAttrs)
        ("Total" as NSString).draw(at: CGPoint(x: totalX, y: y), withAttributes: headerAttrs)
        y += 25
        
        // Line items
        for (index, item) in invoice.lineItems.enumerated() {
            // Calculate row height based on description text
            let desc = item.description as NSString
            let descWidth = qtyX - descX - 10
            let descSize = desc.boundingRect(
                with: CGSize(width: descWidth, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: cellAttrs,
                context: nil
            )
            let rowHeight = max(22, descSize.height + 10)
            
            // Alternating row background
            if index % 2 == 0 {
                context.setFillColor(UIColor(white: 0.95, alpha: 1.0).cgColor)
                context.fill(CGRect(x: margin, y: y - 5, width: contentWidth, height: rowHeight))
            }
            
            // Description (using calculated size from above)
            let descRect = CGRect(x: descX, y: y, width: descWidth, height: max(20, descSize.height))
            desc.draw(in: descRect, withAttributes: cellAttrs)
            
            // Quantity
            let qty = String(format: "%.0f", item.quantity) as NSString
            qty.draw(at: CGPoint(x: qtyX, y: y), withAttributes: cellAttrs)
            
            // Unit price
            let price = String(format: "$%.2f", item.unitPrice) as NSString
            price.draw(at: CGPoint(x: priceX, y: y), withAttributes: cellAttrs)
            
            // Total
            let total = String(format: "$%.2f", item.total) as NSString
            total.draw(at: CGPoint(x: totalX, y: y), withAttributes: cellAttrs)
            
            y += rowHeight
        }
        
        // Bottom border
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(1)
        context.move(to: CGPoint(x: margin, y: y))
        context.addLine(to: CGPoint(x: margin + contentWidth, y: y))
        context.strokePath()
        y += 20
        
        return y
    }
    
    private static func drawTotals(invoice: Invoice, in context: CGContext, yPosition: CGFloat, margin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var y = yPosition
        
        let labelFont = UIFont.systemFont(ofSize: 11, weight: .semibold)
        let valueFont = UIFont.systemFont(ofSize: 11)
        let totalFont = UIFont.systemFont(ofSize: 14, weight: .bold)
        
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: UIColor.darkGray
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: UIColor.black
        ]
        let totalAttrs: [NSAttributedString.Key: Any] = [
            .font: totalFont,
            .foregroundColor: UIColor.black
        ]
        
        let labelX = margin + contentWidth - 200
        let valueX = margin + contentWidth - 80
        
        // Subtotal
        let subtotalLabel = "Subtotal:" as NSString
        let subtotalValue = String(format: "$%.2f", invoice.subtotal) as NSString
        subtotalLabel.draw(at: CGPoint(x: labelX, y: y), withAttributes: labelAttrs)
        subtotalValue.draw(at: CGPoint(x: valueX, y: y), withAttributes: valueAttrs)
        y += 20
        
        // Tax
        let taxLabel = String(format: "Tax (%.0f%%):", invoice.taxRate * 100) as NSString
        let taxValue = String(format: "$%.2f", invoice.taxAmount) as NSString
        taxLabel.draw(at: CGPoint(x: labelX, y: y), withAttributes: labelAttrs)
        taxValue.draw(at: CGPoint(x: valueX, y: y), withAttributes: valueAttrs)
        y += 25
        
        // Total line - using app's dark blue
        let darkBlue = UIColor(red: 0x1A/255.0, green: 0x1F/255.0, blue: 0x2D/255.0, alpha: 1.0) // #1A1F2D
        context.setStrokeColor(darkBlue.cgColor)
        context.setLineWidth(2)
        context.move(to: CGPoint(x: labelX - 10, y: y))
        context.addLine(to: CGPoint(x: margin + contentWidth, y: y))
        context.strokePath()
        y += 15
        
        // Total
        let totalLabel = "TOTAL:" as NSString
        let totalValue = String(format: "$%.2f", invoice.total) as NSString
        totalLabel.draw(at: CGPoint(x: labelX, y: y), withAttributes: totalAttrs)
        totalValue.draw(at: CGPoint(x: valueX, y: y), withAttributes: totalAttrs)
        y += 30
        
        return y
    }
    
    private static func drawPaymentInstructions(instructions: String, in context: CGContext, yPosition: CGFloat, margin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var y = yPosition
        
        let labelFont = UIFont.systemFont(ofSize: 11, weight: .bold)
        let textFont = UIFont.systemFont(ofSize: 10)
        
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: UIColor.black
        ]
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: UIColor.darkGray
        ]
        
        // Label
        let label = "PAYMENT INSTRUCTIONS:" as NSString
        label.draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
        y += 18
        
        // Instructions
        let instructionsText = instructions as NSString
        let rect = CGRect(x: margin, y: y, width: contentWidth, height: 100)
        instructionsText.draw(in: rect, withAttributes: textAttrs)
        y += 40
        
        return y
    }
    
    private static func drawNotes(notes: String, in context: CGContext, yPosition: CGFloat, margin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var y = yPosition
        
        let labelFont = UIFont.systemFont(ofSize: 11, weight: .bold)
        let textFont = UIFont.systemFont(ofSize: 10)
        
        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: labelFont,
            .foregroundColor: UIColor.black
        ]
        let textAttrs: [NSAttributedString.Key: Any] = [
            .font: textFont,
            .foregroundColor: UIColor.darkGray
        ]
        
        // Label
        let label = "NOTES:" as NSString
        label.draw(at: CGPoint(x: margin, y: y), withAttributes: labelAttrs)
        y += 18
        
        // Notes
        let notesText = notes as NSString
        let rect = CGRect(x: margin, y: y, width: contentWidth, height: 100)
        notesText.draw(in: rect, withAttributes: textAttrs)
        y += 40
        
        return y
    }
    
    private static func drawFooter(in context: CGContext, pageHeight: CGFloat, margin: CGFloat, contentWidth: CGFloat) {
        let footerFont = UIFont.systemFont(ofSize: 9)
        let footerAttrs: [NSAttributedString.Key: Any] = [
            .font: footerFont,
            .foregroundColor: UIColor.lightGray
        ]
        
        let footerText = "Thank you for your business!" as NSString
        let footerSize = footerText.size(withAttributes: footerAttrs)
        let footerX = margin + (contentWidth - footerSize.width) / 2
        let footerY = pageHeight - 40
        
        footerText.draw(at: CGPoint(x: footerX, y: footerY), withAttributes: footerAttrs)
    }
    
    private static func drawReceiptPhotos(receiptUrls: [String], in context: CGContext, yPosition: CGFloat, margin: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var y = yPosition + 20
        
        // Header
        let headerFont = UIFont.boldSystemFont(ofSize: 14)
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: UIColor.black
        ]
        
        let headerText = "Receipt Photos:" as NSString
        headerText.draw(at: CGPoint(x: margin, y: y), withAttributes: headerAttrs)
        y += 25
        
        // Draw receipt photo placeholders with URLs
        let photoFont = UIFont.systemFont(ofSize: 10)
        let photoAttrs: [NSAttributedString.Key: Any] = [
            .font: photoFont,
            .foregroundColor: UIColor.darkGray
        ]
        
        for (index, receiptUrl) in receiptUrls.enumerated() {
            // Draw receipt box
            let boxRect = CGRect(x: margin, y: y, width: contentWidth, height: 30)
            context.setStrokeColor(UIColor.lightGray.cgColor)
            context.setLineWidth(1.0)
            context.stroke(boxRect)
            
            // Draw receipt info
            let receiptText = "Receipt \(index + 1): Attached (see email attachment)" as NSString
            receiptText.draw(at: CGPoint(x: margin + 10, y: y + 8), withAttributes: photoAttrs)
            
            y += 35
        }
        
        return y
    }
}
