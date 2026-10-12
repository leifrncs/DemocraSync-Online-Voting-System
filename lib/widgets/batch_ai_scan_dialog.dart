import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';
import '../services/ai_ocr_service.dart';

class BatchAiScanningDialog extends StatefulWidget {
  final String targetAcademicYear;
  final String targetSemester;

  const BatchAiScanningDialog({
    super.key,
    required this.targetAcademicYear,
    required this.targetSemester,
  });

  @override
  State<BatchAiScanningDialog> createState() => _BatchAiScanningDialogState();
}

class _BatchAiScanningDialogState extends State<BatchAiScanningDialog> {
  bool _isScanning = true;
  bool _isCancelled = false;

  int _totalVoters = 0;
  int _currentIndex = 0;
  String _currentVoterName = 'Initializing scan...';
  String _currentStudentId = '';

  int _verifiedCount = 0;
  int _outdatedCount = 0;
  int _missingCorCount = 0;
  int _errorCount = 0;

  final List<Map<String, dynamic>> _renewalRequiredList = [];

  @override
  void initState() {
    super.initState();
    _startBatchScan();
  }

  Future<void> _startBatchScan() async {
    try {
      final votersSnapshot = await FirebaseFirestore.instance.collection('voters').get();
      if (!mounted) return;

      final docs = votersSnapshot.docs;
      setState(() {
        _totalVoters = docs.length;
      });

      if (_totalVoters == 0) {
        setState(() {
          _isScanning = false;
          _currentVoterName = 'No registered voters found.';
        });
        return;
      }

      for (int i = 0; i < docs.length; i++) {
        if (_isCancelled || !mounted) break;

        final doc = docs[i];
        final data = doc.data();
        final studentId = doc.id;
        final studentName = data['name'] ??
            '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim();
        final corBase64 = data['corBase64']?.toString();

        setState(() {
          _currentIndex = i + 1;
          _currentStudentId = studentId;
          _currentVoterName = studentName.isNotEmpty ? studentName : studentId;
        });

        if (corBase64 == null || corBase64.trim().isEmpty) {
          // No COR uploaded
          await doc.reference.update({
            'status': 'Pending Verification',
            'aiAnalysis': {
              'verdict': 'Pending Verification',
              'reason':
                  'No Certificate of Registration uploaded for active Academic Year ${widget.targetAcademicYear} (${widget.targetSemester}).',
              'isOutdated': true,
              'scannedAt': FieldValue.serverTimestamp(),
            },
          });

          await _logAudit(
            studentId: studentId,
            studentName: studentName,
            verdict: 'Pending Verification',
            reason: 'Missing COR document',
            isOutdated: true,
          );

          if (mounted) {
            setState(() {
              _missingCorCount++;
              _renewalRequiredList.add({
                'id': studentId,
                'name': studentName,
                'reason': 'No COR document uploaded',
              });
            });
          }
          continue;
        }

        // Has COR image - analyze with retry logic
        bool success = false;
        int attempts = 0;
        OCRScanResult? scanResult;

        while (!success && attempts < 2 && !_isCancelled) {
          attempts++;
          try {
            final cleanBase64 = corBase64.replaceAll(RegExp(r'\s+'), '');
            final Uint8List imageBytes = base64Decode(cleanBase64);

            scanResult = await AiOcrService().analyzeCOR(
              imageBytes: imageBytes,
              studentId: studentId,
              fullName: studentName,
              firstName: data['firstName'],
              middleName: data['middleName'],
              lastName: data['lastName'],
              suffix: data['suffix'],
              department: data['department'] ?? '',
              course: data['course'] ?? '',
              yearLevel: data['yearLevel'] ?? '',
              expectedAcademicYear: widget.targetAcademicYear,
              expectedSemester: widget.targetSemester,
            );
            success = true;
          } catch (e) {
            if (attempts < 2) {
              await Future.delayed(const Duration(milliseconds: 2500));
            }
          }
        }

        if (scanResult != null) {
          // If term doesn't match or is outdated, mark as pending verification / rejected
          final assignedStatus = scanResult.verdict;

          await doc.reference.update({
            'status': assignedStatus,
            'aiAnalysis': scanResult.toMap(),
          });

          await _logAudit(
            studentId: studentId,
            studentName: studentName,
            verdict: assignedStatus,
            reason: scanResult.reason,
            isOutdated: scanResult.isOutdated,
          );

          if (mounted) {
            setState(() {
              if (assignedStatus == 'Verified') {
                _verifiedCount++;
              } else {
                _outdatedCount++;
                _renewalRequiredList.add({
                  'id': studentId,
                  'name': studentName,
                  'reason': scanResult!.reason,
                });
              }
            });
          }
        } else {
          // Verification failed / Error
          if (mounted) {
            setState(() {
              _errorCount++;
            });
          }
        }

        // Respect API rate limits between voter scans
        if (i < docs.length - 1 && !_isCancelled) {
          await Future.delayed(const Duration(milliseconds: 1200));
        }
      }

      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _currentVoterName = 'Error during batch scan: $e';
        });
      }
    }
  }

  Future<void> _logAudit({
    required String studentId,
    required String studentName,
    required String verdict,
    required String reason,
    required bool isOutdated,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'logCategory': 'AI_OCR_AUDIT',
        'action': 'Batch AI Verification - Academic Year Update',
        'user': 'COMSELEC_BATCH_AI',
        'type': 'Batch Scan',
        'details': {
          'studentId': studentId,
          'name': studentName,
          'targetAcademicYear': widget.targetAcademicYear,
          'targetSemester': widget.targetSemester,
          'verdict': verdict,
          'reason': reason,
          'isOutdated': isOutdated,
        },
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalVoters > 0 ? (_currentIndex / _totalVoters) : 0.0;
    final percent = (progress * 100).toInt();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: nemsuBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: nemsuBlue, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AI Batch Voter Verification',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: nemsuBlue,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Target: ${widget.targetAcademicYear} • ${widget.targetSemester}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: nemsuGold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_isScanning)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.shade400),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.amber.shade800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Scanning',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade800,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade400),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 14, color: Colors.green.shade700),
                          const SizedBox(width: 5),
                          Text(
                            'Completed',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Progress Bar & Percentage
              if (_isScanning) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation<Color>(nemsuBlue),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Processing $_currentIndex of $_totalVoters voters',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                    ),
                    Text(
                      '$percent%',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: nemsuBlue),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_search_rounded, color: nemsuBlue, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _currentVoterName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_currentStudentId.isNotEmpty)
                        Text(
                          _currentStudentId,
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Metrics Chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _metricChip(
                    label: 'Verified',
                    count: _verifiedCount,
                    color: const Color(0xFF10B981),
                    icon: Icons.check_circle_outline_rounded,
                  ),
                  _metricChip(
                    label: 'Outdated / Needs Update',
                    count: _outdatedCount,
                    color: const Color(0xFFF59E0B),
                    icon: Icons.warning_amber_rounded,
                  ),
                  _metricChip(
                    label: 'Missing COR',
                    count: _missingCorCount,
                    color: const Color(0xFF64748B),
                    icon: Icons.description_outlined,
                  ),
                  if (_errorCount > 0)
                    _metricChip(
                      label: 'Errors',
                      count: _errorCount,
                      color: Colors.redAccent,
                      icon: Icons.error_outline_rounded,
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Renewal Required List
              if (_renewalRequiredList.isNotEmpty) ...[
                const Text(
                  'Students Requiring COR Renewal:',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      itemCount: _renewalRequiredList.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, indent: 14, endIndent: 14),
                      itemBuilder: (context, index) {
                        final item = _renewalRequiredList[index];
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          leading: const CircleAvatar(
                            radius: 14,
                            backgroundColor: Color(0xFFFEF3C7),
                            child: Icon(Icons.sync_problem_rounded, size: 16, color: Color(0xFFD97706)),
                          ),
                          title: Text(
                            item['name'] ?? item['id'],
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                          subtitle: Text(
                            'ID: ${item['id']} • ${item['reason']}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ] else if (!_isScanning) ...[
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_rounded, size: 54, color: Colors.green.shade400),
                        const SizedBox(height: 12),
                        const Text(
                          'All registered voters verified for this academic period!',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: nemsuBlue),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ] else
                const Spacer(),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_isScanning)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                      onPressed: () {
                        setState(() {
                          _isCancelled = true;
                          _isScanning = false;
                        });
                      },
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Stop Scan'),
                    )
                  else
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: nemsuBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricChip({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            '$count $label',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
