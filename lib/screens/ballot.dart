import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';
import 'candidate_profile.dart';

class BallotScreen extends StatefulWidget {
  final String studentId;
  final String studentDept;
  final VoidCallback onBack;

  const BallotScreen({
    super.key,
    required this.studentId,
    required this.studentDept,
    required this.onBack,
  });

  @override
  State<BallotScreen> createState() => _BallotScreenState();
}

class _BallotScreenState extends State<BallotScreen> {
  Map<String, String> _selectedCandidates = {};
  
  // 👉 THE FIX: Store the stream here so it doesn't "refresh" on every tap
  late Stream<QuerySnapshot> _candidateStream;

  @override
  void initState() {
    super.initState();
    // Initialize the stream only once
    _candidateStream = FirebaseFirestore.instance.collection('candidates').snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: nemsuBlue),
          onPressed: widget.onBack,
        ),
        title: const Text('Official Ballot', style: TextStyle(color: nemsuBlue, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _candidateStream, // 👉 Using the stabilized stream
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _selectedCandidates.isEmpty) {
            return const Center(child: CircularProgressIndicator(color: nemsuBlue));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No candidates found.", style: TextStyle(color: Colors.grey)));
          }

          var allDocs = snapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

          Map<String, Map<String, List<Map<String, dynamic>>>> organizedBallot = {
            'University-Wide (USG)': {},
            'College Student Government': {},
          };

          for (var candidate in allDocs) {
            String dept = candidate['department'] ?? '';
            String scope = (dept == 'University-Wide (USG)') ? 'University-Wide (USG)' : 'College Student Government';
            String pos = candidate['position'] ?? 'Unknown';

            if (dept != 'University-Wide (USG)' && dept != widget.studentDept) continue;

            if (!organizedBallot[scope]!.containsKey(pos)) {
              organizedBallot[scope]![pos] = [];
            }
            organizedBallot[scope]![pos]!.add(candidate);
          }

          // 👉 THE BODY FIX: Swapped ListView for SingleChildScrollView + Center + ConstrainedBox
          return SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800), // 800px keeps the ballot highly readable
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildScopeSection('University-Wide (USG)', organizedBallot['University-Wide (USG)']!),
                      const SizedBox(height: 30),
                      _buildScopeSection(widget.studentDept.toUpperCase(), organizedBallot['College Student Government']!),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _buildSubmitButton(),
    );
  }


  void _showConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Column(
            children: [
              Icon(Icons.fact_check_outlined, size: 40, color: nemsuBlue),
              SizedBox(height: 8),
              Text('Review Your Ballot', style: TextStyle(color: nemsuBlue, fontWeight: FontWeight.bold)),
            ],
          ),
          // 👉 THE FIX: Added ConstrainedBox to stop the dialog from expanding infinitely
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600), // Caps the width at 600 pixels
            child: SizedBox(
              width: double.maxFinite, // Tells it to fill up to the 600px limit, but no further
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Please verify your selections. Empty positions will be counted as "Abstained".',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                    const Divider(color: nemsuGold, thickness: 2, height: 30),
                    
                    // Summary of votes
                    ..._selectedCandidates.entries.map((entry) {
                      String posKey = entry.key;
                      String posName = posKey.contains('::') ? posKey.split('::').last : posKey;
                      String scopePrefix = posKey.contains('::') && posKey.split('::').first.contains('USG')
                          ? 'USG '
                          : (posKey.contains('::') ? 'College ' : '');

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: Text('$scopePrefix$posName:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: nemsuBlue))),
                            Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                          ],
                        ),
                      );
                    }),
                    if (_selectedCandidates.isEmpty)
                      const Text('No candidates selected.', style: TextStyle(color: Colors.redAccent, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Edit Ballot', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: nemsuBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                // 👉 FIX 1: Close the dialog immediately BEFORE writing to the database
                Navigator.pop(context);

                try {
                  // 👉 2. THE TALLY COUNT
                  for (var entry in _selectedCandidates.entries) {
                    String candidateName = entry.value;
                    var candidateQuery = await FirebaseFirestore.instance
                        .collection('candidates')
                        .where('name', isEqualTo: candidateName)
                        .limit(1)
                        .get();

                    if (candidateQuery.docs.isNotEmpty) {
                      await candidateQuery.docs.first.reference.update({
                        'voteCount': FieldValue.increment(1),
                      });
                    }
                  }

                  // 👉 3. THE DATABASE WRITE
                  await FirebaseFirestore.instance.collection('votes').add({
                    'voterId': widget.studentId,
                    'department': widget.studentDept,
                    'selections': _selectedCandidates,
                    'timestamp': FieldValue.serverTimestamp(),
                  });

                  // 👉 4. THE SECURITY SNAP 
                  // (This triggers the StreamBuilder to show the Success message)
                  await FirebaseFirestore.instance.collection('voters').doc(widget.studentId).update({
                    'hasVoted': true, 
                    'votedAt': FieldValue.serverTimestamp(), 
                  });

                } catch (e) {
                  print('Submission Error: $e');
                }
              },
              child: const Text('SUBMIT FINAL VOTE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildScopeSection(String title, Map<String, List<Map<String, dynamic>>> positions) {
    if (positions.isEmpty) return const SizedBox.shrink();

    const positionHierarchy = [
      'President',
      'Vice President for Internal Affairs',
      'Vice President for External Affairs',
      'Vice President',
      'Executive Secretary',
      'Treasurer',
      'Auditor',
      'Senator',
      'Governor',
      'Vice Governor',
      'Secretary',
      'Treasurer',
      'College Auditor',
      'Public Information Officer',
      'Business Manager',
      'Sargeant at Arms',
      'Program/Year Level Rep',
      'Representative',
    ];

    List<MapEntry<String, List<Map<String, dynamic>>>> sortedPositions = positions.entries.toList()
      ..sort((a, b) {
        int indexA = positionHierarchy.indexOf(a.key);
        int indexB = positionHierarchy.indexOf(b.key);
        if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
        if (indexA != -1) return -1;
        if (indexB != -1) return 1;
        return a.key.compareTo(b.key);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(color: nemsuBlue, borderRadius: BorderRadius.circular(10)),
          child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2, fontSize: 14)),
        ),
        const SizedBox(height: 16),

        ...sortedPositions.map((entry) {
          String positionName = entry.key;
          List<Map<String, dynamic>> candidates = entry.value;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(positionName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: nemsuBlue)),
              const Divider(color: nemsuGold, thickness: 2, height: 12),
              const SizedBox(height: 10),
              ...candidates.map((c) => _buildCandidateTile(c, positionName, title)),
              const SizedBox(height: 25),
            ],
          );
        }),
      ],
    );
  }

  // 👉 THE FIX: Removed ListTile and AnimatedContainer for a pure, flicker-free Row
  Widget _buildCandidateTile(Map<String, dynamic> candidate, String position, String scopeTitle) {
    String name = candidate['name'] ?? 'Unknown';
    String party = candidate['party'] ?? 'Independent';
    String selectionKey = '$scopeTitle::$position';
    bool isSelected = _selectedCandidates[selectionKey] == name;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) _selectedCandidates.remove(selectionKey);
          else _selectedCandidates[selectionKey] = name;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? nemsuBlue.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? nemsuBlue : Colors.grey.shade200, 
            width: isSelected ? 2 : 1
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            // Avatar (Tap to see profile)
            GestureDetector(
              onTap: () {
                Map<String, String> stringData = {
                  "name": name,
                  "party": party,
                  "platform": candidate['platform'] ?? "No platform."
                };
                Navigator.push(context, MaterialPageRoute(builder: (context) => CandidateProfileScreen(candidate: stringData, position: position)));
              },
              child: const CircleAvatar(
                radius: 24,
                backgroundColor: nemsuGold,
                child: Icon(Icons.person, color: nemsuBlue, size: 28),
              ),
            ),
            const SizedBox(width: 16),
            // Name and Party
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
                  const SizedBox(height: 2),
                  Text(party, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            // Radio Button Icon
            Icon(
              isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: isSelected ? nemsuBlue : Colors.grey.shade300,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return Container(
      // Keep the white background and shadow spanning the full width
      decoration: const BoxDecoration(
        color: Colors.white, 
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))]
      ),
      child: Center(
        heightFactor: 1.0, 
        child: ConstrainedBox(
          // 👉 THE FIX: Reduced from 800 to 400 so the button isn't massive!
          constraints: const BoxConstraints(maxWidth: 800), 
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: SizedBox(
              width: double.infinity, // Fills the 400px constraint cleanly
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedCandidates.isEmpty ? Colors.grey.shade300 : nemsuGold,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                onPressed: _selectedCandidates.isEmpty ? null : () => _showConfirmationDialog(context),
                child: Text(
                  'REVIEW & CAST VOTE', 
                  style: TextStyle(
                    color: _selectedCandidates.isEmpty ? Colors.grey.shade500 : nemsuBlue, 
                    fontSize: 16, 
                    fontWeight: FontWeight.bold, 
                    letterSpacing: 1.5
                  )
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}