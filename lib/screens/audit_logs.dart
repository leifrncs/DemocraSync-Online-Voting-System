import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_saver/file_saver.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../constants.dart';

class AuditLogs extends StatefulWidget {
  const AuditLogs({super.key});

  @override
  State<AuditLogs> createState() => _AuditLogsState();
}

class _AuditLogsState extends State<AuditLogs> {
  // --- SEARCH & FILTER STATES ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedSeverity = 'All Severities';
  String _sortBy = 'Newest First';
  bool? _userSelectedTableView;
  bool _isExporting = false;

  // --- PAGINATION STATES ---
  int _currentPage = 0;
  int _pageSize = 15;
  static const List<int> _pageSizeOptions = [15, 25, 50, 100];

  static const List<String> _categoryOptions = [
    'All',
    'Activity Logs',
    'AI OCR Audits',
    'Security Threats',
  ];

  static const List<String> _severityOptions = [
    'All Severities',
    'Critical',
    'High / Warning',
    'Normal / Info',
  ];

  static const List<String> _sortOptions = [
    'Newest First',
    'Oldest First',
    'Severity (High First)',
    'Action (A-Z)',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp.toDate());
  }

  String _formatRelativeTime(Timestamp? timestamp) {
    if (timestamp == null) return 'Just now';
    final now = DateTime.now();
    final difference = now.difference(timestamp.toDate());

    if (difference.inSeconds < 60) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return DateFormat('MMM dd, yyyy').format(timestamp.toDate());
  }

  Color _getCategoryColor(String category) {
    switch (category.toUpperCase()) {
      case 'SECURITY ALERT':
        return const Color(0xFFEF4444);
      case 'AI_OCR_AUDIT':
        return const Color(0xFF8B5CF6);
      case 'ACTIVITY LOG':
        return const Color(0xFF2563EB);
      default:
        return nemsuBlue;
    }
  }

  Color _getSeverityColor(String severity) {
    final s = severity.toLowerCase();
    if (s.contains('crit')) return const Color(0xFFDC2626);
    if (s.contains('warn') || s.contains('high')) return const Color(0xFFD97706);
    if (s.contains('info')) return const Color(0xFF2563EB);
    return const Color(0xFF10B981);
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'SECURITY ALERT':
        return Icons.security_rounded;
      case 'AI_OCR_AUDIT':
        return Icons.document_scanner_rounded;
      case 'ACTIVITY LOG':
        return Icons.history_rounded;
      default:
        return Icons.list_alt_rounded;
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Audit Logs exported successfully!'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating CSV: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  void _showForensicInspector(BuildContext context, Map<String, dynamic> data) {
    final details = data['details'] is Map<String, dynamic> ? data['details'] as Map<String, dynamic> : {};
    final String action = data['action'] ?? data['event'] ?? 'Unknown Action';
    final String category = data['logCategory'] ?? 'ACTIVITY LOG';
    final String severity = data['severity'] ?? data['type'] ?? 'Normal';
    final String user = data['user'] ?? 'System';
    final String timestampStr = _formatTimestamp(data['timestamp'] as Timestamp?);
    final Color categoryColor = _getCategoryColor(category);
    final Color severityColor = _getSeverityColor(severity);

    Widget buildContent() {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: categoryColor.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: categoryColor.withValues(alpha: 0.15),
                  radius: 20,
                  child: Icon(_getCategoryIcon(category), color: categoryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: categoryColor,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: categoryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              category,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: categoryColor),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: severityColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              severity.toUpperCase(),
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: severityColor),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Metadata Grid
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TRIGGERED BY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.account_circle_outlined, size: 16, color: nemsuBlue),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              user,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: nemsuBlue),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('TIMESTAMP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF64748B)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              timestampStr,
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Forensics Key-Value breakdown
          const Text('FORENSIC PAYLOAD & CONTEXT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
          const SizedBox(height: 8),

          if (details.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text('No extended forensic properties recorded for this event.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: details.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontFamily: 'Courier', fontSize: 12, color: Color(0xFF38BDF8)),
                        children: [
                          TextSpan(text: '${e.key}: ', style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                          TextSpan(
                            text: e.value.toString(),
                            style: TextStyle(
                              color: e.value.toString() == 'Critical' || e.value.toString() == 'Rejected'
                                  ? const Color(0xFFF87171)
                                  : (e.value.toString() == 'Verified' ? const Color(0xFF4ADE80) : Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          const SizedBox(height: 20),

          // Action Toolbar
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: nemsuBlue,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final jsonString = const JsonEncoder.withIndent('  ').convert(data);
                  Clipboard.setData(ClipboardData(text: jsonString));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Forensic JSON copied to clipboard!'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: nemsuBlue,
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 16),
                label: const Text('Copy JSON'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: nemsuBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
        ],
      );
    }

    final double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth >= 700) {
      showDialog(
        context: context,
        builder: (context) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 620),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(child: buildContent()),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                ),
                buildContent(),
              ],
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('audit_logs').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: nemsuBlue));
        }

        List<QueryDocumentSnapshot> allDocs = snapshot.hasData ? snapshot.data!.docs : [];

        // KPI Calculations
        int totalEvents = allDocs.length;
        int activityCount = allDocs.where((d) {
          final cat = (d.data() as Map<String, dynamic>)['logCategory'];
          return cat == 'ACTIVITY LOG';
        }).length;
        int threatAlertsCount = allDocs.where((d) {
          final cat = (d.data() as Map<String, dynamic>)['logCategory'];
          return cat == 'SECURITY ALERT';
        }).length;
        int criticalCount = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final cat = data['logCategory'];
          final sev = (data['severity'] ?? data['type'] ?? '').toString();
          return cat == 'SECURITY ALERT' && sev.toLowerCase() == 'critical';
        }).length;
        int failedLogins = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final event = (data['event'] ?? data['action'] ?? '').toString();
          return event.contains('Failed Admin Login');
        }).length;

        // Dynamic System Status
        String sysStatus = 'SECURE';
        Color sysColor = const Color(0xFF10B981);
        IconData sysIcon = Icons.verified_user_rounded;

        if (criticalCount > 3) {
          sysStatus = 'AT RISK';
          sysColor = const Color(0xFFDC2626);
          sysIcon = Icons.gpp_bad_rounded;
        } else if (failedLogins > 5 || criticalCount > 0) {
          sysStatus = 'WARNING';
          sysColor = const Color(0xFFD97706);
          sysIcon = Icons.warning_rounded;
        }

        // --- FILTERING ---
        List<QueryDocumentSnapshot> filteredDocs = allDocs;

        // Filter by Category
        if (_selectedCategory != 'All') {
          filteredDocs = filteredDocs.where((doc) {
            final cat = (doc.data() as Map<String, dynamic>)['logCategory'] ?? '';
            if (_selectedCategory == 'Activity Logs') return cat == 'ACTIVITY LOG';
            if (_selectedCategory == 'AI OCR Audits') return cat == 'AI_OCR_AUDIT';
            if (_selectedCategory == 'Security Threats') return cat == 'SECURITY ALERT';
            return true;
          }).toList();
        }

        // Filter by Severity
        if (_selectedSeverity != 'All Severities') {
          filteredDocs = filteredDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final sev = (data['severity'] ?? data['type'] ?? '').toString().toLowerCase();
            if (_selectedSeverity == 'Critical') return sev.contains('crit');
            if (_selectedSeverity == 'High / Warning') return sev.contains('warn') || sev.contains('high');
            if (_selectedSeverity == 'Normal / Info') return sev.contains('norm') || sev.contains('info') || sev.isEmpty;
            return true;
          }).toList();
        }

        // Filter by Search Query
        if (_searchQuery.trim().isNotEmpty) {
          final q = _searchQuery.trim().toLowerCase();
          filteredDocs = filteredDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final action = (data['action'] ?? data['event'] ?? '').toString().toLowerCase();
            final user = (data['user'] ?? '').toString().toLowerCase();
            final cat = (data['logCategory'] ?? '').toString().toLowerCase();
            final sev = (data['severity'] ?? data['type'] ?? '').toString().toLowerCase();
            final details = (data['details'] ?? '').toString().toLowerCase();
            return action.contains(q) || user.contains(q) || cat.contains(q) || sev.contains(q) || details.contains(q);
          }).toList();
        }

        // --- SORTING ---
        filteredDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          if (_sortBy == 'Action (A-Z)') {
            final aAct = (aData['action'] ?? aData['event'] ?? '').toString();
            final bAct = (bData['action'] ?? bData['event'] ?? '').toString();
            return aAct.compareTo(bAct);
          }

          if (_sortBy == 'Oldest First') {
            final aTs = aData['timestamp'];
            final bTs = bData['timestamp'];
            if (aTs is Timestamp && bTs is Timestamp) {
              return aTs.compareTo(bTs);
            }
            return 0;
          }

          if (_sortBy == 'Severity (High First)') {
            int getSeverityWeight(Map<String, dynamic> data) {
              final s = (data['severity'] ?? data['type'] ?? '').toString().toLowerCase();
              if (s.contains('crit')) return 4;
              if (s.contains('high')) return 3;
              if (s.contains('warn')) return 2;
              return 1;
            }
            int diff = getSeverityWeight(bData).compareTo(getSeverityWeight(aData));
            if (diff != 0) return diff;
          }

          // Default: Newest First
          final aTs = aData['timestamp'];
          final bTs = bData['timestamp'];
          if (aTs is Timestamp && bTs is Timestamp) {
            return bTs.compareTo(aTs);
          }
          return 0;
        });

        // --- PAGINATION CALCULATIONS ---
        int totalCount = filteredDocs.length;
        int totalPages = (totalCount / _pageSize).ceil();
        if (_currentPage >= totalPages && totalPages > 0) {
          _currentPage = totalPages - 1;
        }

        int startIdx = _currentPage * _pageSize;
        int endIdx = (startIdx + _pageSize) > totalCount ? totalCount : (startIdx + _pageSize);
        List<QueryDocumentSnapshot> pageLogs = (startIdx < totalCount) ? filteredDocs.sublist(startIdx, endIdx) : [];

        return LayoutBuilder(
          builder: (context, constraints) {
            bool isMobile = constraints.maxWidth < 700;
            bool isTableView = _userSelectedTableView ?? !isMobile;

            return Column(
              children: [
                // --- TOP INTEGRATED HEADER & ACTION BANNER ---
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Security & Forensic Audit Logs',
                                  style: TextStyle(
                                    fontSize: isMobile ? 20 : 23,
                                    fontWeight: FontWeight.w800,
                                    color: nemsuBlue,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'System-wide accountability, administrative action trails, and threat monitoring',
                                  style: TextStyle(fontSize: isMobile ? 12 : 13, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),

                          // View Toggle Button Group
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              children: [
                                Tooltip(
                                  message: 'Data Table View',
                                  child: InkWell(
                                    onTap: () => setState(() => _userSelectedTableView = true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: isTableView ? nemsuBlue : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(Icons.table_chart_rounded, size: 18, color: isTableView ? Colors.white : const Color(0xFF64748B)),
                                    ),
                                  ),
                                ),
                                Tooltip(
                                  message: 'Card Feed View',
                                  child: InkWell(
                                    onTap: () => setState(() => _userSelectedTableView = false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: !isTableView ? nemsuBlue : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(Icons.grid_view_rounded, size: 18, color: !isTableView ? Colors.white : const Color(0xFF64748B)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Export (.CSV) Button
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: nemsuBlue,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16, vertical: isMobile ? 10 : 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: _isExporting ? null : _exportLogsToCSV,
                            icon: _isExporting
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.download_rounded, size: 18, color: nemsuGold),
                            label: Text(
                              _isExporting ? 'Exporting...' : (isMobile ? 'CSV' : 'Export (.CSV)'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // KPI Summary Bar
                      _buildKpiSummaryBar(
                        totalEvents: totalEvents,
                        activityCount: activityCount,
                        threatAlertsCount: threatAlertsCount,
                        sysStatus: sysStatus,
                        sysColor: sysColor,
                        sysIcon: sysIcon,
                        isMobile: isMobile,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // --- INTEGRATED TOOLBAR: SEARCH & CATEGORY CHIPS & SEVERITY & SORT ---
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search and Dropdowns Row
                      isMobile
                          ? SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildSearchField(width: 220),
                                  const SizedBox(width: 8),
                                  _buildSeverityDropdown(),
                                  const SizedBox(width: 8),
                                  _buildSortDropdown(),
                                ],
                              ),
                            )
                          : Row(
                              children: [
                                Expanded(child: _buildSearchField(width: null)),
                                const SizedBox(width: 10),
                                _buildSeverityDropdown(),
                                const SizedBox(width: 10),
                                _buildSortDropdown(),
                              ],
                            ),
                      const SizedBox(height: 8),

                      // Category Filter Chips
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _categoryOptions.map((cat) {
                            bool isSelected = _selectedCategory == cat;
                            int count;
                            if (cat == 'All') {
                              count = allDocs.length;
                            } else if (cat == 'Activity Logs') {
                              count = activityCount;
                            } else if (cat == 'AI OCR Audits') {
                              count = allDocs.where((d) => (d.data() as Map)['logCategory'] == 'AI_OCR_AUDIT').length;
                            } else {
                              count = threatAlertsCount;
                            }

                            return Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(cat, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFE2E8F0),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '$count',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? Colors.white : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                selected: isSelected,
                                onSelected: (val) {
                                  if (val) {
                                    setState(() {
                                      _selectedCategory = cat;
                                      _currentPage = 0;
                                    });
                                  }
                                },
                                selectedColor: nemsuBlue,
                                backgroundColor: const Color(0xFFF1F5F9),
                                labelStyle: TextStyle(color: isSelected ? Colors.white : const Color(0xFF334155)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(color: isSelected ? nemsuBlue : const Color(0xFFE2E8F0)),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // --- CONTENT AREA (TABLE OR CARD FEED) ---
                Expanded(
                  child: Container(
                    color: nemsuBackground,
                    child: filteredDocs.isEmpty
                        ? _buildEmptyState()
                        : (isTableView ? _buildTableView(pageLogs, isMobile) : _buildCardFeedView(pageLogs, isMobile)),
                  ),
                ),

                // --- PAGINATION CONTROLS FOOTER ---
                _buildPaginationFooter(
                  totalCount: totalCount,
                  totalPages: totalPages,
                  startIdx: startIdx,
                  endIdx: endIdx,
                  isMobile: isMobile,
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- KPI SUMMARY BAR COMPONENT ---
  Widget _buildKpiSummaryBar({
    required int totalEvents,
    required int activityCount,
    required int threatAlertsCount,
    required String sysStatus,
    required Color sysColor,
    required IconData sysIcon,
    required bool isMobile,
  }) {
    if (isMobile) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                _buildKpiItem(
                  Icons.history_rounded,
                  'Total Events',
                  '$totalEvents',
                  nemsuBlue,
                  'Total audit logs, forensic trails, and security alerts recorded.',
                ),
                const SizedBox(width: 8),
                _buildKpiDivider(),
                const SizedBox(width: 8),
                _buildKpiItem(
                  Icons.admin_panel_settings_rounded,
                  'Admin Actions',
                  '$activityCount',
                  const Color(0xFF2563EB),
                  'System administration operations and configurations logged.',
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(height: 1, color: Color(0xFFE2E8F0)),
            ),
            Row(
              children: [
                _buildKpiItem(
                  Icons.security_rounded,
                  'Threat Alerts',
                  '$threatAlertsCount',
                  const Color(0xFFD97706),
                  'Detected security warnings, OCR anomalies, and failed login threats.',
                ),
                const SizedBox(width: 8),
                _buildKpiDivider(),
                const SizedBox(width: 8),
                _buildKpiItem(
                  sysIcon,
                  'System Health',
                  sysStatus,
                  sysColor,
                  'Current threat posture evaluated from critical incidents and failed logins.',
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          _buildKpiItem(
            Icons.history_rounded,
            'Total Events',
            '$totalEvents',
            nemsuBlue,
            'Total audit logs, forensic trails, and security alerts recorded in DemocraSync.',
          ),
          const SizedBox(width: 14),
          _buildKpiDivider(),
          const SizedBox(width: 14),
          _buildKpiItem(
            Icons.admin_panel_settings_rounded,
            'Admin Actions',
            '$activityCount',
            const Color(0xFF2563EB),
            'System administration operations, candidate edits, and report exports.',
          ),
          const SizedBox(width: 14),
          _buildKpiDivider(),
          const SizedBox(width: 14),
          _buildKpiItem(
            Icons.security_rounded,
            'Threat Alerts',
            '$threatAlertsCount',
            const Color(0xFFD97706),
            'Security incidents, forensic discrepancies, and unauthorized attempts.',
          ),
          const SizedBox(width: 14),
          _buildKpiDivider(),
          const SizedBox(width: 14),
          _buildKpiItem(
            sysIcon,
            'System Health',
            sysStatus,
            sysColor,
            'Dynamic health posture: SECURE, WARNING (failed logins), or AT RISK (critical events).',
          ),
        ],
      ),
    );
  }

  Widget _buildKpiItem(IconData icon, String label, String value, Color color, String description) {
    return Expanded(
      child: Tooltip(
        message: description,
        waitDuration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: nemsuSlate,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w500),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.2),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKpiDivider() {
    return Container(width: 1, height: 32, color: const Color(0xFFE2E8F0));
  }

  // --- TOOLBAR CONTROLS ---
  Widget _buildSearchField({double? width}) {
    final field = SizedBox(
      height: 38,
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
            _currentPage = 0;
          });
        },
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search logs by event, admin, details, or IP...',
          hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 15),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _currentPage = 0;
                    });
                  },
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide.none),
        ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: field);
    }
    return field;
  }

  Widget _buildSeverityDropdown() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _severityOptions.contains(_selectedSeverity) ? _selectedSeverity : 'All Severities',
          icon: const Icon(Icons.shield_outlined, size: 15, color: nemsuBlue),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: nemsuBlue),
          items: _severityOptions.map((sev) {
            return DropdownMenuItem(
              value: sev,
              child: Text(sev, style: const TextStyle(fontSize: 12)),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _selectedSeverity = val;
                _currentPage = 0;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortOptions.contains(_sortBy) ? _sortBy : 'Newest First',
          icon: const Icon(Icons.sort_rounded, size: 15, color: nemsuBlue),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: nemsuBlue),
          items: _sortOptions.map((opt) {
            return DropdownMenuItem(
              value: opt,
              child: Text(opt, style: const TextStyle(fontSize: 12)),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) {
              setState(() {
                _sortBy = val;
                _currentPage = 0;
              });
            }
          },
        ),
      ),
    );
  }

  // --- EMPTY STATE VIEW ---
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.history_toggle_off_rounded, size: 48, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Audit Records Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: nemsuBlue),
            ),
            const SizedBox(height: 6),
            const Text(
              'No audit log entries matched your current search filters or category selections.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
            if (_searchQuery.isNotEmpty || _selectedCategory != 'All' || _selectedSeverity != 'All Severities') ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: nemsuBlue,
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _selectedCategory = 'All';
                    _selectedSeverity = 'All Severities';
                    _currentPage = 0;
                  });
                },
                icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                label: const Text('Reset All Filters'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- DATA TABLE VIEW (DESKTOP FIRST) ---
  Widget _buildTableView(List<QueryDocumentSnapshot> docs, bool isMobile) {
    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, tableConstraints) {
            double availableWidth = tableConstraints.maxWidth;
            double tableWidth = availableWidth > 1150 ? availableWidth : 1150;
            double columnSpacing = availableWidth > 1450 ? 32.0 : (availableWidth > 1250 ? 22.0 : 16.0);

            return Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: tableWidth),
                        child: DataTable(
                          headingRowHeight: 48,
                          dataRowMinHeight: 56,
                          dataRowMaxHeight: 64,
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                          horizontalMargin: 20,
                          columnSpacing: columnSpacing,
                          columns: const [
                            DataColumn(label: Text('TIMESTAMP', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.3))),
                            DataColumn(label: Text('CATEGORY', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.3))),
                            DataColumn(label: Text('ACTION / EVENT', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.3))),
                            DataColumn(label: Text('TRIGGERED BY', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.3))),
                            DataColumn(label: Text('SEVERITY / STATUS', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.3))),
                            DataColumn(label: Text('FORENSICS', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF475569), letterSpacing: 0.3))),
                          ],
                          rows: docs.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final String time = _formatTimestamp(data['timestamp'] as Timestamp?);
                            final String category = data['logCategory'] ?? 'ACTIVITY LOG';
                            final String action = data['action'] ?? data['event'] ?? 'Unknown Action';
                            final String user = data['user'] ?? 'System';
                            final String severity = data['severity'] ?? data['type'] ?? 'Normal';
                            final Color categoryColor = _getCategoryColor(category);
                            final Color severityColor = _getSeverityColor(severity);

                            return DataRow(
                              cells: [
                                // Timestamp
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(time, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                                      const SizedBox(height: 1),
                                      Text(_formatRelativeTime(data['timestamp'] as Timestamp?), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),

                                // Category
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: categoryColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: categoryColor.withValues(alpha: 0.25)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(_getCategoryIcon(category), size: 13, color: categoryColor),
                                        const SizedBox(width: 5),
                                        Text(category, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: categoryColor)),
                                      ],
                                    ),
                                  ),
                                ),

                                // Action / Event
                                DataCell(
                                  ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: availableWidth > 1400 ? 380 : 280),
                                    child: Tooltip(
                                      message: action,
                                      waitDuration: const Duration(milliseconds: 300),
                                      child: Text(
                                        action,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: nemsuBlue),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),

                                // Triggered By User
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: nemsuBlue.withValues(alpha: 0.1),
                                        child: const Icon(Icons.person_rounded, size: 14, color: nemsuBlue),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(user, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                                    ],
                                  ),
                                ),

                                // Severity / Status
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: severityColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: severityColor.withValues(alpha: 0.25)),
                                    ),
                                    child: Text(
                                      severity.toUpperCase(),
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: severityColor, letterSpacing: 0.3),
                                    ),
                                  ),
                                ),

                                // Forensics Button
                                DataCell(
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      backgroundColor: Colors.white,
                                      foregroundColor: nemsuBlue,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () => _showForensicInspector(context, data),
                                    icon: const Icon(Icons.visibility_rounded, size: 14, color: nemsuBlue),
                                    label: const Text('Inspect', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- CARD FEED VIEW (MOBILE FIRST & COMPACT) ---
  Widget _buildCardFeedView(List<QueryDocumentSnapshot> docs, bool isMobile) {
    return ListView.separated(
      padding: EdgeInsets.all(isMobile ? 12 : 20),
      itemCount: docs.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final data = docs[index].data() as Map<String, dynamic>;
        final String action = data['action'] ?? data['event'] ?? 'Unknown Action';
        final String category = data['logCategory'] ?? 'ACTIVITY LOG';
        final String user = data['user'] ?? 'System';
        final String severity = data['severity'] ?? data['type'] ?? 'Normal';
        final String time = _formatTimestamp(data['timestamp'] as Timestamp?);
        final String relTime = _formatRelativeTime(data['timestamp'] as Timestamp?);
        final details = data['details'] is Map<String, dynamic> ? data['details'] as Map<String, dynamic> : {};
        final Color categoryColor = _getCategoryColor(category);
        final Color severityColor = _getSeverityColor(severity);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Accent Border
              Container(width: 4, height: 90, color: severityColor),

              // Card Body
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Meta Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: categoryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(category, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: categoryColor)),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: severityColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(severity.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: severityColor)),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 4),
                              Text('$relTime ($time)', style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Action Title
                      Text(
                        action,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: nemsuBlue),
                      ),
                      const SizedBox(height: 4),

                      // User & Details Quick Pill Row
                      Row(
                        children: [
                          const Icon(Icons.person_rounded, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text('By: $user', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                          const Spacer(),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => _showForensicInspector(context, data),
                            icon: const Icon(Icons.open_in_new_rounded, size: 13, color: nemsuBlue),
                            label: const Text('Inspect Forensics', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: nemsuBlue)),
                          ),
                        ],
                      ),

                      // Inline details preview if available
                      if (details.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: details.entries.take(3).map((e) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                '${e.key}: ${e.value}',
                                style: const TextStyle(fontSize: 10.5, fontFamily: 'Courier', color: Color(0xFF334155)),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- PAGINATION FOOTER COMPONENT ---
  Widget _buildPaginationFooter({
    required int totalCount,
    required int totalPages,
    required int startIdx,
    required int endIdx,
    required bool isMobile,
  }) {
    if (totalCount == 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: 10),
      child: isMobile
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${startIdx + 1}-$endIdx of $totalCount',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                      visualDensity: VisualDensity.compact,
                    ),
                    Text(
                      'Page ${_currentPage + 1}/$totalPages',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: nemsuBlue),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Text(
                  'Showing ${startIdx + 1} - $endIdx of $totalCount audit logs',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                const Spacer(),

                // Page Size Selector
                Row(
                  children: [
                    const Text('Rows per page:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(width: 8),
                    Container(
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _pageSizeOptions.contains(_pageSize) ? _pageSize : 15,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: nemsuBlue),
                          items: _pageSizeOptions.map((sz) {
                            return DropdownMenuItem(value: sz, child: Text('$sz'));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _pageSize = val;
                                _currentPage = 0;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),

                // Page Navigator
                Text(
                  'Page ${_currentPage + 1} of $totalPages',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: nemsuBlue),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chevron_left_rounded, size: 16),
                      Text('Prev', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Next', style: TextStyle(fontSize: 12)),
                      Icon(Icons.chevron_right_rounded, size: 16),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}