import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 
import 'dart:convert'; // 👉 NEW: Required to decode the Base64 COR image
import '../constants.dart';
import '../services/ai_ocr_service.dart';

class VoterManagement extends StatefulWidget {
  const VoterManagement({super.key});

  @override
  State<VoterManagement> createState() => _VoterManagementState();
}

class _VoterManagementState extends State<VoterManagement> {
  String searchQuery = '';
  String selectedFilter = 'All';
  String selectedStatus = 'All Status';
  String selectedDept = 'All Departments';

  final List<String> departments = [
    'All Departments',
    'College of Information Technology Education',
    'College of Business and Management',
    'College of Teacher Education',
    'College of Engineering and Technology',
    'College of Arts and Sciences',
  ];

  // 👉 NEW: Pop-up viewer for the Admin to inspect the COR
  void _viewCOR(String base64String) {
    if (base64String.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No COR image found for this student.')));
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

  Future<void> _reScanWithAI(Map<String, dynamic> voter) async {
    String base64 = voter['corBase64'] ?? '';
    if (base64.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No COR image to scan.')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Row(
        children: [
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 12),
          Text('Running Gemini AI OCR analysis...'),
        ],
      ),
      duration: Duration(seconds: 4),
    ));

    try {
      final imageBytes = base64Decode(base64.replaceAll(RegExp(r'\s+'), ''));
      final result = await AiOcrService().analyzeCOR(
        imageBytes: imageBytes,
        studentId: voter['id'],
        fullName: voter['name'],
        firstName: voter['firstName'],
        middleName: voter['middleName'],
        lastName: voter['lastName'],
        suffix: voter['suffix'],
        department: voter['dept'],
        course: voter['course'],
        yearLevel: voter['yearLevel'] ?? '',
      );

      await FirebaseFirestore.instance.collection('voters').doc(voter['id']).update({
        'status': result.verdict,
        'aiAnalysis': result.toMap(),
      });

      await FirebaseFirestore.instance.collection('audit_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'logCategory': 'AI_OCR_AUDIT',
        'action': 'Admin Triggered AI OCR Re-Scan',
        'user': 'Admin_Primary',
        'type': 'Admin Re-Scan',
        'details': {
          'Target': 'voters/${voter['id']}',
          'Verdict': result.verdict,
          'Confidence': '${(result.confidence * 100).toInt()}%',
          'ID Matched': result.idMatched,
          'Name Matched': result.nameMatched,
          'Reason': result.reason,
        },
      });

      if (!mounted) return;
      Navigator.pop(context); // Close details dialog
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('AI Re-Scan complete! Verdict: ${result.verdict} (${result.reason})'),
        backgroundColor: result.verdict == 'Verified' ? Colors.green : Colors.orange,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error during AI Re-Scan: $e'), backgroundColor: Colors.redAccent));
    }
  }

  void _showVoterDetails(Map<String, dynamic> voter) {
    Map<String, dynamic>? aiAnalysis = voter['aiAnalysis'] as Map<String, dynamic>?;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.badge_rounded, color: nemsuBlue),
            SizedBox(width: 10),
            Text('Voter Verification', style: TextStyle(fontWeight: FontWeight.bold, color: nemsuBlue)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoTile('Full Name', voter['name'], isBold: true),
              Row(
                children: [
                  Expanded(child: _infoTile('First Name', voter['firstName'].toString().isNotEmpty ? voter['firstName'] : voter['name'])),
                  Expanded(child: _infoTile('Middle Name', voter['middleName'].toString().isNotEmpty ? voter['middleName'] : 'N/A')),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _infoTile('Last Name', voter['lastName'].toString().isNotEmpty ? voter['lastName'] : 'N/A')),
                  Expanded(child: _infoTile('Suffix', voter['suffix'].toString().isNotEmpty ? voter['suffix'] : 'None')),
                ],
              ),
              const Divider(),
              _infoTile('Student ID', voter['id']),
              _infoTile('Email Address', voter['email']),
              const Divider(),
              _infoTile('Department', voter['dept']),
              _infoTile('Degree Program', voter['course']),
              Row(
                children: [
                  Expanded(child: _infoTile('Year Level', voter['yearLevel'])),
                  Expanded(child: _infoTile('Enrollment', voter['enrollmentStatus'])),
                ],
              ),
              const SizedBox(height: 16),
              
              // 👉 COR Review & Re-scan Section
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300)
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Certificate of Registration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text('Proof of enrollment image', style: TextStyle(color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: nemsuBlue, padding: const EdgeInsets.symmetric(horizontal: 10)),
                          onPressed: () => _viewCOR(voter['corBase64']), 
                          icon: const Icon(Icons.image_search, color: Colors.white, size: 15),
                          label: const Text('View', style: TextStyle(color: Colors.white, fontSize: 11)),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: nemsuGold, foregroundColor: nemsuBlue, padding: const EdgeInsets.symmetric(horizontal: 10)),
                          onPressed: () => _reScanWithAI(voter),
                          icon: const Icon(Icons.auto_awesome, size: 14),
                          label: const Text('AI Re-Scan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ],
                ),
              ),

              // 👉 AI OCR Analysis Card
              if (aiAnalysis != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: nemsuBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome, color: nemsuBlue, size: 15),
                              SizedBox(width: 6),
                              Text('AI OCR Audit Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: nemsuBlue)),
                            ],
                          ),
                          Text(
                            'Confidence: ${((aiAnalysis['confidence'] as num? ?? 0.8) * 100).toInt()}%',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: nemsuBlue),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('• Document Format: ${aiAnalysis['isOfficialCOR'] == true ? 'Official NEMSU COR' : (aiAnalysis['isOfficialCOR'] == false ? 'INVALID / NON-OFFICIAL FORMAT' : 'Unspecified')}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: aiAnalysis['isOfficialCOR'] == true ? Colors.green.shade800 : (aiAnalysis['isOfficialCOR'] == false ? Colors.red.shade700 : null),
                          )),
                      if (aiAnalysis['hasNemsuHeader'] != null || aiAnalysis['hasScheduleTable'] != null)
                        Text('• Structural Markers: Header: ${aiAnalysis['hasNemsuHeader'] == true ? '✓' : '✗'} | Schedule: ${aiAnalysis['hasScheduleTable'] == true ? '✓' : '✗'} | Cert: ${aiAnalysis['hasCertification'] == true ? '✓' : '✗'} | Registrar: ${aiAnalysis['hasRegistrarSignature'] == true ? '✓' : '✗'}',
                            style: const TextStyle(fontSize: 11)),
                      Text('• Detected ID: ${aiAnalysis['detectedStudentId'] ?? 'N/A'} (Match: ${aiAnalysis['idMatched'] == true ? 'YES' : 'NO'})', style: const TextStyle(fontSize: 11)),
                      Text('• Detected Name: ${aiAnalysis['detectedFullName'] ?? 'N/A'} (Match: ${aiAnalysis['nameMatched'] == true ? 'YES' : 'NO'})', style: const TextStyle(fontSize: 11)),
                      if (aiAnalysis['detectedYearLevel'] != null && aiAnalysis['detectedYearLevel'] != 'N/A')
                        Text('• Year Level: ${aiAnalysis['detectedYearLevel']} (Match: ${aiAnalysis['yearLevelMatched'] == true ? 'YES' : 'NO'})', style: const TextStyle(fontSize: 11)),
                      if (aiAnalysis['detectedCourse'] != null && aiAnalysis['detectedCourse'] != 'N/A')
                        Text('• Course: ${aiAnalysis['detectedCourse']} (Match: ${aiAnalysis['courseMatched'] == true ? 'YES' : 'NO'})', style: const TextStyle(fontSize: 11)),
                      if (aiAnalysis['detectedDepartment'] != null && aiAnalysis['detectedDepartment'] != 'N/A')
                        Text('• Department: ${aiAnalysis['detectedDepartment']} (Match: ${aiAnalysis['departmentMatched'] == true ? 'YES' : 'NO'})', style: const TextStyle(fontSize: 11)),
                      if (aiAnalysis['academicYear'] != null && aiAnalysis['academicYear'] != 'N/A')
                        Text('• Academic Period: ${aiAnalysis['semester'] ?? ''} ${aiAnalysis['academicYear'] ?? ''} (Match: ${aiAnalysis['termMatched'] == true ? 'YES' : (aiAnalysis['isOutdated'] == true ? 'OUTDATED' : 'NO')})',
                            style: TextStyle(
                              fontSize: 11,
                              color: aiAnalysis['isOutdated'] == true ? Colors.red.shade700 : null,
                              fontWeight: aiAnalysis['isOutdated'] == true ? FontWeight.bold : FontWeight.normal,
                            )),
                      const SizedBox(height: 4),
                      Text('• AI Notes: ${aiAnalysis['reason'] ?? 'None'}', style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              _buildStatusIndicator(voter['status']),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close', style: TextStyle(color: Colors.grey))),
          
          if (voter['status'] == 'Pending' || voter['status'] == 'Rejected') ...[
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance.collection('voters').doc(voter['id']).update({'status': 'Rejected'});

                  await FirebaseFirestore.instance.collection('audit_logs').add({
                    'timestamp': FieldValue.serverTimestamp(),
                    'logCategory': 'ACTIVITY LOG',
                    'action': 'COR Image Rejected',
                    'user': 'Admin_Primary',
                    'type': 'Verification',
                    'details': {
                      'Target': 'voters/${voter['id']}',
                      'Payload': '{"status": "Rejected"}',
                    },
                  });

                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${voter['name']} was Rejected. They must re-upload their COR.'), backgroundColor: Colors.redAccent));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error rejecting student: $e')));
                }
              },
              child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
            ),

            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance.collection('voters').doc(voter['id']).update({'status': 'Verified'});
                  
                  await FirebaseFirestore.instance.collection('audit_logs').add({
                    'timestamp': FieldValue.serverTimestamp(),
                    'logCategory': 'ACTIVITY LOG',
                    'action': 'Voter Manually Verified',
                    'user': 'Admin_Primary',
                    'type': 'Verification',
                    'details': {
                      'Target': 'voters/${voter['id']}',
                      'Payload': '{"status": "Verified"}',
                    },
                  });
                  
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${voter['name']} has been Verified!'), backgroundColor: Colors.green));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error verifying student: $e')));
                }
              },
              child: const Text('Verify', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ]
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(String status) {
    Color statusColor;
    if (status == 'Verified') statusColor = Colors.green;
    else if (status == 'Rejected') statusColor = Colors.redAccent;
    else statusColor = Colors.orange;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'CURRENT STATUS: ${status.toUpperCase()}',
        textAlign: TextAlign.center,
        style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Voter Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: nemsuBlue)),
          const SizedBox(height: 4),
          const Text('Review COR and verify student eligibility', style: TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 20),

          TextField(
            onChanged: (value) => setState(() => searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search student name or ID...',
              hintStyle: const TextStyle(fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: nemsuBlue),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 0), 
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
            ),
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  value: selectedStatus,
                  // 👉 UPDATED: Added Rejected to filters
                  items: ['All Status', 'Verified', 'Pending', 'Rejected'],
                  onChanged: (val) => setState(() => selectedStatus = val!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown(
                  value: selectedDept,
                  items: departments,
                  onChanged: (val) => setState(() => selectedDept = val!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('voters').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: nemsuBlue));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState('No registered students found.');
                }

                List<Map<String, dynamic>> rawVoters = snapshot.data!.docs.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  String dbStatus = data['status']?.toString() ?? 'Pending';
                  
                  // Normalize statuses
                  if (dbStatus == 'Pending Verification') dbStatus = 'Pending';

                  return {
                    'id': doc.id,
                    'name': data['name'] ?? 'Unknown',
                    'firstName': data['firstName'] ?? '',
                    'middleName': data['middleName'] ?? '',
                    'lastName': data['lastName'] ?? '',
                    'suffix': data['suffix'] ?? '',
                    'email': data['email'] ?? 'N/A',
                    'yearLevel': data['yearLevel'] ?? 'N/A',
                    'dept': data['department'] ?? 'Unknown',
                    'course': data['course'] ?? 'N/A',
                    'status': dbStatus, 
                    'enrollmentStatus': dbStatus == 'Verified' ? 'Enrolled' : 'Under Review',
                    'corBase64': data['corBase64'] ?? '', 
                    'aiAnalysis': data['aiAnalysis'],
                  };
                }).toList();

                List<Map<String, dynamic>> filteredVoters = rawVoters.where((voter) {
                  final matchesSearch = voter['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()) || 
                                        voter['id'].toString().contains(searchQuery);
                  final matchesStatus = selectedStatus == 'All Status' || voter['status'] == selectedStatus;
                  final matchesDept = selectedDept == 'All Departments' || voter['dept'] == selectedDept;
                  
                  return matchesSearch && matchesStatus && matchesDept;
                }).toList();

                if (filteredVoters.isEmpty) {
                  return _buildEmptyState('No students match your criteria.');
                }

                Map<String, List<Map<String, dynamic>>> groupedVoters = {};
                for (var voter in filteredVoters) {
                  groupedVoters.putIfAbsent(voter['dept'], () => []).add(voter);
                }
                List<String> sortedDepts = groupedVoters.keys.toList()..sort();

                return ListView.builder(
                  itemCount: sortedDepts.length,
                  itemBuilder: (context, index) {
                    String deptName = sortedDepts[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDeptHeader(deptName),
                        // 👉 WEB FIX: Used for loop instead of map
                        for (var voter in groupedVoters[deptName]!) 
                          _buildVoterCard(voter),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(message, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({required String value, required List<String> items, required ValueChanged<String?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: nemsuBlue),
          items: items.map((item) => DropdownMenuItem(
            value: item, 
            child: Text(
              item, 
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildDeptHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Row(
        children: [
          const Icon(Icons.business_center, size: 18, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title, 
              style: const TextStyle(fontWeight: FontWeight.bold, color: nemsuBlue, fontSize: 14),
              softWrap: true,
            ),
          ),
          const SizedBox(width: 10),
          const SizedBox(width: 40, child: Divider(thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildVoterCard(Map<String, dynamic> voter) {
    String status = voter['status'];
    Color avatarColor;
    Color iconColor;
    String statusText;

    if (status == 'Verified') {
      avatarColor = Colors.green.withOpacity(0.1);
      iconColor = Colors.green;
      statusText = 'Verified';
    } else if (status == 'Rejected') {
      avatarColor = Colors.red.withOpacity(0.1);
      iconColor = Colors.redAccent;
      statusText = 'Rejected';
    } else {
      avatarColor = Colors.orange.shade50;
      iconColor = Colors.orange;
      statusText = 'Pending';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1, 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: () => _showVoterDetails(voter),
        leading: CircleAvatar(
          backgroundColor: avatarColor,
          child: Icon(Icons.person, color: iconColor),
        ),
        title: Text(voter['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: nemsuBlue)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Text('${voter['id']} • ${voter['course']}', style: const TextStyle(fontSize: 12)),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.circle, size: 14, color: iconColor),
            const SizedBox(height: 4),
            Text(statusText, textAlign: TextAlign.center, style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}