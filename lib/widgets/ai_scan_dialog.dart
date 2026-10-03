import 'package:flutter/material.dart';
import '../constants.dart';
import '../services/ai_ocr_service.dart';

class AiScanningDialog extends StatelessWidget {
  final String statusText;
  const AiScanningDialog({
    super.key,
    this.statusText = 'Verifying Certificate of Registration (COR)... Please wait.',
  });

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
                color: nemsuBlue.withValues(alpha: 0.08),
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
              'Document Verification',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: nemsuBlue),
            ),
            const SizedBox(height: 8),
            Text(
              statusText,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class AiScanResultDialog extends StatelessWidget {
  final OCRScanResult result;
  final VoidCallback onContinue;

  const AiScanResultDialog({
    super.key,
    required this.result,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    Color themeColor;
    IconData headerIcon;
    String headerTitle;
    String description;

    if (result.verdict == 'Verified') {
      themeColor = Colors.green;
      headerIcon = Icons.verified_rounded;
      headerTitle = 'COR Verification Successful';
      description = 'Your Certificate of Registration has been verified. You may now proceed to log in to your account and participate in the election.';
    } else if (result.verdict == 'Rejected') {
      themeColor = Colors.redAccent;
      headerIcon = Icons.cancel_rounded;
      headerTitle = 'Document Verification Failed';
      description = result.reason.isNotEmpty
          ? result.reason
          : 'Your uploaded Certificate of Registration could not be verified. Please ensure you upload an authentic and current NEMSU COR matching your registration details.';
    } else {
      themeColor = Colors.orange;
      headerIcon = Icons.pending_actions_rounded;
      headerTitle = 'Under Admin Verification';
      description = 'Your uploaded document has been submitted and queued for manual inspection by the COMSELEC electoral board.';
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 28.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: themeColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(headerIcon, color: themeColor, size: 48),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                headerTitle,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: themeColor),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: nemsuBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.45),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Status: ${result.verdict}',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: themeColor),
                      ),
                    ),
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
    );
  }
}
