import 'package:flutter/material.dart';
import '../constants.dart';

class GuidelinesScreen extends StatefulWidget {
  // We pass a function from the main screen so this screen knows how to "proceed"
  final VoidCallback onProceed; 

  const GuidelinesScreen({super.key, required this.onProceed});

  @override
  State<GuidelinesScreen> createState() => _GuidelinesScreenState();
}

class _GuidelinesScreenState extends State<GuidelinesScreen> {
  bool _hasAgreed = false; // Tracks the checkbox

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      
      // ❌ APPBAR REMOVED. Handled by StudentMainScreen.

      // 1. THE BODY FIX
      body: SingleChildScrollView(
        // The scroll view stays on the outside so the scrollbar hugs the edge of the screen
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800), // 800px is great for readable text
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Official Voting Guidelines', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: nemsuBlue)),
                  const SizedBox(height: 8),
                  const Text('Please read carefully before proceeding to the ballot:', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 24),

                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: Column(
                        children: [
                          _buildGuidelineItem(Icons.fingerprint, '1. One Student, One Vote', 'Ensure you are logged in with your official NEMSU student credentials. Your account is tied to a single, secure ballot.'),
                          const Divider(height: 1, indent: 60),
                          _buildGuidelineItem(Icons.touch_app_rounded, '2. Select Carefully', 'Choose your preferred candidate for each position. You may only select the maximum number of candidates allowed per office.'),
                          const Divider(height: 1, indent: 60),
                          _buildGuidelineItem(Icons.speaker_notes_off_outlined, '3. Abstaining is Allowed', 'If you do not wish to vote for a specific position, you may leave it blank. Your vote for other positions will still be counted.'),
                          const Divider(height: 1, indent: 60),
                          _buildGuidelineItem(Icons.person_search, '4. Review Candidate Profiles', 'Unsure who to vote for? You can tap on a candidate\'s name or photo to read their platform and credentials.'),
                          const Divider(height: 1, indent: 60),
                          _buildGuidelineItem(Icons.fact_check_outlined, '5. The Final Review', 'Before your vote is cast, you will be shown a summary of your selections. Please double-check this list to ensure accuracy.'),
                          const Divider(height: 1, indent: 60),
                          ListTile(
                            leading: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 32),
                            title: const Text('6. Submissions are Final', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 16)),
                            subtitle: const Padding(
                              padding: EdgeInsets.only(top: 4.0),
                              child: Text('Once you tap "Submit Ballot", your vote is encrypted and cast. You cannot change, undo, or redo your vote after submission.', style: TextStyle(color: Colors.black87, height: 1.4)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      // 2. THE BOTTOM BAR FIX
      bottomNavigationBar: Container(
        // We keep the white background and shadow spanning the full width of the screen...
        decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -4))]),
        child: Center(
          heightFactor: 1.0, // Tells the Center to only take up as much vertical space as it needs
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800), // Matches the text width above!
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => setState(() => _hasAgreed = !_hasAgreed),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _hasAgreed,
                          activeColor: nemsuBlue,
                          onChanged: (bool? value) => setState(() => _hasAgreed = value ?? false),
                        ),
                        const Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(top: 10.0),
                            child: Text('I have read and understood the voting guidelines. I acknowledge that my final submission cannot be changed.', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87, height: 1.4)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _hasAgreed ? nemsuBlue : Colors.grey.shade300,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: _hasAgreed ? 2 : 0,
                      ),
                      onPressed: _hasAgreed ? widget.onProceed : null,
                      child: Text('PROCEED TO BALLOT', style: TextStyle(color: _hasAgreed ? Colors.white : Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGuidelineItem(IconData icon, String title, String description) {
    return ListTile(
      leading: Icon(icon, color: nemsuBlue, size: 32),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: nemsuBlue, fontSize: 16)),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Text(description, style: const TextStyle(color: Colors.black54, height: 1.4)),
      ),
    );
  }
}