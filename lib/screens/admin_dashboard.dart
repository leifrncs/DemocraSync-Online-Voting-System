import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart'; 
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import '../widgets/logout_dialog.dart';
import '../widgets/real_time_clock.dart';
import 'voter_management.dart';
import 'candidate_management.dart';
import 'election_configuration.dart';
import 'audit_logs.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _isSidebarVisible = true; 
  int _selectedIndex = 0; 

  String _selectedTallyScope = 'University-Wide (USG)';
  
  final List<String> _tallyScopes = [
    'University-Wide (USG)',
    'College of Information Technology Education',
    'College of Business and Management',
    'College of Teacher Education',
    'College of Engineering and Technology',
    'College of Arts and Sciences',
  ];

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0: return 'DemocraSync Dashboard';
      case 1: return 'Election Configuration';
      case 2: return 'Candidate Management';
      case 3: return 'NEMSU Voter Management';
      case 4: return 'System Security Audit';
      default: return 'Admin Panel';
    }
  }

  Future<void> _generateAndDownloadPDF() async {
    try {
      var votersSnap = await FirebaseFirestore.instance.collection('voters').get();
      var candidatesSnap = await FirebaseFirestore.instance.collection('candidates').get();

      int totalVoters = votersSnap.docs.where((doc) => (doc.data())['status'] == 'Verified').length;
      int totalVotes = votersSnap.docs.where((doc) => (doc.data())['hasVoted'] == true).length;
      double turnout = totalVoters > 0 ? (totalVotes / totalVoters) * 100 : 0;

      Map<String, List<Map<String, dynamic>>> groupedCandidates = {};
      for (var doc in candidatesSnap.docs) {
        var data = doc.data();
        String position = data['position'] ?? 'Unknown Position';
        groupedCandidates.putIfAbsent(position, () => []).add(data);
      }
      
      groupedCandidates.forEach((key, list) {
        list.sort((a, b) => ((b['voteCount'] as num?)?.toInt() ?? 0).compareTo((a['voteCount'] as num?)?.toInt() ?? 0));
      });

      final pdf = pw.Document();
      final String currentDate = DateFormat('MMMM dd, yyyy - hh:mm a').format(DateTime.now());

      final font = await PdfGoogleFonts.openSansRegular();
      final boldFont = await PdfGoogleFonts.openSansBold();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          theme: pw.ThemeData.withFont(
            base: font,
            bold: boldFont,
          ),
          build: (pw.Context context) {
            return [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text('NORTH EASTERN MINDANAO STATE UNIVERSITY', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('DemocraSync - Official Student Election Tally', style: pw.TextStyle(fontSize: 14)),
                    pw.SizedBox(height: 4),
                    pw.Text('Generated on: $currentDate', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    pw.SizedBox(height: 20),
                    pw.Divider(thickness: 2),
                    pw.SizedBox(height: 20),
                  ],
                ),
              ),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _buildPdfKpi('Registered Voters', totalVoters.toString()),
                  _buildPdfKpi('Total Votes Cast', totalVotes.toString()),
                  _buildPdfKpi('Voter Turnout', '${turnout.toStringAsFixed(1)}%'),
                ],
              ),
              pw.SizedBox(height: 30),

              ...groupedCandidates.entries.map((entry) {
                String position = entry.key;
                List<Map<String, dynamic>> candidates = entry.value;

                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(position.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.SizedBox(height: 8),
                    pw.TableHelper.fromTextArray(
                      headers: ['Candidate Name', 'Party Affiliation', 'Total Votes'],
                      data: candidates.map((c) => [
                        c['name']?.toString() ?? 'Unknown',
                        c['party']?.toString() ?? 'Independent',
                        (c['voteCount'] ?? 0).toString(),
                      ]).toList(),
                      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                      cellHeight: 25,
                      cellAlignments: {
                        0: pw.Alignment.centerLeft,
                        1: pw.Alignment.centerLeft,
                        2: pw.Alignment.center,
                      },
                    ),
                    pw.SizedBox(height: 25),
                  ],
                );
              }),

              pw.SizedBox(height: 40),
              pw.Text('CERTIFIED TRUE AND CORRECT BY:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 40),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  _buildSignatureLine('System Administrator'),
                  _buildSignatureLine('COMSELEC Chairperson'),
                ],
              ),
            ];
          },
        ),
      );

      await Printing.sharePdf(bytes: await pdf.save(), filename: 'DemocraSync_Official_Results.pdf');

      // Write to Audit Logs
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'timestamp': FieldValue.serverTimestamp(),
        'logCategory': 'ACTIVITY LOG',
        'action': 'Official Tally Exported (PDF)',
        'user': 'Admin_Primary',
        'type': 'System Export',
        'details': {
          'Target': 'System Generation',
          'Payload': 'File: DemocraSync_Official_Results.pdf',
        },
      });

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  pw.Widget _buildPdfKpi(String title, String value) {
    return pw.Column(
      children: [
        pw.Text(value, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        pw.SizedBox(height: 4),
        pw.Text(title, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      ],
    );
  }

  pw.Widget _buildSignatureLine(String title) {
    return pw.Column(
      children: [
        pw.Container(width: 150, height: 1, color: PdfColors.black),
        pw.SizedBox(height: 4),
        pw.Text(title, style: const pw.TextStyle(fontSize: 10)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: nemsuBlue,
        automaticallyImplyLeading: false, 
        titleSpacing: 0, 
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () => setState(() => _isSidebarVisible = !_isSidebarVisible),
        ),
        title: Row(
          children: [
            if (MediaQuery.of(context).size.width > 400) ...[
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(color: nemsuGold, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.account_balance_rounded, color: nemsuBlue, size: 20),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_getAppBarTitle(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  const Text('Admin', style: TextStyle(color: nemsuGold, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Center(
              child: RealTimeClock(
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                textColor: Colors.white,
                iconColor: nemsuGold,
                borderColor: nemsuGold.withValues(alpha: 0.35),
                fontSize: 11,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            ),
          ),
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('settings').doc('election').snapshots(),
            builder: (context, snapshot) {
              bool isActive = false;
              if (snapshot.hasData && snapshot.data!.exists) {
                var data = snapshot.data!.data() as Map<String, dynamic>?;
                isActive = data?['isActive'] ?? false;
              }

              return Row(
                children: [
                  if (MediaQuery.of(context).size.width > 600)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Status', style: TextStyle(color: nemsuGold, fontSize: 10)),
                        Text(isActive ? 'ACTIVE' : 'LOCKED', style: TextStyle(color: isActive ? Colors.greenAccent : Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  Switch(
                    value: isActive,
                    activeColor: nemsuGold,
                    activeTrackColor: Colors.green,
                    inactiveTrackColor: Colors.grey.shade600,
                    onChanged: (value) async {
                      try {
                        // 1. Perform the update
                        await FirebaseFirestore.instance.collection('settings').doc('election').set(
                          {'isActive': value}, 
                          SetOptions(merge: true)
                        );
                        
                        // 2. Write to Audit Logs
                        await FirebaseFirestore.instance.collection('audit_logs').add({
                          'timestamp': FieldValue.serverTimestamp(),
                          'action': 'Election Status Toggled',
                          'user': 'admin', // Ensure this user is actually logged in!
                          'type': 'Configuration',
                          'details': {'isActive': value},
                        });

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Status updated: ${value ? "OPEN" : "LOCKED"}'), backgroundColor: Colors.green)
                          );
                        }
                      } catch (e) {
                        // THIS IS THE KEY: If it fails, this will show you exactly why (e.g., Permission Denied)
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update: $e'), backgroundColor: Colors.red)
                          );
                        }
                      }
                    },
                  ),
                ],
              );
            }
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded, color: nemsuGold), 
            tooltip: 'Export Official Results (PDF)',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating Official PDF Report...'), backgroundColor: nemsuBlue));
              await _generateAndDownloadPDF();
            }, 
          ),
        ],
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            width: _isSidebarVisible ? 70 : 0, 
            color: nemsuBlue,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: SizedBox(
                width: 70, 
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildNavItem(Icons.dashboard_rounded, 'Dashboard', 0),
                    const SizedBox(height: 20),
                    _buildNavItem(Icons.settings_suggest_rounded, 'Election Configuration', 1), 
                    const SizedBox(height: 20),
                    _buildNavItem(Icons.how_to_vote_rounded, 'Candidate Management', 2),     
                    const SizedBox(height: 20),
                    _buildNavItem(Icons.people_rounded, 'Voter Management', 3),          
                    const SizedBox(height: 20),
                    _buildNavItem(Icons.assignment_rounded, 'Audit Logs', 4),
                    const Spacer(),
                    Tooltip(
                      message: 'Log Out',
                      waitDuration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.only(left: 12),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: nemsuSlate,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(2, 2),
                          ),
                        ],
                      ),
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.logout, color: Colors.redAccent),
                        onPressed: () => showLogoutConfirmationDialog(context),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: _buildMainContent()),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    switch (_selectedIndex) {
      case 0: return _buildDashboardContent(context);
      case 1: return const ElectionConfiguration();
      case 2: return const CandidateManagement();
      case 3: return const VoterManagement();
      case 4: return const AuditLogs();
      default: return _buildDashboardContent(context);
    }
  }

  Widget _buildNavItem(IconData icon, String title, int index) {
    bool isActive = _selectedIndex == index;
    return Tooltip(
      message: title,
      waitDuration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: nemsuSlate,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(2, 2),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isActive ? nemsuGold : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: Icon(
            icon,
            color: isActive ? nemsuBlue : Colors.white70,
            size: 24,
          ),
          onPressed: () => setState(() => _selectedIndex = index),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('voters').snapshots(),
      builder: (context, votersSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('candidates').snapshots(),
          builder: (context, candidatesSnapshot) {
            
            if (votersSnapshot.connectionState == ConnectionState.waiting || candidatesSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: nemsuBlue));
            }

            final voters = votersSnapshot.data?.docs ?? [];
            final candidates = candidatesSnapshot.data?.docs ?? [];

            int registeredVoters = 0;
            int totalVotes = 0;
            int pendingVerifications = 0;
            Map<String, int> deptTurnout = {};

            for (var doc in voters) {
              var data = doc.data() as Map<String, dynamic>;
              String status = data['status']?.toString() ?? '';
              
              if (status == 'Verified') {
                registeredVoters++;
              } else if (status == 'Pending' || status == 'Pending Verification') {
                pendingVerifications++;
              }

              if (data['hasVoted'] == true) {
                totalVotes++;
                String dept = data['department']?.toString() ?? 'Unknown';
                String shortDept = dept.replaceAll('College of ', '').replaceAll(' Education', '').replaceAll(' and ', ' & ');
                deptTurnout[shortDept] = (deptTurnout[shortDept] ?? 0) + 1;
              }
            }

            double turnoutPercentage = registeredVoters > 0 ? totalVotes / registeredVoters : 0.0;
            Map<String, int> chartPositionVotes = {};
            Map<String, List<Map<String, dynamic>>> scopedCandidates = {};

            for (var doc in candidates) {
              var data = doc.data() as Map<String, dynamic>;
              
              String position = data['position']?.toString() ?? 'Unknown';
              String dept = data['department']?.toString() ?? '';
              int votes = (data['voteCount'] as num?)?.toInt() ?? 0;
              
              chartPositionVotes[position] = (chartPositionVotes[position] ?? 0) + votes;

              if (dept == _selectedTallyScope) {
                scopedCandidates.putIfAbsent(position, () => []).add(data);
              }
            }

            scopedCandidates.forEach((key, list) {
              list.sort((a, b) {
                int bVotes = (b['voteCount'] as num?)?.toInt() ?? 0;
                int aVotes = (a['voteCount'] as num?)?.toInt() ?? 0;
                return bVotes.compareTo(aVotes);
              });
            });

            double screenWidth = MediaQuery.of(context).size.width;

            Widget card1 = _buildKPICard(Icons.how_to_reg_rounded, 'Registered Voters', registeredVoters.toString(), nemsuBlue);
            Widget card2 = _buildKPICard(Icons.how_to_vote_rounded, 'Total Votes Cast', totalVotes.toString(), const Color(0xFF7C3AED));
            Widget card3 = _buildTurnoutCard(turnoutPercentage);
            Widget card4 = _buildKPICard(Icons.pending_actions_rounded, 'Pending Verifications', pendingVerifications.toString(), const Color(0xFFE11D48));

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- SECTION HEADER ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Election Overview',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: nemsuBlue, letterSpacing: -0.3),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Real-time voter turnout and candidate tally statistics',
                            style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // --- KPI METRIC CARDS ---
                  if (screenWidth > 900)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: card1), const SizedBox(width: 14),
                          Expanded(child: card2), const SizedBox(width: 14),
                          Expanded(child: card3), const SizedBox(width: 14),
                          Expanded(child: card4),
                        ],
                      ),
                    )
                  else
                    Column(
                      children: [
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: card1), const SizedBox(width: 10),
                              Expanded(child: card2),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: card3), const SizedBox(width: 10),
                              Expanded(child: card4),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 18),

                  // --- CHARTS SECTION (COMPACT & BEAUTIFUL) ---
                  if (screenWidth > 850) 
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildPieChartCard(deptTurnout, totalVotes, screenWidth)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildBarChartCard(chartPositionVotes)),
                      ],
                    )
                  else ...[
                    _buildPieChartCard(deptTurnout, totalVotes, screenWidth),
                    const SizedBox(height: 16),
                    _buildBarChartCard(chartPositionVotes),
                  ],
                  
                  const SizedBox(height: 18),

                  // --- LIVE TALLY BOARD ---
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: nemsuBlue.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.leaderboard_rounded, color: nemsuBlue, size: 18),
                                ),
                                const SizedBox(width: 10),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Live Tally Board', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: nemsuBlue)),
                                    Text('Select scope to inspect candidate standings', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              constraints: const BoxConstraints(maxWidth: 320), 
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFCBD5E1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _selectedTallyScope,
                                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: nemsuBlue),
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: nemsuBlue),
                                  items: _tallyScopes.map<DropdownMenuItem<String>>((String scope) {
                                    return DropdownMenuItem<String>(
                                      value: scope,
                                      child: Text(scope, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    );
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedTallyScope = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const Divider(height: 1, color: Color(0xFFE2E8F0), thickness: 1),
                        const SizedBox(height: 12),

                        if (scopedCandidates.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 36.0),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.inbox_outlined, size: 40, color: Colors.grey.shade400),
                                  const SizedBox(height: 8),
                                  Text("No candidates registered for $_selectedTallyScope", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                                ],
                              ),
                            ),
                          )
                        else
                          for (var entry in scopedCandidates.entries)
                            Builder(
                              builder: (context) {
                                int totalPosVotes = entry.value.fold(0, (sum, item) => sum + ((item['voteCount'] as num?)?.toInt() ?? 0));
                                int topVotes = entry.value.isNotEmpty ? ((entry.value.first['voteCount'] as num?)?.toInt() ?? 0) : 0;
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 14.0, bottom: 8.0),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 4,
                                            height: 14,
                                            decoration: BoxDecoration(
                                              color: nemsuGold,
                                              borderRadius: BorderRadius.circular(2),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            entry.key.toUpperCase(),
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: nemsuBlue, letterSpacing: 0.5),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              '$totalPosVotes total votes',
                                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    for (var candidate in entry.value)
                                      Builder(
                                        builder: (context) {
                                          String name = candidate['name']?.toString() ?? 'Unknown';
                                          String party = candidate['party']?.toString() ?? 'Independent';
                                          int cVotes = (candidate['voteCount'] as num?)?.toInt() ?? 0;
                                          double pct = totalPosVotes > 0 ? cVotes / totalPosVotes : 0.0;
                                          bool isLeading = topVotes > 0 && cVotes == topVotes;
                                          
                                          return _buildTallyRow(name, party, cVotes, pct, isLeading);
                                        }
                                      )
                                  ],
                                );
                              }
                            )
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        );
      }
    );
  }

  Widget _buildPieChartCard(Map<String, int> deptTurnout, int totalVotes, double screenWidth) {
    const List<Color> colors = [
      nemsuBlue,
      Color(0xFFD4AF37),
      Color(0xFF10B981),
      Color(0xFF6366F1),
      Color(0xFF8B5CF6),
      Color(0xFFF59E0B),
      Color(0xFF06B6D4),
    ];

    List<PieChartSectionData> sections = [];
    int colorIndex = 0;

    for (var entry in deptTurnout.entries) {
      final color = colors[colorIndex % colors.length];
      colorIndex++;
      final double pct = totalVotes > 0 ? (entry.value / totalVotes) * 100 : 0;
      sections.add(
        PieChartSectionData(
          color: color,
          value: entry.value.toDouble(),
          showTitle: false,
          radius: 20,
          badgeWidget: null,
          title: '${pct.toStringAsFixed(0)}%',
        )
      );
    }

    return Container(
      height: 290,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: nemsuBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.donut_large_rounded, color: nemsuBlue, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Turnout by Department',
                    style: TextStyle(fontWeight: FontWeight.bold, color: nemsuBlue, fontSize: 13),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$totalVotes Cast',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: nemsuBlue),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: sections.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.pie_chart_outline_rounded, size: 36, color: Colors.grey.shade300),
                        const SizedBox(height: 6),
                        Text("No votes cast yet", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      // Donut Chart with Center Metric
                      SizedBox(
                        width: 140,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                sections: sections,
                                centerSpaceRadius: 40,
                                sectionsSpace: 2,
                                pieTouchData: PieTouchData(
                                  enabled: true,
                                ),
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$totalVotes',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: nemsuBlue),
                                ),
                                const Text(
                                  'Votes',
                                  style: TextStyle(fontSize: 9, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Compact Legend List
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: deptTurnout.entries.toList().asMap().entries.map<Widget>((entry) {
                              int idx = entry.key;
                              var item = entry.value;
                              Color itemColor = colors[idx % colors.length];
                              double pct = totalVotes > 0 ? (item.value / totalVotes) * 100 : 0.0;

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: itemColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        item.key,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${item.value}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: nemsuBlue),
                                    ),
                                    const SizedBox(width: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: itemColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${pct.toStringAsFixed(0)}%',
                                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: itemColor),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
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

  Widget _buildBarChartCard(Map<String, int> positionVotes) {
    List<BarChartGroupData> barGroups = [];
    List<String> titles = [];
    int index = 0;
    int maxVote = 0;

    positionVotes.forEach((key, value) {
      if (value > maxVote) maxVote = value;
      // Abbreviate long names for bottom axis
      String shortTitle = key
          .replaceAll('Vice President', 'VP')
          .replaceAll('President', 'Pres.')
          .replaceAll('Representative', 'Rep.')
          .replaceAll('Secretary', 'Sec.')
          .replaceAll('Treasurer', 'Treas.')
          .replaceAll('Auditor', 'Aud.')
          .replaceAll('Senator', 'Sen.');
      titles.add(shortTitle);
      
      barGroups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: value.toDouble(),
              gradient: const LinearGradient(
                colors: [Color(0xFF003366), Color(0xFF2563EB)],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              width: 14,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxVote > 0 ? (maxVote * 1.15).toDouble() : 10,
                color: const Color(0xFFF1F5F9),
              ),
            ),
          ],
        )
      );
      index++;
    });

    double maxY = (maxVote > 0 ? maxVote * 1.2 : 10).toDouble();

    return Container(
      height: 290,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: nemsuBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.bar_chart_rounded, color: nemsuBlue, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Votes per Position',
                    style: TextStyle(fontWeight: FontWeight.bold, color: nemsuBlue, fontSize: 13),
                  ),
                ],
              ),
              const Text(
                'Hover/tap for details',
                style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: barGroups.isEmpty 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bar_chart_outlined, size: 36, color: Colors.grey.shade300),
                      const SizedBox(height: 6),
                      Text("No votes cast yet", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                )
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxY,
                    barTouchData: BarTouchData(
                      enabled: true,
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (group) => nemsuSlate,
                        tooltipPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          String fullPos = positionVotes.keys.elementAt(group.x.toInt());
                          return BarTooltipItem(
                            '$fullPos\n',
                            const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.normal),
                            children: [
                              TextSpan(
                                text: '${rod.toY.toInt()} Votes',
                                style: const TextStyle(color: nemsuGold, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            int idx = value.toInt();
                            if (idx < 0 || idx >= titles.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text(
                                titles[idx],
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 9, fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 26,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            if (value == meta.max || value == meta.min) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              value.toInt().toString(),
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9),
                              textAlign: TextAlign.left,
                            );
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) {
                        return const FlLine(
                          color: Color(0xFFF1F5F9),
                          strokeWidth: 1,
                        );
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: barGroups,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPICard(IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16), 
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10), 
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.5),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildTurnoutCard(double percentage) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.pie_chart_rounded, color: Color(0xFFB45309), size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${(percentage * 100).toStringAsFixed(1)}%',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFFB45309), letterSpacing: -0.5),
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Voter Turnout',
            style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6), 
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percentage.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTallyRow(String name, String party, int votes, double percentage, bool isLeading) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isLeading ? const Color(0xFFFFFDF5) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isLeading ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
          width: isLeading ? 1.2 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isLeading ? const Color(0xFFFEF3C7) : nemsuBlue.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLeading ? Icons.workspace_premium_rounded : Icons.person_rounded,
              color: isLeading ? const Color(0xFFB45309) : nemsuBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E293B)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isLeading) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFCD34D), width: 0.8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded, size: 10, color: Color(0xFFB45309)),
                            SizedBox(width: 2),
                            Text(
                              'LEADING',
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Color(0xFFB45309), letterSpacing: 0.3),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  party,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '$votes',
                      style: const TextStyle(fontWeight: FontWeight.w800, color: nemsuBlue, fontSize: 13),
                    ),
                    const Text(
                      ' votes',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(${(percentage * 100).toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isLeading ? const Color(0xFFB45309) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: percentage.clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isLeading ? const Color(0xFFD4AF37) : nemsuBlue,
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
}