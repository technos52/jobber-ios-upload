import 'package:flutter/material.dart';
import '../utils/initialize_dropdown_data.dart';
import '../utils/dropdown_migration_helper.dart';

class AdminDropdownInitScreen extends StatefulWidget {
  const AdminDropdownInitScreen({super.key});

  @override
  State<AdminDropdownInitScreen> createState() =>
      _AdminDropdownInitScreenState();
}

class _AdminDropdownInitScreenState extends State<AdminDropdownInitScreen> {
  bool _isInitializing = false;
  String _status = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin - Initialize Dropdown Data'),
        backgroundColor: const Color(0xFF007BFF),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Initialize Dropdown Management',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF007BFF),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This will create the dropdown management collection in Firebase with default values for:',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              '• Candidate Registration:\n  - Qualifications\n  - Departments\n  - Designations\n  - Company Types',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Job Posting:\n  - Departments/Domains\n  - Job Categories\n  - Industry Types\n  - Job Types',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isInitializing ? null : _initializeData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007BFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isInitializing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Initializing...'),
                      ],
                    )
                  : const Text(
                      'Initialize Dropdown Data (Old Structure)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isInitializing ? null : _migrateToNewStructure,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isInitializing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Migrating...'),
                      ],
                    )
                  : const Text(
                      'Migrate to New Structure (Recommended)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isInitializing ? null : _pushDesignations,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isInitializing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Updating...'),
                      ],
                    )
                  : const Text(
                      '🔄 Update Designations in Firebase',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            if (_status.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _status.contains('Error')
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  border: Border.all(
                    color: _status.contains('Error')
                        ? Colors.red.shade300
                        : Colors.green.shade300,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _status,
                  style: TextStyle(
                    color: _status.contains('Error')
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Firebase Structure (New):',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF007BFF),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Collection: dropdown_options\nDocuments: qualifications, departments, designations, etc.\n\nStructure:\n{\n  "options": ["Option 1", "Option 2", ...],\n  "created_at": timestamp,\n  "updated_at": timestamp\n}\n\nThis new structure is easier to manage and allows real-time updates.',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'Firebase Structure (Old):',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Collection: admin_settings\nDocument: dropdown_management\n\nStructure:\n{\n  "candidate_registration": {\n    "qualifications": [...],\n    "departments": [...],\n    "designations": [...],\n    "company_types": [...]\n  },\n  "job_posting": {\n    "departments": [...],\n    "job_categories": [...],\n    "job_types": [...]\n  }\n}',
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'monospace',
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _migrateToNewStructure() async {
    setState(() {
      _isInitializing = true;
      _status = '';
    });

    try {
      // Check if migration is needed
      final migrationNeeded = await DropdownMigrationHelper.isMigrationNeeded();

      if (!migrationNeeded) {
        setState(() {
          _status =
              'Migration not needed. New dropdown_options collection already exists with data.';
        });
        return;
      }

      // Perform migration
      await DropdownMigrationHelper.migrateToNewStructure();

      setState(() {
        _status =
            'Success! Data has been migrated to the new dropdown_options collection structure.\n\nEach dropdown category is now a separate document with an "options" array field. This makes it easier to manage and allows for real-time updates.\n\nYour admin panel should now work correctly with the app.';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: Failed to migrate to new structure.\n\n$e';
      });
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _initializeData() async {
    setState(() {
      _isInitializing = true;
      _status = '';
    });

    try {
      await DropdownDataInitializer.initializeDropdownData();
      setState(() {
        _status =
            'Success! Dropdown management data has been initialized in Firebase.\n\nYou can now manage dropdown options through the Firebase console or create an admin panel to modify them.';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: Failed to initialize dropdown data.\n\n$e';
      });
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _pushDesignations() async {
    setState(() {
      _isInitializing = true;
      _status = '';
    });

    try {
      await DropdownMigrationHelper.pushDesignationsToFirebase();
      setState(() {
        _status =
            '✅ Success! Designation dropdown has been updated in Firebase.\n\n42 designations are now live in dropdown_options/designation.\n\nAll users will see the updated list next time they open the Designation dropdown.';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: Failed to update designations.\n\n$e';
      });
    } finally {
      setState(() {
        _isInitializing = false;
      });
    }
  }
}
