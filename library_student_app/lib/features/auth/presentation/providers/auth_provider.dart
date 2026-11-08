import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../data/repositories/auth_repository.dart';
import '../../../../core/services/fcm_service.dart';

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final bool hasProfile;
  final bool hasLibrary;
  final bool isVerifiedStudent;
  final bool requestPending;
  final String? profileId;
  final String? studentUniqueId;
  final String? name;
  final String? email;
  final String? mobile;
  final String? parentMobile;
  final String? address;
  final String? ownerUid;
  final String? libraryId;
  final String? libraryName;
  final String? libraryPhone;
  final String? libraryAddress;
  final bool isJoiningLibrary;
  final bool isLeavingLibrary;
  final bool leaveRequestPending;
  final bool kicked;
  final String? kickMessage;
  final String? error;

  const AuthState({
    this.isLoading = true,
    this.isAuthenticated = false,
    this.hasProfile = false,
    this.hasLibrary = false,
    this.isVerifiedStudent = false,
    this.requestPending = false,
    this.profileId,
    this.studentUniqueId,
    this.name,
    this.email,
    this.mobile,
    this.parentMobile,
    this.address,
    this.ownerUid,
    this.libraryId,
    this.libraryName,
    this.libraryPhone,
    this.libraryAddress,
    this.isJoiningLibrary = false,
    this.isLeavingLibrary = false,
    this.leaveRequestPending = false,
    this.kicked = false,
    this.kickMessage,
    this.error,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    bool? hasProfile,
    bool? hasLibrary,
    bool? isVerifiedStudent,
    bool? requestPending,
    String? profileId,
    String? studentUniqueId,
    String? name,
    String? email,
    String? mobile,
    String? parentMobile,
    String? address,
    String? ownerUid,
    String? libraryId,
    String? libraryName,
    String? libraryPhone,
    String? libraryAddress,
    bool? isJoiningLibrary,
    bool? isLeavingLibrary,
    bool? leaveRequestPending,
    bool? kicked,
    String? kickMessage,
    String? error,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      hasProfile: hasProfile ?? this.hasProfile,
      hasLibrary: hasLibrary ?? this.hasLibrary,
      isVerifiedStudent: isVerifiedStudent ?? this.isVerifiedStudent,
      requestPending: requestPending ?? this.requestPending,
      profileId: profileId ?? this.profileId,
      studentUniqueId: studentUniqueId ?? this.studentUniqueId,
      name: name ?? this.name,
      email: email ?? this.email,
      mobile: mobile ?? this.mobile,
      parentMobile: parentMobile ?? this.parentMobile,
      address: address ?? this.address,
      ownerUid: ownerUid ?? this.ownerUid,
      libraryId: libraryId ?? this.libraryId,
      libraryName: libraryName ?? this.libraryName,
      libraryPhone: libraryPhone ?? this.libraryPhone,
      libraryAddress: libraryAddress ?? this.libraryAddress,
      isJoiningLibrary: isJoiningLibrary ?? this.isJoiningLibrary,
      isLeavingLibrary: isLeavingLibrary ?? this.isLeavingLibrary,
      leaveRequestPending: leaveRequestPending ?? this.leaveRequestPending,
      kicked: kicked ?? this.kicked,
      kickMessage: kickMessage ?? this.kickMessage,
      error: error ?? this.error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repo;
  bool _googleInitialized = false;
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _joinStatusSub;

  AuthNotifier(this._repo) : super(const AuthState()) {
    _init();
  }

  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId: '412683622526-ffmeh219k5q9ruot4rkl1fa90ac9tf3e.apps.googleusercontent.com',
      );
      _googleInitialized = true;
    } catch (_) {
      // already initialized
    }
  }

  void _init() {
    // FirebaseAuth restores a persisted session ASYNCHRONOUSLY on cold start,
    // so reading currentUser once can miss it. React to auth state changes so
    // a returning student lands on the right screen instead of the login one.
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        state = const AuthState(isLoading: false, isAuthenticated: false);
      } else {
        _restoreSession(user);
      }
    });

    // Resolve immediately when the session is already available synchronously.
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) {
      _restoreSession(current);
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _joinStatusSub?.cancel();
    super.dispose();
  }

  bool _isRestoring = false;

  /// Restores the local session when it belongs to the signed-in user.
  /// A session saved by a different account (profileId != user.uid) is
  /// ignored so accounts never leak state between users on one device.
  Future<void> _restoreSession(User user) async {
    if (_isRestoring) return;
    _isRestoring = true;
    try {
      final session = await _repo.getSession();
      final profileId = session['profileId'];
      final studentUniqueId = session['studentUniqueId'];
      final ownerUid = session['ownerUid'];

      if (profileId == user.uid && studentUniqueId != null) {
        final requestPending = session['requestPending'] == 'true';
        final leaveRequestPending = session['leaveRequestPending'] == 'true';
        state = AuthState(
          isLoading: false,
          isAuthenticated: true,
          hasProfile: true,
          hasLibrary: ownerUid != null,
          isVerifiedStudent: ownerUid != null && !requestPending,
          profileId: profileId,
          studentUniqueId: studentUniqueId,
          name: session['name'],
          email: session['email'] ?? user.email,
          mobile: session['mobile'],
          parentMobile: session['parentMobile'],
          address: session['address'],
          requestPending: requestPending,
          leaveRequestPending: leaveRequestPending && ownerUid != null,
          ownerUid: ownerUid,
          libraryId: session['libraryId'],
          libraryName: session['libraryName'],
          libraryPhone: session['libraryPhone'],
          libraryAddress: session['libraryAddress'],
        );
        // NOTE: token registration happens only after verifyStudentId, when
        // the owner's student doc is confirmed to exist. Registering here
        // would be a denied CREATE for students the owner hasn't added yet.
        if (ownerUid != null) {
          // Watch the profile for the owner removing this student (kick) so a
          // cold-started session also auto-leaves when it was removed.
          _watchJoinStatus(ownerUid);
          // One-shot Firestore check on every app start so a student who was
          // kicked while the app was closed is detected immediately, even if
          // the stream subscription hasn't emitted yet.
          unawaited(verifyMembership());
        }
        return;
      }

      // Fallback: Check Firestore for an existing profile (e.g., login on a new device or after logout)
      DocumentSnapshot<Map<String, dynamic>>? doc;
      try {
        // Try cache first for instant login if data exists locally
        doc = await FirebaseFirestore.instance
            .collection('student_profiles')
            .doc(user.uid)
            .get(const GetOptions(source: Source.cache));
      } catch (_) {}

      if (doc == null || !doc.exists) {
        doc = await FirebaseFirestore.instance
            .collection('student_profiles')
            .doc(user.uid)
            .get();
      }

      if (doc.exists) {
        final data = doc.data()!;
        final fetchedUniqueId = data['studentUniqueId'] as String?;
        if (fetchedUniqueId != null) {
          final owner = data['currentOwnerUid'] as String?;
          final lib = data['currentLibraryId'] as String?;
          final verifiedOwner = data['verifiedOwnerUid'] as String?;
          final pending = owner != null && verifiedOwner != owner;

          String? libName;
          if (owner != null && data['joinedLibraries'] is List) {
            final joined = data['joinedLibraries'] as List;
            for (final j in joined) {
              if (j is Map && j['ownerUid'] == owner) {
                libName = j['libraryName'] as String?;
                break;
              }
            }
          }

          await _repo.saveSession(
            profileId: user.uid,
            studentUniqueId: fetchedUniqueId,
            name: data['name'] as String?,
            email: data['email'] as String? ?? user.email,
            mobile: data['mobile'] as String?,
            parentMobile: data['parentMobile'] as String?,
            address: data['address'] as String?,
            requestPending: pending,
            ownerUid: owner,
            libraryId: lib,
            libraryName: libName,
          );

          state = AuthState(
            isLoading: false,
            isAuthenticated: true,
            hasProfile: true,
            hasLibrary: owner != null,
            isVerifiedStudent: owner != null && !pending,
            profileId: user.uid,
            studentUniqueId: fetchedUniqueId,
            name: data['name'] as String?,
            email: data['email'] as String? ?? user.email,
            mobile: data['mobile'] as String?,
            parentMobile: data['parentMobile'] as String?,
            address: data['address'] as String?,
            requestPending: pending,
            ownerUid: owner,
            libraryId: lib,
            libraryName: libName,
          );
          
          if (owner != null && pending) {
            _watchJoinStatus(owner);
          }
          return;
        }
      }

      // Authenticated but no local profile yet, and not found in Firestore.
      state = AuthState(
        isLoading: false,
        isAuthenticated: true,
        hasProfile: false,
        name: user.displayName,
        email: user.email,
      );
    } catch (_) {
      state = const AuthState(isLoading: false, isAuthenticated: true, hasProfile: false);
    } finally {
      _isRestoring = false;
    }
  }

  Future<String?> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _restoreSession(cred.user!);
      return null;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _authErrorMessage(e));
      return _authErrorMessage(e);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Something went wrong');
      return 'Something went wrong';
    }
  }

  Future<String?> signUpWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _restoreSession(cred.user!);
      return null;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _authErrorMessage(e));
      return _authErrorMessage(e);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Something went wrong');
      return 'Something went wrong';
    }
  }

  Future<String?> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _ensureGoogleInitialized();
      final googleSignIn = GoogleSignIn.instance;
      final googleUser = await googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;
      String? accessToken;
      try {
        final authz = await googleUser.authorizationClient.authorizationForScopes(['email', 'profile']);
        accessToken = authz?.accessToken;
      } catch (e) {
        debugPrint('authorizationForScopes error (non-fatal): $e');
      }

      if (googleAuth.idToken == null && accessToken == null) {
        state = state.copyWith(isLoading: false, error: 'Could not obtain Google authentication tokens.');
        return 'Could not obtain Google authentication tokens.';
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = cred.user;
      if (user == null) {
        state = state.copyWith(isLoading: false, error: 'Failed to authenticate with Google');
        return 'Failed to authenticate with Google';
      }
      await _restoreSession(user);
      return null;
    } on GoogleSignInException catch (e) {
      final isCanceled = e.code == GoogleSignInExceptionCode.canceled;
      state = state.copyWith(isLoading: false, error: isCanceled ? null : 'Google sign-in failed');
      return isCanceled ? 'Google sign-in cancelled' : 'Google sign-in failed';
    } on FirebaseAuthException catch (e) {
      final msg = _authErrorMessage(e);
      state = state.copyWith(isLoading: false, error: msg);
      return msg;
    } catch (e) {
      final isCanceled = e.toString().toLowerCase().contains('cancel');
      final msg = isCanceled ? 'Google sign-in cancelled' : 'Google sign-in failed';
      state = state.copyWith(isLoading: false, error: isCanceled ? null : msg);
      return msg;
    }
  }

  Future<String?> resetPassword(String email) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
      state = state.copyWith(isLoading: false, error: null);
      return null;
    } on FirebaseAuthException catch (e) {
      state = state.copyWith(isLoading: false, error: _authErrorMessage(e));
      return _authErrorMessage(e);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Something went wrong');
      return 'Something went wrong';
    }
  }

  String _authErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Enter a valid email address';
      case 'user-not-found':
        return 'No account found with this email. Create an account first.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password';
      case 'email-already-in-use':
        return 'An account with this email already exists. Sign in instead.';
      case 'weak-password':
        return 'Password must be at least 6 characters';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return e.message ?? 'Something went wrong';
    }
  }

  /// Lightweight guard: ensures a Firebase user exists before invoking a
  /// callable. The Functions SDK attaches the ID token automatically — no
  /// forced refresh is needed (that used to add a slow network round-trip on
  /// every save).
  Future<String?> _ensureFreshAuth() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return 'Your session has expired. Please sign in again.';
    }
    return null;
  }

  Future<String?> createProfile({
    required String name,
    required String mobile,
    required String parentMobile,
    required String address,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return 'Sign in to create your profile';

      final authGuard = await _ensureFreshAuth();
      if (authGuard != null) {
        state = state.copyWith(isLoading: false, error: authGuard);
        return authGuard;
      }

      final profileId = user.uid;
      final email = user.email ?? '';

      // Profile creation is handled SERVER-SIDE (createStudentProfile Cloud
      // Function) — the unique student ID is generated and the document is
      // written by the server. The client never writes to Firestore directly.
      final fn = FirebaseFunctions.instance.httpsCallable('createStudentProfile');
      final res = await fn.call<Map<String, dynamic>>({
        'name': name.trim(),
        'email': email,
        'mobile': mobile.trim(),
        'parentMobile': parentMobile.trim(),
        'address': address.trim(),
      });
      final studentUniqueId = (res.data['studentUniqueId'] as String?) ?? '';

      await _repo.saveSession(profileId: profileId, studentUniqueId: studentUniqueId,
          name: name.trim(), email: email, mobile: mobile.trim(), parentMobile: parentMobile.trim(), address: address.trim());

      state = AuthState(
        isLoading: false,
        isAuthenticated: true,
        hasProfile: true,
        hasLibrary: false,
        profileId: profileId,
        studentUniqueId: studentUniqueId,
        name: name.trim(),
        email: email,
        mobile: mobile.trim(),
        parentMobile: parentMobile.trim(),
        address: address.trim(),
      );
      return null;
    } on FirebaseFunctionsException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Something went wrong',
      );
      return e.message ?? 'Something went wrong';
    } on FirebaseException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Something went wrong',
      );
      return e.message ?? 'Something went wrong';
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Something went wrong');
      return 'Something went wrong';
    }
  }

  /// Updates the student's own profile (name, mobile, parent mobile, address)
  /// both in Firestore (`student_profiles/{profileId}` — the doc the student
  /// owns) and in the local secure session. The owner's verified registry copy
  /// under `users/{ownerUid}/students` is intentionally left untouched.
  Future<String?> updateProfile({
    required String name,
    required String mobile,
    required String parentMobile,
    required String address,
  }) async {
    final profileId = state.profileId;
    final studentUniqueId = state.studentUniqueId;
    if (profileId == null || studentUniqueId == null) {
      return 'Create your profile first';
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final authGuard = await _ensureFreshAuth();
      if (authGuard != null) {
        state = state.copyWith(isLoading: false, error: authGuard);
        return authGuard;
      }

      // Profile updates are handled SERVER-SIDE (updateStudentProfile Cloud
      // Function) — the client never writes to Firestore directly.
      final fn = FirebaseFunctions.instance.httpsCallable('updateStudentProfile');
      await fn.call({
        'name': name.trim(),
        'mobile': mobile.trim(),
        'parentMobile': parentMobile.trim(),
        'address': address.trim(),
      });

      await _repo.saveSession(
        profileId: profileId,
        studentUniqueId: studentUniqueId,
        name: name.trim(),
        mobile: mobile.trim(),
        parentMobile: parentMobile.trim(),
        address: address.trim(),
      );

      state = state.copyWith(
        isLoading: false,
        name: name.trim(),
        mobile: mobile.trim(),
        parentMobile: parentMobile.trim(),
        address: address.trim(),
        error: null,
      );
      return null;
    } on FirebaseFunctionsException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Something went wrong',
      );
      return e.message ?? 'Something went wrong';
    } on FirebaseException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Something went wrong',
      );
      return e.message ?? 'Something went wrong';
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Something went wrong');
      return 'Something went wrong';
    }
  }

  /// Connects the student to a library (via QR scan or library code).
  ///
  /// This only saves the library's PUBLIC information (name, contact,
  /// address) so the student can browse seats and the book catalog. The
  /// owner must register the student (using the student's unique ID) before
  /// the student can see their personal fees/books/attendance/seat — see
  /// [verifyStudentId].
  Future<String?> joinLibrary({
    required String ownerUid,
    required String libraryId,
    required String libraryName,
    String? phone,
    String? address,
  }) async {
    if (!state.hasProfile || state.profileId == null || state.studentUniqueId == null) {
      return 'Create your profile first';
    }

    // Guard against double-joining the library the student is already in.
    if (state.ownerUid == ownerUid) {
      if (state.requestPending) {
        return 'You already sent a join request to this library.';
      }
      return 'You are already a member of this library.';
    }

    final authGuard = await _ensureFreshAuth();
    if (authGuard != null) return authGuard;
    state = state.copyWith(isJoiningLibrary: true);
    try {
      // Joining is handled SERVER-SIDE (sendJoinRequest Cloud Function).
      // The owner must approve the request before the student becomes verified.
      final fn = FirebaseFunctions.instance.httpsCallable('sendJoinRequest');
      await fn.call<Map<String, dynamic>>({
        'ownerUid': ownerUid,
        'libraryId': libraryId,
        'libraryName': libraryName,
        'phone': phone,
        'address': address,
      });
      
      // In the pending state, the library name might just be the scanned one
      final resolvedName = libraryName;

      await _repo.saveSession(
        profileId: state.profileId!,
        studentUniqueId: state.studentUniqueId!,
        name: state.name,
        email: state.email,
        mobile: state.mobile,
        parentMobile: state.parentMobile,
        address: state.address,
        requestPending: true,
        ownerUid: ownerUid,
        libraryId: libraryId,
        libraryName: resolvedName,
        libraryPhone: phone,
        libraryAddress: address,
      );

      state = state.copyWith(
        isJoiningLibrary: false,
        hasLibrary: true,
        isVerifiedStudent: false,
        requestPending: true,
        ownerUid: ownerUid,
        libraryId: libraryId,
        libraryName: resolvedName,
        libraryPhone: phone,
        libraryAddress: address,
      );
      // Wait for the owner to accept the join request before unlocking the
      // student's personal data — watch the profile doc server-side linkage.
      _watchJoinStatus(ownerUid);
      return null;
    } on FirebaseFunctionsException catch (e) {
      state = state.copyWith(
        isJoiningLibrary: false,
        error: e.message ?? 'Failed to join library',
      );
      return e.message ?? 'Failed to join library';
    } catch (_) {
      state = state.copyWith(isJoiningLibrary: false, error: 'Failed to join library');
      return 'Failed to join library';
    }
  }

  /// Watches the student's profile doc for the owner's acceptance of a join
  /// request. `sendJoinRequest` links the student publicly so seats/location
  /// are visible while pending; when the owner accepts (acceptJoinRequest
  /// writes verifiedOwnerUid server-side), the student becomes a full member.
  void _watchJoinStatus(String ownerUid) {
    final uid = state.profileId;
    if (uid == null) return;
    _joinStatusSub?.cancel();
    _joinStatusSub = FirebaseFirestore.instance
        .collection('student_profiles')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      if (data == null) return;

      // Acceptance path: the owner approved the join request.
      if (data['verifiedOwnerUid'] == ownerUid && state.requestPending) {
        state = state.copyWith(
          requestPending: false,
          isVerifiedStudent: true,
          error: null,
        );
        if (state.ownerUid != null && state.studentUniqueId != null) {
          unawaited(FcmService.instance
              .registerToken(state.ownerUid!, state.studentUniqueId!));
        }
        return;
      }

      // Kick path: the owner removed the library linkage for a student who is
      // currently a member. Auto-leave the library so the portal reflects it.
      final currentOwner = data['currentOwnerUid'];
      if (!state.requestPending &&
          state.ownerUid != null &&
          (currentOwner == null || currentOwner.toString() != state.ownerUid)) {
        _handleKicked(wasLeaveRequest: state.leaveRequestPending);
      }
    });
  }

  /// Handles the owner removing the student from a library (kick, or an
  /// approved leave request). Clears the local library linkage and flags the
  /// UI to show a "removed / approved" notice.
  Future<void> _handleKicked({bool wasLeaveRequest = false}) async {
    final wasJoined = state.hasLibrary;
    final removedUid = state.studentUniqueId;
    final libName = state.libraryName ?? 'the library';

    _joinStatusSub?.cancel();
    // Use the current owner uid captured below before it is cleared.
    final removedOwner = state.ownerUid;
    if (removedOwner != null && removedUid != null) {
      unawaited(FcmService.instance.unregisterToken(removedOwner, removedUid));
    }
    await _repo.clearLibrarySession();
    state = state.copyWith(
      hasLibrary: false,
      isVerifiedStudent: false,
      requestPending: false,
      leaveRequestPending: false,
      ownerUid: null,
      libraryId: null,
      libraryName: null,
      libraryPhone: null,
      libraryAddress: null,
      kicked: wasJoined,
      kickMessage: wasJoined
          ? (wasLeaveRequest
              ? 'Your leave request was approved by the library owner.'
              : 'You were removed from "$libName" by the library owner.')
          : null,
    );
  }

  /// Marks the student as joined (called when the dashboard detects the
  /// owner accepted while the app was closed, so the pending state clears).
  Future<void> markJoined() async {
    _joinStatusSub?.cancel();
    if (state.profileId == null || state.studentUniqueId == null) return;
    if (state.ownerUid != null && state.studentUniqueId != null) {
      unawaited(FcmService.instance
          .registerToken(state.ownerUid!, state.studentUniqueId!));
    }
    await _repo.saveSession(
      profileId: state.profileId!,
      studentUniqueId: state.studentUniqueId!,
      requestPending: false,
      ownerUid: state.ownerUid,
      libraryId: state.libraryId,
      libraryName: state.libraryName,
      libraryPhone: state.libraryPhone,
      libraryAddress: state.libraryAddress,
    );
    state = state.copyWith(
      requestPending: false,
      isVerifiedStudent: true,
      error: null,
    );
  }

  /// Clears the "kicked/removed" notice after the UI has shown it once.
  void acknowledgeKick() {
    state = state.copyWith(kicked: false, kickMessage: null);
    _joinStatusSub?.cancel();
  }

  /// One-shot Firestore membership check, run on app restart and on every
  /// pull-to-refresh. Verifies the student is STILL registered + active in the
  /// owner's library. If the owner kicked/deleted/left the student while the
  /// app was closed, this triggers the same auto-leave as the live watcher so
  /// the dashboard can never keep showing a stale joined state.
  Future<void> verifyMembership() async {
    final ownerUid = state.ownerUid;
    final studentUniqueId = state.studentUniqueId;
    if (ownerUid == null || studentUniqueId == null) return;
    if (state.requestPending || state.leaveRequestPending) return;
    try {
      // 1) The owner's registry doc is the source of truth for membership.
      final studentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(ownerUid)
          .collection('students')
          .doc(studentUniqueId)
          .get(const GetOptions(source: Source.server));
      if (!studentDoc.exists) {
        await _handleKicked(wasLeaveRequest: state.leaveRequestPending);
        return;
      }
      final data = studentDoc.data() ?? const <String, dynamic>{};
      if (data['isActive'] == false ||
          (data['status'] is String &&
              data['status'] == 'left')) {
        await _handleKicked(wasLeaveRequest: state.leaveRequestPending);
        return;
      }
    } on FirebaseException catch (e) {
      // permission-denied / not-found → the student record is gone → kicked.
      if (e.code == 'permission-denied' || e.code == 'not-found') {
        await _handleKicked(wasLeaveRequest: state.leaveRequestPending);
      }
    } catch (_) {
      // Offline or transient error — keep current state; the live watcher and
      // next refresh will re-verify.
    }
  }

  /// Verifies the student against the owner's registry using the student's
  /// unique ID (the one the owner entered when adding the student).
  ///
  /// When verified, the student's personal data (fees, books, attendance,
  /// seat) is unlocked on the dashboard. Otherwise the dashboard stays in
  /// public mode (seats + library info only).
  Future<String?> verifyStudentId(String uniqueId) async {
    final code = uniqueId.trim().toUpperCase();
    if (code.isEmpty || state.ownerUid == null) {
      return 'Enter your unique student ID';
    }
    if (!state.hasProfile || state.profileId == null) {
      return 'Create your profile first';
    }
    final authGuard = await _ensureFreshAuth();
    if (authGuard != null) {
      state = state.copyWith(isLoading: false, error: authGuard);
      return authGuard;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      // Verification + device binding happen SERVER-SIDE (verifyStudentId
      // Cloud Function) — the student's record can no longer be claimed by
      // writing authUid directly from the client.
      final fn = FirebaseFunctions.instance.httpsCallable('verifyStudentId');
      final res = await fn.call<Map<String, dynamic>>({
        'ownerUid': state.ownerUid!,
        'studentUniqueId': code,
      });
      final data = res.data;
      final studentName = (data['name'] as String?) ?? state.name;

      // No longer waiting on a request — stop the acceptance watcher.
      _joinStatusSub?.cancel();

      await _repo.saveSession(
        profileId: state.profileId!,
        studentUniqueId: code,
        name: state.name,
        email: state.email,
        mobile: state.mobile,
        parentMobile: state.parentMobile,
        address: state.address,
        requestPending: false,
        ownerUid: state.ownerUid,
        libraryId: state.libraryId,
        libraryName: studentName ?? state.libraryName,
        libraryPhone: state.libraryPhone,
        libraryAddress: state.libraryAddress,
      );

      state = state.copyWith(
        isLoading: false,
        isVerifiedStudent: true,
        requestPending: false,
        studentUniqueId: code,
        name: studentName,
        error: null,
      );
      // Verified against this library → register this device for its pushes.
      unawaited(FcmService.instance.registerToken(state.ownerUid!, code));
      return null;
    } on FirebaseFunctionsException catch (e) {
      state = state.copyWith(
        isLoading: false,
        isVerifiedStudent: false,
        error: e.message ?? 'Something went wrong',
      );
      return e.message ?? 'Something went wrong';
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Something went wrong');
      return 'Something went wrong';
    }
  }

  /// Reads a library's public document fields (seat capacity, available seats,
  /// facilities, currency) — used by the QR scan flow for a rich preview.
  Future<Map<String, dynamic>?> fetchLibraryDoc(String? ownerUid, String? libraryId) {
    return _repo.fetchLibraryDoc(ownerUid, libraryId);
  }

  /// Looks up a library by its code in the registry and returns the data
  /// WITHOUT automatically joining. Returns null on error (with state.error
  /// set for UI to show).
  Future<Map<String, dynamic>?> lookupLibraryByCode(String code) async {    state = state.copyWith(isLoading: true, error: null);
    try {
      final registry = await _repo.searchLibraryByCode(code);
      if (registry == null) {
        state = state.copyWith(isLoading: false, error: 'Library not found');
        return null;
      }
      state = state.copyWith(isLoading: false);
      return registry;
    } on FirebaseException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Something went wrong',
      );
      return null;
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Something went wrong');
      return null;
    }
  }

  Future<String?> searchLibraryByCode(String code) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final registry = await _repo.searchLibraryByCode(code);
      if (registry == null) {
        state = state.copyWith(isLoading: false, error: 'Library not found');
        return 'Library not found';
      }
      final ownerUid = registry['ownerUid'] as String?;
      final libraryId = registry['libraryId'] as String?;
      final libraryName = registry['libraryName'] as String? ?? 'Library';
      final contactNumber = registry['contactNumber'] as String?;
      final address = registry['address'] as String?;

      if (ownerUid == null || libraryId == null) {
        state = state.copyWith(isLoading: false, error: 'Invalid code');
        return 'Invalid code';
      }

      state = state.copyWith(
        isLoading: false,
        ownerUid: ownerUid,
        libraryId: libraryId,
        libraryName: libraryName,
        libraryPhone: contactNumber,
        libraryAddress: address,
      );
      return await joinLibrary(
        ownerUid: ownerUid,
        libraryId: libraryId,
        libraryName: libraryName,
        phone: contactNumber,
        address: address,
      );
    } on FirebaseException catch (e) {
      // Registry lookup threw — surface the real cause instead of a generic
      // "Something went wrong". The common cause is the Firestore rules not
      // being deployed yet (anonymous students must be allowed to READ
      // /library_registry — see firebase/firestore.rules).
      state = state.copyWith(
        isLoading: false,
        error: e.message ?? 'Something went wrong',
      );
      if (e.code == 'permission-denied') {
        return 'Access denied while looking up this code. The library-registry read rules need to be deployed (firebase deploy --only firestore:rules) and the App Check debug token registered.';
      }
      return e.message ?? 'Something went wrong';
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Something went wrong');
      return 'Something went wrong';
    }
  }

  /// Full sign-out: clears the local session and signs out of Firebase Auth
  /// (and Google), returning the user to the auth screen.
  Future<void> logout() async {
    if (state.ownerUid != null && state.studentUniqueId != null) {
      unawaited(FcmService.instance.unregisterToken(state.ownerUid!, state.studentUniqueId!));
    }
    _joinStatusSub?.cancel();
    await _repo.clearSession();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
    state = const AuthState(isLoading: false, isAuthenticated: false);
  }

  /// Leaves the current library but keeps the account + profile so the
  /// student can rejoin another library without signing in again.
  Future<void> leaveLibrary() async {
    if (state.ownerUid != null && state.studentUniqueId != null) {
      unawaited(FcmService.instance.unregisterToken(state.ownerUid!, state.studentUniqueId!));
    }
    _joinStatusSub?.cancel();
    await _repo.clearLibrarySession();
    state = state.copyWith(
      hasLibrary: false,
      isVerifiedStudent: false,
      requestPending: false,
      leaveRequestPending: false,
      ownerUid: null,
      libraryId: null,
      libraryName: null,
      libraryPhone: null,
      libraryAddress: null,
    );
  }

  /// Requests permission to leave the library. The OWNER must approve the
  /// request — the student cannot leave on their own. While pending the
  /// student stays a member; the request is tracked locally so the dashboard
  /// can show a "pending approval" banner.
  Future<String?> requestLibraryLeave() async {
    if (!state.hasLibrary || state.ownerUid == null) {
      return 'You are not a member of any library.';
    }
    if (state.leaveRequestPending) {
      return 'Leave request already sent. Waiting for the owner to approve.';
    }
    state = state.copyWith(isLeavingLibrary: true, error: null);
    try {
      await FirebaseFunctions.instance
          .httpsCallable('requestLibraryLeave')
          .call();
      state = state.copyWith(isLeavingLibrary: false, leaveRequestPending: true);
      if (state.profileId != null && state.studentUniqueId != null) {
        await _repo.saveSession(
          profileId: state.profileId!,
          studentUniqueId: state.studentUniqueId!,
          ownerUid: state.ownerUid,
          libraryId: state.libraryId,
          libraryName: state.libraryName,
          libraryPhone: state.libraryPhone,
          libraryAddress: state.libraryAddress,
          leaveRequestPending: true,
        );
      }
      return null;
    } on FirebaseFunctionsException catch (e) {
      state = state.copyWith(isLeavingLibrary: false, error: e.message);
      return e.message ?? 'Could not send the leave request.';
    } catch (_) {
      state = state.copyWith(isLeavingLibrary: false, error: 'Could not send the leave request.');
      return 'Could not send the leave request. Please try again.';
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return AuthNotifier(repo);
});
