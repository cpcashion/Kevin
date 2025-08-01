const admin = require('firebase-admin');

// Initialize with project ID only (will use Application Default Credentials)
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: 'kevin-ios-app'
  });
}

const db = admin.firestore();

async function fixInvoiceAttachments() {
  console.log('🔧 Fixing invoice message attachments...\n');
  console.log('📍 Project: kevin-ios-app\n');
  
  try {
    // Get all requests
    const requestsSnapshot = await db.collection('requests').get();
    console.log(`📊 Found ${requestsSnapshot.size} requests\n`);
    
    if (requestsSnapshot.size === 0) {
      console.log('⚠️  No requests found. Make sure you have the right Firebase project configured.');
      console.log('💡 Try running: gcloud config set project kevin-ios-app');
      process.exit(1);
    }
    
    let updatedCount = 0;
    let skippedCount = 0;
    let totalMessages = 0;
    
    for (const requestDoc of requestsSnapshot.docs) {
      const messagesSnapshot = await requestDoc.ref.collection('messages').get();
      totalMessages += messagesSnapshot.size;
      
      for (const messageDoc of messagesSnapshot.docs) {
        const message = messageDoc.data();
        
        // Check if this is an INVOICE_DATA message
        if (message.message && message.message.startsWith('INVOICE_DATA:')) {
          console.log(`📝 Found INVOICE_DATA message in request ${requestDoc.id}`);
          
          // Check if already has attachment
          if (message.attachmentUrl) {
            console.log(`   ✓ Already has attachment: ${message.attachmentUrl}`);
            skippedCount++;
            continue;
          }
          
          // Try to extract invoice ID from the message
          const invoiceIdMatch = message.message.match(/"invoiceId":\s*"([^"]+)"/);
          if (!invoiceIdMatch) {
            console.log(`   ⚠️  Could not extract invoice ID, skipping`);
            skippedCount++;
            continue;
          }
          
          const invoiceId = invoiceIdMatch[1];
          console.log(`   📋 Invoice ID: ${invoiceId}`);
          
          // Get the invoice document
          const invoiceDoc = await db.collection('invoices').doc(invoiceId).get();
          if (!invoiceDoc.exists) {
            console.log(`   ⚠️  Invoice ${invoiceId} not found in database, skipping`);
            skippedCount++;
            continue;
          }
          
          const invoice = invoiceDoc.data();
          if (!invoice.pdfUrl) {
            console.log(`   ⚠️  Invoice ${invoiceId} has no pdfUrl, skipping`);
            skippedCount++;
            continue;
          }
          
          // Update the message with attachment URLs
          await messageDoc.ref.update({
            attachmentUrl: invoice.pdfUrl,
            attachmentThumbUrl: invoice.pdfUrl
          });
          
          console.log(`   ✅ Updated with PDF: ${invoice.pdfUrl}`);
          updatedCount++;
        }
      }
    }
    
    console.log('\n📊 Summary:');
    console.log(`   Total messages scanned: ${totalMessages}`);
    console.log(`   Updated: ${updatedCount} messages`);
    console.log(`   Skipped: ${skippedCount} messages`);
    console.log('\n✅ Fix complete!');
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

fixInvoiceAttachments();
