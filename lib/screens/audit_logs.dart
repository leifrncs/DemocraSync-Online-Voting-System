import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../constants.dart';

class AuditLogs extends StatefulWidget {
  const AuditLogs({super.key});

  @override
  State<AuditLogs> createState() => _AuditLogsState();
}

class _AuditLogsState extends State<AuditLogs> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp.toDate());
  }

  Future<void> _exportLogsToCSV() async {
    setState(() => _isExporting = true);
    
    try {
      var snapshot = await FirebaseFirestore.instance.collection('audit_logs').orderBy('timestamp', descending: true).get();
      
      String escape(String input) => '"${input.replaceAll('"', '""')}"';
      String csvString = "Timestamp,Log Category,Event / Action,Severity / Type,Triggered By,Forensic Details\n";

      for (var doc in snapshot.docs) {
        var data = doc.data();
        String time = _formatTimestamp(data['timestamp'] as Timestamp?);
        String category = data['logCategory'] ?? 'UNKNOWN';
        String action = data['action'] ?? data['event'] ?? '';
        String severityOrType = data['severity'] ?? data['type'] ?? '';
        String user = data['user'] ?? 'System';
        String details = data['details'] != null ? data['details'].toString() : '';

        csvString += '="$time",${escape(category)},${escape(action)},${escape(severityOrType)},${escape(user)},${escape(details)}\n';
      }

      Uint8List bytes = Uint8List.fromList(utf8.encode(csvString));
      String fileName = 'DemocraSync_Audit_Logs_${DateTime.now().millisecondsSinceEpoch}.csv';
      
      await FileSaver.instance.saveFile(
        name: fileName,
        bytes: bytes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Audit Logs downloaded successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error generating CSV: $e'), backgroundColor: Colors.redAccent));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              const Expanded( 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Security & Audit Logs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: nemsuBlue)),
                    Text('System-wide accountability and forensic threat monitoring', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: nemsuBlue, elevation: 1),
                onPressed: _isExporting ? null : _exportLogsToCSV, 
                icon: _isExporting 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: nemsuBlue))
                  : const Icon(Icons.download_rounded, size: 18), 
                label: Text(_isExporting ? 'Exporting...' : 'Export (.CSV)')
              )
            ],
          ),
          const SizedBox(height: 24),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('audit_logs').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: nemsuBlue));
                }

                var allDocs = snapshot.data?.docs ?? [];
                var activityLogs = allDocs.where((d) => (d.data() as Map)['logCategory'] == 'ACTIVITY LOG').toList();
                var securityAlerts = allDocs.where((d) => (d.data() as Map)['logCategory'] == 'SECURITY ALERT').toList();
                
                int criticalCount = securityAlerts.where((d) => (d.data() as Map)['severity'] == 'Critical').length;
                int failedLogins = securityAlerts.where((d) => (d.data() as Map)['event']?.toString().contains('Failed Admin Login') ?? false).length;

                // 👉 THE FIX: Dynamic Status Logic
                String sysStatus = 'SECURE';
                Color sysColor = Colors.green;

                if (criticalCount > 3) {
                  sysStatus = 'AT RISK';
                  sysColor = Colors.red;
                } else if (failedLogins > 5) {
                  sysStatus = 'WARNING';
                  sysColor = Colors.orange;
                }

                Widget card1 = _buildLogKPI('Critical Alerts', criticalCount.toString(), criticalCount > 0 ? Colors.red : Colors.green);
                Widget card2 = _buildLogKPI('Failed Logins', failedLogins.toString(), failedLogins > 0 ? Colors.orange : Colors.green);
                Widget card3 = _buildLogKPI('Admin Actions', activityLogs.length.toString(), nemsuBlue);
                Widget card4 = _buildLogKPI('System Status', sysStatus, sysColor); // Now uses dynamic status

                return Column(
                  children: [
                    if (screenWidth > 800)
                      Row(
                        children: [
                          Expanded(child: card1), const SizedBox(width: 16),
                          Expanded(child: card2), const SizedBox(width: 16),
                          Expanded(child: card3), const SizedBox(width: 16),
                          Expanded(child: card4),
                        ],
                      )
                    else
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: card1), const SizedBox(width: 12),
                              Expanded(child: card2),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: card3), const SizedBox(width: 12),
                              Expanded(child: card4),
                            ],
                          ),
                        ],
                      ),
                    
                    const SizedBox(height: 30),
                    
                    TabBar(
                      controller: _tabController,
                      isScrollable: true, 
                      tabAlignment: TabAlignment.start, 
                      labelColor: nemsuBlue,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: nemsuGold,
                      indicatorWeight: 3,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 16), 
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.history_rounded),
                          child: Text('Action Ledger (${activityLogs.length})', 
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)
                          ),
                        ),
                        Tab(
                          icon: const Icon(Icons.security_rounded),
                          child: Text('Threat Alerts (${securityAlerts.length})', 
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                        ),
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildActivityLedger(activityLogs),
                            _buildSecurityAlerts(securityAlerts),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogKPI(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildActivityLedger(List<QueryDocumentSnapshot> logs) {
    if (logs.isEmpty) return const Center(child: Text("No actions logged yet.", style: TextStyle(color: Colors.grey)));

    return ListView.separated(
      itemCount: logs.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final data = logs[index].data() as Map<String, dynamic>;
        final details = data['details'] as Map<String, dynamic>? ?? {};

        return ExpansionTile(
          leading: const CircleAvatar(backgroundColor: Color(0xFFF0F4F8), child: Icon(Icons.code_rounded, color: nemsuBlue, size: 18)),
          title: Text(data['action'] ?? 'Unknown Action', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: nemsuBlue)),
          subtitle: Text('${_formatTimestamp(data['timestamp'] as Timestamp?)} • User: ${data['user']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          trailing: Chip(
            label: Text(data['type'] ?? '', style: const TextStyle(fontSize: 10, color: nemsuBlue, fontWeight: FontWeight.bold)),
            backgroundColor: nemsuGold.withOpacity(0.3),
            side: BorderSide.none,
          ),
          childrenPadding: const EdgeInsets.all(16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: details.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontFamily: 'Courier', fontSize: 12, color: Colors.greenAccent),
                        children: [
                          TextSpan(text: '${e.key}: ', style: const TextStyle(color: Colors.white70)),
                          TextSpan(text: e.value.toString()),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSecurityAlerts(List<QueryDocumentSnapshot> alerts) {
    if (alerts.isEmpty) return const Center(child: Text("No security threats detected.", style: TextStyle(color: Colors.grey)));

    return ListView.separated(
      itemCount: alerts.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final data = alerts[index].data() as Map<String, dynamic>;
        final details = data['details'] as Map<String, dynamic>? ?? {};
        
        // 👉 THE FIX: Handle 'Warning' severity correctly for the icons and colors
        Color severityColor = data['severity'] == 'Critical' 
            ? Colors.red 
            : ((data['severity'] == 'High' || data['severity'] == 'Warning') ? Colors.orange : Colors.green);
            
        IconData severityIcon = data['severity'] == 'Critical' 
            ? Icons.gpp_bad_rounded 
            : ((data['severity'] == 'High' || data['severity'] == 'Warning') ? Icons.warning_rounded : Icons.gpp_good_rounded);

        return ExpansionTile(
          leading: CircleAvatar(backgroundColor: severityColor.withOpacity(0.1), child: Icon(severityIcon, color: severityColor, size: 20)),
          title: Text(data['event'] ?? 'Unknown Event', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: severityColor)),
          subtitle: Text('Timestamp: ${_formatTimestamp(data['timestamp'] as Timestamp?)}'),
          trailing: Text(data['severity']?.toUpperCase() ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: severityColor, fontSize: 12)),
          childrenPadding: const EdgeInsets.all(16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: severityColor.withOpacity(0.05), 
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: severityColor.withOpacity(0.3))
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: details.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 140, child: Text(e.key.replaceAll('_', ' '), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 12))),
                        Expanded(child: Text(e.value.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87))),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}