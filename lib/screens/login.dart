import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

    // Admin Routing
    if (studentId.toLowerCase() == 'admin') {
      if (password == 'admin123') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminDashboard()));
      } else {
        // 👉 NEW: WRITE A SECURITY THREAT LOG
        FirebaseFirestore.instance.collection('audit_logs').add({
          'timestamp': FieldValue.serverTimestamp(),
          'logCategory': 'SECURITY ALERT',
          'event': 'Failed Admin Login Attempt',
          'severity': 'Warning',
          'details': {
            'Target': 'Login Authentication',
            'Trigger': 'Incorrect password entered for "admin"',
            'Recommended_Action': 'Monitor for brute-force attacks.'
          },
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect Admin Password'), backgroundColor: Colors.redAccent),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      DocumentSnapshot voterDoc = await FirebaseFirestore.instance
          .collection('voters')
          .doc(studentId)
          .get();

      if (voterDoc.exists) {
        Map<String, dynamic> data = voterDoc.data() as Map<String, dynamic>;
        
        if (data['password'] == password) {
          
          // 👉 NEW: NOTIFY BUT DON'T BLOCK
          if (data['status'] == 'Pending Verification' || data['status'] == 'Pending') {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Welcome! Your account is currently under review. The ballot will unlock once verified.'), 
                backgroundColor: Colors.orange, 
                duration: Duration(seconds: 4),
              ),
            );
            // Notice there is no "return;" here anymore. We let the code continue!
          } else if (data['status'] == 'Verified') {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Login Successful!'), backgroundColor: Colors.green),
            );
          }

          // Let them into the app!
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
            const SnackBar(content: Text('Incorrect password. Please try again.'), backgroundColor: Colors.redAccent),
          );
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Student ID not found. Are you registered?'), backgroundColor: Colors.redAccent),
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 15),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // --- 1. HEADER SECTION ---
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

                // --- 2. FORM SECTION ---
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
                      
                      const SizedBox(height: 20),

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

                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Text('Hint: Use ID "admin" & pass "admin123" for Admin Panel', style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
                      ),

                      const SizedBox(height: 30),

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

                      const SizedBox(height: 20),

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

                // --- 3. FOOTER SECTION ---
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
    );
  }
}