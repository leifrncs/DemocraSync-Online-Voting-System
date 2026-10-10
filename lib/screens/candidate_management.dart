import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';

class CandidateManagement extends StatefulWidget {
  const CandidateManagement({super.key});

  @override
  State<CandidateManagement> createState() => _CandidateManagementState();
}

class _CandidateManagementState extends State<CandidateManagement> {
  // --- SEARCH & FILTER STATES ---
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedScope = 'All';
  String _selectedPosition = 'All';

  // --- VIEW & PAGINATION & SORT STATES ---
  bool? _userSelectedTableView;
  String _sortBy = 'Newest First';
  static const List<String> _sortOptions = [
    'Newest First',
    'Name (A-Z)',
    'Name (Z-A)',
    'Position',
    'Party',
  ];

  int _currentPage = 0;
  int _pageSize = 8;
  static const List<int> _pageSizeOptions = [8, 12, 24, 48];

  // --- FIREBASE & CONFIG STATES ---
  List<Map<String, dynamic>> _configuredPositions = [];
  List<String> _departmentsList = [];
  bool _isLoadingConfig = true;

  // --- CANONICAL SCOPES & DEFAULTS ---
  static const List<String> _canonicalScopes = [
    'University-Wide (USG)',
    'College of Information Technology Education',
    'College of Business and Management',
    'College of Teacher Education',
    'College of Engineering and Technology',
    'College of Arts and Sciences',
  ];

  static const List<String> _partyPresets = [
    'Independent',
    'Alyansa Student Party',
    'Lakas Demokratiko',
    'Sandigan Youth',
    'Forward Vanguard',
    'United Leaders',
  ];

  @override
  void initState() {
    super.initState();
    _loadElectionConfig();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- 1. LOAD CONFIGURATION FROM FIREBASE ---
  Future<void> _loadElectionConfig() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('config').doc('election_settings').get();

      List<Map<String, dynamic>> loadedPositions = [];
      if (doc.exists && doc.data() != null) {
        var data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('positions') && data['positions'] is List) {
          loadedPositions = List<Map<String, dynamic>>.from(data['positions']);
        }
      }

      // Automatically migrate any 'Secretary Treasurer' to separate 'Secretary' and 'Treasurer'
      List<Map<String, dynamic>> expandedPositions = [];
      for (var p in loadedPositions) {
        if (p['position'] == 'Secretary Treasurer') {
          expandedPositions.add({'scope': p['scope'], 'position': 'Secretary', 'seats': p['seats'] ?? p['maxElected'] ?? 1});
          expandedPositions.add({'scope': p['scope'], 'position': 'Treasurer', 'seats': p['seats'] ?? p['maxElected'] ?? 1});
        } else {
          expandedPositions.add(p);
        }
      }
      loadedPositions = expandedPositions;

      if (loadedPositions.isEmpty) {
        loadedPositions = _generateDefaultPositions();
      }

      // Automatically migrate any existing candidates in Firestore from 'Secretary Treasurer' to 'Secretary'
      FirebaseFirestore.instance
          .collection('candidates')
          .where('position', isEqualTo: 'Secretary Treasurer')
          .get()
          .then((snap) {
        for (var d in snap.docs) {
          d.reference.update({'position': 'Secretary'});
        }
      }).catchError((_) {});

      Set<String> depts = {..._canonicalScopes};
      for (var p in loadedPositions) {
        if (p['scope'] != null && p['scope'].toString().isNotEmpty) {
          depts.add(p['scope'].toString());
        }
      }

      if (mounted) {
        setState(() {
          _configuredPositions = loadedPositions;
          _departmentsList = depts.toList();
          _isLoadingConfig = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _configuredPositions = _generateDefaultPositions();
          _departmentsList = [..._canonicalScopes];
          _isLoadingConfig = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _generateDefaultPositions() {
    List<Map<String, dynamic>> defaults = [];
    final usgPositions = [
      {'scope': 'University-Wide (USG)', 'position': 'President', 'seats': 1},
      {'scope': 'University-Wide (USG)', 'position': 'Vice President for Internal Affairs', 'seats': 1},
      {'scope': 'University-Wide (USG)', 'position': 'Vice President for External Affairs', 'seats': 1},
      {'scope': 'University-Wide (USG)', 'position': 'Executive Secretary', 'seats': 1},
      {'scope': 'University-Wide (USG)', 'position': 'Treasurer', 'seats': 1},
      {'scope': 'University-Wide (USG)', 'position': 'Auditor', 'seats': 1},
      {'scope': 'University-Wide (USG)', 'position': 'Senator', 'seats': 12},
    ];
    defaults.addAll(usgPositions);

    final collegeScopes = [
      'College of Information Technology Education',
      'College of Business and Management',
      'College of Teacher Education',
      'College of Engineering and Technology',
      'College of Arts and Sciences',
    ];

    for (var college in collegeScopes) {
      defaults.addAll([
        {'scope': college, 'position': 'Governor', 'seats': 1},
        {'scope': college, 'position': 'Vice Governor', 'seats': 1},
        {'scope': college, 'position': 'Secretary', 'seats': 1},
        {'scope': college, 'position': 'Treasurer', 'seats': 1},
        {'scope': college, 'position': 'College Auditor', 'seats': 1},
        {'scope': college, 'position': 'Public Information Officer', 'seats': 2},
        {'scope': college, 'position': 'Business Manager', 'seats': 2},
        {'scope': college, 'position': 'Sargeant at Arms', 'seats': 2},
        {'scope': college, 'position': 'Program/Year Level Rep', 'seats': 4},
      ]);
    }
    return defaults;
  }

  // --- 2. DYNAMIC POSITIONS FOR A GIVEN SCOPE ---
  List<String> _getPositionsForDepartment(String department) {
    var matching = _configuredPositions
        .where((p) => p['scope'] == department)
        .map((p) => p['position'] as String)
        .toSet()
        .toList();

    if (matching.isNotEmpty) return matching;

    // Fallback if specific scope not in config yet
    if (department == 'University-Wide (USG)') {
      return [
        'President',
        'Vice President for Internal Affairs',
        'Vice President for External Affairs',
        'Executive Secretary',
        'Treasurer',
        'Auditor',
        'Senator',
      ];
    }
    return [
      'Governor',
      'Vice Governor',
      'Secretary',
      'Treasurer',
      'College Auditor',
      'Public Information Officer',
      'Business Manager',
      'Sargeant at Arms',
      'Program/Year Level Rep',
    ];
  }

  // Get available positions for current filter bar
  List<String> _getFilterPositionsList() {
    if (_selectedScope == 'All') {
      return _configuredPositions.map((p) => p['position'] as String).toSet().toList();
    }
    return _getPositionsForDepartment(_selectedScope);
  }

  String _getScopeAbbreviation(String scope) {
    return scope
        .replaceAll('University-Wide (USG)', 'USG (Univ-Wide)')
        .replaceAll('College of Information Technology Education', 'CITE (IT Education)')
        .replaceAll('College of Business and Management', 'CBM (Business & Mgmt)')
        .replaceAll('College of Teacher Education', 'CTE (Teacher Ed)')
        .replaceAll('College of Engineering and Technology', 'CET (Engineering & Tech)')
        .replaceAll('College of Arts and Sciences', 'CAS (Arts & Sciences)')
        .replaceAll('College of ', '');
  }

  String _getInitials(String name) {
    if (name.trim().isEmpty) return '?';
    List<String> parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }

  // --- 3. ADD / EDIT CANDIDATE DIALOG ---
  Future<void> _showCandidateForm({String? docId, Map<String, dynamic>? existingCandidate}) async {
    bool isEdit = docId != null;

    final formKey = GlobalKey<FormState>();
    TextEditingController nameController = TextEditingController(text: isEdit ? existingCandidate!['name'] : '');
    TextEditingController partyController = TextEditingController(text: isEdit ? existingCandidate!['party'] : 'Independent');
    TextEditingController platformController = TextEditingController(text: isEdit ? existingCandidate!['platform'] : '');

    String formDept = isEdit && existingCandidate!['department'] != null && _departmentsList.contains(existingCandidate['department'])
        ? existingCandidate['department']
        : (_selectedScope != 'All' && _departmentsList.contains(_selectedScope) ? _selectedScope : _departmentsList.first);

    List<String> availablePositions = _getPositionsForDepartment(formDept);
    String formPos = isEdit && availablePositions.contains(existingCandidate!['position'])
        ? existingCandidate['position']
        : (isEdit && existingCandidate!['position'] == 'Secretary Treasurer' ? 'Secretary' : availablePositions.first);

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 550),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: nemsuBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(isEdit ? Icons.edit_note_rounded : Icons.person_add_alt_1_rounded, color: nemsuBlue, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isEdit ? 'Edit Candidate Profile' : 'Register New Candidate',
                                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: nemsuBlue),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isEdit ? 'Update details for this candidate' : 'Add a candidate to the official election roster',
                                      style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 20, color: Color(0xFF94A3B8)),
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          const SizedBox(height: 18),

                          // 1. Candidate Full Name
                          const Text('Candidate Full Name', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: nameController,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'e.g. Juan D. Dela Cruz',
                              hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.person_outline_rounded, size: 20, color: Color(0xFF64748B)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: nemsuBlue, width: 1.5)),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter the candidate\'s full name' : null,
                          ),
                          const SizedBox(height: 16),

                          // 2. Department / College Scope Dropdown
                          const Text('College Scope / Department', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          InputDecorator(
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.domain_rounded, size: 20, color: Color(0xFF64748B)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: nemsuBlue, width: 1.5)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _departmentsList.contains(formDept) ? formDept : _departmentsList.first,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                                items: _departmentsList.map((d) {
                                  return DropdownMenuItem(
                                    value: d,
                                    child: Text(d, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (newDept) {
                                  if (newDept != null) {
                                    setDialogState(() {
                                      formDept = newDept;
                                      availablePositions = _getPositionsForDepartment(formDept);
                                      formPos = availablePositions.isNotEmpty ? availablePositions.first : 'No Position';
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 3. Dynamic Position Dropdown
                          const Text('Elective Position', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          InputDecorator(
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.badge_outlined, size: 20, color: Color(0xFF64748B)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: nemsuBlue, width: 1.5)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: availablePositions.contains(formPos) ? formPos : (availablePositions.isNotEmpty ? availablePositions.first : null),
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                                style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                                items: availablePositions.map((pos) {
                                  return DropdownMenuItem(
                                    value: pos,
                                    child: Text(pos, style: const TextStyle(fontSize: 14), overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() => formPos = val);
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 4. Political Party & Quick Chips
                          const Text('Political Party / Affiliation', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: partyController,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'e.g. Independent, Alyansa, Lakas',
                              hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                              prefixIcon: const Icon(Icons.flag_outlined, size: 20, color: Color(0xFF64748B)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: nemsuBlue, width: 1.5)),
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Party Quick Presets
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _partyPresets.map((party) {
                                bool isSelected = partyController.text.trim() == party;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 6),
                                  child: InkWell(
                                    onTap: () {
                                      setDialogState(() {
                                        partyController.text = party;
                                      });
                                    },
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isSelected ? nemsuGold.withValues(alpha: 0.25) : const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: isSelected ? const Color(0xFFD97706) : const Color(0xFFE2E8F0)),
                                      ),
                                      child: Text(
                                        party,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                          color: isSelected ? const Color(0xFF92400E) : const Color(0xFF475569),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 5. Campaign Platform / Manifesto
                          const Text('Campaign Platform & Manifesto', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: platformController,
                            maxLines: 3,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              hintText: 'Describe key advocacies, goals, and platform points...',
                              hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                              contentPadding: const EdgeInsets.all(13),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: nemsuBlue, width: 1.5)),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Dialog Actions
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11)),
                                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 14)),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: nemsuBlue,
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () async {
                                  if (!formKey.currentState!.validate()) return;

                                  String candidateName = nameController.text.trim();
                                  String candidateParty = partyController.text.trim().isEmpty ? 'Independent' : partyController.text.trim();
                                  String candidatePlatform = platformController.text.trim().isEmpty
                                      ? 'No platform statement submitted yet.'
                                      : platformController.text.trim();

                                  Map<String, dynamic> candidatePayload = {
                                    'name': candidateName,
                                    'department': formDept,
                                    'position': formPos,
                                    'party': candidateParty,
                                    'platform': candidatePlatform,
                                    'timestamp': isEdit && existingCandidate!['timestamp'] != null
                                        ? existingCandidate['timestamp']
                                        : FieldValue.serverTimestamp(),
                                  };

                                  try {
                                    if (isEdit) {
                                      await FirebaseFirestore.instance.collection('candidates').doc(docId).update(candidatePayload);
                                      await FirebaseFirestore.instance.collection('audit_logs').add({
                                        'timestamp': FieldValue.serverTimestamp(),
                                        'action': 'Candidate Updated',
                                        'user': 'admin',
                                        'type': 'Candidate Management',
                                        'details': {'candidate': candidateName, 'department': formDept, 'position': formPos},
                                      });
                                    } else {
                                      candidatePayload['voteCount'] = 0;
                                      await FirebaseFirestore.instance.collection('candidates').add(candidatePayload);
                                      await FirebaseFirestore.instance.collection('audit_logs').add({
                                        'timestamp': FieldValue.serverTimestamp(),
                                        'action': 'Candidate Registered',
                                        'user': 'admin',
                                        'type': 'Candidate Management',
                                        'details': {'candidate': candidateName, 'department': formDept, 'position': formPos},
                                      });
                                    }

                                    if (!context.mounted) return;
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(isEdit ? 'Candidate "$candidateName" updated successfully!' : 'Candidate "$candidateName" registered!'),
                                        backgroundColor: const Color(0xFF10B981),
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error saving candidate: $e'), backgroundColor: Colors.redAccent),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.check_rounded, size: 18),
                                label: Text(isEdit ? 'Save Changes' : 'Register Candidate', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // --- 4. VIEW FULL CANDIDATE PROFILE DIALOG ---
  void _viewCandidateProfile(Map<String, dynamic> candidate) {
    showDialog(
      context: context,
      builder: (context) {
        String name = candidate['name'] ?? 'Unknown Candidate';
        String dept = candidate['department'] ?? 'Unknown Department';
        String pos = candidate['position'] ?? 'Unknown Position';
        String party = candidate['party'] ?? 'Independent';
        String platform = candidate['platform'] ?? 'No platform provided.';
        int voteCount = candidate['voteCount'] is int ? candidate['voteCount'] : 0;

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Banner
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: const BoxDecoration(
                    color: nemsuBlue,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: nemsuGold,
                        child: Text(
                          _getInitials(name),
                          style: const TextStyle(color: nemsuBlue, fontWeight: FontWeight.w900, fontSize: 22),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$pos  •  $party',
                              style: const TextStyle(color: nemsuGold, fontSize: 14.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(22.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Scope & Vote Count Chips
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.domain_rounded, size: 16, color: Color(0xFF475569)),
                                const SizedBox(width: 6),
                                Text(
                                  _getScopeAbbreviation(dept),
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.how_to_vote_rounded, size: 16, color: Color(0xFF059669)),
                                const SizedBox(width: 6),
                                Text(
                                  '$voteCount votes recorded',
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Platform Section
                      const Text(
                        'Campaign Platform & Manifesto',
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: nemsuBlue),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          platform,
                          style: const TextStyle(fontSize: 14.5, height: 1.5, color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                ),

                // Footer
                Padding(
                  padding: const EdgeInsets.only(left: 22, right: 22, bottom: 18),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: nemsuBlue)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 5. DELETE CANDIDATE ---
  void _confirmDelete(String docId, String candidateName, String department, String position) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text('Remove Candidate?', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently remove $candidateName ($position - ${_getScopeAbbreviation(department)}) from the official election roster?',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 14))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.collection('candidates').doc(docId).delete();
                await FirebaseFirestore.instance.collection('audit_logs').add({
                  'timestamp': FieldValue.serverTimestamp(),
                  'action': 'Candidate Removed',
                  'user': 'admin',
                  'type': 'Candidate Management',
                  'details': {'candidate': candidateName, 'department': department, 'position': position},
                });

                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Candidate "$candidateName" removed.'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to remove candidate: $e'), backgroundColor: Colors.redAccent),
                );
              }
            },
            child: const Text('Confirm Remove', style: TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  // --- 6. TOP KPI METRICS BAR ---
  Widget _buildKpiSummaryBar(List<QueryDocumentSnapshot> docs) {
    int totalCandidates = docs.length;
    int usgCandidates = docs.where((d) => (d.data() as Map<String, dynamic>)['department'] == 'University-Wide (USG)').length;
    int collegeCandidates = docs.where((d) => (d.data() as Map<String, dynamic>)['department'] != 'University-Wide (USG)').length;
    int distinctParties = docs
        .map((d) => ((d.data() as Map<String, dynamic>)['party'] ?? '').toString().trim())
        .where((p) => p.isNotEmpty)
        .toSet()
        .length;

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
            Icons.group_outlined,
            'Total Candidates',
            '$totalCandidates',
            nemsuBlue,
            'Total registered candidates across USG and all 5 College Student Councils.',
          ),
          const SizedBox(width: 14),
          _buildKpiDivider(),
          const SizedBox(width: 14),
          _buildKpiItem(
            Icons.account_balance_outlined,
            'USG Roster',
            '$usgCandidates',
            const Color(0xFF2563EB),
            'Candidates running for University Student Government campus-wide offices and senate.',
          ),
          const SizedBox(width: 14),
          _buildKpiDivider(),
          const SizedBox(width: 14),
          _buildKpiItem(
            Icons.domain_rounded,
            'College Councils',
            '$collegeCandidates',
            const Color(0xFF0D9488),
            'Candidates running for local departmental student councils (CITE, CBM, CTE, CET, CAS).',
          ),
          const SizedBox(width: 14),
          _buildKpiDivider(),
          const SizedBox(width: 14),
          _buildKpiItem(
            Icons.flag_outlined,
            'Parties Registered',
            '$distinctParties',
            const Color(0xFFD97706),
            'Distinct political party affiliations and independent candidate slates represented.',
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
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
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
    return Container(height: 28, width: 1, color: const Color(0xFFE2E8F0));
  }

  // --- 5. PAGINATED DATA TABLE VIEW (MATCHED SYSTEM TYPOGRAPHY) ---
  Widget _buildCandidatesTable(List<QueryDocumentSnapshot> pageCandidates) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, tableConstraints) {
            double availableWidth = tableConstraints.maxWidth;
            double tableWidth = availableWidth > 980 ? availableWidth : 980;
            double columnSpacing = availableWidth > 1350 ? 36.0 : (availableWidth > 1100 ? 26.0 : 18.0);

            return Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                physics: const AlwaysScrollableScrollPhysics(),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: tableWidth),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      horizontalMargin: 20,
                      columnSpacing: columnSpacing,
                      headingRowHeight: 52,
                      dataRowMinHeight: 64,
                      dataRowMaxHeight: 70,
                      columns: const [
                        DataColumn(label: Text('Candidate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: nemsuBlue))),
                        DataColumn(label: Text('College / Scope', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: nemsuBlue))),
                        DataColumn(label: Text('Position', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: nemsuBlue))),
                        DataColumn(label: Text('Party Affiliation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: nemsuBlue))),
                        DataColumn(label: Text('Platform Snippet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: nemsuBlue))),
                        DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: nemsuBlue))),
                      ],
                      rows: pageCandidates.map((doc) {
                        var candidate = doc.data() as Map<String, dynamic>;
                        String docId = doc.id;
                        String name = candidate['name'] ?? 'Unnamed Candidate';
                        String dept = candidate['department'] ?? 'Unknown Scope';
                        String pos = candidate['position'] ?? 'Unknown Position';
                        String party = candidate['party'] ?? 'Independent';
                        String platform = candidate['platform'] ?? 'No platform statement submitted.';
                        bool isIndependent = party.toLowerCase().contains('independent');

                        return DataRow(
                          cells: [
                            // Candidate Name & Initials Avatar
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: nemsuGold,
                                    child: Text(
                                      _getInitials(name),
                                      style: const TextStyle(color: nemsuBlue, fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(maxWidth: 180),
                                    child: Text(
                                      name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: nemsuBlue),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // College / Scope
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _getScopeAbbreviation(dept),
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),

                            // Position
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: nemsuBlue.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  pos,
                                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: nemsuBlue),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),

                            // Party Affiliation
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: isIndependent ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isIndependent ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE),
                                  ),
                                ),
                                child: Text(
                                  party,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isIndependent ? const Color(0xFF92400E) : const Color(0xFF1D4ED8),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),

                            // Platform Snippet
                            DataCell(
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 240),
                                child: InkWell(
                                  onTap: () => _viewCandidateProfile(candidate),
                                  borderRadius: BorderRadius.circular(6),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.format_quote_rounded, size: 14, color: Color(0xFF94A3B8)),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            platform,
                                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF475569)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Actions
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Tooltip(
                                    message: 'View Full Platform & Profile',
                                    child: InkWell(
                                      onTap: () => _viewCandidateProfile(candidate),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF475569)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: 'Edit Candidate Profile',
                                    child: InkWell(
                                      onTap: () => _showCandidateForm(docId: docId, existingCandidate: candidate),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: nemsuBlue.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.edit_outlined, size: 16, color: nemsuBlue),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Tooltip(
                                    message: 'Remove Candidate',
                                    child: InkWell(
                                      onTap: () => _confirmDelete(docId, name, dept, pos),
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // --- 6. PAGINATED CARD GRID VIEW (RESPONSIVE) ---
  Widget _buildCandidatesCardGrid(List<QueryDocumentSnapshot> pageCandidates, bool isWide) {
    return isWide
        ? GridView.builder(
            padding: const EdgeInsets.symmetric(vertical: 2),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisExtent: 215,
              crossAxisSpacing: 14,
              mainAxisSpacing: 12,
            ),
            itemCount: pageCandidates.length,
            itemBuilder: (context, index) {
              var doc = pageCandidates[index];
              return _buildCandidateCard(doc.data() as Map<String, dynamic>, doc.id);
            },
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 2),
            itemCount: pageCandidates.length,
            itemBuilder: (context, index) {
              var doc = pageCandidates[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: SizedBox(
                  height: 215,
                  child: _buildCandidateCard(doc.data() as Map<String, dynamic>, doc.id),
                ),
              );
            },
          );
  }

  // --- 7. CANDIDATE CARD ITEM ---
  Widget _buildCandidateCard(Map<String, dynamic> candidate, String docId) {
    String name = candidate['name'] ?? 'Unnamed Candidate';
    String dept = candidate['department'] ?? 'Unknown Scope';
    String pos = candidate['position'] ?? 'Unknown Position';
    String party = candidate['party'] ?? 'Independent';
    String platform = candidate['platform'] ?? 'No platform statement submitted.';
    bool isIndependent = party.toLowerCase().contains('independent');

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _viewCandidateProfile(candidate),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Avatar + Name + Position & Scope Tags
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: nemsuGold,
                    child: Text(
                      _getInitials(name),
                      style: const TextStyle(color: nemsuBlue, fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: nemsuBlue),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: [
                            // Position Tag
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: nemsuBlue.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                pos,
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: nemsuBlue),
                              ),
                            ),
                            // Scope Tag
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                _getScopeAbbreviation(dept),
                                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Party Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: isIndependent ? const Color(0xFFFEF3C7) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isIndependent ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE),
                      ),
                    ),
                    child: Text(
                      party,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: isIndependent ? const Color(0xFF92400E) : const Color(0xFF1D4ED8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Platform Snippet (2 Lines)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.format_quote_rounded, size: 15, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          platform,
                          style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Color(0xFF475569), height: 1.35),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Bottom Action Bar
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _viewCandidateProfile(candidate),
                    icon: const Icon(Icons.visibility_outlined, size: 15, color: Color(0xFF64748B)),
                    label: const Text('View Platform', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: nemsuBlue,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => _showCandidateForm(docId: docId, existingCandidate: candidate),
                        icon: const Icon(Icons.edit_outlined, size: 13),
                        label: const Text('Edit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 6),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Color(0xFFFECDD3)),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: () => _confirmDelete(docId, name, dept, pos),
                        icon: const Icon(Icons.delete_outline_rounded, size: 13),
                        label: const Text('Remove', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- 8. PAGINATION CONTROLS BAR (RESPONSIVE) ---
  Widget _buildPaginationBar(int totalCount, int totalPages, bool isMobile) {
    int startItem = totalCount == 0 ? 0 : (_currentPage * _pageSize) + 1;
    int endItem = ((_currentPage + 1) * _pageSize) > totalCount ? totalCount : ((_currentPage + 1) * _pageSize);

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Text('Rows: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                    Container(
                      height: 28,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _pageSize,
                          items: _pageSizeOptions.map((size) {
                            return DropdownMenuItem(value: size, child: Text('$size', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)));
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
                Text(
                  'Showing $startItem-$endItem of $totalCount',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF334155), fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.first_page_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'First Page',
                  color: _currentPage > 0 ? nemsuBlue : Colors.grey.shade400,
                  onPressed: _currentPage > 0 ? () => setState(() => _currentPage = 0) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Previous Page',
                  color: _currentPage > 0 ? nemsuBlue : Colors.grey.shade400,
                  onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Text(
                    'Page ${_currentPage + 1} of ${totalPages == 0 ? 1 : totalPages}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: nemsuBlue),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Next Page',
                  color: _currentPage < totalPages - 1 ? nemsuBlue : Colors.grey.shade400,
                  onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.last_page_rounded, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Last Page',
                  color: _currentPage < totalPages - 1 ? nemsuBlue : Colors.grey.shade400,
                  onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage = totalPages - 1) : null,
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: Rows per page & Range
          Row(
            children: [
              const Text('Rows per page: ', style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
              Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _pageSize,
                    items: _pageSizeOptions.map((size) {
                      return DropdownMenuItem(value: size, child: Text('$size', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)));
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
              const SizedBox(width: 14),
              Text(
                'Showing $startItem-$endItem of $totalCount candidates',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), fontWeight: FontWeight.w600),
              ),
            ],
          ),

          // Right: Page navigation buttons
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.first_page_rounded, size: 20),
                tooltip: 'First Page',
                color: _currentPage > 0 ? nemsuBlue : Colors.grey.shade400,
                onPressed: _currentPage > 0 ? () => setState(() => _currentPage = 0) : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                tooltip: 'Previous Page',
                color: _currentPage > 0 ? nemsuBlue : Colors.grey.shade400,
                onPressed: _currentPage > 0 ? () => setState(() => _currentPage--) : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  'Page ${_currentPage + 1} of ${totalPages == 0 ? 1 : totalPages}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: nemsuBlue),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                tooltip: 'Next Page',
                color: _currentPage < totalPages - 1 ? nemsuBlue : Colors.grey.shade400,
                onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage++) : null,
              ),
              IconButton(
                icon: const Icon(Icons.last_page_rounded, size: 20),
                tooltip: 'Last Page',
                color: _currentPage < totalPages - 1 ? nemsuBlue : Colors.grey.shade400,
                onPressed: _currentPage < totalPages - 1 ? () => setState(() => _currentPage = totalPages - 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingConfig) {
      return const Center(child: CircularProgressIndicator(color: nemsuBlue));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('candidates').orderBy('timestamp', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator(color: nemsuBlue));
        }

        List<QueryDocumentSnapshot> allDocs = snapshot.hasData ? snapshot.data!.docs : [];

        // Filter by Scope
        List<QueryDocumentSnapshot> filteredDocs = allDocs;
        if (_selectedScope != 'All') {
          filteredDocs = filteredDocs.where((doc) {
            return (doc.data() as Map<String, dynamic>)['department'] == _selectedScope;
          }).toList();
        }

        // Filter by Position
        if (_selectedPosition != 'All') {
          filteredDocs = filteredDocs.where((doc) {
            return (doc.data() as Map<String, dynamic>)['position'] == _selectedPosition;
          }).toList();
        }

        // Filter by Search Query (Name, Party, Platform, Position)
        if (_searchQuery.trim().isNotEmpty) {
          String query = _searchQuery.trim().toLowerCase();
          filteredDocs = filteredDocs.where((doc) {
            var data = doc.data() as Map<String, dynamic>;
            String name = (data['name'] ?? '').toString().toLowerCase();
            String party = (data['party'] ?? '').toString().toLowerCase();
            String platform = (data['platform'] ?? '').toString().toLowerCase();
            String pos = (data['position'] ?? '').toString().toLowerCase();
            String dept = (data['department'] ?? '').toString().toLowerCase();
            return name.contains(query) || party.contains(query) || platform.contains(query) || pos.contains(query) || dept.contains(query);
          }).toList();
        }

        // Sorting
        filteredDocs.sort((a, b) {
          var aData = a.data() as Map<String, dynamic>;
          var bData = b.data() as Map<String, dynamic>;
          if (_sortBy == 'Name (A-Z)') return (aData['name'] ?? '').toString().compareTo((bData['name'] ?? '').toString());
          if (_sortBy == 'Name (Z-A)') return (bData['name'] ?? '').toString().compareTo((aData['name'] ?? '').toString());
          if (_sortBy == 'Position') return (aData['position'] ?? '').toString().compareTo((bData['position'] ?? '').toString());
          if (_sortBy == 'Party') return (aData['party'] ?? '').toString().compareTo((bData['party'] ?? '').toString());
          
          // Default / Newest First
          var aTs = aData['timestamp'];
          var bTs = bData['timestamp'];
          if (aTs is Timestamp && bTs is Timestamp) {
            return bTs.compareTo(aTs);
          }
          return 0;
        });

        // Pagination Calculations
        int totalCount = filteredDocs.length;
        int totalPages = (totalCount / _pageSize).ceil();
        if (_currentPage >= totalPages && totalPages > 0) {
          _currentPage = totalPages - 1;
        }

        int startIdx = _currentPage * _pageSize;
        int endIdx = (startIdx + _pageSize) > totalCount ? totalCount : (startIdx + _pageSize);
        List<QueryDocumentSnapshot> pageCandidates = (startIdx < totalCount) ? filteredDocs.sublist(startIdx, endIdx) : [];

        List<String> availablePositionsForScope = ['All', ..._getFilterPositionsList()];

        return LayoutBuilder(
          builder: (context, constraints) {
            bool isMobile = constraints.maxWidth < 700;
            bool isWide = constraints.maxWidth > 850;
            bool isTableView = _userSelectedTableView ?? !isMobile;

            return Column(
              children: [
                // --- TOP INTEGRATED HEADER & ACTION ---
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
                                  'Candidate Management',
                                  style: TextStyle(
                                    fontSize: isMobile ? 20 : 23,
                                    fontWeight: FontWeight.w800,
                                    color: nemsuBlue,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Organize and manage candidates for USG and all College Councils in real-time',
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
                                  message: 'Card Grid View',
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

                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: nemsuBlue,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 18, vertical: isMobile ? 10 : 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () => _showCandidateForm(),
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: nemsuGold),
                            label: Text(isMobile ? 'Add' : 'Add Candidate', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // KPI Summary Bar
                      _buildKpiSummaryBar(allDocs),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // --- INTEGRATED TOOLBAR: SEARCH & SCOPE & POSITION & SORT FILTERS ---
                Container(
                  width: double.infinity,
                  color: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 14 : 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search Bar & Position & Sort Dropdowns
                      isMobile
                          ? SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 220,
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
                                        hintText: 'Search candidate, party, position...',
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
                                  ),
                                  const SizedBox(width: 8),

                                  // Position Sub-Filter Dropdown
                                  Container(
                                    height: 38,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: availablePositionsForScope.contains(_selectedPosition) ? _selectedPosition : 'All',
                                        icon: const Icon(Icons.filter_list_rounded, size: 15, color: nemsuBlue),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: nemsuBlue),
                                        items: availablePositionsForScope.map((pos) {
                                          return DropdownMenuItem(
                                            value: pos,
                                            child: Text(pos == 'All' ? 'All Positions' : pos, style: const TextStyle(fontSize: 12)),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _selectedPosition = val;
                                              _currentPage = 0;
                                            });
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),

                                  // Sort Dropdown
                                  Container(
                                    height: 38,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _sortBy,
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
                                  ),
                                ],
                              ),
                            )
                          : Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: SizedBox(
                                    height: 40,
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: (val) {
                                        setState(() {
                                          _searchQuery = val;
                                          _currentPage = 0;
                                        });
                                      },
                                      style: const TextStyle(fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: 'Search by candidate name, party, position, or platform...',
                                        hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
                                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: Color(0xFF64748B)),
                                        suffixIcon: _searchQuery.isNotEmpty
                                            ? IconButton(
                                                icon: const Icon(Icons.clear, size: 16),
                                                onPressed: () {
                                                  _searchController.clear();
                                                  setState(() {
                                                    _searchQuery = '';
                                                    _currentPage = 0;
                                                  });
                                                },
                                              )
                                            : null,
                                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                        filled: true,
                                        fillColor: const Color(0xFFF1F5F9),
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Position Sub-Filter Dropdown
                                Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: availablePositionsForScope.contains(_selectedPosition) ? _selectedPosition : 'All',
                                      icon: const Icon(Icons.filter_list_rounded, size: 18, color: nemsuBlue),
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: nemsuBlue),
                                      items: availablePositionsForScope.map((pos) {
                                        return DropdownMenuItem(
                                          value: pos,
                                          child: Text(pos == 'All' ? 'All Positions' : pos, style: const TextStyle(fontSize: 13.5)),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          setState(() {
                                            _selectedPosition = val;
                                            _currentPage = 0;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Sort Dropdown
                                Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _sortBy,
                                      icon: const Icon(Icons.sort_rounded, size: 18, color: nemsuBlue),
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: nemsuBlue),
                                      items: _sortOptions.map((opt) {
                                        return DropdownMenuItem(
                                          value: opt,
                                          child: Text('Sort: $opt', style: const TextStyle(fontSize: 13.5)),
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
                                ),
                              ],
                            ),
                      const SizedBox(height: 8),

                      // College Scope Filter Chips Bar
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildScopeFilterChip('All', allDocs.length),
                            const SizedBox(width: 6),
                            ..._canonicalScopes.map((scope) {
                              int count = allDocs.where((d) => (d.data() as Map<String, dynamic>)['department'] == scope).length;
                              return Padding(
                                padding: const EdgeInsets.only(right: 6.0),
                                child: _buildScopeFilterChip(scope, count, displayName: _getScopeAbbreviation(scope)),
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),

                // --- CANDIDATE LIST / GRID / TABLE ---
                Expanded(
                  child: filteredDocs.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_search_rounded, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 10),
                              Text(
                                _searchQuery.isNotEmpty || _selectedScope != 'All' || _selectedPosition != 'All'
                                    ? 'No candidates found matching the selected filters.'
                                    : 'No candidates registered in the roster yet.',
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 14),
                              if (_searchQuery.isNotEmpty || _selectedScope != 'All' || _selectedPosition != 'All')
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: nemsuBlue,
                                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _searchController.clear();
                                      _searchQuery = '';
                                      _selectedScope = 'All';
                                      _selectedPosition = 'All';
                                      _sortBy = 'Newest First';
                                      _currentPage = 0;
                                    });
                                  },
                                  icon: const Icon(Icons.clear_all_rounded, size: 18),
                                  label: const Text('Clear All Filters', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                )
                              else
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: nemsuBlue,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onPressed: () => _showCandidateForm(),
                                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: nemsuGold),
                                  label: const Text('Add First Candidate', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        )
                      : Padding(
                          padding: EdgeInsets.symmetric(horizontal: isMobile ? 12.0 : 20.0, vertical: 12.0),
                          child: isTableView ? _buildCandidatesTable(pageCandidates) : _buildCandidatesCardGrid(pageCandidates, isWide),
                        ),
                ),

                // --- PAGINATION BAR ---
                _buildPaginationBar(totalCount, totalPages, isMobile),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildScopeFilterChip(String scope, int count, {String? displayName}) {
    bool isSelected = _selectedScope == scope;
    String label = displayName ?? scope;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedScope = scope;
          _selectedPosition = 'All'; // Reset position sub-filter on scope change
          _currentPage = 0;
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? nemsuBlue : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? nemsuBlue : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF475569),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: isSelected ? nemsuGold : const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? nemsuBlue : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}