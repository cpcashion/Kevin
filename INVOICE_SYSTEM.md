# Invoice Generation System

## Overview
The Kevin Maint app now includes a complete invoice generation system that allows admins to create professional PDF invoices and email them to business operators.

## Features

### ✅ Invoice Builder
- **Auto-populate from receipts**: Automatically loads approved receipts as line items
- **Manual line items**: Add custom labor charges, materials, or services
- **Tax calculation**: Automatic tax calculation with configurable rate
- **Payment terms**: Customizable payment instructions and due dates
- **Notes field**: Add custom notes to invoices

### ✅ PDF Generation
- **Professional template**: Clean, branded invoice design
- **Company branding**: Kevin Maint logo and contact information
- **Itemized billing**: Clear line item breakdown with quantities and prices
- **Totals section**: Subtotal, tax, and grand total
- **Payment instructions**: Customizable payment terms and methods

### ✅ Email Integration
- **Native iOS email**: Uses MFMailComposeViewController
- **PDF attachment**: Automatically attaches generated PDF
- **Pre-filled recipient**: Auto-populates business email
- **Professional template**: Pre-written email body with invoice details

### ✅ Firebase Integration
- **Invoice storage**: Invoices saved to Firestore `invoices` collection
- **PDF storage**: PDFs uploaded to Firebase Storage at `invoices/{invoiceId}/invoice.pdf`
- **Receipt linking**: Line items can reference receipt documents
- **Security rules**: Admin-only creation, business owners can view their invoices

## How to Use

### For Admins

1. **Navigate to Issue Detail**
   - Open any issue in the admin dashboard
   - Scroll to "Admin Actions" section

2. **Generate Invoice**
   - Tap "Generate Invoice" button
   - Review auto-populated line items from receipts
   - Add additional line items as needed (labor, materials, etc.)
   - Adjust tax rate if necessary (default 8%)
   - Set due date (default 30 days)
   - Add payment instructions or notes

3. **Preview & Send**
   - Tap "Preview Invoice" to see PDF before sending
   - Tap "Generate & Email Invoice" to create and send
   - PDF is generated and uploaded to Firebase
   - Email composer opens with PDF attached
   - Send email to business operator

### Invoice Number Format
- Format: `INV-YYYYMMDD-XXXX`
- Example: `INV-20241022-1234`
- Automatically generated with date and random suffix

## Data Models

### Invoice
```swift
struct Invoice {
    let id: String
    let invoiceNumber: String
    let issueId: String
    let businessId: String
    let businessName: String
    var lineItems: [InvoiceLineItem]
    let issueDate: Date
    var dueDate: Date
    var taxRate: Double
    var status: InvoiceStatus
    var pdfUrl: String?
}
```

### InvoiceLineItem
```swift
struct InvoiceLineItem {
    let id: String
    var description: String
    var quantity: Double
    var unitPrice: Double
    var receiptId: String?
}
```

### InvoiceStatus
- `draft` - Invoice created but not sent
- `sent` - Invoice emailed to customer
- `paid` - Invoice marked as paid
- `overdue` - Past due date and unpaid
- `cancelled` - Invoice cancelled

## Firebase Collections

### invoices
- **Path**: `/invoices/{invoiceId}`
- **Permissions**: 
  - Create: Admin only
  - Read: Business owners and admins
  - Update/Delete: Admin only

### Firebase Storage
- **Path**: `/invoices/{invoiceId}/invoice.pdf`
- **Permissions**:
  - Upload: Admin only
  - Download: All authenticated users

## Files Created

### Models
- `InvoiceModels.swift` - Invoice data structures

### Services
- `InvoicePDFGenerator.swift` - PDF generation with professional template

### Views
- `InvoiceBuilderView.swift` - Invoice creation UI
- `EmailInvoiceView.swift` - Email composer integration

### Updated Files
- `FirebaseClient.swift` - Added invoice CRUD methods
- `AdminIssueDetailView.swift` - Added "Generate Invoice" button
- `firestore.rules` - Added invoice security rules
- `storage.rules` - Added PDF storage rules

## Future Enhancements

### Potential Features
- [ ] Invoice templates (different styles)
- [ ] Recurring invoices
- [ ] Payment tracking (mark as paid)
- [ ] Invoice history view
- [ ] Bulk invoice generation
- [ ] Custom branding per business
- [ ] Invoice reminders
- [ ] Stripe payment integration
- [ ] Invoice analytics dashboard

## Company Information

Update company details in `InvoicePDFGenerator.swift`:

```swift
private struct CompanyInfo {
    static let name = "Kevin Maint"
    static let address = "Charlotte, NC"
    static let phone = "(555) 123-4567"
    static let email = "billing@kevinmaint.com"
}
```

## Payment Instructions

Default payment instructions can be customized in the invoice builder. Current default:

> Payment due within 30 days. Please make checks payable to Kevin Maint.

## Tax Rate

Default tax rate is 8% but can be adjusted per invoice in the builder UI.

## Testing

### Test Invoice Generation
1. Create a test issue with receipts
2. Open issue in admin view
3. Tap "Generate Invoice"
4. Add line items
5. Preview PDF
6. Test email sending

### Verify Firebase Storage
- Check Firebase Console → Storage → `invoices/` folder
- Verify PDF uploads successfully
- Test PDF download URL

### Verify Firestore
- Check Firebase Console → Firestore → `invoices` collection
- Verify invoice documents created
- Check all fields populated correctly

## Notes

- Email functionality requires device to have email configured
- PDFs are generated client-side using PDFKit (no external API costs)
- Invoice numbers are unique but not sequential (random suffix)
- All invoices are stored permanently in Firebase
- Business operators can view their invoices in the app (future feature)
