import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/ai_ocr_service.dart';

class AiScanningDialog extends StatelessWidget {
  final String statusText;
  const AiScanningDialog({super.key, required this.statusText});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: nemsuBlue.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: nemsuBlue,
                  strokeWidth: 3.5,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'AI Vision Verification',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: nemsuBlue),
            ),
            const SizedBox(height: 8),
            Text(
              statusText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: nemsuBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded, color: nemsuGold, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'Gemini AI Document Scanner',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: nemsuBlue),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AiScanResultDialog extends StatelessWidget {
  final OCRScanResult result;
  final String inputStudentId;
  final String inputFullName;
  final VoidCallback onContinue;

  const AiScanResultDialog({
    super.key,
    required this.result,
    required this.inputStudentId,
    required this.inputFullName,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    Color themeColor;
    IconData headerIcon;
    String headerTitle;

    if (result.verdict == 'Verified') {
      themeColor = Colors.green;
      headerIcon = Icons.verified_rounded;
      headerTitle = 'COR Automatically Verified!';
    } else if (result.verdict == 'Rejected') {
      themeColor = Colors.redAccent;
      headerIcon = Icons.cancel_rounded;
      headerTitle = 'Document Verification Failed';
    } else {
      themeColor = Colors.orange;
      headerIcon = Icons.pending_actions_rounded;
      headerTitle = 'Under Admin Verification';
    }

    int confidencePercent = (result.confidence * 100).toInt().clamp(0, 100);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(headerIcon, color: themeColor, size: 44),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  headerTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: themeColor),
                ),
                const SizedBox(height: 6),
                Text(
                  result.reason,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                ),
                const SizedBox(height: 20),

                // AI Match Table
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: nemsuBackground,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.auto_awesome, color: nemsuBlue, size: 16),
                              SizedBox(width: 6),
                              Text('AI Extraction Audit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: nemsuBlue)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: themeColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$confidencePercent% Confidence',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: themeColor),
                            ),
                          ),
                        ],
                      ),
                      // Document Layout Authenticity Row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(
                            width: 80,
                            child: Text('Format', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  result.isOfficialCOR
                                      ? 'Official NEMSU COR Format'
                                      : 'Non-Official / Incomplete Format',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: result.isOfficialCOR ? Colors.green.shade800 : Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            result.isOfficialCOR ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
                            color: result.isOfficialCOR ? Colors.green : Colors.redAccent,
                            size: 18,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      _buildComparisonRow(
                        'Student ID',
                        inputStudentId,
                        result.detectedStudentId,
                        result.idMatched,
                      ),
                      const SizedBox(height: 10),
                      _buildComparisonRow(
                        'Full Name',
                        inputFullName,
                        result.detectedFullName,
                        result.nameMatched,
                      ),
                      if (result.academicYear != 'N/A' || result.semester != 'N/A') ...[
                        const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(
                              width: 80,
                              child: Text('Academic Term', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${result.semester} • ${result.academicYear}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                  if (result.isOutdated)
                                    const Text('Outdated Document (Prior Term)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent))
                                  else if (result.termMatched)
                                    Text('Current Term Verified', style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                            Icon(
                              result.termMatched
                                  ? Icons.check_circle
                                  : (result.isOutdated ? Icons.cancel_rounded : Icons.info_outline_rounded),
                              color: result.termMatched
                                  ? Colors.green
                                  : (result.isOutdated ? Colors.redAccent : Colors.orange),
                              size: 18,
                            ),
                          ],
                        ),
                      ],
                      if (result.detectedDepartment != 'N/A') ...[
                        const SizedBox(height: 10),
                        _buildSimpleRow('Detected Dept', result.detectedDepartment),
                      ]
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: nemsuBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    onContinue();
                  },
                  child: Text(
                    result.verdict == 'Verified' ? 'Continue to Sign In' : 'Acknowledge & Continue',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildComparisonRow(String label, String expected, String detected, bool isMatch) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Form: $expected', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text('COR: $detected', style: TextStyle(fontSize: 12, color: isMatch ? Colors.green.shade800 : Colors.redAccent)),
            ],
          ),
        ),
        Icon(
          isMatch ? Icons.check_circle : Icons.warning_amber_rounded,
          color: isMatch ? Colors.green : Colors.orange,
          size: 18,
        ),
      ],
    );
  }

  Widget _buildSimpleRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}
