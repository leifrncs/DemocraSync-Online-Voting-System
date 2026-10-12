import 'dart:async';
import 'package:flutter/material.dart';
import '../constants.dart';
import '../utils/election_schedule_helper.dart';

class DashboardScreen extends StatelessWidget {
  final VoidCallback onNavigateToBallot;
  final VoidCallback? onViewVotes;
  final VoidCallback? onStatusChanged;

  final String studentName; 
  final String studentDept;
  final bool hasVoted;
  final bool isElectionActive;
  final ElectionScheduleState? scheduleState;

  const DashboardScreen({
    super.key, 
    required this.onNavigateToBallot,
    this.onViewVotes,
    this.onStatusChanged,
    required this.studentName, 
    required this.studentDept,
    required this.hasVoted,
    required this.isElectionActive,
    this.scheduleState,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveCanVote = scheduleState?.canVote ?? isElectionActive;
    final isButtonDisabled = !hasVoted && !effectiveCanVote;
    
    String buttonText = 'PROCEED TO BALLOT';
    if (hasVoted) {
      buttonText = 'VIEW MY CASTED BALLOT';
    } else if (!effectiveCanVote) {
      buttonText = scheduleState?.actionButtonLabel ?? 'ELECTION CLOSED';
    }

    return Scaffold(
      backgroundColor: Colors.transparent, 
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Welcome Card
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
                    const SizedBox(height: 20),

                    // Election Schedule & Status Card (Isolated Ticking Widget)
                    if (scheduleState != null) ...[
                      ElectionScheduleCard(
                        state: scheduleState!,
                        onStatusChanged: onStatusChanged,
                      ),
                      const SizedBox(height: 24),
                    ],

                    Image.asset(
                      'assets/democrasync-logo1.png',
                      width: 90, 
                      height: 90,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 6),
                    const Text('DemocraSync', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: nemsuBlue)),
                    const Text('Empowering the Student Voice.', style: TextStyle(fontSize: 15, color: nemsuGold, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                    const SizedBox(height: 28),

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
                    const SizedBox(height: 28),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Why Use This App?', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: nemsuBlue)),
                    ),
                    const SizedBox(height: 16),
                    _buildFeatureItem(Icons.security, 'Secure & Verified', 'Built exclusively for verified NEMSU students to ensure every vote is legitimate.'),
                    const SizedBox(height: 16),
                    _buildFeatureItem(Icons.touch_app, 'Convenient', 'Skip the long lines. Cast your ballot from anywhere on campus.'),
                    const SizedBox(height: 40),

                    // Action Button
                    SizedBox(
                      width: double.infinity,
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
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: hasVoted ? nemsuBlue : (isButtonDisabled ? Colors.grey.shade700 : Colors.white), 
                            fontWeight: FontWeight.bold, 
                            fontSize: 15,
                            letterSpacing: 1.1,
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

/// Dedicated schedule card that isolates live ticking updates to prevent full dashboard rebuilds
class ElectionScheduleCard extends StatefulWidget {
  final ElectionScheduleState state;
  final VoidCallback? onStatusChanged;

  const ElectionScheduleCard({
    super.key,
    required this.state,
    this.onStatusChanged,
  });

  @override
  State<ElectionScheduleCard> createState() => _ElectionScheduleCardState();
}

class _ElectionScheduleCardState extends State<ElectionScheduleCard> {
  Timer? _timer;
  ElectionScheduleStatus? _lastStatus;

  @override
  void initState() {
    super.initState();
    _lastStatus = widget.state.status;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _checkStatusTransition();
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(ElectionScheduleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _lastStatus = widget.state.status;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _checkStatusTransition() {
    final now = DateTime.now();
    if (widget.state.status == ElectionScheduleStatus.upcoming && widget.state.start != null) {
      if (now.isAfter(widget.state.start!) || now.isAtSameMomentAs(widget.state.start!)) {
        if (_lastStatus != ElectionScheduleStatus.open) {
          _lastStatus = ElectionScheduleStatus.open;
          widget.onStatusChanged?.call();
        }
      }
    } else if (widget.state.status == ElectionScheduleStatus.open && widget.state.end != null) {
      if (now.isAfter(widget.state.end!) || now.isAtSameMomentAs(widget.state.end!)) {
        if (_lastStatus != ElectionScheduleStatus.ended) {
          _lastStatus = ElectionScheduleStatus.ended;
          widget.onStatusChanged?.call();
        }
      }
    }
  }

  String _getLiveTimeRemainingText() {
    final now = DateTime.now();
    if (widget.state.status == ElectionScheduleStatus.upcoming && widget.state.start != null) {
      if (now.isBefore(widget.state.start!)) {
        final diff = widget.state.start!.difference(now);
        return 'Opens in ${ElectionScheduleHelper.formatDuration(diff)}';
      } else {
        return 'Opening now...';
      }
    }

    if (widget.state.status == ElectionScheduleStatus.open && widget.state.end != null) {
      if (now.isBefore(widget.state.end!)) {
        final diff = widget.state.end!.difference(now);
        return 'Closes in ${ElectionScheduleHelper.formatDuration(diff)}';
      } else {
        return 'Voting period has officially ended';
      }
    }

    return widget.state.timeRemainingText;
  }

  @override
  Widget build(BuildContext context) {
    Color badgeBg;
    Color badgeTextColor;
    IconData badgeIcon;

    switch (widget.state.status) {
      case ElectionScheduleStatus.open:
        badgeBg = const Color(0xFFDCFCE7);
        badgeTextColor = const Color(0xFF166534);
        badgeIcon = Icons.check_circle_rounded;
        break;
      case ElectionScheduleStatus.upcoming:
        badgeBg = const Color(0xFFFEF3C7);
        badgeTextColor = const Color(0xFF92400E);
        badgeIcon = Icons.schedule_rounded;
        break;
      case ElectionScheduleStatus.ended:
        badgeBg = const Color(0xFFFEE2E2);
        badgeTextColor = const Color(0xFF991B1B);
        badgeIcon = Icons.event_busy_rounded;
        break;
      case ElectionScheduleStatus.manuallyLocked:
        badgeBg = const Color(0xFFFFFBEB);
        badgeTextColor = const Color(0xFFB45309);
        badgeIcon = Icons.pause_circle_filled_rounded;
        break;
      case ElectionScheduleStatus.notConfigured:
        badgeBg = const Color(0xFFF1F5F9);
        badgeTextColor = const Color(0xFF475569);
        badgeIcon = Icons.lock_outline_rounded;
        break;
    }

    final isNarrow = MediaQuery.of(context).size.width < 600;
    final liveRemainingText = _getLiveTimeRemainingText();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: nemsuBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.event_note_rounded, color: nemsuBlue, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Election Schedule',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: nemsuBlue),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 14, color: badgeTextColor),
                    const SizedBox(width: 5),
                    Text(
                      widget.state.statusBadge,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: badgeTextColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 14),

          // Schedule Tiles
          if (isNarrow)
            Column(
              children: [
                _buildScheduleTile(
                  icon: Icons.play_circle_fill_rounded,
                  iconColor: const Color(0xFF10B981),
                  label: 'Start of Voting',
                  value: widget.state.formattedStart,
                ),
                const SizedBox(height: 10),
                _buildScheduleTile(
                  icon: Icons.stop_circle_rounded,
                  iconColor: const Color(0xFFE11D48),
                  label: 'End of Voting',
                  value: widget.state.formattedEnd,
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildScheduleTile(
                    icon: Icons.play_circle_fill_rounded,
                    iconColor: const Color(0xFF10B981),
                    label: 'Start of Voting',
                    value: widget.state.formattedStart,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildScheduleTile(
                    icon: Icons.stop_circle_rounded,
                    iconColor: const Color(0xFFE11D48),
                    label: 'End of Voting',
                    value: widget.state.formattedEnd,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 14),

          // Context & Live Countdown Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: badgeBg.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: badgeTextColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 16, color: badgeTextColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    liveRemainingText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: badgeTextColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: nemsuBlue),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}