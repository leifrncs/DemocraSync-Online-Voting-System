import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'constants.dart';
import 'firebase_options.dart';
import 'screens/login.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const NemsuVotingApp());
}
class NemsuVotingApp extends StatelessWidget {
  const NemsuVotingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NEMSU Voting System',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.light(
          primary: nemsuBlue,
          secondary: nemsuGold,
        ),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: nemsuBlue, width: 2.0),
          ),
          prefixIconColor: nemsuBlue,
        ),
      ),
      home: const LoginScreen(), 
    );
  }
}