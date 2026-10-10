import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('Candidate and Position sorting logic works correctly', () {
    final Map<String, List<Map<String, dynamic>>> testCandidates = {
      'Senator': [
        {'name': 'Bob', 'voteCount': 100},
        {'name': 'Alice', 'voteCount': 250},
        {'name': 'Charlie', 'voteCount': 250},
      ],
      'President': [
        {'name': 'Zack', 'voteCount': 400},
        {'name': 'Aaron', 'voteCount': 600},
      ],
      'Auditor': [
        {'name': 'David', 'voteCount': 300},
      ],
    };

    // Candidate vote sorting (highest to lowest, ties broken alphabetically)
    testCandidates.forEach((key, list) {
      list.sort((a, b) {
        int voteA = (a['voteCount'] as num?)?.toInt() ?? 0;
        int voteB = (b['voteCount'] as num?)?.toInt() ?? 0;
        if (voteB != voteA) {
          return voteB.compareTo(voteA);
        }
        return (a['name']?.toString() ?? '').compareTo(b['name']?.toString() ?? '');
      });
    });

    expect(testCandidates['President']![0]['name'], 'Aaron');
    expect(testCandidates['President']![1]['name'], 'Zack');
    expect(testCandidates['Senator']![0]['name'], 'Alice'); // 250, alphabetically before Charlie
    expect(testCandidates['Senator']![1]['name'], 'Charlie'); // 250
    expect(testCandidates['Senator']![2]['name'], 'Bob'); // 100

    // Position hierarchy sorting
    const positionHierarchy = [
      'President',
      'Vice President for Internal Affairs',
      'Vice President for External Affairs',
      'Vice President',
      'Executive Secretary',
      'Secretary',
      'Treasurer',
      'Auditor',
      'Public Relations Officer',
      'Senator',
      'Governor',
      'Vice Governor',
      'Secretary Treasurer',
      'Representative',
    ];

    List<MapEntry<String, List<Map<String, dynamic>>>> sortedEntries = testCandidates.entries.toList()
      ..sort((a, b) {
        int indexA = positionHierarchy.indexOf(a.key);
        int indexB = positionHierarchy.indexOf(b.key);
        if (indexA != -1 && indexB != -1) return indexA.compareTo(indexB);
        if (indexA != -1) return -1;
        if (indexB != -1) return 1;
        return a.key.compareTo(b.key);
      });

    expect(sortedEntries.map((e) => e.key).toList(), ['President', 'Auditor', 'Senator']);
  });

  test('PDF Election Tally Generation generates valid bytes with refined layout', () async {
    final logoFile = File('assets/nemsu_logo.png');
    expect(logoFile.existsSync(), isTrue, reason: 'NEMSU logo asset should exist');
    final logoBytes = await logoFile.readAsBytes();
    final logoImage = pw.MemoryImage(logoBytes);

    final fontFile = File('assets/fonts/arial.ttf');
    final boldFontFile = File('assets/fonts/arialbd.ttf');
    expect(fontFile.existsSync(), isTrue, reason: 'Arial font asset should exist');
    expect(boldFontFile.existsSync(), isTrue, reason: 'Arial bold font asset should exist');

    final fontData = await fontFile.readAsBytes();
    final boldFontData = await boldFontFile.readAsBytes();

    final arialFont = pw.Font.ttf(fontData.buffer.asByteData());
    final arialBoldFont = pw.Font.ttf(boldFontData.buffer.asByteData());

    final pdf = pw.Document();
    final String printedDateTime = DateFormat('MMMM dd, yyyy hh:mm:ss a').format(DateTime(2026, 10, 10, 17, 30, 0));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 16, 36, 24),
        theme: pw.ThemeData.withFont(
          base: arialFont,
          bold: arialBoldFont,
        ),
        header: (pw.Context context) {
          const double logoSize = 48;
          return pw.Column(
            children: [
              pw.Center(
                child: pw.Container(
                  width: logoSize,
                  height: logoSize,
                  child: pw.Image(logoImage),
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Center(
                child: pw.Text(
                  'NORTH EASTERN MINDANAO STATE UNIVERSITY',
                  style: pw.TextStyle(
                    fontSize: 12.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.black,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Center(
                child: pw.Text(
                  'Brgy. Rosario, Tandag City, Surigao del Sur',
                  style: const pw.TextStyle(
                    fontSize: 9.5,
                    color: PdfColors.black,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1.5, color: PdfColors.black),
              pw.SizedBox(height: 12),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Date/Time Printed : $printedDateTime',
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey800),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text(
                'DemocraSync- Official Student Election Tally',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.black,
                ),
                textAlign: pw.TextAlign.center,
              ),
            ),
            pw.SizedBox(height: 14),

            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Text('1,250', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.SizedBox(height: 2),
                    pw.Text('Registered Voters', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('1,100', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.SizedBox(height: 2),
                    pw.Text('Total Votes Cast', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('88.0%', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.SizedBox(height: 2),
                    pw.Text('Voter Turnout', style: const pw.TextStyle(fontSize: 9.5, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),

            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'PRESIDENT',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                ),
                pw.SizedBox(height: 6),
                pw.TableHelper.fromTextArray(
                  headers: ['Candidate Name', 'Party Affiliation', 'Total Votes'],
                  data: [
                    ['Maria Santos', 'Sandigan Party', '650'],
                    ['Juan Dela Cruz', 'Tindog Party', '450'],
                  ],
                  columnWidths: {
                    0: const pw.FlexColumnWidth(4.5),
                    1: const pw.FlexColumnWidth(3.5),
                    2: const pw.FlexColumnWidth(2.0),
                  },
                  headerStyle: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                  headerHeight: 24,
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  cellHeight: 22,
                  cellPadding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  cellAlignments: {
                    0: pw.Alignment.centerLeft,
                    1: pw.Alignment.centerLeft,
                    2: pw.Alignment.center,
                  },
                ),
                pw.SizedBox(height: 16),
              ],
            ),

            pw.SizedBox(height: 25),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('CERTIFIED TRUE AND CORRECT BY:', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 35),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Container(width: 170, height: 1, color: PdfColors.black),
                      pw.SizedBox(height: 4),
                      pw.Text('COMSELEC Chairperson', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
      ),
    );

    final bytes = await pdf.save();
    expect(bytes, isNotEmpty);
    expect(bytes.length, greaterThan(1000));
  });
}
