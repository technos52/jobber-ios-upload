import 'package:flutter/material.dart';

class DemoPageScreen extends StatelessWidget {
  final String title;

  const DemoPageScreen({super.key, required this.title});

  static const primaryBlue = Color(0xFF007BFF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFF1F2937),
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    primaryBlue.withOpacity(0.1),
                    primaryBlue.withOpacity(0.05),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getIconForTitle(title),
                size: 64,
                color: primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                'This page is under development.\nComing soon!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForTitle(String title) {
    switch (title.toLowerCase()) {
      case 'edit profile':
        return Icons.edit_rounded;
      case 'my applications':
        return Icons.work_outline_rounded;
      case 'saved jobs':
        return Icons.bookmark_outline_rounded;
      case 'my resume':
        return Icons.description_outlined;
      case 'help & support':
        return Icons.help_outline_rounded;
      case 'about us':
        return Icons.info_outline_rounded;
      default:
        return Icons.person_outline_rounded;
    }
  }
}
