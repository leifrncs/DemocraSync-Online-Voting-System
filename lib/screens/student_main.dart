import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';
import 'dashboard.dart';
import 'ballot.dart';     
import 'profile.dart';    
import 'guidelines.dart'; 
import 'login.dart'; 

class StudentMainScreen extends StatefulWidget {
  final String studentName;
  final String studentId;
  final String studentDept;

  const StudentMainScreen({
    super.key, 
    required this.studentName,
    required this.studentId,
    required this.studentDept,
  });

  @override
  State<StudentMainScreen> createState() => _StudentMainScreenState();
}

class _StudentMainScreenState extends State<StudentMainScreen> {
  int _selectedIndex = 0;
  bool _guidelinesAccepted = false;

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0: return 'Student Dashboard';
      case 1: return _guidelinesAccepted ? 'Official Ballot' : 'Voting Guidelines';
      case 2: return 'Profile Settings';
      default: return 'DemocraSync';
    }
  }

  Widget _buildLockScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle),
              child: Icon(Icons.lock_clock_rounded, size: 80, color: Colors.orange.shade400),
            ),
            const SizedBox(height: 24),
            const Text('Verification Pending', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: nemsuBlue)),
            const SizedBox(height: 12),
            const Text(
              'The COMSELEC is currently verifying your student records. Please wait for activation before accessing the ballot.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // 👉 NEW: The screen shown when the admin has toggled the election OFF
  Widget _buildElectionClosedScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
              child: Icon(Icons.block_rounded, size: 80, color: Colors.red.shade400),
            ),
            const SizedBox(height: 24),
            const Text('Election is Closed', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: nemsuBlue)),
            const SizedBox(height: 12),
            const Text(
              'The COMSELEC has not yet opened the voting period or it has already ended. Please wait for official announcements.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVotedMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.verified_user_rounded, size: 80, color: Colors.green),
            const SizedBox(height: 24),
            const Text(
              'Vote Successfully Cast!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: nemsuBlue),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'Thank you for exercising your right to vote and participating in the NEMSU Student Elections.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: nemsuBlue,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                setState(() {
                  _selectedIndex = 0; 
                });
              },
              icon: const Icon(Icons.home_rounded, color: Colors.white),
              label: const Text('Return to Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            const Text(
              'The results will be published once the election period ends.', 
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // 👉 UPDATED: Now receives the isElectionActive status
  Widget _buildDynamicBody(bool isVerified, bool hasVoted, bool isElectionActive) {
    switch (_selectedIndex) {
      case 0: 
        return DashboardScreen(
          studentName: widget.studentName, 
          studentDept: widget.studentDept,
          hasVoted: hasVoted, 
          isElectionActive: isElectionActive, // Pass it down to the dashboard
          onNavigateToBallot: () => setState(() => _selectedIndex = 1),
        );
      case 1: 
        if (hasVoted) return _buildVotedMessage();
        if (!isElectionActive) return _buildElectionClosedScreen(); // 👉 Blocks the ballot!
        if (!isVerified) return _buildLockScreen();
        return _guidelinesAccepted 
            ? BallotScreen(
                studentId: widget.studentId, 
                studentDept: widget.studentDept,
                onBack: () => setState(() => _guidelinesAccepted = false),
              ) 
            : GuidelinesScreen(onProceed: () => setState(() => _guidelinesAccepted = true));
      case 2: 
        return ProfileScreen(studentId: widget.studentId); 
      default: 
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 👉 THE FIX: Added an outer StreamBuilder to listen to the global Election status
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('settings').doc('election').snapshots(),
      builder: (context, electionSnapshot) {
        
        bool isElectionActive = false;
        if (electionSnapshot.hasData && electionSnapshot.data!.exists) {
           isElectionActive = (electionSnapshot.data!.data() as Map<String, dynamic>?)?['isActive'] ?? false;
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('voters').doc(widget.studentId).snapshots(),
          builder: (context, snapshot) {
            
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator(color: nemsuBlue)));
            }
            
            var data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
            bool isVerified = data['status'] == 'Verified';
            bool hasVoted = data['hasVoted'] ?? false;

            // Only hide the nav bar if the ballot is genuinely open
            bool isBallotOpen = _selectedIndex == 1 && _guidelinesAccepted && !hasVoted && isElectionActive && isVerified;

            return Scaffold(
              backgroundColor: const Color(0xFFF1F5F9),
              appBar: isBallotOpen ? null : AppBar(
                backgroundColor: Colors.white, 
                elevation: 1,
                automaticallyImplyLeading: false, 
                title: Row(
                  children: [
                    Image.asset('assets/democrasync-logo1.png', width: 35, height: 35, fit: BoxFit.contain),
                    const SizedBox(width: 12),
                    Text(_getAppBarTitle(), style: const TextStyle(color: nemsuBlue, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                    onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false),
                  ),
                ],
              ),
              
              body: _buildDynamicBody(isVerified, hasVoted, isElectionActive),

              bottomNavigationBar: isBallotOpen ? null : Container(
                decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))]),
                child: BottomNavigationBar(
                  currentIndex: _selectedIndex,
                  onTap: (index) => setState(() => _selectedIndex = index),
                  backgroundColor: Colors.white,
                  selectedItemColor: nemsuBlue,
                  unselectedItemColor: Colors.grey.shade600,
                  type: BottomNavigationBarType.fixed,
                  items: const [
                    BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard_rounded), label: 'Home'),
                    BottomNavigationBarItem(icon: Icon(Icons.how_to_vote_outlined), activeIcon: Icon(Icons.how_to_vote_rounded), label: 'Ballot'),
                    BottomNavigationBarItem(icon: Icon(Icons.person_outline_rounded), activeIcon: Icon(Icons.person_rounded), label: 'Profile'),
                  ],
                ),
              ),
            );
          }
        );
      }
    );
  }
}