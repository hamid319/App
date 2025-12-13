import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<DocumentSnapshot<Map<String, dynamic>>> getDocument(String collection, String docId) {
    return _db.collection(collection).doc(docId).get();
  }

  Future<void> setDocument(String collection, String docId, Map<String, dynamic> data) {
    return _db.collection(collection).doc(docId).set(data);
  }

  Future<void> updateDocument(String collection, String docId, Map<String, dynamic> data) {
    return _db.collection(collection).doc(docId).update(data);
  }

  Future<void> deleteDocument(String collection, String docId) {
    return _db.collection(collection).doc(docId).delete();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> streamCollection(String collection, {int? limit}) {
    final query = limit != null ? _db.collection(collection).limit(limit) : _db.collection(collection);
    return query.snapshots();
  }
}
