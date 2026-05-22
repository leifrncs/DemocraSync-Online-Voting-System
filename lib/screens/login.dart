import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bcrypt/bcrypt.dart'; 
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'student_main.dart'; 
import 'admin_dashboard.dart'; 
import 'signup.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false; 

  Future<void> _handleLogin() async {
    String studentId = _studentIdController.text.trim();
    String password = _passwordController.text.trim();

    if (studentId.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both ID and Password'), backgroundColor: Colors.redAccent),
      );
      return;
    }

    setState(() => _isLoading = true);

    final prefs = await SharedPreferences.getInstance();

    // --- 1. ADMIN LOGIN LOGIC ---
    if (studentId.toLowerCase() == 'admin' && password == 'admin123') {
      await prefs.setString('studentId', 'admin');
      await prefs.setBool('isAdmin', true);
      
      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminDashboard()),
      );
      return;
    }

    // --- 2. STUDENT LOGIN LOGIC ---
    try {
      DocumentSnapshot voterDoc = await FirebaseFirestore.instance
          .collection('voters')
          .doc(studentId)
          .get();

      if (voterDoc.exists) {
        Map<String, dynamic> data = voterDoc.data() as Map<String, dynamic>;
        
        bool isPasswordCorrect = false;
        try {
          // Keep your existing BCrypt check
          isPasswordCorrect = BCrypt.checkpw(password, data['password']);
        } catch (e) {
          isPasswordCorrect = false; 
        }
        
        if (isPasswordCorrect) {
          // Save session data to SharedPreferences
          await prefs.setString('studentId', studentId);
          await prefs.setString('studentName', data['name'] ?? 'Student');
          await prefs.setString('studentDept', data['department'] ?? 'NEMSU Student');
          await prefs.setBool('isAdmin', false);

          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => StudentMainScreen(
                studentName: data['name'] ?? 'Student', 
                studentId: studentId,
                studentDept: data['department'] ?? 'NEMSU Student', 
              ),
            ),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Incorrect password.'), backgroundColor: Colors.redAccent),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student ID not found.'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection Error: $e'), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: SafeArea(
          // 👉 THE FIX: SingleChildScrollView is now the parent
          child: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600), // Standard width for login cards
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15), // Padding moved here
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          Image.asset(
                          'assets/democrasync-logo1.png',
                          width: 150, 
                          height: 150,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'DemocraSync',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: nemsuBlue, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Empowering the NEMSU Voice in Real-Time',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: nemsuBlue.withOpacity(0.8), fontSize: 16, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),

                    const SizedBox(height: 40),

                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(blurRadius: 20, color: Color(0x14000000), offset: Offset(0, 6))],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Student ID', style: TextStyle(color: nemsuBlue, fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _studentIdController,
                            maxLength: 8,
                            decoration: InputDecoration(
                              hintText: '23-00001',
                              hintStyle: const TextStyle(color: Color(0xFFBDBDBD)),
                              prefixIcon: const Icon(Icons.badge_outlined, color: nemsuBlue, size: 20),
                              filled: true,
                              fillColor: const Color(0xFFF8F9FF),
                              counterText: '', 
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD0D8F0), width: 1.5)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: nemsuBlue, width: 2)),
                            ),
                          ),
                          
                          const SizedBox(height: 15),

                          const Text('Password', style: TextStyle(color: nemsuBlue, fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible, 
                            decoration: InputDecoration(
                              hintText: 'Enter your password',
                              hintStyle: const TextStyle(color: Color(0xFFBDBDBD)),
                              prefixIcon: const Icon(Icons.lock_outline_rounded, color: nemsuBlue, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(_isPasswordVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: const Color(0xFF9E9E9E), size: 20),
                                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8F9FF),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD0D8F0), width: 1.5)),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: nemsuBlue, width: 2)),
                            ),
                          ),

                          const SizedBox(height: 20),

                          SizedBox(
                            height: 54,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: nemsuBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), elevation: 0),
                              onPressed: _isLoading ? null : _handleLogin,
                              child: _isLoading 
                                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                : const Text('Sign In', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),

                          const SizedBox(height: 15),

                          Center(
                            child: InkWell(
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpScreen())),
                              child: Text('Not registered? Create an account', style: TextStyle(color: nemsuBlue.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE8EAF6), width: 1)),
                      child: const Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shield_outlined, color: Color(0xFFBDBDBD), size: 14),
                              SizedBox(width: 6),
                              Text('Authorized students only.', style: TextStyle(color: Color(0xFF9E9E9E), fontSize: 12)),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text('Powered by Syntax Society', style: TextStyle(color: Color(0xFFBDBDBD), fontSize: 11, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }
}