import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';
import '../utils/election_schedule_helper.dart';
import '../widgets/logout_dialog.dart';
import '../widgets/voting_receipt_dialog.dart';
import '../widgets/real_time_clock.dart';
import 'dashboard.dart';
import 'ballot.dart';     
import 'profile.dart';    
import 'guidelines.dart'; 

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
  Timer? _ballotWatchdogTimer;

  // 👉 Stabilized streams initialized once to prevent StreamBuilder re-subscribing & flickering
  late final Stream<DocumentSnapshot> _electionToggleStream;
  late final Stream<DocumentSnapshot> _electionConfigStream;
  late final Stream<DocumentSnapshot> _voterStream;

  @override
  void initState() {
    super.initState();
    _electionToggleStream = FirebaseFirestore.instance.collection('settings').doc('election').snapshots();
    _electionConfigStream = FirebaseFirestore.instance.collection('config').doc('election_settings').snapshots();
    _voterStream = FirebaseFirestore.instance.collection('voters').doc(widget.studentId).snapshots();
  }

  @override
  void dispose() {
    _ballotWatchdogTimer?.cancel();
    super.dispose();
  }

  void _onTabChanged(int index) {
    setState(() {
      _selectedIndex = index;
      _updateBallotWatchdog();
    });
  }

  /// Watchdog runs only when user is inside the Ballot tab to eject them if voting time ends
  void _updateBallotWatchdog() {
    if (_selectedIndex == 1) {
      _ballotWatchdogTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && _selectedIndex == 1) {
          setState(() {});
        }
      });
    } else {
      _ballotWatchdogTimer?.cancel();
      _ballotWatchdogTimer = null;
    }
  }

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

  /// Screen shown when voting is locked (upcoming, concluded, paused, or unconfigured)
  Widget _buildElectionLockedScreen(ElectionScheduleState state) {
    Color iconColor;
    Color iconBg;
    IconData iconData;

    switch (state.status) {
      case ElectionScheduleStatus.upcoming:
        iconColor = Colors.amber.shade800;
        iconBg = Colors.amber.shade50;
        iconData = Icons.schedule_rounded;
        break;
      case ElectionScheduleStatus.ended:
        iconColor = Colors.red.shade600;
        iconBg = Colors.red.shade50;
        iconData = Icons.event_busy_rounded;
        break;
      case ElectionScheduleStatus.manuallyLocked:
        iconColor = Colors.orange.shade800;
        iconBg = Colors.orange.shade50;
        iconData = Icons.pause_circle_filled_rounded;
        break;
      default:
        iconColor = Colors.blueGrey.shade600;
        iconBg = Colors.blueGrey.shade50;
        iconData = Icons.lock_clock_rounded;
        break;
    }

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 550),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                  child: Icon(iconData, size: 76, color: iconColor),
                ),
                const SizedBox(height: 24),
                Text(
                  state.statusHeadline,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: nemsuBlue),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  state.statusDescription,
                  style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                if (state.start != null && state.end != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.play_circle_fill_rounded, size: 16, color: Color(0xFF10B981)),
                            const SizedBox(width: 8),
                            const Text('Starts: ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                            Expanded(
                              child: Text(
                                state.formattedStart,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: nemsuBlue),
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.stop_circle_rounded, size: 16, color: Color(0xFFE11D48)),
                            const SizedBox(width: 8),
                            const Text('Ends: ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                            Expanded(
                              child: Text(
                                state.formattedEnd,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: nemsuBlue),
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                ],

                SizedBox(
                  width: 240,
                  height: 48,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: nemsuBlue, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => _onTabChanged(0),
                    icon: const Icon(Icons.arrow_back_rounded, color: nemsuBlue),
                    label: const Text(
                      'Back to Dashboard',
                      style: TextStyle(color: nemsuBlue, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
            SizedBox(
              width: 260,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: nemsuGold,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 1,
                ),
                onPressed: () {
                  showVotingReceiptDialog(
                    context,
                    studentId: widget.studentId,
                    studentName: widget.studentName,
                    studentDept: widget.studentDept,
                  );
                },
                icon: const Icon(Icons.receipt_long_rounded, color: nemsuBlue),
                label: const Text(
                  'View My Casted Ballot',
                  style: TextStyle(color: nemsuBlue, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: 260,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: nemsuBlue, width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _onTabChanged(0),
                icon: const Icon(Icons.home_rounded, color: nemsuBlue),
                label: const Text(
                  'Return to Dashboard',
                  style: TextStyle(color: nemsuBlue, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
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

  Widget _buildDynamicBody(bool isVerified, bool hasVoted, ElectionScheduleState scheduleState) {
    switch (_selectedIndex) {
      case 0: 
        return DashboardScreen(
          studentName: widget.studentName, 
          studentDept: widget.studentDept,
          hasVoted: hasVoted, 
          isElectionActive: scheduleState.canVote,
          scheduleState: scheduleState,
          onStatusChanged: () {
            if (mounted) setState(() {});
          },
          onViewVotes: () {
            showVotingReceiptDialog(
              context,
              studentId: widget.studentId,
              studentName: widget.studentName,
              studentDept: widget.studentDept,
            );
          },
          onNavigateToBallot: () => _onTabChanged(1),
        );
      case 1: 
        if (hasVoted) return _buildVotedMessage();
        if (!scheduleState.canVote) return _buildElectionLockedScreen(scheduleState);
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
    return StreamBuilder<DocumentSnapshot>(
      stream: _electionToggleStream,
      builder: (context, electionSnapshot) {
        return StreamBuilder<DocumentSnapshot>(
          stream: _electionConfigStream,
          builder: (context, configSnapshot) {
            final electionToggleData = electionSnapshot.data?.data() as Map<String, dynamic>?;
            final electionConfigData = configSnapshot.data?.data() as Map<String, dynamic>?;

            final scheduleState = ElectionScheduleHelper.evaluate(
              electionConfigDoc: electionConfigData,
              electionToggleDoc: electionToggleData,
              currentTime: DateTime.now(),
            );

            return StreamBuilder<DocumentSnapshot>(
              stream: _voterStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator(color: nemsuBlue)));
                }
                
                var data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                bool isVerified = data['status'] == 'Verified';
                bool hasVoted = data['hasVoted'] ?? false;

                // Only hide the nav bar if the ballot is genuinely open
                bool isBallotOpen = _selectedIndex == 1 && _guidelinesAccepted && !hasVoted && scheduleState.canVote && isVerified;

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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Center(
                          child: RealTimeClock(
                            backgroundColor: nemsuBackground,
                            textColor: nemsuBlue,
                            iconColor: nemsuGold,
                            borderColor: nemsuGold.withValues(alpha: 0.35),
                            fontSize: 11,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
                        tooltip: 'Logout',
                        onPressed: () => showLogoutConfirmationDialog(context),
                      ),
                    ],
                  ),
                  
                  body: _buildDynamicBody(isVerified, hasVoted, scheduleState),

                  bottomNavigationBar: isBallotOpen ? null : Container(
                    decoration: BoxDecoration(boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -2))]),
                    child: BottomNavigationBar(
                      currentIndex: _selectedIndex,
                      onTap: _onTabChanged,
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
              },
            );
          },
        );
      },
    );
  }
}