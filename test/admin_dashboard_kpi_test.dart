import 'package:flutter_test/flutter_test.dart';
import 'package:DemocraSync/utils/admin_kpi_helper.dart';

void main() {
  group('Admin Dashboard KPI Calculations & Normalization Tests', () {
    test('Calculates registeredVoters as total accounts in database matching Voter Management', () {
      final testVoters = [
        {'id': '2023-0001', 'status': 'Verified', 'hasVoted': false},
        {'id': '2023-0002', 'status': 'Pending Verification', 'hasVoted': false},
        {'id': '2023-0003', 'status': 'Pending', 'hasVoted': false},
        {'id': '2023-0004', 'status': 'Rejected', 'hasVoted': false},
        {'id': '2023-0005', 'status': null, 'hasVoted': false}, // Missing status defaults to pending
      ];

      final metrics = AdminKpiHelper.calculate(
        voters: testVoters,
        votes: [],
      );

      // Registered voters should be the total count (5), not just verified (1)
      expect(metrics.registeredVoters, 5);
      expect(metrics.verifiedVoters, 1);
      expect(metrics.rejectedVoters, 1);
      expect(metrics.pendingVerifications, 3); // Pending Verification, Pending, and null
      expect(metrics.totalVotes, 0);
      expect(metrics.turnoutPercentage, 0.0);
    });

    test('Normalizes status case-insensitively and handles whitespace', () {
      final testVoters = [
        {'id': 'V1', 'status': 'VERIFIED'},
        {'id': 'V2', 'status': '  verified  '},
        {'id': 'V3', 'status': 'Verified'},
        {'id': 'V4', 'status': 'pending'},
        {'id': 'V5', 'status': 'PENDING VERIFICATION'},
        {'id': 'V6', 'status': 'Under Review'},
        {'id': 'V7', 'status': 'REJECTED'},
      ];

      final metrics = AdminKpiHelper.calculate(
        voters: testVoters,
        votes: [],
      );

      expect(metrics.registeredVoters, 7);
      expect(metrics.verifiedVoters, 3); // V1, V2, V3
      expect(metrics.pendingVerifications, 3); // V4, V5, V6
      expect(metrics.rejectedVoters, 1); // V7
    });

    test('Calculates turnoutPercentage based on verified eligible voters', () {
      final testVoters = [
        {'id': 'V1', 'status': 'Verified', 'hasVoted': true, 'department': 'College of Information Technology Education'},
        {'id': 'V2', 'status': 'Verified', 'hasVoted': true, 'department': 'College of Teacher Education'},
        {'id': 'V3', 'status': 'Verified', 'hasVoted': false},
        {'id': 'V4', 'status': 'Verified', 'hasVoted': false},
        {'id': 'V5', 'status': 'Pending', 'hasVoted': false},
        {'id': 'V6', 'status': 'Rejected', 'hasVoted': false},
      ];

      final metrics = AdminKpiHelper.calculate(
        voters: testVoters,
        votes: [
          {'voterId': 'V1', 'department': 'College of Information Technology Education'},
          {'voterId': 'V2', 'department': 'College of Teacher Education'},
        ],
      );

      expect(metrics.registeredVoters, 6);
      expect(metrics.verifiedVoters, 4);
      expect(metrics.totalVotes, 2);
      // Turnout: 2 votes / 4 verified voters = 0.5 (50.0%)
      expect(metrics.turnoutPercentage, 0.5);
    });

    test('Reconciles votes collection with voters hasVoted flag seamlessly', () {
      final testVoters = [
        // Voter has hasVoted: 'true' as string
        {'id': 'V1', 'status': 'Verified', 'hasVoted': 'true', 'department': 'College of Business and Management'},
        // Voter has hasVoted: true as boolean
        {'id': 'V2', 'status': 'Verified', 'hasVoted': true, 'department': 'College of Business and Management'},
        // Voter has hasVoted: false, but vote document exists in votes collection
        {'id': 'V3', 'status': 'Verified', 'hasVoted': false, 'department': 'College of Arts and Sciences'},
        // Voter not yet voted
        {'id': 'V4', 'status': 'Verified', 'hasVoted': false},
      ];

      final testVotes = [
        {'voterId': 'V1', 'department': 'College of Business and Management'},
        {'voterId': 'V2', 'department': 'College of Business and Management'},
        {'voterId': 'V3', 'department': 'College of Arts and Sciences'},
      ];

      final metrics = AdminKpiHelper.calculate(
        voters: testVoters,
        votes: testVotes,
      );

      expect(metrics.totalVotes, 3);
      expect(metrics.verifiedVoters, 4);
      expect(metrics.turnoutPercentage, 0.75); // 75.0%
      expect(metrics.deptTurnout['Business & Management'], 2);
      expect(metrics.deptTurnout['Arts & Sciences'], 1);
    });

    test('Handles division by zero safely when zero verified voters exist', () {
      final testVoters = [
        {'id': 'V1', 'status': 'Pending', 'hasVoted': false},
        {'id': 'V2', 'status': 'Pending', 'hasVoted': false},
      ];

      final metrics = AdminKpiHelper.calculate(
        voters: testVoters,
        votes: [],
      );

      expect(metrics.registeredVoters, 2);
      expect(metrics.verifiedVoters, 0);
      expect(metrics.pendingVerifications, 2);
      expect(metrics.totalVotes, 0);
      expect(metrics.turnoutPercentage, 0.0);
    });

    test('Normalizes department abbreviations accurately', () {
      expect(AdminKpiHelper.normalizeDepartment('College of Information Technology Education'), 'Information Technology');
      expect(AdminKpiHelper.normalizeDepartment('College of Business and Management'), 'Business & Management');
      expect(AdminKpiHelper.normalizeDepartment('College of Teacher Education'), 'Teacher');
      expect(AdminKpiHelper.normalizeDepartment('College of Engineering and Technology'), 'Engineering & Technology');
      expect(AdminKpiHelper.normalizeDepartment('College of Arts and Sciences'), 'Arts & Sciences');
      expect(AdminKpiHelper.normalizeDepartment(''), 'Unknown');
    });
  });
}
