import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';
import 'firebase_options.dart';
import 'screens/login.dart';
import 'screens/student_main.dart';
import 'screens/admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  // 1. Check for saved session
  final prefs = await SharedPreferences.getInstance();
  final String? savedId = prefs.getString('studentId');
  final bool isAdmin = prefs.getBool('isAdmin') ?? false;
  final String? savedName = prefs.getString('studentName');
  final String? savedDept = prefs.getString('studentDept');

  runApp(NemsuVotingApp(
    savedId: savedId, 
    isAdmin: isAdmin, 
    savedName: savedName, 
    savedDept: savedDept
  ));
}

class NemsuVotingApp extends StatelessWidget {
  final String? savedId;
  final bool isAdmin;
  final String? savedName;
  final String? savedDept;

  const NemsuVotingApp({
    super.key, 
    this.savedId, 
    this.isAdmin = false, 
    this.savedName, 
    this.savedDept
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DemocraSync',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.light(
          primary: nemsuBlue,
          secondary: nemsuGold,
        ),
        useMaterial3: true,
      ),
      // 2. Logic to route based on saved session
      home: _determineInitialScreen(),
    );
  }

  Widget _determineInitialScreen() {
    if (savedId != null) {
      if (isAdmin) {
        return const AdminDashboard();
      } else {
        return StudentMainScreen(
          studentId: savedId!, 
          studentName: savedName ?? 'Student', 
          studentDept: savedDept ?? 'NEMSU Student'
        );
      }
    }
    return const LoginScreen();
  }
}