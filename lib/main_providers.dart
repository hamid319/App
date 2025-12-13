import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/auth_service.dart';
import 'core/services/firestore_service.dart';
import 'core/services/location_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final firestoreServiceProvider = Provider<FirestoreService>((ref) => FirestoreService());
final locationServiceProvider = Provider<LocationService>((ref) => LocationService());
