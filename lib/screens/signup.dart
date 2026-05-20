import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 👉 NEW: Firestore import
import 'dart:convert'; // 👉 NEW: For Base64 encoding
import 'dart:io';      // 👉 NEW: For reading the file
import '../constants.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // --- CONTROLLERS ---
  final _studentIdController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _ageController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // --- STATE VARIABLES ---
  bool _isPasswordVisible = false;
  bool _isLoading = false; // 👉 NEW: Tracks database upload status

  String? _selectedDept;
  String? _selectedCourse;
  String? _selectedYear;
  String? _selectedGender;
  PlatformFile? _pickedFile; 
  bool _agreedToTerms = false;

  final Map<String, List<String>> _coursesByDept = {
    'College of Teacher Education': [
      'Bachelor of Secondary Education major in Science',
      'Bachelor of Secondary Education major in Filipino',
      'Bachelor of Secondary Education major in English',
      'Bachelor of Physical Education',
      'Bachelor of Elementary Education',
      'Bachelor of Early Childhood Education'
    ],
    'College of Arts and Sciences': [
      'Batsilyer sa Sining ng Filipino',
      'Bachelor of Science in Midwifery',
      'Bachelor of Science in Mathematics',
      'Bachelor of Science in Environmental Science',
      'Bachelor of Science in Biology',
      'Bachelor of Arts in Political Science',
      'Bachelor of Arts in English',
      'Bachelor of Arts in Economics'
    ],
    'College of Business and Management': [
      'Bachelor of Science in Hospitality Management',
      'Bachelor of Public Administration',
      'Bachelor of Science in Business Administration major in Marketing Management',
      'Bachelor of Science in Business Administration major in Human Resource Management',
      'Bachelor of Science in Business Administration major in Financial Management'
    ],
    'College of Information Technology Education': [
      'Bachelor of Science in Computer Science'
    ],
    'College of Engineering and Technology': [
      'Bachelor of Science in Civil Engineering'
    ],
  };

  final List<String> _yearLevels = ['1st Year', '2nd Year', '3rd Year', '4th Year', '5th Year'];
  final List<String> _genders = ['Male', 'Female', 'Other'];

  @override
  void dispose() {
    _studentIdController.dispose();
    _fullNameController.dispose();
    _ageController.dispose();
    _birthDateController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickCOR() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
    );

    if (result != null) {
      setState(() {
        _pickedFile = result.files.first;
      });
    }
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 6570)), 
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _birthDateController.text = "${picked.year}-${picked.month}-${picked.day}";
      });
    }
  }

  // 👉 UPDATED: Now handles Base64 encoding and Firestore writes
  Future<void> _handleRegistration() async {
    final email = _emailController.text.trim();
    final studentId = _studentIdController.text.trim();

    // 1. Basic Validations
    if (studentId.isEmpty || _fullNameController.text.isEmpty) {
      _showError('Please fill in all text fields.');
      return;
    }
    if (_selectedDept == null || _selectedCourse == null || _selectedYear == null || _selectedGender == null) {
      _showError('Please select all dropdown options.');
      return;
    }
    if (!email.endsWith('@nemsu.edu.ph')) {
      _showError('Registration denied: Must use an official @nemsu.edu.ph email.');
      return;
    }
    if (_pickedFile == null) {
      _showError('Please upload your Certificate of Registration (COR).');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Passwords do not match.');
      return;
    }
    if (!_agreedToTerms) {
      _showError('Please agree to the terms and conditions.');
      return;
    }

    setState(() => _isLoading = true); // Start loading spinner

    try {
      // 2. Check for Duplicate Student ID
      DocumentSnapshot existingUser = await FirebaseFirestore.instance.collection('voters').doc(studentId).get();
      if (existingUser.exists) {
        _showError('This Student ID is already registered.');
        setState(() => _isLoading = false);
        return;
      }

      // 3. Convert the Image to a Base64 Text String
      String base64Image = '';
      if (_pickedFile!.bytes != null) {
        // For Web
        base64Image = base64Encode(_pickedFile!.bytes!);
      } else {
        // For Mobile
        File file = File(_pickedFile!.path!);
        List<int> bytes = await file.readAsBytes();
        base64Image = base64Encode(bytes);
      }

      // Firestore has a 1MB limit per document. 
      if (base64Image.length > 900000) {
        _showError('File is too large! Please select a smaller or compressed image.');
        setState(() => _isLoading = false);
        return;
      }

      // 4. Save Student Data AND the Base64 Image directly to Firestore
      await FirebaseFirestore.instance.collection('voters').doc(studentId).set({
        'name': _fullNameController.text.trim(),
        'age': _ageController.text.trim(),
        'birthDate': _birthDateController.text,
        'gender': _selectedGender,
        'department': _selectedDept,
        'course': _selectedCourse,
        'yearLevel': _selectedYear,
        'email': email,
        'password': _passwordController.text, 
        'corBase64': base64Image, // 👉 The AI Python script will read this!
        'status': 'Pending Verification', // 👉 Default lock status
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 5. Success! Navigate back
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registration submitted! Awaiting AI verification.'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);

    } catch (e) {
      _showError('Error during registration: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false); // Stop loading spinner
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.redAccent));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        appBar: AppBar(
          backgroundColor: Colors.transparent, 
          elevation: 0, 
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: nemsuBlue), 
            onPressed: () => Navigator.pop(context)
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: Column(
              children: [
                const Text('Student Registration', style: TextStyle(color: nemsuBlue, fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Please fill out the form below to register your information.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 25),

                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.white, 
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [BoxShadow(blurRadius: 15, color: Color(0x0D000000))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- SECTION 1: PERSONAL INFO ---
                      _sectionTitle('Personal Information'),
                      _buildField(_fullNameController, 'Full Name', Icons.person_outline),
                      Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Age takes up 2 parts of the space
                          Expanded(
                            flex: 2, 
                            child: TextFormField(
                              controller: _ageController,
                              keyboardType: TextInputType.number,
                              decoration: _buildInputDecoration('Age', Icons.cake_outlined),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Birth Date takes up 3 parts of the space so the text fits
                          Expanded(
                            flex: 3, 
                            child: TextFormField(
                              controller: _birthDateController,
                              readOnly: true,
                              onTap: _selectDate,
                              decoration: _buildInputDecoration('Birth Date', Icons.calendar_month_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                      _buildDropdown('Gender', _genders, _selectedGender, (val) => setState(() => _selectedGender = val), Icons.wc_outlined),

                      // --- SECTION 2: ACADEMIC INFO ---
                      const SizedBox(height: 20),
                      _sectionTitle('Academic Details'),
                      _buildField(_studentIdController, 'Student ID (e.g. 23-0001)', Icons.badge_outlined),
                      
                      _buildDropdown(
                        'Select Department', 
                        _coursesByDept.keys.toList(), 
                        _selectedDept, 
                        (val) {
                          setState(() {
                            _selectedDept = val;
                            _selectedCourse = null; 
                          });
                        }, 
                        Icons.account_balance_outlined
                      ),
                      _buildDropdown(
                        'Select Academic Program', 
                        _selectedDept == null ? [] : _coursesByDept[_selectedDept]!, 
                        _selectedCourse, 
                        (val) => setState(() => _selectedCourse = val), 
                        Icons.school_outlined
                      ),
                      _buildDropdown('Year Level', _yearLevels, _selectedYear, (val) => setState(() => _selectedYear = val), Icons.layers_outlined),
                                          
                      // --- SECTION 3: DOCUMENT UPLOAD ---
                      const SizedBox(height: 20),
                      _sectionTitle('Enrollment Verification'),
                      const Text('Upload Certificate of Registration (Small Image/Screenshot)', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _pickCOR,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            color: nemsuBlue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: nemsuBlue.withOpacity(0.2), style: BorderStyle.solid),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.cloud_upload_outlined, color: nemsuBlue, size: 30),
                              const SizedBox(height: 8),
                              Text(_pickedFile == null ? 'Select File' : _pickedFile!.name, 
                                style: const TextStyle(color: nemsuBlue, fontWeight: FontWeight.bold, fontSize: 13),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // --- SECTION 4: SECURITY ---
                      const SizedBox(height: 20),
                      _sectionTitle('Account Security'),
                      _buildField(_emailController, 'NEMSU Email (@nemsu.edu.ph)', Icons.email_outlined),
                      _buildPasswordField(_passwordController, 'Password'),
                      _buildPasswordField(_confirmPasswordController, 'Confirm Password'),

                      // --- TERMS ---
                      Row(
                        children: [
                          Checkbox(value: _agreedToTerms, activeColor: nemsuBlue, onChanged: (val) => setState(() => _agreedToTerms = val!)),
                          const Expanded(child: Text('I agree to the Data Privacy Policy for student elections.', style: TextStyle(fontSize: 11))),
                        ],
                      ),

                      const SizedBox(height: 20),
                      
                      // 👉 UPDATED: Button shows a loading spinner during upload
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: nemsuBlue, 
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12), 
                            ),
                          ),
                          onPressed: _isLoading ? null : _handleRegistration,
                          child: _isLoading 
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                            : const Text('Submit Registration', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
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

  // --- UI HELPERS ---
  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12, top: 4),
    child: Text(title, style: const TextStyle(color: nemsuBlue, fontWeight: FontWeight.bold, fontSize: 14)),
  );

  Widget _buildField(TextEditingController controller, String hint, IconData icon, {bool isNumber = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        decoration: _buildInputDecoration(hint, icon),
      ),
    );
  }

  Widget _buildDropdown(String hint, List<String> items, String? value, Function(String?) onChanged, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        isExpanded: true,
        decoration: _buildInputDecoration(hint, icon),
        value: value,
        items: items.map((e) => DropdownMenuItem(
          value: e, 
          child: Text(
            e, 
            style: const TextStyle(fontSize: 13),
            overflow: TextOverflow.ellipsis, 
            maxLines: 1, 
          )
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String hint) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: !_isPasswordVisible,
        decoration: _buildInputDecoration(hint, Icons.lock_outline).copyWith(
          suffixIcon: IconButton(
            icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, size: 20),
            onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: nemsuBlue, size: 20),
      filled: true, fillColor: const Color(0xFFF8F9FF),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD0D8F0))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: nemsuBlue, width: 2)),
    );
  }
}