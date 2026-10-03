import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../constants.dart';

void showVotingReceiptDialog(
  BuildContext context, {
  required String studentId,
  required String studentName,
  required String studentDept,
}) {
  showDialog(
    context: context,
    builder: (context) => VotingReceiptDialog(
      studentId: studentId,
      studentName: studentName,
      studentDept: studentDept,
    ),
  );
}

class VotingReceiptDialog extends StatelessWidget {
  final String studentId;
  final String studentName;
  final String studentDept;

  const VotingReceiptDialog({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.studentDept,
  });

  Future<Map<String, dynamic>> _fetchReceiptData() async {
    // 1. Fetch the student's vote document
    final voteQuery = await FirebaseFirestore.instance
        .collection('votes')
        .where('voterId', isEqualTo: studentId)
        .limit(1)
        .get();

    Map<String, dynamic> voteData = {};
    if (voteQuery.docs.isNotEmpty) {
      voteData = voteQuery.docs.first.data();
    }

    // 2. Fetch candidates to extract all relevant positions for USG & Dept
    final candidateSnap = await FirebaseFirestore.instance.collection('candidates').get();
    
    Map<String, Set<String>> positionsByScope = {
      'University-Wide (USG)': {},
      'College Student Government': {},
    };

    for (var doc in candidateSnap.docs) {
      final data = doc.data();
      final dept = data['department'] ?? '';
      final pos = data['position'] ?? 'Unknown';

      if (dept == 'University-Wide (USG)') {
        positionsByScope['University-Wide (USG)']!.add(pos);
      } else if (dept == studentDept) {
        positionsByScope['College Student Government']!.add(pos);
      }
    }

    return {
      'vote': voteData,
      'positionsByScope': positionsByScope,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650, maxHeight: 750),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _fetchReceiptData(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(40.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: nemsuBlue),
                    SizedBox(height: 16),
                    Text('Fetching your official ballot...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }

            if (snapshot.hasError || !snapshot.hasData || (snapshot.data!['vote'] as Map).isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 50, color: Colors.orange),
                    const SizedBox(height: 16),
                    const Text(
                      'Receipt Not Found',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: nemsuBlue),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'No cast ballot records were found for your student ID.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: nemsuBlue),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
            }

            final vote = snapshot.data!['vote'] as Map<String, dynamic>;
            final selections = Map<String, dynamic>.from(vote['selections'] ?? {});
            final positionsByScope = snapshot.data!['positionsByScope'] as Map<String, Set<String>>;
            
            Timestamp? timestamp = vote['timestamp'] as Timestamp?;
            String formattedDate = timestamp != null
                ? DateFormat('MMMM dd, yyyy • hh:mm a').format(timestamp.toDate())
                : 'Recorded on file';

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header banner
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: const BoxDecoration(
                    color: nemsuBlue,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: nemsuGold.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified_rounded, color: nemsuGold, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'OFFICIAL VOTING RECEIPT',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'North Eastern Mindanao State University',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Scrollable Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Voter Information Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            children: [
                              _buildInfoRow('Student Name:', studentName),
                              const SizedBox(height: 8),
                              _buildInfoRow('Student ID:', studentId),
                              const SizedBox(height: 8),
                              _buildInfoRow('Department:', studentDept),
                              const SizedBox(height: 8),
                              _buildInfoRow('Date & Time:', formattedDate),
                              const Divider(height: 20, color: Colors.grey),
                              Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Ballot Status:',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: nemsuBlue),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.green.shade300),
                                    ),
                                    child: Text(
                                      'VERIFIED & CASTED',
                                      style: TextStyle(
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        const Text(
                          'YOUR BALLOT SELECTIONS',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            color: nemsuBlue,
                          ),
                        ),
                        const Divider(color: nemsuGold, thickness: 2, height: 16),
                        const SizedBox(height: 8),

                        // 1. University-Wide USG Positions
                        _buildReceiptScope(
                          title: 'UNIVERSITY-WIDE (USG)',
                          positions: positionsByScope['University-Wide (USG)'] ?? {},
                          selections: selections,
                        ),

                        const SizedBox(height: 20),

                        // 2. Departmental Positions
                        _buildReceiptScope(
                          title: '${studentDept.toUpperCase()} GOVERNMENT',
                          positions: positionsByScope['College Student Government'] ?? {},
                          selections: selections,
                        ),

                        // Extra positions in selections that might not be in candidate snapshots
                        ..._buildUncategorizedSelections(positionsByScope, selections),

                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.blue.shade100),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.shield_outlined, color: Colors.blue.shade700, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'This digital receipt confirms your votes have been sealed and safely stored in the official COMSELEC tally.',
                                  style: TextStyle(fontSize: 11, color: Colors.blue.shade900, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom Action Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey.shade200)),
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: nemsuBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'DONE',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildReceiptScope({
    required String title,
    required Set<String> positions,
    required Map<String, dynamic> selections,
  }) {
    if (positions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            color: nemsuBlue.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w900,
              color: nemsuBlue,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ...positions.map((position) {
          final candidateVoted = selections[position]?.toString();
          final hasVotedForPos = candidateVoted != null && candidateVoted.trim().isNotEmpty;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    position,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: nemsuBlue),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 6,
                  child: hasVotedForPos
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            const Icon(Icons.how_to_vote, size: 16, color: nemsuBlue),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                candidateVoted,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        )
                      : Container(
                          alignment: Alignment.centerRight,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              'Abstained',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  List<Widget> _buildUncategorizedSelections(
    Map<String, Set<String>> positionsByScope,
    Map<String, dynamic> selections,
  ) {
    Set<String> allKnownPositions = {
      ...positionsByScope['University-Wide (USG)'] ?? {},
      ...positionsByScope['College Student Government'] ?? {},
    };

    List<String> extraPositions = selections.keys.where((p) => !allKnownPositions.contains(p)).toList();
    if (extraPositions.isEmpty) return [];

    return [
      const SizedBox(height: 12),
      ...extraPositions.map((position) {
        final candidateVoted = selections[position]?.toString() ?? 'Abstained';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  position,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: nemsuBlue),
                ),
              ),
              Expanded(
                flex: 6,
                child: Text(
                  candidateVoted,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }),
    ];
  }
}
