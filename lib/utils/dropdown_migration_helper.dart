import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper class to migrate dropdown data from old structure to new structure
class DropdownMigrationHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Migrate data from admin_settings/dropdown_management to dropdown_options collection
  static Future<void> migrateToNewStructure() async {
    try {
      print(
        'Starting migration from old structure to new dropdown_options collection...',
      );

      // Read from old structure
      final oldDoc = await _firestore
          .collection('admin_settings')
          .doc('dropdown_management')
          .get();

      if (!oldDoc.exists) {
        print('No old structure found. Creating default dropdown options...');
        await _createDefaultDropdownOptions();
        return;
      }

      final oldData = oldDoc.data() as Map<String, dynamic>;

      // Migrate candidate registration options
      if (oldData['candidate_registration'] != null) {
        final candidateData =
            oldData['candidate_registration'] as Map<String, dynamic>;

        await _migrateCategory(
          'qualifications',
          candidateData['qualifications'],
        );
        await _migrateCategory('departments', candidateData['departments']);
        await _migrateCategory('designations', candidateData['designations']);
        await _migrateCategory('company_types', candidateData['company_types']);
      }

      // Migrate job posting options
      if (oldData['job_posting'] != null) {
        final jobData = oldData['job_posting'] as Map<String, dynamic>;

        await _migrateCategory('job_departments', jobData['departments']);
        await _migrateCategory('job_types', jobData['job_types']);
        await _migrateCategory('industry_types', jobData['industry_types']);

        // Handle job categories (more complex structure)
        if (jobData['job_categories'] != null) {
          final categories = jobData['job_categories'] as List;
          final categoryNames = categories
              .map((cat) => cat['name'] as String)
              .toList();
          await _migrateCategory('job_categories', categoryNames);
        }
      }

      print('Migration completed successfully!');
    } catch (e) {
      print('Error during migration: $e');
      rethrow;
    }
  }

  /// Migrate a specific category to the new structure
  static Future<void> _migrateCategory(
    String categoryName,
    dynamic options,
  ) async {
    if (options == null) return;

    try {
      List<String> optionsList;

      if (options is List) {
        optionsList = options.cast<String>();
      } else {
        print('Skipping $categoryName - invalid format');
        return;
      }

      await _firestore.collection('dropdown_options').doc(categoryName).set({
        'options': optionsList,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'migrated_from_old_structure': true,
      });

      print('Migrated $categoryName: ${optionsList.length} options');
    } catch (e) {
      print('Error migrating $categoryName: $e');
    }
  }

  /// Create default dropdown options if no old structure exists
  static Future<void> _createDefaultDropdownOptions() async {
    final defaultOptions = {
      'qualifications': [
        '10th Pass',
        '12th Pass',
        'Diploma',
        'Bachelor\'s Degree (B.A/B.Sc/B.Com/B.Tech/BE)',
        'Master\'s Degree (M.A/M.Sc/M.Com/M.Tech/ME)',
        'MBA',
        'PhD',
        'Professional Certification',
        'Other',
      ],
      'departments': [
        'Information Technology',
        'Human Resources',
        'Finance & Accounting',
        'Marketing & Sales',
        'Operations',
        'Customer Service',
        'Administration',
        'Engineering',
        'Design & Creative',
        'Legal',
        'Research & Development',
        'Quality Assurance',
        'Supply Chain',
        'Business Development',
        'Data Science',
        'Digital Marketing',
        'Content Writing',
        'Other',
      ],
      'designations': [
        'Trainee',
        'Apprentice',
        'DET (Diploma Engineer Trainee)',
        'GET (Graduate Engineer Trainee)',
        'Operator',
        'Technician',
        'Senior Technician',
        'Team Leader',
        'Line Leader',
        'Analyst',
        'Specialist',
        'Coordinator',
        'Planner',
        'Inspector',
        'Auditor',
        'Supervisor',
        'Executive',
        'Senior Executive',
        'Shift Incharge',
        'Junior Engineer',
        'Engineer',
        'Senior Engineer',
        'Assistant Manager',
        'Deputy Manager',
        'Manager',
        'Senior Manager',
        'AGM (Assistant General Manager)',
        'DGM (Deputy General Manager)',
        'General Manager (GM)',
        'Plant Head',
        'Unit Head',
        'Functional Head',
        'Director',
        'Vice President (VP)',
        'Senior Vice President (SVP)',
        'Chief Executive Officer (CEO)',
        'Chief Operating Officer (COO)',
        'Chief Financial Officer (CFO)',
        'Chief Technology Officer (CTO)',
        'President',
        'Managing Director (MD)',
        'Other Designation',
      ],
      'company_types': [
        'Startup (1-50 employees)',
        'Small Business (51-200 employees)',
        'Medium Enterprise (201-1000 employees)',
        'Large Corporation (1000+ employees)',
        'Government Organization',
        'Non-Profit Organization',
        'Educational Institution',
        'Healthcare Organization',
        'Financial Institution',
        'Technology Company',
        'Manufacturing Company',
        'Retail Company',
        'Consulting Firm',
        'Other',
      ],
      'job_departments': [
        'Company',
        'Banking & Finance',
        'Education & Training',
        'Healthcare & Medical',
        'Hospitality & Tourism',
        'Government & Public Sector',
        'Retail & E-commerce',
        'Information Technology',
        'Manufacturing',
        'Real Estate',
        'Media & Entertainment',
        'Transportation & Logistics',
        'Other',
      ],
      'job_categories': [
        'Company Jobs',
        'Bank/NBFC Jobs',
        'School Jobs',
        'Hospital Jobs',
        'Hotel/Bar Jobs',
        'Govt Jobs Info',
        'Mall/Shopkeeper Jobs',
      ],
      'job_types': [
        'Full Time',
        'Part Time',
        'Contract',
        'Internship',
        'Freelance',
        'Remote',
        'Hybrid',
        'Temporary',
        'Seasonal',
      ],
      'industry_types': [
        'Information Technology and Services',
        'Computer Software',
        'Computer Hardware',
        'Engineering',
        'Manufacturing',
        'Consulting',
        'Marketing and Advertising',
        'Human Resources',
        'Business Development',
        'Operations',
        'Finance',
        'Banking',
        'Financial Services',
        'Investment Banking',
        'Insurance',
        'Education Management',
        'Higher Education',
        'Primary & Secondary Education',
        'E-learning',
        'Hospital & Health Care',
        'Medical Practice',
        'Medical Devices',
        'Pharmaceuticals',
        'Hospitality',
        'Food & Beverages',
        'Tourism',
        'Event Management',
        'Government Administration',
        'Public Policy',
        'Defense',
        'Law Enforcement',
        'Retail',
        'E-commerce',
        'Fashion & Apparel',
        'Consumer Goods',
        'Other',
      ],
    };

    for (final entry in defaultOptions.entries) {
      await _migrateCategory(entry.key, entry.value);
    }
  }

  /// Check if migration is needed
  static Future<bool> isMigrationNeeded() async {
    try {
      // Check if new structure exists
      final newCollection = await _firestore
          .collection('dropdown_options')
          .limit(1)
          .get();

      if (newCollection.docs.isNotEmpty) {
        return false; // New structure exists, no migration needed
      }

      // Check if old structure exists
      final oldDoc = await _firestore
          .collection('admin_settings')
          .doc('dropdown_management')
          .get();

      return oldDoc.exists; // Migration needed if old structure exists
    } catch (e) {
      print('Error checking migration status: $e');
      return true; // Assume migration is needed if we can't check
    }
  }

  /// Add a new option to a category
  static Future<void> addOption(String category, String newOption) async {
    try {
      await _firestore.collection('dropdown_options').doc(category).update({
        'options': FieldValue.arrayUnion([newOption]),
        'updated_at': FieldValue.serverTimestamp(),
      });
      print('Added "$newOption" to $category');
    } catch (e) {
      print('Error adding option: $e');
      rethrow;
    }
  }

  /// Remove an option from a category
  static Future<void> removeOption(
    String category,
    String optionToRemove,
  ) async {
    try {
      await _firestore.collection('dropdown_options').doc(category).update({
        'options': FieldValue.arrayRemove([optionToRemove]),
        'updated_at': FieldValue.serverTimestamp(),
      });
      print('Removed "$optionToRemove" from $category');
    } catch (e) {
      print('Error removing option: $e');
      rethrow;
    }
  }

  /// Update entire category options
  static Future<void> updateCategoryOptions(
    String category,
    List<String> newOptions,
  ) async {
    try {
      await _firestore.collection('dropdown_options').doc(category).set({
        'options': newOptions,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('Updated $category with ${newOptions.length} options');
    } catch (e) {
      print('Error updating category: $e');
      rethrow;
    }
  }

  /// Directly push updated designations to Firebase dropdown_options collection
  static Future<void> pushDesignationsToFirebase() async {
    const updatedDesignations = [
      'Trainee',
      'Apprentice',
      'DET (Diploma Engineer Trainee)',
      'GET (Graduate Engineer Trainee)',
      'Operator',
      'Technician',
      'Senior Technician',
      'Team Leader',
      'Line Leader',
      'Analyst',
      'Specialist',
      'Coordinator',
      'Planner',
      'Inspector',
      'Auditor',
      'Supervisor',
      'Executive',
      'Senior Executive',
      'Shift Incharge',
      'Junior Engineer',
      'Engineer',
      'Senior Engineer',
      'Assistant Manager',
      'Deputy Manager',
      'Manager',
      'Senior Manager',
      'AGM (Assistant General Manager)',
      'DGM (Deputy General Manager)',
      'General Manager (GM)',
      'Plant Head',
      'Unit Head',
      'Functional Head',
      'Director',
      'Vice President (VP)',
      'Senior Vice President (SVP)',
      'Chief Executive Officer (CEO)',
      'Chief Operating Officer (COO)',
      'Chief Financial Officer (CFO)',
      'Chief Technology Officer (CTO)',
      'President',
      'Managing Director (MD)',
      'Other Designation',
    ];

    try {
      // Update new-structure document: dropdown_options/designation
      await _firestore.collection('dropdown_options').doc('designation').set({
        'options': updatedDesignations,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('✅ dropdown_options/designation updated: ${updatedDesignations.length} items');

      // Also update old-structure for backward compatibility
      try {
        await _firestore
            .collection('admin_settings')
            .doc('dropdown_management')
            .update({
          'candidate_registration.designations': updatedDesignations,
          'updated_at': FieldValue.serverTimestamp(),
        });
        print('✅ admin_settings/dropdown_management designations updated');
      } catch (_) {
        // Old structure may not exist — that's fine
        print('ℹ️ Old structure not found, skipping admin_settings update');
      }
    } catch (e) {
      print('❌ Error pushing designations to Firebase: $e');
      rethrow;
    }
  }
}
