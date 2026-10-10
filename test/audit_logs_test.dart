import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Audit Logs Logic & Filtering Tests', () {
    test('Calculates System Health correctly based on critical threats and failed logins', () {
      String calculateSystemHealth(int criticalCount, int failedLogins) {
        if (criticalCount > 3) return 'AT RISK';
        if (failedLogins > 5 || criticalCount > 0) return 'WARNING';
        return 'SECURE';
      }

      // 0 critical, 0 failed logins -> SECURE
      expect(calculateSystemHealth(0, 0), 'SECURE');

      // 1 critical -> WARNING
      expect(calculateSystemHealth(1, 0), 'WARNING');

      // 6 failed logins -> WARNING
      expect(calculateSystemHealth(0, 6), 'WARNING');

      // 4 critical -> AT RISK
      expect(calculateSystemHealth(4, 2), 'AT RISK');
    });

    test('Filters audit logs by search query across multiple fields', () {
      List<Map<String, dynamic>> logs = [
        {
          'action': 'Admin Triggered AI OCR Re-Scan',
          'user': 'Admin_Primary',
          'logCategory': 'AI_OCR_AUDIT',
          'severity': 'Normal',
          'details': {'Target': 'voters/2021-1002', 'Verdict': 'Verified'}
        },
        {
          'action': 'Failed Admin Login Attempt',
          'user': '192.168.1.105',
          'logCategory': 'SECURITY ALERT',
          'severity': 'Critical',
          'details': {'Reason': 'Invalid credentials'}
        },
        {
          'action': 'Official Tally Exported (PDF)',
          'user': 'Admin_Primary',
          'logCategory': 'ACTIVITY LOG',
          'severity': 'Info',
          'details': {'Payload': 'DemocraSync_Official_Results.pdf'}
        },
      ];

      List<Map<String, dynamic>> filterByQuery(String query) {
        if (query.trim().isEmpty) return logs;
        String q = query.trim().toLowerCase();
        return logs.where((l) {
          String action = (l['action'] ?? l['event'] ?? '').toString().toLowerCase();
          String user = (l['user'] ?? '').toString().toLowerCase();
          String cat = (l['logCategory'] ?? '').toString().toLowerCase();
          String sev = (l['severity'] ?? l['type'] ?? '').toString().toLowerCase();
          String details = (l['details'] ?? '').toString().toLowerCase();
          return action.contains(q) ||
              user.contains(q) ||
              cat.contains(q) ||
              sev.contains(q) ||
              details.contains(q);
        }).toList();
      }

      expect(filterByQuery('pdf').length, 1);
      expect(filterByQuery('critical').length, 1);
      expect(filterByQuery('admin_primary').length, 2);
      expect(filterByQuery('2021-1002').length, 1);
      expect(filterByQuery('nonexistent').length, 0);
    });

    test('Filters audit logs accurately by Category chip', () {
      List<Map<String, dynamic>> logs = [
        {'logCategory': 'ACTIVITY LOG'},
        {'logCategory': 'AI_OCR_AUDIT'},
        {'logCategory': 'SECURITY ALERT'},
        {'logCategory': 'ACTIVITY LOG'},
      ];

      List<Map<String, dynamic>> filterByCategory(String selectedCategory) {
        if (selectedCategory == 'All') return logs;
        return logs.where((l) {
          String cat = l['logCategory'] ?? '';
          if (selectedCategory == 'Activity Logs') return cat == 'ACTIVITY LOG';
          if (selectedCategory == 'AI OCR Audits') return cat == 'AI_OCR_AUDIT';
          if (selectedCategory == 'Security Threats') return cat == 'SECURITY ALERT';
          return true;
        }).toList();
      }

      expect(filterByCategory('All').length, 4);
      expect(filterByCategory('Activity Logs').length, 2);
      expect(filterByCategory('AI OCR Audits').length, 1);
      expect(filterByCategory('Security Threats').length, 1);
    });

    test('Pagination calculations partition audit logs correctly', () {
      int totalLogs = 45;
      int pageSize = 15;
      int totalPages = (totalLogs / pageSize).ceil();
      expect(totalPages, 3);

      // Page 0
      int start0 = 0 * pageSize;
      int end0 = (start0 + pageSize) > totalLogs ? totalLogs : (start0 + pageSize);
      expect(start0, 0);
      expect(end0, 15);

      // Page 2 (last page)
      int start2 = 2 * pageSize;
      int end2 = (start2 + pageSize) > totalLogs ? totalLogs : (start2 + pageSize);
      expect(start2, 30);
      expect(end2, 45);
    });

    test('Responsive view toggle logic defaults to desktop=table and mobile=card with override', () {
      bool resolveViewMode({required double screenWidth, bool? userOverride}) {
        bool isMobile = screenWidth < 700;
        return userOverride ?? !isMobile;
      }

      // Default desktop (width 1200) -> table view (true)
      expect(resolveViewMode(screenWidth: 1200), true);

      // Default mobile (width 400) -> card view (false)
      expect(resolveViewMode(screenWidth: 400), false);

      // Mobile with user override to table -> table view (true)
      expect(resolveViewMode(screenWidth: 400, userOverride: true), true);

      // Desktop with user override to card -> card view (false)
      expect(resolveViewMode(screenWidth: 1200, userOverride: false), false);
    });

    test('Dropdown options lists contain initial values and resolve fallbacks safely', () {
      const severityOptions = [
        'All Severities',
        'Critical',
        'High / Warning',
        'Normal / Info',
      ];
      String initialSeverity = 'All Severities';
      expect(severityOptions.contains(initialSeverity), true);

      // Defensive fallback tests
      String resolveSeverity(String val) =>
          severityOptions.contains(val) ? val : 'All Severities';
      expect(resolveSeverity('All Severities'), 'All Severities');
      expect(resolveSeverity('Critical'), 'Critical');
      expect(resolveSeverity('All'), 'All Severities'); // Fallback works safely

      const sortOptions = [
        'Newest First',
        'Oldest First',
        'Severity (High First)',
        'Action (A-Z)',
      ];
      String initialSort = 'Newest First';
      expect(sortOptions.contains(initialSort), true);

      const pageSizeOptions = [15, 25, 50, 100];
      int initialPageSize = 15;
      expect(pageSizeOptions.contains(initialPageSize), true);
    });
  });
}
