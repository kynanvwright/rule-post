// ──────────────────────────────────────────────────────────────────────────────
// File: src/utils/deep_delete_doc.ts
// Purpose: Delete the document and its subcollections and documents
// ──────────────────────────────────────────────────────────────────────────────
export async function deepDeleteDoc(
  docRef: FirebaseFirestore.DocumentReference,
) {
  const subcollections = await docRef.listCollections();
  for (const subcol of subcollections) {
    const docs = await subcol.listDocuments();
    for (const doc of docs) {
      await deepDeleteDoc(doc); // recurse
    }
  }
  await docRef.delete();
}
