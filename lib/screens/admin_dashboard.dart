import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart'; 
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../constants.dart';
import 'login.dart'; 
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

      int totalVoters = votersSnap.docs.length;
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
                      await FirebaseFirestore.instance.collection('settings').doc('election').set({'isActive': value}, SetOptions(merge: true));
                      
                      // Write to Audit Logs
                      await FirebaseFirestore.instance.collection('audit_logs').add({
                        'timestamp': FieldValue.serverTimestamp(),
                        'logCategory': 'ACTIVITY LOG',
                        'action': 'Election Status Toggled',
                        'user': 'Admin_Primary',
                        'type': 'Configuration',
                        'details': {
                          'Target': 'settings/election',
                          'Payload': '{"isActive": $value}',
                        },
                      });

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value ? 'Voting is OPEN for students.' : 'Voting is CLOSED for students.'), backgroundColor: value ? Colors.green : Colors.redAccent));
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
                    _buildNavItem(Icons.dashboard_rounded, 0),
                    const SizedBox(height: 20),
                    _buildNavItem(Icons.settings_suggest_rounded, 1), 
                    const SizedBox(height: 20),
                    _buildNavItem(Icons.how_to_vote_rounded, 2),     
                    const SizedBox(height: 20),
                    _buildNavItem(Icons.people_rounded, 3),          
                    const SizedBox(height: 20),
                    _buildNavItem(Icons.assignment_rounded, 4),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen())),
                      tooltip: 'Logout',
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

  Widget _buildNavItem(IconData icon, int index) {
    bool isActive = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: isActive ? nemsuGold : Colors.transparent, borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: isActive ? nemsuBlue : Colors.white70, size: 24),
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

            int registeredVoters = voters.length;
            int totalVotes = 0;
            int pendingVerifications = 0;
            Map<String, int> deptTurnout = {};

            for (var doc in voters) {
              var data = doc.data() as Map<String, dynamic>;
              if (data['status'] == 'Pending' || data['status'] == 'Pending Verification') {
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

            Widget card1 = _buildKPICard(Icons.how_to_reg, 'Registered Voters', registeredVoters.toString(), nemsuBlue);
            Widget card2 = _buildKPICard(Icons.how_to_vote, 'Total Votes', totalVotes.toString(), Colors.purple);
            Widget card3 = _buildTurnoutCard(turnoutPercentage);
            Widget card4 = _buildKPICard(Icons.warning_amber_rounded, 'Pending Verifications', pendingVerifications.toString(), Colors.redAccent);

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Election Overview', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: nemsuBlue)),
                  const Text('Live Real-Time Data', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),

                  // 👉 THE FIX: IntrinsicHeight makes all cards perfectly matched in height!
                  if (screenWidth > 900)
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: card1), const SizedBox(width: 16),
                          Expanded(child: card2), const SizedBox(width: 16),
                          Expanded(child: card3), const SizedBox(width: 16),
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
                              Expanded(child: card1), const SizedBox(width: 12),
                              Expanded(child: card2),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(child: card3), const SizedBox(width: 12),
                              Expanded(child: card4),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 32),

                  if (screenWidth > 800) 
                    Row(
                      children: [
                        Expanded(child: _buildPieChartCard(deptTurnout)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildBarChartCard(chartPositionVotes)),
                      ],
                    )
                  else ...[
                    _buildPieChartCard(deptTurnout),
                    const SizedBox(height: 16),
                    _buildBarChartCard(chartPositionVotes),
                  ],
                  
                  const SizedBox(height: 32),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)]),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            const Text('Live Tally Board', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: nemsuBlue)),
                            Container(
                              constraints: const BoxConstraints(maxWidth: 300), 
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F4F8),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  value: _selectedTallyScope,
                                  icon: const Icon(Icons.arrow_drop_down, color: nemsuBlue),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: nemsuBlue),
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
                        const Divider(height: 30, color: nemsuGold, thickness: 2),

                        if (scopedCandidates.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(20.0),
                            child: Center(child: Text("No candidates found for this department.", style: TextStyle(color: Colors.grey))),
                          )
                        else
                          for (var entry in scopedCandidates.entries)
                            Builder(
                              builder: (context) {
                                int totalPosVotes = entry.value.fold(0, (sum, item) => sum + ((item['voteCount'] as num?)?.toInt() ?? 0));
                                
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                                      child: Text(entry.key, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87)),
                                    ),
                                    for (var candidate in entry.value)
                                      Builder(
                                        builder: (context) {
                                          String name = candidate['name']?.toString() ?? 'Unknown';
                                          String party = candidate['party']?.toString() ?? 'Independent';
                                          int cVotes = (candidate['voteCount'] as num?)?.toInt() ?? 0;
                                          double pct = totalPosVotes > 0 ? cVotes / totalPosVotes : 0.0;
                                          
                                          return _buildTallyRow(name, party, cVotes, pct);
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

  Widget _buildPieChartCard(Map<String, int> deptTurnout) {
    List<Color> colors = [nemsuBlue, nemsuGold, Colors.purple, Colors.teal, Colors.orange];
    int colorIndex = 0;

    List<PieChartSectionData> sections = [];
    for (var entry in deptTurnout.entries) {
      final color = colors[colorIndex % colors.length];
      colorIndex++;
      sections.add(
        PieChartSectionData(
          color: color,
          value: entry.value.toDouble(),
          title: entry.value.toString(),
          radius: 50,
          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        )
      );
    }

    return Container(
      height: 420, 
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Turnout by Department', style: TextStyle(fontWeight: FontWeight.bold, color: nemsuBlue, fontSize: 14)),
          Expanded(
            child: sections.isEmpty 
              ? const Center(child: Text("No votes cast yet", style: TextStyle(color: Colors.grey)))
              : PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 40,
                    sectionsSpace: 2,
                  ),
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 60,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: deptTurnout.keys.toList().asMap().entries.map<Widget>((e) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.circle, color: colors[e.key % colors.length], size: 10),
                      const SizedBox(width: 4),
                      Text(e.value, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ],
                  );
                }).toList(),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildBarChartCard(Map<String, int> positionVotes) {
    List<BarChartGroupData> barGroups = [];
    List<String> titles = [];
    int index = 0;

    positionVotes.forEach((key, value) {
      titles.add(key.replaceAll(' ', '\n')); 
      barGroups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(toY: value.toDouble(), color: nemsuBlue, width: 16, borderRadius: BorderRadius.circular(4)),
          ],
        )
      );
      index++;
    });

    return Container(
      height: 420, 
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Votes per Position', style: TextStyle(fontWeight: FontWeight.bold, color: nemsuBlue, fontSize: 14)),
          const SizedBox(height: 20),
          Expanded(
            child: barGroups.isEmpty 
              ? const Center(child: Text("No votes cast yet", style: TextStyle(color: Colors.grey)))
              : BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: positionVotes.values.fold(0, (max, v) => v > max ? v : max).toDouble() + 5, 
                    barTouchData: BarTouchData(enabled: false),
                    titlesData: FlTitlesData(
                      show: true,
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            if (value.toInt() >= titles.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(titles[value.toInt()], style: const TextStyle(color: Colors.grey, fontSize: 8), textAlign: TextAlign.center),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: barGroups,
                  ),
                ),
          ),
        ],
      ),
    );
  }

  // 👉 THE FIX: Simplified internal column layout for smooth stretching
  Widget _buildKPICard(IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16), 
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
          const SizedBox(height: 12), 
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color))),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildTurnoutCard(double percentage) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: nemsuGold.withOpacity(0.2), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.data_usage, color: nemsuGold, size: 20)),
          const SizedBox(height: 12),
          FittedBox(fit: BoxFit.scaleDown, child: Text('${(percentage * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: nemsuGold))),
          const SizedBox(height: 4),
          const Text('Voter Turnout', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8), 
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: percentage, minHeight: 6, backgroundColor: Colors.grey.shade200, valueColor: const AlwaysStoppedAnimation<Color>(nemsuGold)))
        ],
      ),
    );
  }

  Widget _buildTallyRow(String name, String party, int votes, double percentage) {
    return Card(
      elevation: 0, color: const Color(0xFFF8F9FA), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            const CircleAvatar(backgroundColor: nemsuGold, child: Icon(Icons.person, color: nemsuBlue)),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(party, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('$votes Votes', style: const TextStyle(fontWeight: FontWeight.bold, color: nemsuBlue)),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(value: percentage, minHeight: 8, backgroundColor: Colors.grey.shade300, valueColor: const AlwaysStoppedAnimation<Color>(nemsuBlue)),
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