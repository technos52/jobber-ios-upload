import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Temporary storage for incomplete registration data
  static Map<String, dynamic>? _tempCandidateData;
  static Map<String, dynamic>? _tempEmployerData;

  // Store candidate data temporarily (not in Firebase)
  static void storeCandidateStep1Data({
    required String fullName,
    required String title,
    required String gender,
    required String mobileNumber,
    required int birthYear,
    required int age,
  }) {
    try {
      debugPrint('🔍 Storing candidate step 1 data temporarily...');

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception(
          'Please sign in with Google first to continue registration.',
        );
      }

      _tempCandidateData = {
        'fullName': fullName,
        'title': title,
        'gender': gender,
        'mobileNumber': mobileNumber,
        'birthYear': birthYear,
        'age': age,
        'email': user.email,
        'uid': user.uid,
        'step': 1,
      };

      debugPrint('✅ Step 1 data stored temporarily');
    } catch (e) {
      debugPrint('❌ Error storing step 1 data: $e');
      rethrow;
    }
  }

  // Store candidate step 2 data temporarily
  static void storeCandidateStep2Data({
    required String qualification,
    required int experienceYears,
    required int experienceMonths,
    required String jobCategory,
    required String jobType,
    required String designation,
    required String companyName,
    String? companyType,
    required String email,
    String? currentlyWorking,
    int? noticePeriod,
  }) {
    try {
      debugPrint('🔍 Storing candidate step 2 data temporarily...');

      if (_tempCandidateData == null) {
        throw Exception(
          'Step 1 data not found. Please start registration from the beginning.',
        );
      }

      // Merge step 2 data with existing temp data
      _tempCandidateData!.addAll({
        'qualification': qualification,
        'experienceYears': experienceYears,
        'experienceMonths': experienceMonths,
        'jobCategory': jobCategory,
        'jobType': jobType,
        'designation': designation,
        'companyName': companyName,
        'companyType': companyType,
        'email': email,
        'emailVerified': true,
        'step': 2,
      });

      if (currentlyWorking != null) {
        _tempCandidateData!['currentlyWorking'] = currentlyWorking;
      }
      if (noticePeriod != null) {
        _tempCandidateData!['noticePeriod'] = noticePeriod;
      }

      debugPrint('✅ Step 2 data stored temporarily');
    } catch (e) {
      debugPrint('❌ Error storing step 2 data: $e');
      rethrow;
    }
  }

  // Complete candidate registration and save to Firebase
  static Future<void> completeCandidateRegistration({
    required String maritalStatus,
    required String state,
    required String district,
    bool? currentlyWorking,
    int? noticePeriod,
  }) async {
    try {
      debugPrint('🔍 Completing candidate registration...');

      if (_tempCandidateData == null) {
        throw Exception(
          'Registration data not found. Please start registration from the beginning.',
        );
      }

      final uid = _tempCandidateData!['uid'] as String;
      final mobileNumber = _tempCandidateData!['mobileNumber'] as String?;
      final email = _tempCandidateData!['email'] as String;

      // Check for email conflicts before saving
      await _checkCandidateEmailConflicts(email, uid, mobileNumber);

      // Prepare final complete data
      final completeData = Map<String, dynamic>.from(_tempCandidateData!);

      // Create combined experience field from years and months
      final experienceYears = completeData['experienceYears'] as int? ?? 0;
      final experienceMonths = completeData['experienceMonths'] as int? ?? 0;

      String experienceText = '';
      if (experienceYears > 0 && experienceMonths > 0) {
        experienceText = '$experienceYears years $experienceMonths months';
      } else if (experienceYears > 0) {
        experienceText = '$experienceYears years';
      } else if (experienceMonths > 0) {
        experienceText = '$experienceMonths months';
      } else {
        experienceText = 'Fresher';
      }

      completeData.addAll({
        'maritalStatus': maritalStatus,
        'state': state,
        'district': district,
        'experience': experienceText, // Add combined experience field
        'registrationComplete': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'step': 3,
      });

      if (currentlyWorking != null) {
        completeData['currentlyWorking'] = currentlyWorking;
      }
      if (noticePeriod != null) {
        completeData['noticePeriod'] = noticePeriod;
        // Also add notice period as text for better display
        String noticePeriodText = '';
        switch (noticePeriod) {
          case 0:
            noticePeriodText = 'Immediate';
            break;
          case 15:
            noticePeriodText = '15 days';
            break;
          case 30:
            noticePeriodText = '1 month';
            break;
          case 60:
            noticePeriodText = '2 months';
            break;
          case 90:
            noticePeriodText = '3 months';
            break;
          default:
            noticePeriodText = '$noticePeriod days';
        }
        completeData['noticePeriodText'] = noticePeriodText;
      }

      // Save complete data to Firebase using uid as the document ID
      await _firestore
          .collection('candidates')
          .doc(uid)
          .set(completeData);

      // Clear temporary data
      _tempCandidateData = null;

      debugPrint('✅ Candidate registration completed and saved to Firebase');
    } catch (e) {
      debugPrint('❌ Error completing candidate registration: $e');
      rethrow;
    }
  }

  // Check for email conflicts
  static Future<void> _checkCandidateEmailConflicts(
    String email,
    String currentUid,
    String? currentMobileNumber,
  ) async {
    // Check if email is already used by another candidate
    final candidateQuery = await _firestore
        .collection('candidates')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (candidateQuery.docs.isNotEmpty) {
      final existingCandidate = candidateQuery.docs.first;
      final data = existingCandidate.data();
      final existingUid = data['uid'] as String?;

      if (existingUid != null) {
        if (existingUid != currentUid) {
          throw Exception(
            'This email is already registered with another candidate account. Please use a different email address.',
          );
        }
      } else {
        // Fallback for extremely old legacy records where uid is not in document
        if (existingCandidate.id != currentUid &&
            (currentMobileNumber == null || existingCandidate.id != currentMobileNumber)) {
          throw Exception(
            'This email is already registered with another candidate account. Please use a different email address.',
          );
        }
      }
    }

    // Check if email is used by an employer
    final employerQuery = await _firestore
        .collection('employers')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (employerQuery.docs.isNotEmpty) {
      throw Exception(
        'This email is already in use for an employer account. You cannot use the same email for both a candidate and an employer.',
      );
    }
  }

  // Get temporary candidate data
  static Map<String, dynamic>? getTempCandidateData() {
    return _tempCandidateData;
  }

  // Clear temporary candidate data
  static void clearTempCandidateData() {
    _tempCandidateData = null;
    debugPrint('🗑️ Temporary candidate data cleared');
  }

  // Store employer data temporarily (not in Firebase)
  static void storeTempEmployerData(Map<String, dynamic> employerData) {
    _tempEmployerData = employerData;
    debugPrint('🔍 Employer data stored temporarily');
  }

  // Complete employer registration and save to Firebase
  static Future<void> completeEmployerRegistration() async {
    try {
      debugPrint('🔍 Completing employer registration...');

      if (_tempEmployerData == null) {
        throw Exception('Employer registration data not found.');
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Authentication required to complete registration.');
      }

      // Check for conflicts
      final email = _tempEmployerData!['email'] as String;
      await _checkEmployerEmailConflicts(email, user.uid);

      // Prepare final complete data
      final completeData = Map<String, dynamic>.from(_tempEmployerData!);
      completeData.addAll({
        'registrationComplete': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'approvalStatus': 'pending',
      });

      // Save complete data to Firebase
      await _firestore.collection('employers').doc(user.uid).set(completeData);

      // Clear temporary data
      _tempEmployerData = null;

      debugPrint('✅ Employer registration completed and saved to Firebase');
    } catch (e) {
      debugPrint('❌ Error completing employer registration: $e');
      rethrow;
    }
  }

  // Check for employer email conflicts
  static Future<void> _checkEmployerEmailConflicts(
    String email,
    String uid,
  ) async {
    // Check if email is already used by another employer
    final employerQuery = await _firestore
        .collection('employers')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (employerQuery.docs.isNotEmpty) {
      final existingEmployer = employerQuery.docs.first;
      if (existingEmployer.id != uid) {
        throw Exception(
          'This email is already registered with another employer account.',
        );
      }
    }

    // Check if email is used by a candidate
    final candidateQuery = await _firestore
        .collection('candidates')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (candidateQuery.docs.isNotEmpty) {
      throw Exception(
        'This email is already in use for a candidate account. You cannot use the same email for both a candidate and an employer.',
      );
    }
  }

  // Get temporary employer data
  static Map<String, dynamic>? getTempEmployerData() {
    return _tempEmployerData;
  }

  // Clear temporary employer data
  static void clearTempEmployerData() {
    _tempEmployerData = null;
    debugPrint('🗑️ Temporary employer data cleared');
  }

  // Legacy methods for backward compatibility (now redirect to temp storage)
  static Future<void> saveCandidateStep1Data({
    required String fullName,
    required String title,
    required String gender,
    required String mobileNumber,
    required int birthYear,
    required int age,
  }) async {
    storeCandidateStep1Data(
      fullName: fullName,
      title: title,
      gender: gender,
      mobileNumber: mobileNumber,
      birthYear: birthYear,
      age: age,
    );
  }

  static Future<void> updateCandidateStep2Data({
    required String mobileNumber,
    required String qualification,
    required int experienceYears,
    required int experienceMonths,
    required String jobCategory,
    required String jobType,
    required String designation,
    required String companyName,
    String? companyType,
    required String email,
    String? currentlyWorking,
    int? noticePeriod,
  }) async {
    storeCandidateStep2Data(
      qualification: qualification,
      experienceYears: experienceYears,
      experienceMonths: experienceMonths,
      jobCategory: jobCategory,
      jobType: jobType,
      designation: designation,
      companyName: companyName,
      companyType: companyType,
      email: email,
      currentlyWorking: currentlyWorking,
      noticePeriod: noticePeriod,
    );
  }

  static Future<void> updateCandidateStep3Data({
    required String mobileNumber,
    required String maritalStatus,
    required String state,
    required String district,
    bool? currentlyWorking,
    int? noticePeriod,
  }) async {
    await completeCandidateRegistration(
      maritalStatus: maritalStatus,
      state: state,
      district: district,
      currentlyWorking: currentlyWorking,
      noticePeriod: noticePeriod,
    );
  }

  // Retrieve candidate by document ID (only completed registrations)
  static Future<Map<String, dynamic>?> getCandidateData(
    String documentId,
  ) async {
    try {
      final doc = await _firestore
          .collection('candidates')
          .doc(documentId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        // Only return data if registration is complete
        if (data['registrationComplete'] == true) {
          return data;
        }
      }
      return null;
    } catch (_) {
      throw Exception('Unable to load your profile. Please try again later.');
    }
  }

  // Get the most recent candidate (admin/debug) - only completed registrations
  static Future<Map<String, dynamic>?> getLatestCandidateData() async {
    try {
      final query = await _firestore
          .collection('candidates')
          .where('registrationComplete', isEqualTo: true)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) return query.docs.first.data();
      return null;
    } catch (_) {
      throw Exception('Unable to fetch the latest candidate data.');
    }
  }

  // Helper: check if a candidate exists for a given email (only completed registrations)
  static Future<bool> candidateExistsByEmail(String email) async {
    try {
      final query = await _firestore
          .collection('candidates')
          .where('email', isEqualTo: email)
          .where('registrationComplete', isEqualTo: true)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Helper: check if an employer exists for a given email (only completed registrations)
  static Future<bool> employerExistsByEmail(String email) async {
    try {
      final query = await _firestore
          .collection('employers')
          .where('email', isEqualTo: email)
          .where('registrationComplete', isEqualTo: true)
          .limit(1)
          .get();
      return query.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // Helper: check if an employer exists for a given UID (only completed registrations)
  static Future<bool> employerExistsByUid(String uid) async {
    try {
      final doc = await _firestore.collection('employers').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        return data['registrationComplete'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // Helper: get employer data by UID (only completed registrations)
  static Future<Map<String, dynamic>?> getEmployerByUid(String uid) async {
    try {
      final doc = await _firestore.collection('employers').doc(uid).get();
      if (doc.exists) {
        final data = doc.data()!;
        if (data['registrationComplete'] == true) {
          return data;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Helper: comprehensive duplicate check for employer registration
  static Future<Map<String, dynamic>> checkEmployerDuplicates({
    required String email,
    required String uid,
  }) async {
    try {
      // Check for email duplicates (only completed registrations)
      final emailQuery = await _firestore
          .collection('employers')
          .where('email', isEqualTo: email)
          .where('registrationComplete', isEqualTo: true)
          .limit(1)
          .get();

      // Check for UID duplicates (only completed registrations)
      final uidDoc = await _firestore.collection('employers').doc(uid).get();
      final uidExists =
          uidDoc.exists && (uidDoc.data()?['registrationComplete'] == true);

      // Check for candidate with same email (only completed registrations)
      final candidateExists = await candidateExistsByEmail(email);

      return {
        'emailExists': emailQuery.docs.isNotEmpty,
        'emailOwnerId': emailQuery.docs.isNotEmpty
            ? emailQuery.docs.first.id
            : null,
        'uidExists': uidExists,
        'uidData': uidExists ? uidDoc.data() : null,
        'candidateConflict': candidateExists,
        'canProceed':
            !candidateExists &&
            (!emailQuery.docs.isNotEmpty || emailQuery.docs.first.id == uid) &&
            (!uidExists || (uidDoc.data()?['email'] == email)),
      };
    } catch (e) {
      return {
        'emailExists': false,
        'emailOwnerId': null,
        'uidExists': false,
        'uidData': null,
        'candidateConflict': false,
        'canProceed': false,
        'error': e.toString(),
      };
    }
  }

  // Get candidate data by email (only completed registrations)
  static Future<Map<String, dynamic>?> getCandidateByEmail(String email) async {
    try {
      final query = await _firestore
          .collection('candidates')
          .where('email', isEqualTo: email)
          .where('registrationComplete', isEqualTo: true)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return query.docs.first.data();
      }
      return null;
    } catch (_) {
      throw Exception('Unable to load your profile. Please try again later.');
    }
  }

  // Helper method to get user document ID by email (only completed registrations)
  static Future<String?> getUserDocumentIdByEmail(String email) async {
    try {
      debugPrint('🔍 Looking for candidate document with email: $email');

      final query = await _firestore
          .collection('candidates')
          .where('email', isEqualTo: email)
          .where('registrationComplete', isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final docId = query.docs.first.id;
        debugPrint('✅ Found candidate document with ID: $docId');
        return docId;
      }

      debugPrint('❌ No completed candidate document found with email: $email');
      return null;
    } catch (e) {
      debugPrint('❌ Error finding user document by email: $e');
      return null;
    }
  }
}
