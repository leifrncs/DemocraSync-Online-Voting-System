import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart'; 
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;     
import '../constants.dart';
import '../services/ai_ocr_service.dart';
import '../widgets/ai_scan_dialog.dart';

class ProfileScreen extends StatefulWidget {
  final String studentId; 

  const ProfileScreen({super.key, required this.studentId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = false;

  // --- COR MANAGEMENT ---
  void _viewCOR(String base64String) {
    if (base64String.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No COR image found.')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(
                  base64Decode(base64String.replaceAll(RegExp(r'\s+'), '')),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(20),
                    child: const Text('Error loading image. It may be corrupted.', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.cancel, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateCOR() async {
    // 1. Mobile permissions check
    if (!kIsWeb) {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.storage,
        Permission.photos,
      ].request();

      if (!(statuses[Permission.photos]!.isGranted || statuses[Permission.storage]!.isGranted)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Permission denied! Please allow access to photos/storage.'), backgroundColor: Colors.redAccent));
        return;
      }
    }

    // 2. Pick the file using Web-safe data loading
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'png', 'jpeg'],
      withData: true,
    );

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        var pickedFile = result.files.first;

        if (pickedFile.bytes == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to read file data. Please try again.'), backgroundColor: Colors.redAccent));
          setState(() => _isLoading = false);
          return;
        }

        final imageBytes = pickedFile.bytes!;
        String base64Image = base64Encode(imageBytes);

        if (base64Image.length > 900000) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File is too large! Please select a smaller image.'), backgroundColor: Colors.redAccent));
          setState(() => _isLoading = false);
          return;
        }

        // Fetch current student profile for verification matching
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('voters').doc(widget.studentId).get();
        Map<String, dynamic> userData = (userDoc.data() as Map<String, dynamic>?) ?? {};
        String fullName = userData['name'] ?? '';
        String department = userData['department'] ?? '';
        String course = userData['course'] ?? '';
        String yearLevel = userData['yearLevel'] ?? '';

        // 3. Launch interactive AI Vision OCR Scanning Dialog
        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AiScanningDialog(
            statusText: 'Analyzing updated Certificate of Registration (COR) with Gemini Vision AI...',
          ),
        );

        // 4. Perform AI OCR Analysis
        final ocrResult = await AiOcrService().analyzeCOR(
          imageBytes: imageBytes,
          studentId: widget.studentId,
          fullName: fullName,
          firstName: userData['firstName'],
          middleName: userData['middleName'],
          lastName: userData['lastName'],
          suffix: userData['suffix'],
          department: department,
          course: course,
          yearLevel: yearLevel,
        );

        // Close scanning dialog
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        String assignedStatus = ocrResult.verdict;

        // 5. Update Firestore with new COR, Status, and AI Analysis
        await FirebaseFirestore.instance.collection('voters').doc(widget.studentId).update({
          'corBase64': base64Image,
          'status': assignedStatus,
          'aiAnalysis': ocrResult.toMap(),
        });

        // 6. Log re-upload event in Audit Logs
        await FirebaseFirestore.instance.collection('audit_logs').add({
          'timestamp': FieldValue.serverTimestamp(),
          'logCategory': 'AI_OCR_AUDIT',
          'action': 'COR Re-upload AI Verification',
          'user': widget.studentId,
          'type': 'COR Re-upload',
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

        // 7. Present interactive AI Result Dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AiScanResultDialog(
            result: ocrResult,
            onContinue: () {
              // Dialog dismissed
            },
          ),
        );

      } catch (e) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating COR: $e'), backgroundColor: Colors.redAccent));
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // --- ACCOUNT SECURITY MANAGEMENT ---
  void _editEmail(String currentEmail) {
    TextEditingController emailController = TextEditingController(text: currentEmail);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Email', style: TextStyle(color: nemsuBlue, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: emailController,
          decoration: InputDecoration(
            labelText: 'New Institutional Email',
            hintText: '@nemsu.edu.ph',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: nemsuBlue),
            onPressed: () async {
              String newEmail = emailController.text.trim();
              if (!newEmail.endsWith('@nemsu.edu.ph')) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Must be an official @nemsu.edu.ph email.'), backgroundColor: Colors.orange));
                return;
              }
              await FirebaseFirestore.instance.collection('voters').doc(widget.studentId).update({'email': newEmail});
              if (!context.mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email updated successfully!'), backgroundColor: Colors.green));
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _changePassword(String actualPassword) {
    TextEditingController currentCtrl = TextEditingController();
    TextEditingController newCtrl = TextEditingController();
    TextEditingController confirmCtrl = TextEditingController();
    bool obscureText = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // Required to toggle password visibility inside a dialog
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Change Password', style: TextStyle(color: nemsuBlue, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: currentCtrl, obscureText: obscureText, decoration: const InputDecoration(labelText: 'Current Password')),
                  const SizedBox(height: 10),
                  TextField(controller: newCtrl, obscureText: obscureText, decoration: const InputDecoration(labelText: 'New Password')),
                  const SizedBox(height: 10),
                  TextField(controller: confirmCtrl, obscureText: obscureText, decoration: const InputDecoration(labelText: 'Confirm New Password')),
                  Row(
                    children: [
                      Checkbox(value: !obscureText, onChanged: (val) => setDialogState(() => obscureText = !val!)),
                      const Text('Show Passwords', style: TextStyle(fontSize: 12)),
                    ],
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: nemsuBlue),
                onPressed: () async {
                  if (currentCtrl.text != actualPassword) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Current password is incorrect.'), backgroundColor: Colors.redAccent));
                    return;
                  }
                  if (newCtrl.text != confirmCtrl.text || newCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New passwords do not match or are empty.'), backgroundColor: Colors.orange));
                    return;
                  }

                  await FirebaseFirestore.instance.collection('voters').doc(widget.studentId).update({'password': newCtrl.text});
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed successfully!'), backgroundColor: Colors.green));
                },
                child: const Text('Update', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      
      body: Stack(
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('voters').doc(widget.studentId).snapshots(),
            builder: (context, snapshot) {
              
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: nemsuBlue));
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return const Center(child: Text("Error: Profile data not found."));
              }

              var data = snapshot.data!.data() as Map<String, dynamic>;
              
              String name = data['name'] ?? 'Unknown Student';
              String firstName = data['firstName'] ?? '';
              String middleName = data['middleName'] ?? '';
              String lastName = data['lastName'] ?? '';
              String suffix = data['suffix'] ?? '';
              String enrollmentStatus = data['status'] ?? 'Pending Verification';
              
              String department = data['department'] ?? 'N/A';
              String course = data['course'] ?? 'N/A';
              String yearLevel = data['yearLevel'] ?? 'N/A';
              String email = data['email'] ?? 'N/A';
              String password = data['password'] ?? '';
              String corBase64 = data['corBase64'] ?? '';

              return SingleChildScrollView(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 700),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                    // --- 1. USER ID CARD (HEADER) ---
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))],
                      ),
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 45,
                            backgroundColor: nemsuGold,
                            child: Icon(Icons.person, size: 50, color: nemsuBlue),
                          ),
                          const SizedBox(height: 16),
                          Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: nemsuBlue), textAlign: TextAlign.center),
                          const SizedBox(height: 4),
                          Text('ID: ${widget.studentId}', style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 12),
                          
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: enrollmentStatus == 'Verified' ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: enrollmentStatus == 'Verified' ? Colors.green : Colors.orange),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(enrollmentStatus == 'Verified' ? Icons.verified_rounded : Icons.pending_actions_rounded, 
                                  color: enrollmentStatus == 'Verified' ? Colors.green : Colors.orange, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  enrollmentStatus == 'Verified' ? 'Verified Voter' : (enrollmentStatus == 'Rejected' ? 'Verification Rejected' : 'Verification Pending'), 
                                  style: TextStyle(color: enrollmentStatus == 'Verified' ? Colors.green : Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 25),

                    // --- 2. STUDENT INFORMATION (READ-ONLY) ---
                    _buildSectionHeader('Student Information'),
                    Container(
                      decoration: _cardDecoration(),
                      child: Column(
                        children: [
                          _buildReadOnlyRow(Icons.person_outline, 'First Name', firstName.isNotEmpty ? firstName : name),
                          const Divider(height: 1, indent: 50),
                          _buildReadOnlyRow(Icons.person_outline, 'Middle Name', middleName.isNotEmpty ? middleName : 'N/A'),
                          const Divider(height: 1, indent: 50),
                          _buildReadOnlyRow(Icons.person_outline, 'Last Name', lastName.isNotEmpty ? lastName : 'N/A'),
                          const Divider(height: 1, indent: 50),
                          _buildReadOnlyRow(Icons.badge_outlined, 'Suffix', suffix.isNotEmpty ? suffix : 'None'),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // --- 3. ACADEMIC DETAILS & COR (PARTIALLY EDITABLE) ---
                    _buildSectionHeader('Academic Details'),
                    Container(
                      decoration: _cardDecoration(),
                      child: Column(
                        children: [
                          _buildReadOnlyRow(Icons.account_balance_outlined, 'Department', department),
                          const Divider(height: 1, indent: 50),
                          _buildReadOnlyRow(Icons.school_outlined, 'Academic Program', course),
                          const Divider(height: 1, indent: 50),
                          _buildReadOnlyRow(Icons.layers_outlined, 'Year Level', yearLevel),
                          const Divider(height: 1, indent: 50),
                          
                          // 👉 NEW: COR Viewer & Uploader
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            child: Row(
                              children: [
                                const Icon(Icons.file_present_rounded, color: nemsuBlue, size: 22),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Certificate of Registration', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                                      SizedBox(height: 2),
                                      Text('Enrollment Proof', style: TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _viewCOR(corBase64), 
                                  child: const Text('View', style: TextStyle(fontWeight: FontWeight.bold, color: nemsuBlue))
                                ),
                                // Only show update button if they are not verified
                                if (enrollmentStatus != 'Verified')
                                  TextButton(
                                    onPressed: _updateCOR, 
                                    child: const Text('Update', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange))
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),
                    
                    // --- 4. ACCOUNT SECURITY (FULLY EDITABLE) ---
                    _buildSectionHeader('Account Security'),
                    Container(
                      decoration: _cardDecoration(),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.email_outlined, color: nemsuBlue),
                            title: const Text('Institutional Email', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                            subtitle: Text(email, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w600)),
                            trailing: const Icon(Icons.edit_outlined, color: Colors.grey, size: 20),
                            onTap: () => _editEmail(email),
                          ),
                          const Divider(height: 1, indent: 50),
                          
                          ListTile(
                            leading: const Icon(Icons.lock_outline, color: nemsuBlue),
                            title: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                            onTap: () => _changePassword(password),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
                  ),
                ),
                ),
              );
            }
          ),
          
          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black45,
              child: const Center(child: CircularProgressIndicator(color: nemsuGold)),
            ),
        ],
      ),
    );
  }

  // --- UI HELPERS ---
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5)),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
    );
  }

  Widget _buildReadOnlyRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey.shade400, size: 22),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, color: Colors.black87, fontWeight: FontWeight.w600, height: 1.3)),
              ],
            ),
          ),
          const Icon(Icons.lock_outline, color: Colors.grey, size: 16), 
        ],
      ),
    );
  }
}