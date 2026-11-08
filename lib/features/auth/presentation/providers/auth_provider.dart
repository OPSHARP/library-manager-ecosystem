import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../../../core/services/auto_backup_service.dart';
import '../../../../core/services/firestore_service.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../library_setup/data/models/library_model.dart';
import '../../../library_setup/data/repositories/library_repository.dart';

class AppUser {
  final String uid;
  final String displayName;
  final String? email;

  const AppUser({
    required this.uid,
    this.displayName = 'Library Owner',
    this.email,
  });
}

Future<void> ensureUserDocInFirestore(String uid, String name, String? email) async {
  try {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final doc = await userRef.get();
    if (!doc.exists) {
      await userRef.set({
        'uid': uid,
        'displayName': name,
        'email': email,
        'role': 'user',
        'isAdmin': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      final updates = <String, dynamic>{
        'displayName': name,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (email != null && email.isNotEmpty) {
        updates['email'] = email;
      }
      await userRef.set(updates, SetOptions(merge: true));
    }
  } catch (_) {}
}

Future<String?> ensureLibraryExists(String uid, String displayName) async {
  try {
    final fs = FirestoreService(uid: uid);
    final repo = LibraryRepository(fs);
    final libraryId = 'lib_$uid';

    LibraryModel? existing;
    try {
      existing = await repo.getLibrarySync(libraryId);
    } catch (_) {
      existing = null;
    }

    if (existing == null) {
      final code = await repo.generateUniqueCode();
      final qrPayload = '{"ownerUid":"$uid","libraryId":"$libraryId","libraryCode":"$code"}';
      final model = LibraryModel(
        libraryId: libraryId,
        ownerId: uid,
        libraryName: "$displayName's Library",
        libraryCode: code,
        qrData: qrPayload,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      try {
        await repo.updateLibrary(libraryId, model);
        await repo.registerLibraryCode(code, uid, libraryId, "$displayName's Library");
      } catch (_) {
        await repo.saveCurrentLibraryId(libraryId);
      }
    } else {
      await repo.saveCurrentLibraryId(libraryId);
      if (existing.libraryCode == null) {
        final code = await repo.generateUniqueCode();
        final qrPayload = '{"ownerUid":"$uid","libraryId":"$libraryId","libraryCode":"$code"}';
        final updated = existing.copyWith(libraryCode: code, qrData: qrPayload);
        await repo.updateLibrary(libraryId, updated);
        await repo.registerLibraryCode(code, uid, libraryId, existing.libraryName,
            contactNumber: existing.contactNumber, address: existing.address);
      }
    }
    return null;
  } catch (_) {
    return null;
  }
}

class AuthNotifier extends StateNotifier<AsyncValue<AppUser?>> {
  AuthNotifier() : super(const AsyncValue.loading()) {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    try {
      // Wait for the first auth state event to ensure the SDK is fully
      // initialized. Bounded by a timeout so the splash can never hang if the
      // SDK stalls.
      final fbUser = await FirebaseAuth.instance
          .authStateChanges()
          .first
          .timeout(const Duration(seconds: 10), onTimeout: () => null);
      if (fbUser == null) {
        state = const AsyncValue.data(null);
        return;
      }

      final uid = fbUser.uid;
      final secureStorage = SecureStorageService.instance;
      final name = fbUser.displayName ??
          await secureStorage.getString('auth_name') ??
          'Library Owner';
      final email = fbUser.email ?? await secureStorage.getString('auth_email');

      // Mark the session loaded IMMEDIATELY so the splash resolves fast.
      // Previously the heavy network/backup work below ran BEFORE this line,
      // which kept `isLoading` true and pinned the whole app on the splash /
      // loading screen (the router redirect sends every route back to /splash
      // while auth is loading). If that work stalled, the app appeared stuck
      // forever. Now it runs in the background and can never gate startup.
      state = AsyncValue.data(
        AppUser(uid: uid, displayName: name, email: email),
      );

      unawaited(_postRestoreWork(uid, name, email));
    } catch (_) {
      state = const AsyncValue.data(null);
    }
  }

  /// Heavy, network-bound startup work — runs in the background so it never
  /// blocks the first frame or the splash screen. Ensures the owner's library
  /// + user documents exist, restores cached profile prefs, and refreshes
  /// backups. Every step is isolated so one failure can never stall the rest.
  Future<void> _postRestoreWork(String uid, String name, String? email) async {
    try {
      await ensureLibraryExists(uid, name);
    } catch (_) {}
    try {
      await ensureUserDocInFirestore(uid, name, email);
    } catch (_) {}

    // Restore profile data from the Firestore library doc → SharedPreferences.
    try {
      final prefs = await SharedPreferences.getInstance();
      final fs = FirestoreService(uid: uid);
      final libDoc = await fs.librariesCol.doc('lib_$uid').get();
      if (libDoc.exists) {
        final data = libDoc.data()!;
        if (data['libraryName'] is String) {
          await prefs.setString('library_name', data['libraryName'] as String);
        }
        if (data['city'] is String) {
          await prefs.setString('city', data['city'] as String);
        }
        if (data['address'] is String) {
          await prefs.setString('address', data['address'] as String);
        }
      }
    } catch (_) {
    }

    try {
      await AutoBackupService.instance.restoreLatestBackup(uid);
    } catch (_) {}
    try {
      AutoBackupService.instance.triggerBackup(uid, force: true);
    } catch (_) {}
  }


  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Enter a valid email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'user-not-found':
        return 'No account found with this email';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password';
      case 'email-already-in-use':
        return 'An account with this email already exists. Sign in instead.';
      case 'weak-password':
        return 'Password must be at least 6 characters';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase Console';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return e.message ?? 'Authentication failed';
    }
  }

  Future<String?> signInWithEmail(String email, String password) async {
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final fbUser = cred.user;
      if (fbUser == null) return 'Authentication failed';

      final secureStorage = SecureStorageService.instance;
      final name = fbUser.displayName ??
          await secureStorage.getString('auth_name') ??
          'Library Owner';
      final userEmail = fbUser.email ?? email.trim();
      final uid = fbUser.uid;

      await secureStorage.saveString('auth_name', name);
      await secureStorage.saveString('auth_email', userEmail);

      await ensureLibraryExists(uid, name);
      await ensureUserDocInFirestore(uid, name, userEmail);
      state = AsyncValue.data(
        AppUser(uid: uid, displayName: name, email: userEmail),
      );
      await AutoBackupService.instance.restoreLatestBackup(uid);
      AutoBackupService.instance.triggerBackup(uid, force: true);
      return null;
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e);
    } catch (e) {
      return 'Sign in failed: ${e.toString()}';
    }
  }

  Future<String?> signUpWithEmail(String email, String password, {String? displayName}) async {
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final fbUser = cred.user;
      if (fbUser == null) return 'Registration failed';

      final name = (displayName != null && displayName.trim().isNotEmpty)
          ? displayName.trim()
          : 'Library Owner';
      try {
        await fbUser.updateDisplayName(name);
      } catch (_) {}

      final secureStorage = SecureStorageService.instance;
      final userEmail = fbUser.email ?? email.trim();
      final uid = fbUser.uid;

      await secureStorage.saveString('auth_name', name);
      await secureStorage.saveString('auth_email', userEmail);

      await ensureLibraryExists(uid, name);
      await ensureUserDocInFirestore(uid, name, userEmail);
      state = AsyncValue.data(
        AppUser(uid: uid, displayName: name, email: userEmail),
      );
      await AutoBackupService.instance.restoreLatestBackup(uid);
      AutoBackupService.instance.triggerBackup(uid, force: true);
      return null;
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e);
    } catch (e) {
      return 'Sign up failed: ${e.toString()}';
    }
  }

  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _authErrorMessage(e);
    } catch (e) {
      return 'Password reset failed: ${e.toString()}';
    }
  }

  Future<String?> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn.instance;
      // In version 7.x, we must first initialize it if it hasn't been initialized, 
      // but if we call it from anywhere, we might need to initialize it.
      // Wait, let's just initialize it in main or here.
      try {
        await googleSignIn.initialize(
          serverClientId: '412683622526-ffmeh219k5q9ruot4rkl1fa90ac9tf3e.apps.googleusercontent.com',
        );
      } catch (_) {
        // already initialized
      }
      
      final googleUser = await googleSignIn.authenticate();
      
      final googleAuth = googleUser.authentication;
      final authz = await googleUser.authorizationClient.authorizationForScopes(['email', 'profile']);

      final credential = GoogleAuthProvider.credential(
        accessToken: authz?.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final fbUser = userCredential.user;
      if (fbUser == null) return 'Failed to authenticate with Google';

      final secureStorage = SecureStorageService.instance;
      final name = fbUser.displayName ?? googleUser.displayName ?? 'Library Owner';
      final email = fbUser.email ?? googleUser.email;
      final uid = fbUser.uid;

      await secureStorage.saveString('auth_name', name);
      await secureStorage.saveString('auth_email', email);

      await ensureLibraryExists(uid, name);
      await ensureUserDocInFirestore(uid, name, email);
      state = AsyncValue.data(
        AppUser(uid: uid, displayName: name, email: email),
      );
      await AutoBackupService.instance.restoreLatestBackup(uid);
      AutoBackupService.instance.triggerBackup(uid, force: true);
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Google Sign-In failed';
    } catch (e) {
      return 'Google Sign-In failed: ${e.toString()}';
    }
  }

  /// Permanently deletes all user data from Firestore, removes auth
  /// credentials, clears local storage, and signs out.
  Future<void> deleteAccount() async {
    final currentUser = state.valueOrNull;
    if (currentUser == null) return;
    final fbUser = FirebaseAuth.instance.currentUser;

    try {
      final fs = FirestoreService(uid: currentUser.uid);
      final prefs = await SharedPreferences.getInstance();

      // 0. Remove public library_registry and registered_libraries entries so the owner's library
      // does not linger in the student Nearby map or code lookup after deletion.
      try {
        final libSnap = await fs.firestore
            .collection('users')
            .doc(currentUser.uid)
            .collection('libraries')
            .get();
        for (final doc in libSnap.docs) {
          final code = doc.data()['libraryCode'] as String?;
          final libId = doc.id;
          if (code != null && code.isNotEmpty) {
            await LibraryRepository(fs).unregisterLibraryCode(code, libraryId: libId);
          } else {
            await FirebaseFirestore.instance
                .collection('registered_libraries')
                .doc(libId)
                .delete();
          }
        }
      } catch (_) {}

      try {
        final regSnap = await FirebaseFirestore.instance
            .collection('registered_libraries')
            .where('ownerUid', isEqualTo: currentUser.uid)
            .get();
        for (final doc in regSnap.docs) {
          await doc.reference.delete();
        }
      } catch (_) {}

      try {
        final regCodeSnap = await FirebaseFirestore.instance
            .collection('library_registry')
            .where('ownerUid', isEqualTo: currentUser.uid)
            .get();
        for (final doc in regCodeSnap.docs) {
          await doc.reference.delete();
        }
      } catch (_) {}

      // 1. Delete all data subcollections under users/{uid}/
      final collections = [
        'students', 'staff', 'seats', 'seat_layouts', 'attendance',
        'fees', 'books', 'book_transactions', 'notifications',
        'libraries', 'settings', 'reports', 'backups',
      ];
      for (final name in collections) {
        try {
          final snap = await fs.firestore
              .collection('users')
              .doc(currentUser.uid)
              .collection(name)
              .get();
          if (snap.docs.isNotEmpty) {
            for (int i = 0; i < snap.docs.length; i += 500) {
              final batch = fs.firestore.batch();
              final chunk = snap.docs.skip(i).take(500);
              for (final doc in chunk) {
                batch.delete(doc.reference);
              }
              await batch.commit();
            }
          }
        } catch (_) {
        }
      }

      final secureStorage = SecureStorageService.instance;
      await secureStorage.clearAll();
      await prefs.clear();

      // 3. Sign out of Google
      try {
        await GoogleSignIn.instance.signOut();
      } catch (_) {
      }
      
      // 4. Delete the Firebase Auth User
      if (fbUser != null) {
        await fbUser.delete();
      }

      // 5. Reset state
      state = const AsyncValue.data(null);
    } catch (_) {
      // Force logout even if deletion partially fails
      final secureStorage = SecureStorageService.instance;
      await secureStorage.clearAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await FirebaseAuth.instance.signOut();
      state = const AsyncValue.data(null);
    }
  }

  /// Update profile in-place without re-running the full session restore.
  /// Also persists changes to Firestore user doc and library doc.
  Future<void> updateProfile({
    required String name,
    String? email,
    String? libraryName,
    String? city,
    String? address,
  }) async {
    final currentUser = state.valueOrNull;
    if (currentUser == null) return;

    final secureStorage = SecureStorageService.instance;
    final prefs = await SharedPreferences.getInstance();
    await secureStorage.saveString('auth_name', name);
    if (email != null && email.isNotEmpty) await secureStorage.saveString('auth_email', email);
    if (libraryName != null) await prefs.setString('library_name', libraryName);
    if (city != null) await prefs.setString('city', city);
    if (address != null) await prefs.setString('address', address);

    try {
      final fbUser = FirebaseAuth.instance.currentUser;
      if (fbUser != null) {
        await fbUser.updateDisplayName(name);
        if (email != null && email.isNotEmpty && email != fbUser.email) {
          await fbUser.verifyBeforeUpdateEmail(email);
        }
      }
    } catch (_) {}

    try {
      final fs = FirestoreService(uid: currentUser.uid);
      final libId = 'lib_${currentUser.uid}';
      final updates = <String, dynamic>{
        'updatedAt': DateTime.now(),
      };
      if (libraryName != null && libraryName.isNotEmpty) updates['libraryName'] = libraryName;
      if (city != null) updates['city'] = city;
      if (address != null) updates['address'] = address;
      await fs.librariesCol.doc(libId).set(updates, SetOptions(merge: true));
    } catch (_) {
    }

    state = AsyncValue.data(
      AppUser(
        uid: currentUser.uid,
        displayName: name,
        email: email ?? currentUser.email,
      ),
    );
    AutoBackupService.instance.triggerBackup(currentUser.uid, force: true);
  }

  Future<void> logout() async {
    try {
      final secureStorage = SecureStorageService.instance;
      await secureStorage.clearAll();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await GoogleSignIn.instance.signOut();
      await FirebaseAuth.instance.signOut();
    } catch (_) {
    }
    state = const AsyncValue.data(null);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AsyncValue<AppUser?>>((
  ref,
) {
  return AuthNotifier();
});

final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authProvider).valueOrNull;
});

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return FirestoreService(uid: 'pending');
  return FirestoreService(uid: user.uid);
});

final isAdminProvider = StreamProvider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(false);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .snapshots()
      .asyncMap((doc) async {
    if (doc.exists && doc.data() != null) {
      final data = doc.data()!;
      if (data['isAdmin'] == true || data['admin'] == true || data['role'] == 'admin') {
        return true;
      }
    }
    if (user.email != null && user.email!.isNotEmpty) {
      try {
        final emailDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.email)
            .get();
        if (emailDoc.exists && emailDoc.data() != null) {
          final data = emailDoc.data()!;
          if (data['isAdmin'] == true || data['admin'] == true || data['role'] == 'admin') {
            return true;
          }
        }
      } catch (_) {}
    }
    return false;
  });
});

final isAdminSyncProvider = Provider<bool>((ref) {
  return ref.watch(isAdminProvider).valueOrNull ?? false;
});
