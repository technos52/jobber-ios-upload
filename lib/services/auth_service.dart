import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../utils/user_role_storage.dart';
import '../firebase_options.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: defaultTargetPlatform == TargetPlatform.iOS
        ? DefaultFirebaseOptions.ios.iosClientId
        : null,
  );
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Current user getter
  static User? get currentUser => _auth.currentUser;

  // Account deletion
  static Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final email = user.email;
      final uid = user.uid;

      // 1. Delete Firestore records
      if (email != null) {
        final candidateQuery = await _firestore
            .collection('candidates')
            .where('email', isEqualTo: email)
            .get();
        for (var doc in candidateQuery.docs) {
          await doc.reference.delete();
        }
      }

      await _firestore.collection('employers').doc(uid).delete();

      // 2. Delete Firebase Auth user
      await user.delete();
      
      // 3. Sign out from Google if necessary
      await _googleSignIn.signOut();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception('SECURITY_REAUTH_REQUIRED');
      }
      rethrow;
    } catch (e) {
      debugPrint('Error deleting account: $e');
      rethrow;
    }
  }

  // Auth state changes stream
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Anonymous sign-in for guests/reviewers
  static Future<UserCredential?> signInAnonymously() async {
    try {
      final credential = await _auth.signInAnonymously();
      return credential;
    } catch (e) {
      debugPrint('Error signing in anonymously: $e');
      rethrow;
    }
  }

  // Signed‑in check
  static bool get isSignedIn => _auth.currentUser != null;

  // -----------------------------------------------------------------
  // Enhanced duplicate prevention for employer registration
  // -----------------------------------------------------------------
  static Future<bool> canCreateEmployerAccount(String email, String uid) async {
    try {
      // Check if candidate exists with this email
      final candidateQuery = await _firestore
          .collection('candidates')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (candidateQuery.docs.isNotEmpty) {
        debugPrint('🚫 Candidate account already exists with email: $email');
        return false;
      }

      // Check if employer exists with this email but different UID
      final employerQuery = await _firestore
          .collection('employers')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (employerQuery.docs.isNotEmpty) {
        final existingEmployer = employerQuery.docs.first;
        if (existingEmployer.id != uid) {
          debugPrint(
            '🚫 Employer account already exists with email: $email (different UID)',
          );
          return false;
        }
      }

      // Check if employer exists with this UID but different email
      final employerDoc = await _firestore
          .collection('employers')
          .doc(uid)
          .get();

      if (employerDoc.exists) {
        final data = employerDoc.data()!;
        final existingEmail = data['email'] as String?;
        if (existingEmail != null && existingEmail != email) {
          debugPrint(
            '🚫 UID already associated with different email: $existingEmail',
          );
          return false;
        }
      }

      debugPrint('✅ Can create employer account for email: $email, UID: $uid');
      return true;
    } catch (e) {
      debugPrint('❌ Error checking employer account eligibility: $e');
      return false;
    }
  }

  // -----------------------------------------------------------------
  // Role conflict detection
  // -----------------------------------------------------------------
  // Returns true if the signed‑in user has both a candidate and an employer record.
  static Future<bool> _hasRoleConflict(User user) async {
    try {
      // Employer record is stored by UID
      final employerDoc = await _firestore
          .collection('employers')
          .doc(user.uid)
          .get();
      final hasEmployer = employerDoc.exists;

      // Candidate record is stored by email
      bool hasCandidate = false;
      final email = user.email;
      if (email != null) {
        final candidateQuery = await _firestore
            .collection('candidates')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        hasCandidate = candidateQuery.docs.isNotEmpty;
      }
      return hasEmployer && hasCandidate;
    } catch (e) {
      debugPrint('Error checking role conflict: $e');
      // If we cannot determine, treat as no conflict to avoid blocking login.
      return false;
    }
  }

  // -----------------------------------------------------------------
  // Enhanced duplicate prevention for candidate registration
  // -----------------------------------------------------------------
  static Future<bool> canCreateCandidateAccount(
    String email,
    String uid,
  ) async {
    try {
      // Check if employer exists with this email
      final employerQuery = await _firestore
          .collection('employers')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (employerQuery.docs.isNotEmpty) {
        debugPrint('🚫 Employer account already exists with email: $email');
        return false;
      }

      // Check if candidate exists with this email but different UID
      final candidateQuery = await _firestore
          .collection('candidates')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (candidateQuery.docs.isNotEmpty) {
        final existingCandidate = candidateQuery.docs.first;
        // For candidates, we need to check if it's truly a different user
        // Since candidates use mobile number as doc ID, we check UID in the document
        final candidateData = existingCandidate.data();
        final existingUid = candidateData['uid'] as String?;
        if (existingUid != null && existingUid != uid) {
          debugPrint(
            '🚫 Candidate account already exists with email: $email (different UID)',
          );
          return false;
        }
      }

      debugPrint('✅ Can create candidate account for email: $email, UID: $uid');
      return true;
    } catch (e) {
      debugPrint('❌ Error checking candidate account eligibility: $e');
      return false;
    }
  }

  // -----------------------------------------------------------------
  // Sign‑in with Apple for candidates
  // -----------------------------------------------------------------
  static Future<UserCredential?> signInWithAppleForCandidate() async {
    try {
      debugPrint('🔍 Starting Sign-In with Apple for candidates...');
      
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
      final AuthCredential credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        // Check for existing candidate in Firestore
        final existingCandidateQuery = await _firestore
            .collection('candidates')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();

        if (existingCandidateQuery.docs.isNotEmpty) {
          final candidateData = existingCandidateQuery.docs.first.data();
          final registrationComplete = candidateData['registrationComplete'] ?? false;
          final mobileNumber = existingCandidateQuery.docs.first.id;

          if (registrationComplete) {
            throw Exception('EXISTING_USER_COMPLETE:$mobileNumber');
          } else {
            throw Exception('EXISTING_USER_INCOMPLETE:$mobileNumber');
          }
        }
      }

      return userCredential;
    } catch (e) {
      debugPrint('🔍 Error in candidate Apple Sign-In: $e');
      rethrow;
    }
  }

  // -----------------------------------------------------------------
  // Sign‑in with Apple for employers
  // -----------------------------------------------------------------
  static Future<UserCredential?> signInWithAppleForEmployer() async {
    try {
      debugPrint('🔍 Starting Sign-In with Apple for employers...');
      
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
      final AuthCredential credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) {
        // Pre-check if this email can be used for employer registration
        final canCreate = await canCreateEmployerAccount(
          user.email!,
          user.uid,
        );
        if (!canCreate) {
          debugPrint('🚫 Cannot create employer account with this email');
          await user.delete();
          await signOut();
          throw Exception(
            'This email is already associated with another account. Please use a different email address.',
          );
        }
      }

      return userCredential;
    } catch (e) {
      debugPrint('🔍 Error in employer Apple Sign-In: $e');
      rethrow;
    }
  }

  // -----------------------------------------------------------------
  // Simplified Google Sign-In for candidates (handles existing accounts gracefully)
  // -----------------------------------------------------------------
  static Future<UserCredential?> signInWithGoogleForCandidate() async {
    try {
      debugPrint('🔍 Starting simplified Google Sign-In for candidates...');

      // Force account picker each time
      await _googleSignIn.signOut();
      debugPrint('🔍 Signed out from previous Google session');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('🔍 Google Sign-In cancelled by user');
        return null;
      }

      debugPrint('🔍 Google user selected: ${googleUser.email}');

      // Check for existing candidate in Firestore first
      final existingCandidateQuery = await _firestore
          .collection('candidates')
          .where('email', isEqualTo: googleUser.email)
          .limit(1)
          .get();

      // Try Firebase authentication
      try {
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        if (googleAuth.accessToken == null || googleAuth.idToken == null) {
          debugPrint('🔍 ERROR: Missing authentication tokens');
          return null;
        }

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCredential = await _auth.signInWithCredential(credential);
        debugPrint(
          '🔍 Firebase sign-in successful: ${userCredential.user?.email}',
        );

        // Refresh token & set persistence
        if (userCredential.user != null) {
          await userCredential.user!.reload();
          await userCredential.user!.getIdToken(true);
          if (kIsWeb) {
            await _auth.setPersistence(Persistence.LOCAL);
          }
        }

        // Handle existing candidate data
        if (existingCandidateQuery.docs.isNotEmpty) {
          final candidateData = existingCandidateQuery.docs.first.data();
          final registrationComplete =
              candidateData['registrationComplete'] ?? false;
          final mobileNumber = existingCandidateQuery.docs.first.id;

          debugPrint(
            '🔍 Found existing candidate: $mobileNumber, complete: $registrationComplete',
          );

          if (registrationComplete) {
            throw Exception('EXISTING_USER_COMPLETE:$mobileNumber');
          } else {
            throw Exception('EXISTING_USER_INCOMPLETE:$mobileNumber');
          }
        }

        // New user - return successful credential
        debugPrint('🔍 New candidate user - sign-in successful');
        return userCredential;
      } on FirebaseAuthException catch (e) {
        debugPrint('🔍 Firebase Auth Error: ${e.code} - ${e.message}');

        if (e.code == 'account-exists-with-different-credential') {
          debugPrint(
            '🔍 Account exists with different credential - trying to link',
          );

          // If user exists in Firestore, try to sign them in with existing method
          if (existingCandidateQuery.docs.isNotEmpty) {
            final candidateData = existingCandidateQuery.docs.first.data();
            final registrationComplete =
                candidateData['registrationComplete'] ?? false;
            final mobileNumber = existingCandidateQuery.docs.first.id;

            debugPrint('🔍 User exists in Firestore - allowing sign-in');

            // For existing Firestore users, we'll create a special exception
            // that tells the UI to handle this as an existing user
            if (registrationComplete) {
              throw Exception('EXISTING_USER_COMPLETE:$mobileNumber');
            } else {
              throw Exception('EXISTING_USER_INCOMPLETE:$mobileNumber');
            }
          } else {
            // User doesn't exist in Firestore but has Firebase Auth account
            debugPrint('🔍 User has Firebase Auth but no Firestore data');
            throw Exception(
              'ACCOUNT_LINKING_REQUIRED:${googleUser.email}:This email is already registered. Please sign in with your existing method first.',
            );
          }
        } else {
          // Other Firebase errors
          await _googleSignIn.signOut();
          throw Exception('Firebase Auth Error: ${e.message}');
        }
      }
    } catch (e) {
      debugPrint('🔍 Error in candidate Google Sign-In: $e');
      if (!e.toString().contains('EXISTING_USER_') &&
          !e.toString().contains('ACCOUNT_LINKING_')) {
        await _googleSignIn.signOut();
      }
      rethrow;
    }
  }

  // -----------------------------------------------------------------
  // Sign‑in with Google for employer registration (with enhanced duplicate prevention)
  // -----------------------------------------------------------------
  static Future<UserCredential?> signInWithGoogleForEmployer() async {
    try {
      debugPrint('🔍 Starting Google Sign-In for employer registration...');

      // Force account picker each time
      await _googleSignIn.signOut();
      debugPrint('🔍 Signed out from previous Google session');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('🔍 Google Sign-In cancelled by user');
        return null;
      }

      debugPrint('🔍 Google user selected: ${googleUser.email}');

      // Pre-check if this email can be used for employer registration
      final canCreate = await canCreateEmployerAccount(
        googleUser.email,
        googleUser.id,
      );
      if (!canCreate) {
        debugPrint('🚫 Cannot create employer account with this email');
        await _googleSignIn.signOut();
        throw Exception(
          'This email is already associated with another account. Please use a different email address.',
        );
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        debugPrint('🔍 ERROR: Missing authentication tokens');
        return null;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      debugPrint(
        '🔍 Firebase sign-in successful: ${userCredential.user?.email}',
      );

      // Double-check after Firebase auth creation
      if (userCredential.user != null) {
        final finalCheck = await canCreateEmployerAccount(
          userCredential.user!.email!,
          userCredential.user!.uid,
        );

        if (!finalCheck) {
          debugPrint('🚫 Final check failed - deleting auth user');
          await userCredential.user!.delete();
          await _googleSignIn.signOut();
          throw Exception(
            'Account creation conflict detected. Please try with a different email.',
          );
        }

        // Refresh token & set persistence
        await userCredential.user!.reload();
        await userCredential.user!.getIdToken(true);
        if (kIsWeb) {
          await _auth.setPersistence(Persistence.LOCAL);
        }
      }

      debugPrint('🔍 Employer Google Sign-In completed successfully');
      return userCredential;
    } catch (e) {
      debugPrint('🔍 Error in employer Google Sign-In: $e');
      await _googleSignIn.signOut();
      rethrow;
    }
  }

  // -----------------------------------------------------------------
  // Sign‑in with Apple
  // -----------------------------------------------------------------
  static Future<UserCredential?> signInWithApple() async {
    try {
      debugPrint('🔍 Starting Sign-In with Apple...');
      
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      debugPrint('🔍 Apple credential received');

      final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
      final AuthCredential credential = oAuthProvider.credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      debugPrint('🔍 Firebase sign-in with Apple successful: ${userCredential.user?.email}');
      
      return userCredential;
    } catch (e) {
      debugPrint('🔍 Error signing in with Apple: $e');
      return null;
    }
  }

  // -----------------------------------------------------------------
  // Sign‑in with Google (includes conflict check)
  // -----------------------------------------------------------------
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      debugPrint('🔍 Starting Google Sign-In process...');
      debugPrint(
        '🔍 GoogleSignIn configured with clientId: ${_googleSignIn.clientId}',
      );

      // Force account picker each time
      await _googleSignIn.signOut();
      debugPrint('🔍 Signed out from previous Google session');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        debugPrint('🔍 Google Sign-In cancelled by user');
        return null;
      }

      debugPrint('🔍 Google user selected: ${googleUser.email}');
      debugPrint('🔍 Google user ID: ${googleUser.id}');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      debugPrint('🔍 Got Google authentication tokens');
      debugPrint('🔍 Access token exists: ${googleAuth.accessToken != null}');
      debugPrint('🔍 ID token exists: ${googleAuth.idToken != null}');

      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        debugPrint('🔍 ERROR: Missing authentication tokens');
        return null;
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      debugPrint('🔍 Created Firebase credential');

      final userCredential = await _auth.signInWithCredential(credential);
      debugPrint(
        '🔍 Firebase sign-in successful: ${userCredential.user?.email}',
      );
      debugPrint('🔍 Firebase user UID: ${userCredential.user?.uid}');

      // Refresh token & set persistence for web
      if (userCredential.user != null) {
        await userCredential.user!.reload();
        await userCredential.user!.getIdToken(true);
        if (kIsWeb) {
          await _auth.setPersistence(Persistence.LOCAL);
        }
        debugPrint('🔍 Token refreshed and persistence set');
      }

      // Conflict detection – if the user has both roles, sign out and abort.
      final User? signedInUser = userCredential.user;
      if (signedInUser != null) {
        debugPrint('🔍 Checking for role conflicts...');
        final conflict = await _hasRoleConflict(signedInUser);
        if (conflict) {
          debugPrint('🔍 Role conflict detected – signing out.');
          await signOut();
          return null;
        }
        debugPrint('🔍 No role conflicts found');
      }

      debugPrint('🔍 Google Sign-In completed successfully');
      return userCredential;
    } on FirebaseAuthException catch (e) {
      debugPrint('🔍 Firebase Auth Error: ${e.code} - ${e.message}');
      debugPrint('🔍 Firebase Auth Details: ${e.toString()}');
      if (e.code == 'invalid-credential') {
        debugPrint('🔍 Invalid credential - check Firebase configuration');
      } else if (e.code == 'account-exists-with-different-credential') {
        debugPrint('🔍 Account exists with different credential');
      } else if (e.code == 'operation-not-allowed') {
        debugPrint('🔍 Google Sign-In not enabled in Firebase Console');
      } else if (e.code == 'user-disabled') {
        debugPrint('🔍 User account has been disabled');
      }
      return null;
    } on PlatformException catch (e) {
      debugPrint('🔍 Platform Exception: ${e.code} - ${e.message}');
      debugPrint('🔍 Platform Exception Details: ${e.toString()}');
      if (e.code == 'sign_in_failed') {
        debugPrint('🔍 Google Sign-In failed - check SHA-1 configuration');
      } else if (e.code == 'network_error') {
        debugPrint('🔍 Network error - check internet connection');
      } else if (e.code == 'sign_in_canceled') {
        debugPrint('🔍 Sign-In was canceled by user');
      } else if (e.code == 'sign_in_required') {
        debugPrint('🔍 Sign-In required - user needs to sign in again');
      }
      return null;
    } catch (e) {
      debugPrint('🔍 General Error signing in with Google: $e');
      debugPrint('🔍 Error type: ${e.runtimeType}');
      debugPrint('🔍 Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  // -----------------------------------------------------------------
  // Sign‑out
  // -----------------------------------------------------------------
  static Future<void> signOut() async {
    try {
      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
      await UserRoleStorage.clearRole();
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  // -----------------------------------------------------------------
  // Retrieve user data (candidate or employer) with role preference.
  // -----------------------------------------------------------------
  static Future<Map<String, dynamic>?> getUserData() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    try {
      await user.reload();

      Map<String, dynamic>? employerCache;
      Map<String, dynamic>? candidateCache;

      Future<Map<String, dynamic>?> fetchEmployer() async {
        if (employerCache != null) return employerCache;
        final doc = await _firestore
            .collection('employers')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          final data = doc.data()!;
          data['userType'] = 'employer';
          employerCache = data;
          return data;
        }
        return null;
      }

      Future<Map<String, dynamic>?> fetchCandidate() async {
        if (candidateCache != null) return candidateCache;
        final email = user.email;
        if (email == null) return null;
        final query = await _firestore
            .collection('candidates')
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final data = query.docs.first.data();
          data['userType'] = 'candidate';
          data['docId'] = query.docs.first.id;
          candidateCache = data;
          return data;
        }
        return null;
      }

      final preferredRole = await UserRoleStorage.getRole();

      if (preferredRole == 'candidate') {
        final candidateData = await fetchCandidate();
        if (candidateData != null) return candidateData;
        final employerData = await fetchEmployer();
        if (employerData != null) return employerData;
      } else if (preferredRole == 'employer') {
        final employerData = await fetchEmployer();
        if (employerData != null) return employerData;
        final candidateData = await fetchCandidate();
        if (candidateData != null) return candidateData;
      } else {
        final employerData = await fetchEmployer();
        if (employerData != null) return employerData;
        final candidateData = await fetchCandidate();
        if (candidateData != null) return candidateData;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  // -----------------------------------------------------------------
  // Registration completeness check
  // -----------------------------------------------------------------
  static Future<bool> isRegistrationComplete() async {
    final userData = await getUserData();
    if (userData == null) return false;
    final userType = userData['userType'] as String?;
    if (userType == 'employer') {
      return userData['registrationComplete'] ?? true;
    } else if (userType == 'candidate') {
      return userData['registrationComplete'] ?? false;
    }
    return false;
  }

  // -----------------------------------------------------------------
  // Token refresh helper
  // -----------------------------------------------------------------
  static Future<void> refreshToken() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        await user.reload();
        await user.getIdToken(true);
      }
    } catch (e) {
      debugPrint('Error refreshing token: $e');
    }
  }

  // -----------------------------------------------------------------
  // Auth status check used by UI
  // -----------------------------------------------------------------
  static Future<Map<String, dynamic>> checkAuthStatus() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'isAuthenticated': false,
        'userType': null,
        'isRegistrationComplete': false,
        'userData': null,
      };
    }
    try {
      // Handle anonymous guest users (for Google Play Review)
      if (user.isAnonymous) {
        return {
          'isAuthenticated': true,
          'userType': 'candidate',
          'isRegistrationComplete': true,
          'userData': {
            'fullName': 'Guest User',
            'email': 'guest@example.com',
            'userType': 'candidate',
          },
        };
      }

      await refreshToken();
      final userData = await getUserData();
      final isComplete = await isRegistrationComplete();
      return {
        'isAuthenticated': true,
        'userType': userData?['userType'],
        'isRegistrationComplete': isComplete,
        'userData': userData,
      };
    } catch (e) {
      debugPrint('Error checking auth status: $e');
      return {
        'isAuthenticated': true,
        'userType': null,
        'isRegistrationComplete': false,
        'userData': null,
      };
    }
  }

  // -----------------------------------------------------------------
  // Persistence initialization (called from main)
  // -----------------------------------------------------------------
  static Future<void> initializeAuth() async {
    try {
      if (kIsWeb) {
        await _auth.setPersistence(Persistence.LOCAL);
      }
      final user = _auth.currentUser;
      if (user != null) {
        await user.reload();
        await user.getIdToken(true);
      }
    } catch (e) {
      debugPrint('Error initializing auth: $e');
      await signOut();
    }
  }

  // -----------------------------------------------------------------
  // Employer approval status (company verification)
  // -----------------------------------------------------------------
  static Future<Map<String, dynamic>> getApprovalStatus() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {'isApproved': false, 'approvalStatus': 'not_authenticated'};
    }
    try {
      final employerDoc = await _firestore
          .collection('employers')
          .doc(user.uid)
          .get(const GetOptions(source: Source.server));
      if (employerDoc.exists) {
        final data = employerDoc.data()!;
        final approvalStatus = data['approvalStatus'] as String? ?? 'pending';
        return {
          'approvalStatus': approvalStatus,
          'companyName': data['companyName'],
        };
      }
      return {'approvalStatus': 'not_found'};
    } catch (e) {
      debugPrint('Error checking approval status: $e');
      // Fallback to cache fetch
      try {
        final employerDoc = await _firestore
            .collection('employers')
            .doc(user.uid)
            .get();
        if (employerDoc.exists) {
          final data = employerDoc.data()!;
          final approvalStatus = data['approvalStatus'] as String? ?? 'pending';
          return {
            'approvalStatus': approvalStatus,
            'companyName': data['companyName'],
          };
        }
      } catch (_) {}
      return {'approvalStatus': 'error'};
    }
  }

  // -----------------------------------------------------------------
  // Stream of approval status updates
  // -----------------------------------------------------------------
  static Stream<DocumentSnapshot> getApprovalStatusStream() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();
    return _firestore.collection('employers').doc(user.uid).snapshots();
  }

  // -----------------------------------------------------------------
  // Verify auth state – used on app resume
  // -----------------------------------------------------------------
  static Future<bool> verifyAuthState() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;
      await user.reload();
      await user.getIdToken(true);
      return true;
    } catch (e) {
      debugPrint('Auth verification failed: $e');
      await signOut();
      return false;
    }
  }
}
