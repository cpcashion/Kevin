// Firebase Admin Script to Delete Problematic Issue
// Run this in Firebase Console or with Firebase Admin SDK

// The problematic issue ID from the crash logs
const problematicIssueId = "1E3A3988-8EB0-4FEF-9D60-521D119CA69E";

// Delete the issue and all related data
async function deleteProblematicIssue() {
  try {
    console.log(`Deleting issue: ${problematicIssueId}`);
    
    // Delete the main issue document
    await db.collection('issues').doc(problematicIssueId).delete();
    console.log('✅ Deleted main issue document');
    
    // Delete related issue photos
    const issuePhotos = await db.collection('issuePhotos')
      .where('issueId', '==', problematicIssueId)
      .get();
    
    for (const doc of issuePhotos.docs) {
      await doc.ref.delete();
      console.log(`✅ Deleted issue photo: ${doc.id}`);
    }
    
    // Delete related work logs
    const workLogs = await db.collection('workLogs')
      .where('issueId', '==', problematicIssueId)
      .get();
    
    for (const doc of workLogs.docs) {
      await doc.ref.delete();
      console.log(`✅ Deleted work log: ${doc.id}`);
    }
    
    // Delete related receipts
    const receipts = await db.collection('receipts')
      .where('issueId', '==', problematicIssueId)
      .get();
    
    for (const doc of receipts.docs) {
      await doc.ref.delete();
      console.log(`✅ Deleted receipt: ${doc.id}`);
    }
    
    // Delete related work orders
    const workOrders = await db.collection('workOrders')
      .where('issueId', '==', problematicIssueId)
      .get();
    
    for (const doc of workOrders.docs) {
      await doc.ref.delete();
      console.log(`✅ Deleted work order: ${doc.id}`);
    }
    
    console.log('🎉 Successfully deleted all data for problematic issue');
    
  } catch (error) {
    console.error('❌ Error deleting issue:', error);
  }
}

// Run the deletion
deleteProblematicIssue();

// Alternative: Delete ALL issues with empty IDs (nuclear option)
async function deleteAllIssuesWithEmptyIds() {
  try {
    console.log('🔍 Finding all issues with empty or missing IDs...');
    
    const allIssues = await db.collection('issues').get();
    let deletedCount = 0;
    
    for (const doc of allIssues.docs) {
      const data = doc.data();
      const idField = data.id;
      
      // Delete if id field is empty, null, or missing
      if (!idField || idField === '' || idField === null) {
        console.log(`🗑️ Deleting issue with empty ID: ${doc.id}`);
        await doc.ref.delete();
        deletedCount++;
      }
    }
    
    console.log(`🎉 Deleted ${deletedCount} issues with empty IDs`);
    
  } catch (error) {
    console.error('❌ Error deleting issues with empty IDs:', error);
  }
}

// Uncomment the line below to run the nuclear option
// deleteAllIssuesWithEmptyIds();
