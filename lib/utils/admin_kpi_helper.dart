/// Helper class and data model for Admin Dashboard KPI calculations.
/// Ensures consistent KPI metrics across the Admin Dashboard screen,
/// Department Turnout charts, and official PDF exports.
class AdminKpiMetrics {
  /// Total registered student voter accounts in the database.
  final int registeredVoters;

  /// Verified student voters who are eligible to vote.
  final int verifiedVoters;

  /// Student registrations or COR submissions awaiting review/verification.
  final int pendingVerifications;

  /// Registrations or COR submissions marked as rejected.
  final int rejectedVoters;

  /// Total ballots cast across all colleges, reconciled from the votes collection
  /// and verified voter activity.
  final int totalVotes;

  /// Turnout percentage calculated as totalVotes / verifiedVoters (0.0 to 1.0).
  final double turnoutPercentage;

  /// Department votes breakdown with shortened college labels.
  final Map<String, int> deptTurnout;

  const AdminKpiMetrics({
    required this.registeredVoters,
    required this.verifiedVoters,
    required this.pendingVerifications,
    required this.rejectedVoters,
    required this.totalVotes,
    required this.turnoutPercentage,
    required this.deptTurnout,
  });
}

class AdminKpiHelper {
  /// Normalizes college / department names for chart and tally displays.
  static String normalizeDepartment(String dept) {
    if (dept.trim().isEmpty) return 'Unknown';
    return dept
        .replaceAll('College of ', '')
        .replaceAll(' Education', '')
        .replaceAll(' and ', ' & ')
        .trim();
  }

  /// Calculates reconciled KPI metrics from raw voters and votes document datasets.
  static AdminKpiMetrics calculate({
    required List<Map<String, dynamic>> voters,
    required List<Map<String, dynamic>> votes,
  }) {
    final int registeredVoters = voters.length;
    int verifiedVoters = 0;
    int pendingVerifications = 0;
    int rejectedVoters = 0;

    final Set<String> votedStudentIds = {};
    final Map<String, int> deptTurnout = {};

    // 1. Process Voters Collection
    for (var voter in voters) {
      final String id = voter['id']?.toString() ?? voter['studentId']?.toString() ?? '';
      final String rawStatus = voter['status']?.toString().trim().toLowerCase() ?? '';

      if (rawStatus == 'verified') {
        verifiedVoters++;
      } else if (rawStatus == 'rejected') {
        rejectedVoters++;
      } else {
        // Any account not verified and not rejected is pending (null, empty, pending, under review, etc.)
        pendingVerifications++;
      }

      // Check for vote completion with type-safety
      final dynamic hasVotedVal = voter['hasVoted'];
      final bool hasVotedBool = hasVotedVal == true ||
          hasVotedVal?.toString().toLowerCase() == 'true' ||
          hasVotedVal == 1;

      if (hasVotedBool) {
        if (id.isNotEmpty) {
          votedStudentIds.add(id);
        }
        final String dept = voter['department']?.toString() ?? 'Unknown';
        final String shortDept = normalizeDepartment(dept);
        deptTurnout[shortDept] = (deptTurnout[shortDept] ?? 0) + 1;
      }
    }

    // 2. Reconcile with Votes Collection (ballots submitted)
    for (var vote in votes) {
      final String voterId = vote['voterId']?.toString() ?? vote['id']?.toString() ?? '';
      if (voterId.isNotEmpty && !votedStudentIds.contains(voterId)) {
        votedStudentIds.add(voterId);
        final String dept = vote['department']?.toString() ?? 'Unknown';
        final String shortDept = normalizeDepartment(dept);
        deptTurnout[shortDept] = (deptTurnout[shortDept] ?? 0) + 1;
      }
    }

    // Total votes takes the reconciled maximum of submitted ballots and flagged voters
    int totalVotes = votes.length;
    if (votedStudentIds.length > totalVotes) {
      totalVotes = votedStudentIds.length;
    }

    // Turnout is calculated based on verified eligible voters
    final double turnoutPercentage =
        verifiedVoters > 0 ? (totalVotes / verifiedVoters) : 0.0;

    return AdminKpiMetrics(
      registeredVoters: registeredVoters,
      verifiedVoters: verifiedVoters,
      pendingVerifications: pendingVerifications,
      rejectedVoters: rejectedVoters,
      totalVotes: totalVotes,
      turnoutPercentage: turnoutPercentage,
      deptTurnout: deptTurnout,
    );
  }
}
