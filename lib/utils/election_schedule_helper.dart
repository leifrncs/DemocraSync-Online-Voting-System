import 'package:intl/intl.dart';

enum ElectionScheduleStatus {
  upcoming,
  open,
  ended,
  manuallyLocked,
  notConfigured,
}

class ElectionScheduleState {
  final bool isManuallyActive;
  final DateTime? start;
  final DateTime? end;
  final ElectionScheduleStatus status;
  final bool canVote;
  final String statusBadge;
  final String statusHeadline;
  final String statusDescription;
  final String actionButtonLabel;
  final String timeRemainingText;

  const ElectionScheduleState({
    required this.isManuallyActive,
    required this.start,
    required this.end,
    required this.status,
    required this.canVote,
    required this.statusBadge,
    required this.statusHeadline,
    required this.statusDescription,
    required this.actionButtonLabel,
    required this.timeRemainingText,
  });

  String formatDateTime(DateTime? dt) {
    if (dt == null) return 'Not set';
    return DateFormat('MMM d, yyyy • h:mm a').format(dt);
  }

  String get formattedStart => formatDateTime(start);
  String get formattedEnd => formatDateTime(end);
}

class ElectionScheduleHelper {
  static ElectionScheduleState evaluate({
    required Map<String, dynamic>? electionConfigDoc,
    required Map<String, dynamic>? electionToggleDoc,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();

    final isManuallyActive = electionToggleDoc?['isActive'] == true;

    DateTime? startDate;
    DateTime? endDate;

    if (electionConfigDoc != null && electionConfigDoc.containsKey('schedule')) {
      final schedule = electionConfigDoc['schedule'];
      if (schedule is Map<String, dynamic>) {
        if (schedule['start'] != null) {
          startDate = DateTime.tryParse(schedule['start'].toString());
        }
        if (schedule['end'] != null) {
          endDate = DateTime.tryParse(schedule['end'].toString());
        }
      }
    }

    // 1. Fallback if no valid schedule dates are configured
    if (startDate == null || endDate == null) {
      if (isManuallyActive) {
        return ElectionScheduleState(
          isManuallyActive: true,
          start: startDate,
          end: endDate,
          status: ElectionScheduleStatus.open,
          canVote: true,
          statusBadge: 'VOTING OPEN',
          statusHeadline: 'Election Is Active',
          statusDescription: 'The ballot is open for voting as authorized by COMSELEC.',
          actionButtonLabel: 'PROCEED TO BALLOT',
          timeRemainingText: 'Election currently open',
        );
      } else {
        return ElectionScheduleState(
          isManuallyActive: false,
          start: startDate,
          end: endDate,
          status: ElectionScheduleStatus.notConfigured,
          canVote: false,
          statusBadge: 'ELECTION LOCKED',
          statusHeadline: 'Election Is Locked',
          statusDescription: 'COMSELEC has not opened the voting period or set the election schedule.',
          actionButtonLabel: 'ELECTION LOCKED',
          timeRemainingText: 'Schedule not yet configured',
        );
      }
    }

    // 2. Schedule window checks
    if (now.isBefore(startDate)) {
      final diff = startDate.difference(now);
      final remaining = formatDuration(diff);
      return ElectionScheduleState(
        isManuallyActive: isManuallyActive,
        start: startDate,
        end: endDate,
        status: ElectionScheduleStatus.upcoming,
        canVote: false,
        statusBadge: 'UPCOMING',
        statusHeadline: 'Voting Has Not Started Yet',
        statusDescription: 'The official voting window will open on ${DateFormat('MMMM d, yyyy at h:mm a').format(startDate)}.',
        actionButtonLabel: 'VOTING OPENS AT ${DateFormat('h:mm a').format(startDate)}',
        timeRemainingText: 'Opens in $remaining',
      );
    }

    if (now.isAfter(endDate)) {
      return ElectionScheduleState(
        isManuallyActive: isManuallyActive,
        start: startDate,
        end: endDate,
        status: ElectionScheduleStatus.ended,
        canVote: false,
        statusBadge: 'CONCLUDED',
        statusHeadline: 'Voting Period Has Concluded',
        statusDescription: 'The election ended on ${DateFormat('MMMM d, yyyy at h:mm a').format(endDate)}. Official results are being audited.',
        actionButtonLabel: 'ELECTION CONCLUDED',
        timeRemainingText: 'Voting period has officially ended',
      );
    }

    // 3. Within scheduled window
    if (!isManuallyActive) {
      return ElectionScheduleState(
        isManuallyActive: false,
        start: startDate,
        end: endDate,
        status: ElectionScheduleStatus.manuallyLocked,
        canVote: false,
        statusBadge: 'PAUSED',
        statusHeadline: 'Voting Temporarily Suspended',
        statusDescription: 'Voting is scheduled to be open, but COMSELEC has temporarily paused ballot access. Please wait for an update.',
        actionButtonLabel: 'VOTING TEMPORARILY PAUSED',
        timeRemainingText: 'Ballot paused by COMSELEC',
      );
    }

    // 4. Open and Active
    final remainingDiff = endDate.difference(now);
    final remaining = formatDuration(remainingDiff);
    return ElectionScheduleState(
      isManuallyActive: true,
      start: startDate,
      end: endDate,
      status: ElectionScheduleStatus.open,
      canVote: true,
      statusBadge: 'VOTING OPEN',
      statusHeadline: 'Election Is Active',
      statusDescription: 'Voting is live and accepting ballots until ${DateFormat('MMMM d, yyyy at h:mm a').format(endDate)}.',
      actionButtonLabel: 'PROCEED TO BALLOT',
      timeRemainingText: 'Closes in $remaining',
    );
  }

  static String formatDuration(Duration d) {
    if (d.inDays > 0) {
      final hours = d.inHours % 24;
      final minutes = d.inMinutes % 60;
      return '${d.inDays}d ${hours}h ${minutes}m';
    }
    if (d.inHours > 0) {
      final minutes = d.inMinutes % 60;
      final seconds = d.inSeconds % 60;
      return '${d.inHours}h ${minutes}m ${seconds}s';
    }
    if (d.inMinutes > 0) {
      final seconds = d.inSeconds % 60;
      return '${d.inMinutes}m ${seconds}s';
    }
    return '${d.inSeconds}s';
  }
}
