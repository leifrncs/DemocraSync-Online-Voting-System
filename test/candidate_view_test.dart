import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Candidate Management View & Pagination Logic Tests', () {
    test('Calculates total pages and slice indices correctly for pagination', () {
      int totalCandidates = 19;
      int pageSize = 8;
      int totalPages = (totalCandidates / pageSize).ceil();
      expect(totalPages, 3);

      // Page 0
      int page0Start = 0 * pageSize;
      int page0End = (page0Start + pageSize) > totalCandidates ? totalCandidates : (page0Start + pageSize);
      expect(page0Start, 0);
      expect(page0End, 8);

      // Page 1
      int page1Start = 1 * pageSize;
      int page1End = (page1Start + pageSize) > totalCandidates ? totalCandidates : (page1Start + pageSize);
      expect(page1Start, 8);
      expect(page1End, 16);

      // Page 2 (last page)
      int page2Start = 2 * pageSize;
      int page2End = (page2Start + pageSize) > totalCandidates ? totalCandidates : (page2Start + pageSize);
      expect(page2Start, 16);
      expect(page2End, 19);
    });

    test('Candidate sorting orders lists correctly by Name (A-Z) and (Z-A)', () {
      List<Map<String, dynamic>> candidates = [
        {'name': 'Charlie Garcia', 'position': 'Senator', 'party': 'Independent'},
        {'name': 'Alice Santos', 'position': 'President', 'party': 'Alyansa Student Party'},
        {'name': 'Bob Dela Cruz', 'position': 'Governor', 'party': 'Lakas Demokratiko'},
      ];

      // Sort A-Z
      candidates.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
      expect(candidates[0]['name'], 'Alice Santos');
      expect(candidates[1]['name'], 'Bob Dela Cruz');
      expect(candidates[2]['name'], 'Charlie Garcia');

      // Sort Z-A
      candidates.sort((a, b) => b['name'].toString().compareTo(a['name'].toString()));
      expect(candidates[0]['name'], 'Charlie Garcia');
      expect(candidates[1]['name'], 'Bob Dela Cruz');
      expect(candidates[2]['name'], 'Alice Santos');
    });

    test('Candidate sorting orders correctly by Position and Party', () {
      List<Map<String, dynamic>> candidates = [
        {'name': 'Candidate 1', 'position': 'Senator', 'party': 'Independent'},
        {'name': 'Candidate 2', 'position': 'Auditor', 'party': 'Alyansa Student Party'},
        {'name': 'Candidate 3', 'position': 'Governor', 'party': 'Sandigan Youth'},
      ];

      // Sort by Position
      candidates.sort((a, b) => a['position'].toString().compareTo(b['position'].toString()));
      expect(candidates[0]['position'], 'Auditor');
      expect(candidates[1]['position'], 'Governor');
      expect(candidates[2]['position'], 'Senator');

      // Sort by Party
      candidates.sort((a, b) => a['party'].toString().compareTo(b['party'].toString()));
      expect(candidates[0]['party'], 'Alyansa Student Party');
      expect(candidates[1]['party'], 'Independent');
      expect(candidates[2]['party'], 'Sandigan Youth');
    });

    test('Responsive view toggle logic defaults to desktop=table and mobile=card with override', () {
      bool? userSelectedTableView;

      // On wide screen (isMobile = false), default should be table
      bool isMobileWide = false;
      bool isTableViewWide = userSelectedTableView ?? !isMobileWide;
      expect(isTableViewWide, isTrue);

      // On mobile screen (isMobile = true), default should be card
      bool isMobileNarrow = true;
      bool isTableViewNarrow = userSelectedTableView ?? !isMobileNarrow;
      expect(isTableViewNarrow, isFalse);

      // When user explicitly selects Card Grid View on desktop
      userSelectedTableView = false;
      expect(userSelectedTableView ?? !isMobileWide, isFalse);

      // When user explicitly selects Table View on mobile
      userSelectedTableView = true;
      expect(userSelectedTableView ?? !isMobileNarrow, isTrue);
    });
  });
}
