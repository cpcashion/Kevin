const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// Initialize Admin SDK using local service account if available, else ADC
(() => {
  if (admin.apps.length) return;
  const saPath = path.join(__dirname, 'serviceAccount.json');
  if (fs.existsSync(saPath)) {
    console.log('🔐 Using local serviceAccount.json credentials');
    const serviceAccount = require(saPath);
    admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
  } else {
    console.log('🔐 Using GOOGLE_APPLICATION_CREDENTIALS / Application Default Credentials');
    admin.initializeApp({ credential: admin.credential.applicationDefault() });
  }
})();

const db = admin.firestore();

async function fixInvoiceMessages() {
  console.log('🔧 Starting invoice message fix...\n');
  
  try {
    // Get all invoices
    const invoicesSnapshot = await db.collection('invoices').get();
    console.log(`📊 Found ${invoicesSnapshot.size} invoices\n`);
    
    let updatedCount = 0;
    let skippedCount = 0;
    
    for (const invoiceDoc of invoicesSnapshot.docs) {
      const invoice = invoiceDoc.data();
      const invoiceId = invoiceDoc.id;
      const issueId = invoice.issueId;
      const pdfUrl = invoice.pdfUrl;
      
      if (!issueId) {
        console.log(`⚠️  Invoice ${invoiceId} has no issueId, skipping`);
        skippedCount++;
        continue;
      }
      
      if (!pdfUrl) {
        console.log(`⚠️  Invoice ${invoiceId} has no pdfUrl, skipping`);
        skippedCount++;
        continue;
      }
      
      // Find the INVOICE_DATA message for this invoice
      const messagesSnapshot = await db
        .collection('requests')
        .doc(issueId)
        .collection('messages')
        .where('message', '>=', `INVOICE_DATA:{\n  "invoiceId": "${invoiceId}"`)
        .where('message', '<=', `INVOICE_DATA:{\n  "invoiceId": "${invoiceId}\uffff"`)
        .get();
      
      if (messagesSnapshot.empty) {
        console.log(`⚠️  No message found for invoice ${invoiceId}`);
        skippedCount++;
        continue;
      }
      
      // Update each matching message
      for (const messageDoc of messagesSnapshot.docs) {
        const messageData = messageDoc.data();
        
        // Check if already has attachment
        if (messageData.attachmentUrl) {
          console.log(`✓ Message ${messageDoc.id} already has attachment, skipping`);
          skippedCount++;
          continue;
        }
        
        // Update with attachment URLs
        await messageDoc.ref.update({
          attachmentUrl: pdfUrl,
          attachmentThumbUrl: pdfUrl
        });
        
        console.log(`✅ Updated message ${messageDoc.id} for invoice ${invoice.invoiceNumber}`);
        console.log(`   PDF URL: ${pdfUrl}\n`);
        updatedCount++;
      }
    }
    
    console.log('\n📊 Summary:');
    console.log(`   Updated: ${updatedCount} messages`);
    console.log(`   Skipped: ${skippedCount} messages`);
    console.log('\n✅ Invoice message fix complete!');
    
  } catch (error) {
    console.error('❌ Error fixing invoice messages:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

fixInvoiceMessages();
