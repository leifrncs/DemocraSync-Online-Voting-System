import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../constants.dart';
import '../services/ai_ocr_service.dart';

class VoterManagement extends StatefulWidget {
  const VoterManagement({super.key});

  @override
  State<VoterManagement> createState() => _VoterManagementState();
}

class _VoterManagementState extends State<VoterManagement> {
  // --- SEARCH & FILTER STATES ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDept = 'All';
  String _selectedStatus = 'All';
  String _selectedYearLevel = 'All';
  String _sortBy = 'Name (A-Z)';
  bool? _userSelectedTableView; // Auto-adapts to card on mobile (<700px) unless manually toggled

  // --- PAGINATION STATES ---
  int _currentPage = 0;
  int _pageSize = 25;
  final List<int> _pageSizeOptions = [15, 25, 50, 100];

  // --- CANONICAL DEPARTMENTS ---
  static const List<String> _departments = [
    'College of Information Technology Education',
    'College of Business and Management',
    'College of Teacher Education',
    'College of Engineering and Technology',
    'College of Arts and Sciences',
  ];

  static const List<String> _yearLevels = [
    'All',
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    '5th Year',
  ];

  static const List<String> _sortOptions = [
    'Name (A-Z)',
    'Name (Z-A)',
    'Student ID (Asc)',
    'Student ID (Desc)',
    'Status (Pending First)',
    'Status (Verified First)',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getScopeAbbreviation(String scope) {
    return scope
        .replaceAll('College of Information Technology Education', 'CITE (IT Education)')
        .replaceAll('College of Business and Management', 'CBM (Business & Mgmt)')
        .replaceAll('College of Teacher Education', 'CTE (Teacher Ed)')
        .replaceAll('College of Engineering and Technology', 'CET (Engineering & Tech)')
        .replaceAll('College of Arts and Sciences', 'CAS (Arts & Sciences)')
        .replaceAll('College of ', '');
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  // --- 1. POPUP COR IMAGE VIEWER ---
  void _viewCOR(String base64String, String studentName) {
    if (base64String.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No Certificate of Registration (COR) image uploaded.'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            children: [
              // Modal Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: const BoxDecoration(
                  color: nemsuBlue,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.document_scanner_rounded, color: nemsuGold, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Certificate of Registration (COR) • $studentName',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Image Viewer with Interactive Pan/Zoom
              Expanded(
                child: Container(
                  color: const Color(0xFF0F172A),
                  child: InteractiveViewer(
                    panEnabled: true,
                    boundaryMargin: const EdgeInsets.all(30),
                    minScale: 0.5,
                    maxScale: 5.0,
                    child: Center(
                      child: Image.memory(
                        base64Decode(base64String.replaceAll(RegExp(r'\s+'), '')),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(24),
                          child: const Text('Error decoding COR image. The file may be corrupted.', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom hint
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFFF8FAFC),
                child: const Row(
                  children: [
                    Icon(Icons.zoom_in_rounded, size: 16, color: Color(0xFF64748B)),
                    SizedBox(width: 8),
                    Text('Pinch or scroll mouse wheel to zoom. Drag to pan around the document.', style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 2. AI OCR RE-SCAN ---
  Future<void> _reScanWithAI(Map<String, dynamic> voter) async {
    String base64 = voter['corBase64'] ?? '';
    if (base64.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No COR image to scan.')));
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
            SizedBox(width: 12),
            Text('Analyzing Certificate of Registration (COR)...'),
          ],
        ),
        duration: Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );

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
        backgroundColor: result.verdict == 'Verified' ? const Color(0xFF10B981) : Colors.orange,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error during AI Re-Scan: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  // --- 3. VOTER DETAILS & COR AUDIT DIALOG ---
  void _showVoterDetails(Map<String, dynamic> voter) {
    Map<String, dynamic>? aiAnalysis = voter['aiAnalysis'] as Map<String, dynamic>?;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                decoration: const BoxDecoration(
                  color: nemsuBlue,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: nemsuGold,
                      child: Text(
                        _getInitials(voter['name']),
                        style: const TextStyle(color: nemsuBlue, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            voter['name'] ?? 'Unknown Student',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${voter['id']}  •  ${voter['dept']}',
                            style: const TextStyle(color: nemsuGold, fontSize: 12, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status and Program Info
                      Row(
                        children: [
                          _buildStatusBadge(voter['status']),
                          const Spacer(),
                          Text(
                            'Year: ${voter['yearLevel']} • ${voter['enrollmentStatus']}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Student Info Grid
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(child: _infoTile('Email Address', voter['email'])),
                                Expanded(child: _infoTile('Degree Program', voter['course'])),
                              ],
                            ),
                            const Divider(height: 16, color: Color(0xFFE2E8F0)),
                            Row(
                              children: [
                                Expanded(child: _infoTile('College Scope', voter['dept'])),
                                Expanded(child: _infoTile('Student ID', voter['id'], isBold: true)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Certificate of Registration Action Tile
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Certificate of Registration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: nemsuBlue)),
                                Text('Official enrollment proof document', style: TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: nemsuBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                                  ),
                                  onPressed: () => _viewCOR(voter['corBase64'] ?? '', voter['name']),
                                  icon: const Icon(Icons.image_search_rounded, size: 15),
                                  label: const Text('View COR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: nemsuGold,
                                    foregroundColor: nemsuBlue,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                                  ),
                                  onPressed: () => _reScanWithAI(voter),
                                  icon: const Icon(Icons.auto_awesome, size: 15),
                                  label: const Text('AI Re-Scan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // AI OCR Analysis Diagnostics Card
                      if (aiAnalysis != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9FF),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFBAE6FD)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.auto_awesome_rounded, color: Color(0xFF0284C7), size: 16),
                                      SizedBox(width: 6),
                                      Text('AI OCR Diagnostic Report', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0369A1))),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE0F2FE),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Confidence: ${((aiAnalysis['confidence'] as num? ?? 0.8) * 100).toInt()}%',
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _buildAiMarker('Document Authenticity', aiAnalysis['isOfficialCOR'] == true ? 'Official NEMSU COR' : 'Non-Official / Invalid Format', aiAnalysis['isOfficialCOR'] == true),
                              _buildAiMarker('Student ID Match', '${aiAnalysis['detectedStudentId'] ?? 'N/A'} (Match: ${aiAnalysis['idMatched'] == true ? 'YES' : 'NO'})', aiAnalysis['idMatched'] == true),
                              _buildAiMarker('Student Name Match', '${aiAnalysis['detectedFullName'] ?? 'N/A'} (Match: ${aiAnalysis['nameMatched'] == true ? 'YES' : 'NO'})', aiAnalysis['nameMatched'] == true),
                              if (aiAnalysis['academicYear'] != null && aiAnalysis['academicYear'] != 'N/A')
                                _buildAiMarker('Academic Term', '${aiAnalysis['semester'] ?? ''} ${aiAnalysis['academicYear'] ?? ''} (Match: ${aiAnalysis['termMatched'] == true ? 'YES' : 'OUTDATED'})', aiAnalysis['termMatched'] == true),
                              const SizedBox(height: 6),
                              Text('• AI Verdict Reason: ${aiAnalysis['reason'] ?? 'None'}', style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: Color(0xFF475569))),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Action Buttons Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                  borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 13.5)),
                    ),
                    const SizedBox(width: 10),
                    if (voter['status'] == 'Pending' || voter['status'] == 'Verified')
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          await _updateVoterStatus(voter['id'], voter['name'], 'Rejected');
                          if (context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.cancel_rounded, size: 16),
                        label: const Text('Reject COR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    const SizedBox(width: 8),
                    if (voter['status'] == 'Pending' || voter['status'] == 'Rejected')
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          await _updateVoterStatus(voter['id'], voter['name'], 'Verified');
                          if (context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.check_circle_rounded, size: 16),
                        label: const Text('Verify Student', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAiMarker(String label, String value, bool isSuccess) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Icon(isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 14, color: isSuccess ? const Color(0xFF10B981) : Colors.redAccent),
          const SizedBox(width: 6),
          Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, color: isSuccess ? const Color(0xFF0F766E) : Colors.redAccent, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateVoterStatus(String studentId, String studentName, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('voters').doc(studentId).update({'status': newStatus});
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'logCategory': 'VOTER_MANAGEMENT',
        'action': 'Voter Status Updated to $newStatus',
        'user': 'admin',
        'type': 'Verification',
        'details': {'studentId': studentId, 'name': studentName, 'status': newStatus},
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$studentName marked as $newStatus!'),
          backgroundColor: newStatus == 'Verified' ? const Color(0xFF10B981) : Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating voter status: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Widget _infoTile(String label, dynamic value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
          const SizedBox(height: 1),
          Text(
            (value ?? 'N/A').toString(),
            style: TextStyle(fontSize: 13.5, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: const Color(0xFF1E293B)),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color border;
    Color text;
    IconData icon;

    if (status == 'Verified') {
      bg = const Color(0xFFECFDF5);
      border = const Color(0xFFA7F3D0);
      text = const Color(0xFF047857);
      icon = Icons.check_circle_rounded;
    } else if (status == 'Rejected') {
      bg = const Color(0xFFFEF2F2);
      border = const Color(0xFFFECDD3);
      text = const Color(0xFFB91C1C);
      icon = Icons.cancel_rounded;
    } else {
      bg = const Color(0xFFFFFBEB);
      border = const Color(0xFFFDE68A);
      text = const Color(0xFFB45309);
      icon = Icons.hourglass_top_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: text),
          const SizedBox(width: 5),
          Text(
            status.toUpperCase(),
            style: TextStyle(color: text, fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // --- 4. TOP KPI METRICS BAR WITH HOVER TOOLTIPS ---
  Widget _buildKpiSummaryBar(List<Map<String, dynamic>> voters, bool isMobile) {
    int total = voters.length;
    int verified = voters.where((v) => v['status'] == 'Verified').length;
    int pending = voters.where((v) => v['status'] == 'Pending' || v['status'] == 'Pending Verification').length;
    int rejected = voters.where((v) => v['status'] == 'Rejected').length;

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildKpiItem(
                  Icons.how_to_reg_rounded,
                  'Total Registered',
                  '$total',
                  nemsuBlue,
                  'Total registered student voters in the DemocraSync database.',
                ),
                const SizedBox(width: 8),
                _buildKpiDivider(),
                const SizedBox(width: 8),
                _buildKpiItem(
                  Icons.verified_rounded,
                  'Verified Voters',
                  '$verified',
                  const Color(0xFF10B981),
                  'Students whose enrollment has been verified and are cleared to vote.',
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(height: 1, color: Color(0xFFE2E8F0)),
            ),
            Row(
              children: [
                _buildKpiItem(
                  Icons.pending_actions_rounded,
                  'Pending Review',
                  '$pending',
                  const Color(0xFFD97706),
                  'Students with uploaded documents awaiting administrative or AI verification.',
                ),
                const SizedBox(width: 8),
                _buildKpiDivider(),
                const SizedBox(width: 8),
                _buildKpiItem(
                  Icons.cancel_outlined,
                  'Rejected CORs',
                  '$rejected',
                  const Color(0xFFE11D48),
                  'Students whose registration or COR proof was rejected.',
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          _buildKpiItem(
            Icons.how_to_reg_rounded,
            'Total Registered',
            '$total',
            nemsuBlue,
            'Total registered student voters in the DemocraSync database.',
          ),
          const SizedBox(width: 14),
          _buildKpiDivider(),
          const SizedBox(width: 14),
          _buildKpiItem(
            Icons.verified_rounded,
            'Verified Voters',
            '$verified',
            const Color(0xFF10B981),
            'Students whose enrollment has been verified and are cleared to vote.',
          ),
          const SizedBox(width: 14),
          _buildKpiDivider(),
          const SizedBox(width: 14),
          _buildKpiItem(
            Icons.pending_actions_rounded,
            'Pending Review',
            '$pending',
            const Color(0xFFD97706),
            'Students with uploaded documents awaiting administrative or AI verification.',
          ),
          const SizedBox(width: 14),
          _buildKpiDivider(),
          const SizedBox(width: 14),
          _buildKpiItem(
            Icons.cancel_outlined,
            'Rejected CORs',
            '$rejected',
            const Color(0xFFE11D48),
            'Students whose registration or COR proof was rejected.',
          ),
        ],
      ),
    );
  }

  Widget _buildKpiItem(IconData icon, String label, String value, Color color, String description) {
    return Expanded(
      child: Tooltip(
        message: description,
        waitDuration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: nemsuSlate,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiDivider() {
    return Container(height: 28, width: 1, color: const Color(0xFFE2E8F0));
  }

  // --- 5. PAGINATED DATA TABLE VIEW (FULL WIDTH & SCALED TYPOGRAPHY) ---
  Widget _buildVotersTable(List<Map<String, dynamic>> pageVoters) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, tableConstraints) {
            double availableWidth = tableConstraints.maxWidth;
            double tableWidth = availableWidth > 980 ? availableWidth : 980;
            double columnSpacing = availableWidth > 1350 ? 36.0 : (availableWidth > 1100 ? 28.0 : 20.0);

            return Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                physics: const AlwaysScrollableScrollPhysics(),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: tableWidth),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      horizontalMargin: 24,
                      columnSpacing: columnSpacing,
                      headingRowHeight: 52,
                      dataRowMinHeight: 60,
                      dataRowMaxHeight: 66,
                      columns: const [
                        DataColumn(label: Text('Student', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: nemsuBlue))),
                        DataColumn(label: Text('Student ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: nemsuBlue))),
                        DataColumn(label: Text('College & Program', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: nemsuBlue))),
                        DataColumn(label: Text('Year Level', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: nemsuBlue))),
                        DataColumn(label: Text('AI OCR Match', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: nemsuBlue))),
                        DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: nemsuBlue))),
                        DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: nemsuBlue))),
                      ],
                      rows: pageVoters.map((voter) {
                        Map<String, dynamic>? aiAnalysis = voter['aiAnalysis'] as Map<String, dynamic>?;

                        return DataRow(
                          cells: [
                            // Student Name & Avatar
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 19,
                                    backgroundColor: nemsuGold,
                                    child: Text(
                                      _getInitials(voter['name']),
                                      style: const TextStyle(color: nemsuBlue, fontWeight: FontWeight.bold, fontSize: 12.5),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        voter['name'],
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: nemsuBlue),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        voter['email'],
                                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Student ID
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  voter['id'],
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                ),
                              ),
                            ),

                            // College & Program
                            DataCell(
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _getScopeAbbreviation(voter['dept']),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Color(0xFF1E293B)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    voter['course'],
                                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),

                            // Year Level
                            DataCell(
                              Text(
                                voter['yearLevel'] ?? 'N/A',
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                              ),
                            ),

                            // AI OCR Match
                            DataCell(
                              aiAnalysis != null
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          aiAnalysis['isOfficialCOR'] == true ? Icons.verified_rounded : Icons.warning_amber_rounded,
                                          size: 16,
                                          color: aiAnalysis['isOfficialCOR'] == true ? const Color(0xFF10B981) : Colors.orange,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          aiAnalysis['isOfficialCOR'] == true
                                              ? 'Official (${((aiAnalysis['confidence'] as num? ?? 0.8) * 100).toInt()}%)'
                                              : 'Non-Official',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: aiAnalysis['isOfficialCOR'] == true ? const Color(0xFF065F46) : const Color(0xFF9A3412),
                                          ),
                                        ),
                                      ],
                                    )
                                  : const Text('Pending Scan', style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic)),
                            ),

                            // Status
                            DataCell(_buildStatusBadge(voter['status'])),

                            // Action
                            DataCell(
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: nemsuBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: () => _showVoterDetails(voter),
                                icon: const Icon(Icons.rate_review_outlined, size: 14.5),
                                label: const Text('Review', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- 6. PAGINATED CARD GRID VIEW (MATCHED TYPOGRAPHY) ---
  Widget _buildVotersCardGrid(List<Map<String, dynamic>> pageVoters, bool isWide) {
    return isWide
        ? GridView.builder(
            padding: const EdgeInsets.symmetric(vertical: 2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 140,
              crossAxisSpacing: 12,
              mainAxisSpacing: 10,
            ),
            itemCount: pageVoters.length,
            itemBuilder: (context, index) => _buildVoterCard(pageVoters[index]),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 2),
            itemCount: pageVoters.length,
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: _buildVoterCard(pageVoters[index]),
            ),
          );
  }

  Widget _buildVoterCard(Map<String, dynamic> voter) {
    Map<String, dynamic>? aiAnalysis = voter['aiAnalysis'] as Map<String, dynamic>?;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1.5)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showVoterDetails(voter),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 11.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Avatar + Name + Student ID Badge + Status Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 19,
                    backgroundColor: nemsuGold,
                    child: Text(
                      _getInitials(voter['name']),
                      style: const TextStyle(color: nemsuBlue, fontWeight: FontWeight.bold, fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          voter['name'],
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: nemsuBlue),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                voter['id'],
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              voter['yearLevel'] ?? '',
                              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(voter['status']),
                ],
              ),
              const SizedBox(height: 7),

              // Department & Program Info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.domain_rounded, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${_getScopeAbbreviation(voter['dept'])} • ${voter['course']}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 7),

              // Footer: AI Match Indicator & Review Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (aiAnalysis != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.auto_awesome, size: 13, color: Color(0xFF0284C7)),
                          const SizedBox(width: 4),
                          Text(
                            'AI: ${((aiAnalysis['confidence'] as num? ?? 0.8) * 100).toInt()}% match',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: Color(0xFF0369A1)),
                          ),
                        ],
                      ),
                    )
                  else
                    const Text('No scan data', style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic)),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: nemsuBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5.5),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => _showVoterDetails(voter),
                    icon: const Icon(Icons.rate_review_outlined, size: 13),
                    label: const Text('Review', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 7. PAGINATION CONTROLS BAR (RESPONSIVE) ---
  Widget _buildPaginationBar(int totalCount, int totalPages, bool isMobile) {
    int startItem = totalCount == 0 ? 0 : (_currentPage * _pageSize) + 1;
    int endItem = ((_currentPage + 1) * _pageSize) > totalCount ? totalCount : ((_currentPage + 1) * _pageSize);

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Rows: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                    Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _pageSize,
                          items: _pageSizeOptions.map((size) {
                            return DropdownMenuItem(value: size, child: Text('$size', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _pageSize = val;
                                _currentPage = 0;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Showing $startItem-$endItem of $totalCount',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.first_page_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'First Page',
                  color: _currentPage > 0 ? nemsuBlue : Colors.grey.shade400,
                  onPressed: _currentPage > 0 ? () => setState(() => _currentPage = 0) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Previous Page',
                  color: _currentPage > 0 ? nemsuBlue : Colors.grey.shade400,
                  onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Text(
                    'Page ${_currentPage + 1} of ${totalPages == 0 ? 1 : totalPages}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: nemsuBlue),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Next Page',
                  color: _currentPage < totalPages - 1 ? nemsuBlue : Colors.grey.shade400,
                  onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.last_page_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Last Page',
                  color: _currentPage < totalPages - 1 ? nemsuBlue : Colors.grey.shade400,
                  onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage = totalPages - 1) : null,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Rows per page & Range
          Row(
            children: [
              const Text('Rows per page: ', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _pageSize,
                    items: _pageSizeOptions.map((size) {
                      return DropdownMenuItem(value: size, child: Text('$size', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _pageSize = val;
                          _currentPage = 0;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(
                'Showing $startItem-$endItem of $totalCount voters',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), fontWeight: FontWeight.w600),
              ),
            ],
          ),

          // Right: Page navigation buttons
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.first_page_rounded, size: 20),
                tooltip: 'First Page',
                color: _currentPage > 0 ? nemsuBlue : Colors.grey.shade400,
                onPressed: _currentPage > 0 ? () => setState(() => _currentPage = 0) : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                tooltip: 'Previous Page',
                color: _currentPage > 0 ? nemsuBlue : Colors.grey.shade400,
                onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Page ${_currentPage + 1} of ${totalPages == 0 ? 1 : totalPages}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: nemsuBlue),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                tooltip: 'Next Page',
                color: _currentPage < totalPages - 1 ? nemsuBlue : Colors.grey.shade400,
                onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page_rounded, size: 20),
                tooltip: 'Last Page',
                color: _currentPage < totalPages - 1 ? nemsuBlue : Colors.grey.shade400,
                onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage = totalPages - 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('voters').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: nemsuBlue));
        }

        List<Map<String, dynamic>> rawVoters = [];
        if (snapshot.hasData) {
          rawVoters = snapshot.data!.docs.map((doc) {
            var data = doc.data() as Map<String, dynamic>;
            String dbStatus = data['status']?.toString() ?? 'Pending';
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
              'timestamp': data['timestamp'],
            };
          }).toList();
        }

        // Filter by Department Scope
        List<Map<String, dynamic>> filtered = rawVoters;
        if (_selectedDept != 'All') {
          filtered = filtered.where((v) => v['dept'] == _selectedDept).toList();
        }

        // Filter by Status
        if (_selectedStatus != 'All') {
          filtered = filtered.where((v) => v['status'] == _selectedStatus).toList();
        }

        // Filter by Year Level
        if (_selectedYearLevel != 'All') {
          filtered = filtered.where((v) => v['yearLevel'] == _selectedYearLevel).toList();
        }

        // Filter by Search Query
        if (_searchQuery.trim().isNotEmpty) {
          String query = _searchQuery.trim().toLowerCase();
          filtered = filtered.where((v) {
            String name = (v['name'] ?? '').toString().toLowerCase();
            String id = (v['id'] ?? '').toString().toLowerCase();
            String email = (v['email'] ?? '').toString().toLowerCase();
            String course = (v['course'] ?? '').toString().toLowerCase();
            String dept = (v['dept'] ?? '').toString().toLowerCase();
            return name.contains(query) || id.contains(query) || email.contains(query) || course.contains(query) || dept.contains(query);
          }).toList();
        }

        // Sorting
        filtered.sort((a, b) {
          if (_sortBy == 'Name (A-Z)') return a['name'].toString().compareTo(b['name'].toString());
          if (_sortBy == 'Name (Z-A)') return b['name'].toString().compareTo(a['name'].toString());
          if (_sortBy == 'Student ID (Asc)') return a['id'].toString().compareTo(b['id'].toString());
          if (_sortBy == 'Student ID (Desc)') return b['id'].toString().compareTo(a['id'].toString());
          if (_sortBy == 'Status (Pending First)') {
            int aP = a['status'] == 'Pending' ? 0 : (a['status'] == 'Rejected' ? 1 : 2);
            int bP = b['status'] == 'Pending' ? 0 : (b['status'] == 'Rejected' ? 1 : 2);
            return aP.compareTo(bP);
          }
          if (_sortBy == 'Status (Verified First)') {
            int aP = a['status'] == 'Verified' ? 0 : 1;
            int bP = b['status'] == 'Verified' ? 0 : 1;
            return aP.compareTo(bP);
          }
          return 0;
        });

        // Pagination Calculations
        int totalCount = filtered.length;
        int totalPages = (totalCount / _pageSize).ceil();
        if (_currentPage >= totalPages && totalPages > 0) {
          _currentPage = totalPages - 1;
        }

        int startIdx = _currentPage * _pageSize;
        int endIdx = (startIdx + _pageSize) > totalCount ? totalCount : (startIdx + _pageSize);
        List<Map<String, dynamic>> pageVoters = (startIdx < totalCount) ? filtered.sublist(startIdx, endIdx) : [];

        return LayoutBuilder(
          builder: (context, constraints) {
            bool isMobile = constraints.maxWidth < 700;
            bool isWide = constraints.maxWidth > 850;
            bool isTableView = _userSelectedTableView ?? !isMobile;

            return Column(
              children: [
                // --- TOP INTEGRATED HEADER & KPI STATS BAR ---
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Voter Management',
                                  style: TextStyle(
                                    fontSize: isMobile ? 20 : 23,
                                    fontWeight: FontWeight.w800,
                                    color: nemsuBlue,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Review student registrations, verify COR document authenticity, and manage voting eligibility',
                                  style: TextStyle(fontSize: isMobile ? 12 : 13, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),
                          // View Toggle Button Group
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                Tooltip(
                                  message: 'Data Table View',
                                  child: InkWell(
                                    onTap: () => setState(() => _userSelectedTableView = true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isTableView ? nemsuBlue : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(Icons.table_chart_rounded, size: 18, color: isTableView ? Colors.white : const Color(0xFF64748B)),
                                    ),
                                  ),
                                ),
                                Tooltip(
                                  message: 'Card Grid View',
                                  child: InkWell(
                                    onTap: () => setState(() => _userSelectedTableView = false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: !isTableView ? nemsuBlue : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(Icons.grid_view_rounded, size: 18, color: !isTableView ? Colors.white : const Color(0xFF64748B)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildKpiSummaryBar(rawVoters, isMobile),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // --- MULTI-CRITERIA TOOLBAR ---
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search Bar, Year Level, and Sort Dropdowns
                      isMobile
                          ? SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 220,
                                    height: 38,
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: (val) {
                                        setState(() {
                                          _searchQuery = val;
                                          _currentPage = 0;
                                        });
                                      },
                                      style: const TextStyle(fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: 'Search student or course...',
                                        hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                        prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
                                        suffixIcon: _searchQuery.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear, size: 15),
                                                onPressed: () {
                                                  _searchController.clear();
                                                  setState(() {
                                                    _searchQuery = '';
                                                    _currentPage = 0;
                                                  });
                                                },
                                              )
                                            : null,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 6),
                                        filled: true,
                                        fillColor: const Color(0xFFF1F5F9),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide.none),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Year Level Filter Dropdown
                                  Container(
                                    height: 38,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedYearLevel,
                                        icon: const Icon(Icons.school_rounded, size: 15, color: nemsuBlue),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: nemsuBlue),
                                        items: _yearLevels.map((year) {
                                          return DropdownMenuItem(value: year, child: Text(year == 'All' ? 'All Years' : year));
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _selectedYearLevel = val;
                                              _currentPage = 0;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Sort Dropdown
                                  Container(
                                    height: 38,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _sortBy,
                                        icon: const Icon(Icons.sort_rounded, size: 15, color: nemsuBlue),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: nemsuBlue),
                                        items: _sortOptions.map((opt) {
                                          return DropdownMenuItem(value: opt, child: Text(opt));
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() => _sortBy = val);
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: SizedBox(
                                    height: 40,
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: (val) {
                                        setState(() {
                                          _searchQuery = val;
                                          _currentPage = 0;
                                        });
                                      },
                                      style: const TextStyle(fontSize: 13.5),
                                      decoration: InputDecoration(
                                        hintText: 'Search by student name, ID, email, or course...',
                                        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                                        suffixIcon: _searchQuery.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear, size: 16),
                                                onPressed: () {
                                                  _searchController.clear();
                                                  setState(() {
                                                    _searchQuery = '';
                                                    _currentPage = 0;
                                                  });
                                                },
                                              )
                                            : null,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                        filled: true,
                                        fillColor: const Color(0xFFF1F5F9),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide.none),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Year Level Filter Dropdown
                                Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _selectedYearLevel,
                                      icon: const Icon(Icons.school_rounded, size: 16, color: nemsuBlue),
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: nemsuBlue),
                                      items: _yearLevels.map((year) {
                                        return DropdownMenuItem(value: year, child: Text(year == 'All' ? 'All Years' : year));
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _selectedYearLevel = val;
                                            _currentPage = 0;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Sort Dropdown
                                Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(7),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _sortBy,
                                      icon: const Icon(Icons.sort_rounded, size: 16, color: nemsuBlue),
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: nemsuBlue),
                                      items: _sortOptions.map((opt) {
                                        return DropdownMenuItem(value: opt, child: Text(opt));
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() => _sortBy = val);
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                      const SizedBox(height: 8),

                      // Scope Chips & Status Chips Bar
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            // Status Chips
                            _buildStatusFilterChip('All', rawVoters.length),
                            const SizedBox(width: 5),
                            _buildStatusFilterChip('Verified', rawVoters.where((v) => v['status'] == 'Verified').length),
                            const SizedBox(width: 5),
                            _buildStatusFilterChip('Pending', rawVoters.where((v) => v['status'] == 'Pending' || v['status'] == 'Pending Verification').length),
                            const SizedBox(width: 5),
                            _buildStatusFilterChip('Rejected', rawVoters.where((v) => v['status'] == 'Rejected').length),
                            const SizedBox(width: 12),
                            Container(width: 1, height: 20, color: const Color(0xFFCBD5E1)),
                            const SizedBox(width: 12),

                            // College Scope Chips
                            _buildScopeFilterChip('All', rawVoters.length),
                            const SizedBox(width: 5),
                            ..._departments.map((dept) {
                              int count = rawVoters.where((v) => v['dept'] == dept).length;
                              return Padding(
                                padding: const EdgeInsets.only(right: 5.0),
                                child: _buildScopeFilterChip(dept, count, displayName: _getScopeAbbreviation(dept)),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // --- MAIN VOTERS CONTENT ---
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_search_rounded, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 10),
                              Text(
                                _searchQuery.isNotEmpty || _selectedDept != 'All' || _selectedStatus != 'All' || _selectedYearLevel != 'All'
                                    ? 'No student voters found matching the selected filters.'
                                    : 'No registered student voters in the database yet.',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 14),
                              if (_searchQuery.isNotEmpty || _selectedDept != 'All' || _selectedStatus != 'All' || _selectedYearLevel != 'All')
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: nemsuBlue,
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                      _selectedDept = 'All';
                                      _selectedStatus = 'All';
                                      _selectedYearLevel = 'All';
                                      _currentPage = 0;
                                    });
                                  },
                                  icon: const Icon(Icons.clear_all_rounded, size: 18),
                                  label: const Text('Clear All Filters', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        )
                      : Padding(
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12.0 : 20.0, vertical: 12.0),
                          child: isTableView ? _buildVotersTable(pageVoters) : _buildVotersCardGrid(pageVoters, isWide),
                        ),
                ),

                // --- PAGINATION BAR ---
                _buildPaginationBar(totalCount, totalPages, isMobile),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildScopeFilterChip(String scope, int count, {String? displayName}) {
    bool isSelected = _selectedDept == scope;
    String label = displayName ?? scope;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedDept = scope;
          _currentPage = 0;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected ? nemsuBlue : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? nemsuBlue : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? nemsuGold : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? nemsuBlue : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusFilterChip(String status, int count) {
    bool isSelected = _selectedStatus == status;

    Color activeColor = nemsuBlue;
    if (status == 'Verified') activeColor = const Color(0xFF10B981);
    if (status == 'Pending') activeColor = const Color(0xFFD97706);
    if (status == 'Rejected') activeColor = Colors.redAccent;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedStatus = status;
          _currentPage = 0;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? activeColor : const Color(0xFFE2E8F0)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              status == 'All' ? 'All Status' : status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? Colors.white : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}