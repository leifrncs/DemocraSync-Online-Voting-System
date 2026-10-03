import 'package:flutter/material.dart';
import '../constants.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onNavigateToBallot;
  final VoidCallback? onViewVotes;

  final String studentName; 
  final String studentDept;
  final bool hasVoted;
  final bool isElectionActive; // 👉 NEW: Receives the global election status

  const DashboardScreen({
    super.key, 
    required this.onNavigateToBallot,
    this.onViewVotes,
    required this.studentName, 
    required this.studentDept,
    required this.hasVoted,
    required this.isElectionActive,
  });

  @override
  Widget build(BuildContext context) {
    // 👉 Helper variables to determine button styling
    // If student has voted, they can always view their votes even if election is closed
    bool isButtonDisabled = !hasVoted && !isElectionActive;
    
    String buttonText = 'PROCEED TO BALLOT';
    if (hasVoted) {
      buttonText = 'VIEW MY CASTED BALLOT';
    } else if (!isElectionActive) {
      buttonText = 'ELECTION CLOSED';
    }

    return Scaffold(
      backgroundColor: Colors.transparent, 

      // 👉 1. THE BODY FIX
      body: SafeArea(
        child: SingleChildScrollView(
          // Scrollbar stays on the far right edge
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800), // Matches Ballot and Guidelines width perfectly
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Welcome, $studentName!', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: nemsuBlue)),
                          const SizedBox(height: 4),
                          Text(studentDept, style: const TextStyle(fontSize: 14, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    Image.asset(
                      'assets/democrasync-logo1.png',
                      width: 100, 
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 6),
                    const Text('DemocraSync', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: nemsuBlue)),
                    const Text('Empowering the Student Voice.', style: TextStyle(fontSize: 16, color: nemsuGold, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                    const SizedBox(height: 32),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Our Mission', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: nemsuBlue)),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '"To empower the student body of North Eastern Mindanao State University by providing a secure, transparent, and accessible digital voting platform."',
                      style: TextStyle(fontSize: 16, height: 1.6, color: Colors.black87, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.justify,
                    ),
                    const SizedBox(height: 32),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Why Use This App?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: nemsuBlue)),
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(Icons.security, 'Secure & Verified', 'Built exclusively for verified NEMSU students to ensure every vote is legitimate.'),
                    const SizedBox(height: 16),
                    _buildFeatureItem(Icons.touch_app, 'Convenient', 'Skip the long lines. Cast your ballot from anywhere on campus.'),
                    const SizedBox(height: 50),

                    SizedBox(
                      width: double.infinity, // Forces the button to stretch nicely across the column
                      height: 55,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasVoted 
                              ? nemsuGold 
                              : (isButtonDisabled ? Colors.grey.shade400 : nemsuBlue),
                          elevation: hasVoted ? 2 : 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(
                          hasVoted ? Icons.receipt_long_rounded : Icons.how_to_vote_rounded,
                          color: hasVoted ? nemsuBlue : (isButtonDisabled ? Colors.grey.shade700 : Colors.white),
                        ),
                        onPressed: isButtonDisabled 
                            ? null 
                            : (hasVoted ? (onViewVotes ?? onNavigateToBallot) : onNavigateToBallot), 
                        label: Text(
                          buttonText, 
                          style: TextStyle(
                            color: hasVoted ? nemsuBlue : (isButtonDisabled ? Colors.grey.shade700 : Colors.white), 
                            fontWeight: FontWeight.bold, 
                            fontSize: 16,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),

      
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: nemsuGold.withValues(alpha: 0.2), shape: BoxShape.circle),
          child: Icon(icon, color: nemsuBlue, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: nemsuBlue)),
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(fontSize: 14, color: Colors.black54, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}