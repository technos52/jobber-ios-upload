import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/auth_wrapper.dart';
import 'screens/welcome_screen.dart';
import 'screens/employer_dashboard_screen.dart';
import 'screens/candidate_registration_step3_fixed.dart';
import 'screens/approval_pending_screen.dart';
import 'screens/employer_verification_screen.dart';
import 'screens/employer_status_screen.dart';
import 'screens/firebase_debug_screen.dart';
import 'screens/admin_employer_management_screen.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/database_test_screen.dart';
import 'screens/admin_dropdown_init_screen.dart';
import 'screens/candidate_job_search_screen.dart';
import 'test_dropdown_service.dart';
import 'test_dropdown_debug.dart';
import 'test_firebase_data.dart';
import 'simple_dropdown_test.dart';
import 'test_dropdown_mapping.dart';
import 'fix_dropdown_data.dart';
import 'debug_candidate_dashboard.dart';
import 'simple_candidate_dashboard.dart';
import 'test_google_auth_debug.dart';
import 'services/auth_service.dart';
import 'services/video_ad_service.dart';
import 'utils/route_observer.dart';
import 'utils/responsive_utils.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/terms_conditions_screen.dart';
import 'screens/fix_empty_dropdowns_screen.dart';
import 'screens/employer_login_screen.dart';
import 'screens/candidate_auth_screen.dart';
import 'debug_admob_real_ads.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Initialize Firebase for Firestore functionality
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Disable Firestore persistence so candidate job lists always fetch fresh data
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
    );

    // Initialize AdMob
    await VideoAdService.initialize();

    await AuthService.initializeAuth();

    // Preload first ad
    VideoAdService.loadRewardedAd();

    runApp(const MyApp());
  } catch (e) {
    debugPrint('Error during app initialization: $e');
    runApp(const MyApp());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'All Job Open',
      debugShowCheckedModeBanner: false,
      theme: _buildResponsiveTheme(),
      navigatorObservers: [routeObserver],
      home: const AuthWrapper(),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/candidate_registration_step3': (context) =>
            const CandidateRegistrationStep3Screen(),
        '/candidate_dashboard': (context) => const SimpleCandidateDashboard(),
        '/candidate_job_search': (context) => const CandidateJobSearchScreen(),
        '/simple_candidate_dashboard': (context) =>
            const SimpleCandidateDashboard(),
        '/employer_dashboard': (context) => const EmployerDashboardScreen(),
        '/auth': (context) => const AuthWrapper(),
        '/approval_pending': (context) => const ApprovalPendingScreen(
          companyName: 'Company',
          approvalStatus: 'pending',
        ),
        '/employer_verification': (context) =>
            const EmployerVerificationScreen(companyName: 'Company'),
        '/employer_status': (context) => const EmployerStatusScreen(),
        '/post_job': (context) => const EmployerDashboardScreen(),
        '/firebase_debug': (context) => const FirebaseDebugScreen(),
        '/admin_dashboard': (context) => const AdminDashboardScreen(),
        '/admin_employers': (context) => const AdminEmployerManagementScreen(),
        '/database_test': (context) => const DatabaseTestScreen(),
        '/admin_dropdown_init': (context) => const AdminDropdownInitScreen(),
        '/test_dropdown': (context) => const TestDropdownServiceScreen(),
        '/debug_dropdown': (context) => const DropdownDebugScreen(),
        '/test_mapping': (context) => const TestDropdownMapping(),
        '/fix_dropdown': (context) => const FixDropdownDataScreen(),
        '/debug_dashboard': (context) => const DebugCandidateDashboard(),
        '/simple_dashboard': (context) => const SimpleCandidateDashboard(),
        '/test_firebase': (context) => const TestFirebaseDataScreen(),
        '/simple_test': (context) => const SimpleDropdownTest(),
        '/privacy_policy': (context) => const PrivacyPolicyScreen(),
        '/terms_conditions': (context) => const TermsConditionsScreen(),
        '/fix_dropdowns': (context) => const FixEmptyDropdownsScreen(),
        '/login': (context) => const AuthWrapper(), // Generic login route
        '/employer_login': (context) => const EmployerLoginScreen(),
        '/candidate_auth': (context) => const CandidateAuthScreen(),
        '/test_google_auth': (context) => const GoogleAuthDebugScreen(),
        '/debug_admob': (context) => AdMobDiagnosticScreen(),
      },
      // Add responsive builder to handle different screen sizes
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            // Ensure text scale factor doesn't exceed reasonable limits
            textScaler: TextScaler.linear(
              ResponsiveUtils.getResponsiveTextScaleFactor(
                context,
              ).clamp(0.8, 1.3),
            ),
          ),
          child: child!,
        );
      },
    );
  }

  /// Build responsive theme based on screen size
  ThemeData _buildResponsiveTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF007BFF),
        brightness: Brightness.light,
      ),
      useMaterial3: true,
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.adaptivePlatformDensity,

      // Responsive app bar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Color(0xFF007BFF)),
        titleTextStyle: TextStyle(
          color: Color(0xFF1F2937),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        centerTitle: true,
      ),

      // Responsive card theme
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Responsive elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF007BFF),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Responsive outlined button theme
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF007BFF),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: const BorderSide(color: Color(0xFF007BFF)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),

      // Responsive text button theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF007BFF),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // Responsive input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF007BFF), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: TextStyle(
          color: Colors.grey.shade400,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1F2937),
        ),
      ),

      // Responsive bottom navigation bar theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: Color(0xFF007BFF),
        unselectedItemColor: Color(0xFF9CA3AF),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Responsive snack bar theme
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1F2937),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      // Responsive dialog theme
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: const TextStyle(
          color: Color(0xFF1F2937),
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Responsive list tile theme
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        titleTextStyle: TextStyle(
          color: Color(0xFF1F2937),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
      ),

      // Responsive divider theme
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
        space: 1,
      ),

      // Responsive chip theme
      chipTheme: ChipThemeData(
        backgroundColor: Colors.grey.shade100,
        selectedColor: const Color(0xFF007BFF).withValues(alpha: 0.1),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
