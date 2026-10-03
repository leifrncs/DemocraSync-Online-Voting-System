import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'package:bcrypt/bcrypt.dart'; 
import 'dart:convert'; 
import 'package:flutter/foundation.dart' show kIsWeb;      
import '../constants.dart';
import '../services/ai_ocr_service.dart';
import '../widgets/ai_scan_dialog.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // --- CONTROLLERS ---
  final _studentIdController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _suffixController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // --- STATE VARIABLES ---
  bool _isPasswordVisible = false;
  bool _isLoading = false; 

  String? _selectedDept;
  String? _selectedCourse;
  String? _selectedYear;
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

  @override
  void dispose() {
    _studentIdController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _suffixController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickCOR() async {
    // 1. Only request permissions if we are NOT on web
    if (!kIsWeb) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.photos,
      ].request();

      if (!(statuses[Permission.photos]!.isGranted || statuses[Permission.storage]!.isGranted)) {
        _showError('Permission denied! Please allow access to photos/storage.');
        return;
      }
    }

    // 2. Pick the file with Web data support FOR ALL PLATFORMS
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png'],
      withData: true, 
    );

    if (result != null) {
      setState(() {
        _pickedFile = result.files.first;
      });
    }
  }

  void _showPrivacyPolicyDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.policy_rounded, color: nemsuBlue),
              SizedBox(width: 8),
              Expanded(child: Text('Data Privacy Policy', style: TextStyle(color: nemsuBlue, fontWeight: FontWeight.bold, fontSize: 18))),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                      'DemocraSync Online Voting Application\nNorth Eastern Mindanao State University (NEMSU)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildPolicyHeader('Statement of Policy'),
                  _buildPolicyText('The North Eastern Mindanao State University (NEMSU) is committed to protecting the privacy and security of its students\' personal data. This Data Privacy Policy explains how the DemocraSync Online Voting Application collects, uses, processes, and protects your information in compliance with the Republic Act No. 10173, also known as the Data Privacy Act of 2012 (DPA), and its Implementing Rules and Regulations.'),
                  
                  _buildPolicyHeader('1. Information We Collect'),
                  _buildPolicyText('To facilitate a secure, fair, and transparent student election process, DemocraSync collects the following types of information:'),
                  _buildPolicyBullet('Personal Identification Data: Full Name, Student ID Number, Course, Year Level, and Section/College.'),
                  _buildPolicyBullet('Contact Information: Institutional Email Address or registered secondary email.'),
                  _buildPolicyBullet('Technical and Security Data: IP address, device type, browser information, and login timestamps to monitor system security and prevent unauthorized access.'),
                  _buildPolicyBullet('Voting Data: Encrypted records of your ballot submission. Note: To ensure the sanctity of the ballot, your personal identity is permanently decoupled from your specific vote choices. The system records THAT you voted, but not WHO you voted for.'),

                  _buildPolicyHeader('2. Purpose of Data Collection'),
                  _buildPolicyText('Your personal data is collected and processed exclusively for the following purposes:'),
                  _buildPolicyBullet('To verify your identity and eligibility to vote in the current election.'),
                  _buildPolicyBullet('To issue secure, one-time voting credentials (e.g., OTPs or voting links).'),
                  _buildPolicyBullet('To prevent election fraud, such as multiple voting or unauthorized access.'),
                  _buildPolicyBullet('To generate accurate and verifiable voter turnout reports and election results.'),
                  _buildPolicyBullet('To maintain an audit trail for the resolution of any electoral protests or technical disputes.'),

                  _buildPolicyHeader('3. Data Sharing and Disclosure'),
                  _buildPolicyText('NEMSU will never sell, rent, or trade your personal information. Access to your data within the DemocraSync system is strictly limited to:'),
                  _buildPolicyBullet('Authorized System Administrators: For technical maintenance and security monitoring.'),
                  _buildPolicyBullet('NEMSU Commission on Elections (COMELEC): For verifying voter rolls and addressing election protests.'),
                  _buildPolicyText('Your data will not be disclosed to any external third parties unless mandated by law or a valid legal order.'),

                  _buildPolicyHeader('4. Data Security'),
                  _buildPolicyText('We implement robust organizational, physical, and technical security measures to safeguard your data. These include:'),
                  _buildPolicyBullet('End-to-end encryption of all data transmitted between your device and our servers.'),
                  _buildPolicyBullet('Strict role-based access controls for system administrators and election officials.'),
                  _buildPolicyBullet('Cryptographic hashing of voting receipts to guarantee ballot secrecy and integrity.'),
                  _buildPolicyBullet('Regular security audits and vulnerability assessments of the DemocraSync platform.'),

                  _buildPolicyHeader('5. Data Retention and Disposal'),
                  _buildPolicyText('Personal data collected during the election period will only be retained for as long as necessary to fulfill the purposes outlined in this policy. Specifically:'),
                  _buildPolicyBullet('Voter logs and system audit trails will be retained for sixty (60) days following the official certification of election results, or until any pending electoral protests are fully resolved.'),
                  _buildPolicyBullet('After the retention period, all personal data and voting records will be securely and permanently deleted from our servers in accordance with the National Archives of the Philippines guidelines and the DPA.'),

                  _buildPolicyHeader('6. Rights of the Data Subject'),
                  _buildPolicyText('Under the Data Privacy Act of 2012, you possess the following rights regarding your personal data:'),
                  _buildPolicyBullet('Right to be Informed: To know how your data will be collected and processed.'),
                  _buildPolicyBullet('Right to Access: To request a copy of the personal information we hold about you.'),
                  _buildPolicyBullet('Right to Object: To withhold consent, recognizing that doing so will forfeit your ability to use DemocraSync and participate in the online election.'),
                  _buildPolicyBullet('Right to Rectification: To correct any inaccuracies in your student voting profile.'),
                  _buildPolicyBullet('Right to Erasure or Blocking: To request the deletion of your data under specific conditions established by law.'),

                  _buildPolicyHeader('7. Consent'),
                  _buildPolicyText('By logging into the DemocraSync Online Voting Application and casting your ballot, you explicitly consent to the collection, processing, and storage of your personal data as described in this Data Privacy Policy.'),

                  _buildPolicyHeader('8. Contact Us'),
                  _buildPolicyText('If you have any questions, concerns, or requests regarding this Privacy Policy or your personal data, please contact the NEMSU Data Protection Officer (DPO) or the Supreme Student Council (SSC) COMELEC at:\n• Email: dpo@nemsu.edu.ph / comelec@nemsu.edu.ph\n• Office: Office of the Student Affairs and Services, North Eastern Mindanao State University, Tandag City, Surigao del Sur.'),
                  ],
              ),
            ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('Close', style: TextStyle(color: Colors.grey))
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: nemsuBlue, foregroundColor: Colors.white),
              onPressed: () {
                setState(() => _agreedToTerms = true);
                Navigator.pop(context);
              },
              child: const Text('I Agree'),
            ),
          ],
        );
      }
    );
  }

  // Formatting helpers for the dialog
  Widget _buildPolicyHeader(String text) => Padding(
    padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: nemsuBlue)),
  );
  Widget _buildPolicyText(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(text, style: const TextStyle(fontSize: 12, height: 1.4)),
  );
  Widget _buildPolicyBullet(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6.0, left: 12.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: nemsuGold)),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12, height: 1.4))),
      ],
    ),
  );

  Future<void> _handleRegistration() async {
    final email = _emailController.text.trim();
    final studentId = _studentIdController.text.trim();
    final firstName = _firstNameController.text.trim();
    final middleName = _middleNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final suffix = _suffixController.text.trim();

    if (studentId.isEmpty || firstName.isEmpty || lastName.isEmpty) {
      _showError('Please fill in all required text fields.');
      return;
    }
    if (_selectedDept == null || _selectedCourse == null || _selectedYear == null) {
      _showError('Please select all academic dropdown options.');
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
      _showError('Please agree to the Data Privacy Policy.');
      return;
    }

    // Construct full name string from structured components
    final fullName = [
      firstName,
      if (middleName.isNotEmpty) middleName,
      lastName,
      if (suffix.isNotEmpty) suffix,
    ].join(' ');

    setState(() => _isLoading = true);

    try {
      DocumentSnapshot existingUser = await FirebaseFirestore.instance.collection('voters').doc(studentId).get();
      if (existingUser.exists) {
        _showError('This Student ID is already registered.');
        setState(() => _isLoading = false);
        return;
      }

      if (_pickedFile!.bytes == null) {
        _showError('Failed to read file data. Please try re-selecting the image.');
        setState(() => _isLoading = false);
        return;
      }

      final imageBytes = _pickedFile!.bytes!;
      String base64Image = base64Encode(imageBytes);

      if (base64Image.length > 900000) {
        _showError('File is too large! Please select a smaller or compressed image.');
        setState(() => _isLoading = false);
        return;
      }

      // 1. Launch interactive Document Verification Scanning Dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AiScanningDialog(
          statusText: 'Verifying Certificate of Registration (COR)... Please wait.',
        ),
      );

      // 2. Perform AI OCR Analysis
      final ocrResult = await AiOcrService().analyzeCOR(
        imageBytes: imageBytes,
        studentId: studentId,
        fullName: fullName,
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        suffix: suffix,
        department: _selectedDept!,
        course: _selectedCourse!,
        yearLevel: _selectedYear!,
      );

      // Close scanning dialog
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      String hashedPassword = BCrypt.hashpw(_passwordController.text, BCrypt.gensalt());
      String assignedStatus = ocrResult.verdict; // 'Verified', 'Pending Verification', or 'Rejected'

      // 3. Save Student Record with AI Analysis in Firestore (Personal details age/birthDate/gender removed)
      await FirebaseFirestore.instance.collection('voters').doc(studentId).set({
        'firstName': firstName,
        'middleName': middleName.isNotEmpty ? middleName : null,
        'lastName': lastName,
        'suffix': suffix.isNotEmpty ? suffix : null,
        'name': fullName,
        'department': _selectedDept,
        'course': _selectedCourse,
        'yearLevel': _selectedYear,
        'email': email,
        'password': hashedPassword, 
        'corBase64': base64Image,
        'status': assignedStatus,
        'aiAnalysis': ocrResult.toMap(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      // 4. Log AI OCR Event in Audit Logs
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'logCategory': 'AI_OCR_AUDIT',
        'action': 'AI OCR Verification Processed',
        'user': studentId,
        'type': 'Student Registration',
        'details': {
          'Verdict': assignedStatus,
          'Confidence': '${(ocrResult.confidence * 100).toInt()}%',
          'ID Matched': ocrResult.idMatched,
          'Name Matched': ocrResult.nameMatched,
          'Year Level Matched': ocrResult.yearLevelMatched,
          'Course Matched': ocrResult.courseMatched,
          'Dept Matched': ocrResult.departmentMatched,
          'Detected ID': ocrResult.detectedStudentId,
          'Detected Name': ocrResult.detectedFullName,
          'Reason': ocrResult.reason,
        },
      });

      if (!mounted) return;

      // 5. Present interactive AI Result Dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AiScanResultDialog(
          result: ocrResult,
          onContinue: () {
            Navigator.pop(context); // Return to Login screen
          },
        ),
      );

    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // Close scanning dialog if open
      }
      _showError('Error during registration: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
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
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 700),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                      _sectionTitle('Student Information'),
                      _buildField(_firstNameController, 'First Name', Icons.person_outline),
                      _buildField(_middleNameController, 'Middle Name (Optional)', Icons.person_outline),
                      _buildField(_lastNameController, 'Last Name', Icons.person_outline),
                      _buildField(_suffixController, 'Suffix (e.g. Jr., III - Optional)', Icons.badge_outlined),

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

                      const SizedBox(height: 20),
                      _sectionTitle('Account Security'),
                      _buildField(_emailController, 'NEMSU Email (@nemsu.edu.ph)', Icons.email_outlined),
                      _buildPasswordField(_passwordController, 'Password'),
                      _buildPasswordField(_confirmPasswordController, 'Confirm Password'),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Checkbox(
                            value: _agreedToTerms, 
                            activeColor: nemsuBlue, 
                            onChanged: (val) => setState(() => _agreedToTerms = val!)
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: _showPrivacyPolicyDialog,
                              child: RichText(
                                text: const TextSpan(
                                  style: TextStyle(fontSize: 11, color: Colors.black87),
                                  children: [
                                    TextSpan(text: 'I have read and agree to the '),
                                    TextSpan(
                                      text: 'Data Privacy Policy', 
                                      style: TextStyle(color: nemsuBlue, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)
                                    ),
                                    TextSpan(text: ' for student elections.'),
                                  ]
                                )
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      
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
          ),
        ),
      ),
    );
  }

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