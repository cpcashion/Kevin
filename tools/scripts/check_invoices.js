const fs = require('fs');
const path = require('path');
const admin = require('firebase-admin');

// Initialize Admin SDK
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

async function checkInvoices() {
  console.log('🔍 Checking for invoices and invoice messages...\n');
  
  try {
    // Check invoices collection
    const invoicesSnapshot = await db.collection('invoices').get();
    console.log(`📊 Invoices collection: ${invoicesSnapshot.size} documents\n`);
    
    if (invoicesSnapshot.size > 0) {
      invoicesSnapshot.forEach(doc => {
        const data = doc.data();
        console.log(`Invoice ${doc.id}:`);
        console.log(`  Number: ${data.invoiceNumber}`);
        console.log(`  Issue ID: ${data.issueId}`);
        console.log(`  PDF URL: ${data.pdfUrl || 'MISSING'}`);
        console.log(`  Status: ${data.status}`);
        console.log('');
      });
    }
    
    // Check for INVOICE_DATA messages
    console.log('🔍 Searching for INVOICE_DATA messages...\n');
    
    const requestsSnapshot = await db.collection('requests').get();
    console.log(`📊 Found ${requestsSnapshot.size} requests\n`);
    
    let messageCount = 0;
    for (const requestDoc of requestsSnapshot.docs) {
      const messagesSnapshot = await requestDoc.ref.collection('messages').get();
      
      for (const messageDoc of messagesSnapshot.docs) {
        const message = messageDoc.data();
        
        if (message.message && message.message.startsWith('INVOICE_DATA:')) {
          messageCount++;
          console.log(`Found INVOICE_DATA message in request ${requestDoc.id}:`);
          console.log(`  Message ID: ${messageDoc.id}`);
          console.log(`  Message: ${message.message.substring(0, 100)}...`);
          console.log(`  Has attachmentUrl: ${!!message.attachmentUrl}`);
          console.log(`  AttachmentUrl: ${message.attachmentUrl || 'MISSING'}`);
          console.log('');
        }
      }
    }
    
    console.log(`\n📊 Total INVOICE_DATA messages found: ${messageCount}`);
    
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

checkInvoices();
