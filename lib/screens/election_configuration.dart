import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';
import '../services/ai_ocr_service.dart';

class ElectionConfiguration extends StatefulWidget {
  const ElectionConfiguration({super.key});

  @override
  State<ElectionConfiguration> createState() => _ElectionConfigurationState();
}

class _ElectionConfigurationState extends State<ElectionConfiguration> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // --- SETTINGS STATE ---
  DateTime? startDate = DateTime.now();
  TimeOfDay? startTime = const TimeOfDay(hour: 8, minute: 0);
  DateTime? endDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay? endTime = const TimeOfDay(hour: 17, minute: 0);

  List<Map<String, dynamic>> positionRules = [];
  bool isLoading = true;
  bool _isSaving = false;

  // --- POSITION FILTER & SEARCH ---
  String _selectedScopeFilter = 'All';
  String _positionSearchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // --- ACADEMIC PERIOD STATE ---
  String _selectedAcademicYear = '2026-2027';
  String _selectedSemester = '1st Semester';
  bool _enforceTermVerification = true;

  final List<String> _academicYearOptions = [
    '2024-2025',
    '2025-2026',
    '2026-2027',
    '2027-2028',
    '2028-2029',
    '2029-2030',
  ];

  final List<String> _semesterOptions = [
    '1st Semester',
    '2nd Semester',
    'Summer / Midyear',
  ];

  final TextEditingController _apiKeyController = TextEditingController();
  bool _isApiKeyVisible = false;
  bool _isTestingKey = false;
  ApiTestResult? _lastTestResult;
  String _activeModelName = geminiModelName;
  List<String> _availableVisionModels = List.from(presetVisionModels);

  // Official Canonical Colleges & Scopes matching DemocraSync
  final List<String> scopes = [
    'University-Wide (USG)',
    'College of Information Technology Education',
    'College of Business and Management',
    'College of Teacher Education',
    'College of Engineering and Technology',
    'College of Arts and Sciences',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadConfiguration();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _apiKeyController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- DEDUPLICATE POSITIONS HELPER ---
  List<Map<String, dynamic>> _deduplicatePositions(List<Map<String, dynamic>> rawList) {
    Map<String, Map<String, dynamic>> unique = {};
    for (var item in rawList) {
      String pos = (item['position'] ?? '').toString().trim();
      String scope = (item['scope'] ?? '').toString().trim();
      if (pos.isNotEmpty && scope.isNotEmpty) {
        String key = '$scope::$pos';
        unique[key] = item;
      }
    }
    return unique.values.toList();
  }

  // --- STANDARD POSITIONS TEMPLATE GENERATOR ---
  List<Map<String, dynamic>> _generateDefaultPositions() {
    List<Map<String, dynamic>> generatedPositions = [
      {'position': 'President', 'scope': 'University-Wide (USG)', 'maxElected': 1},
      {'position': 'Vice President for Internal Affairs', 'scope': 'University-Wide (USG)', 'maxElected': 1},
      {'position': 'Vice President for External Affairs', 'scope': 'University-Wide (USG)', 'maxElected': 1},
      {'position': 'Executive Secretary', 'scope': 'University-Wide (USG)', 'maxElected': 1},
      {'position': 'Treasurer', 'scope': 'University-Wide (USG)', 'maxElected': 1},
      {'position': 'Auditor', 'scope': 'University-Wide (USG)', 'maxElected': 1},
      {'position': 'Senator', 'scope': 'University-Wide (USG)', 'maxElected': 12},
    ];

    for (String scope in scopes) {
      if (scope != 'University-Wide (USG)') {
        generatedPositions.addAll([
          {'position': 'Governor', 'scope': scope, 'maxElected': 1},
          {'position': 'Vice Governor', 'scope': scope, 'maxElected': 1},
          {'position': 'Secretary Treasurer', 'scope': scope, 'maxElected': 1},
          {'position': 'College Auditor', 'scope': scope, 'maxElected': 1},
          {'position': 'Public Information Officer', 'scope': scope, 'maxElected': 2},
          {'position': 'Business Manager', 'scope': scope, 'maxElected': 2},
          {'position': 'Sargeant at Arms', 'scope': scope, 'maxElected': 2},
          {'position': 'Program/Year Level Rep', 'scope': scope, 'maxElected': 4}, 
        ]);
      }
    }
    return _deduplicatePositions(generatedPositions);
  }

  // --- FIREBASE: LOAD CONFIGURATION ---
  Future<void> _loadConfiguration() async {
    try {
      String activeKey = await AiOcrService().getActiveApiKey();
      String activeModel = await AiOcrService().getActiveModelName();
      _apiKeyController.text = activeKey;
      _activeModelName = activeModel;
      if (!_availableVisionModels.contains(activeModel)) {
        _availableVisionModels.insert(0, activeModel);
      }

      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('config').doc('election_settings').get();
      
      if (doc.exists && doc.data() != null) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        setState(() {
          if (data.containsKey('academicYear') && data['academicYear'] != null) {
            String ay = data['academicYear'].toString().trim();
            if (ay.isNotEmpty) {
              if (!_academicYearOptions.contains(ay)) {
                _academicYearOptions.insert(0, ay);
              }
              _selectedAcademicYear = ay;
            }
          }
          if (data.containsKey('semester') && data['semester'] != null) {
            String sem = data['semester'].toString().trim();
            if (sem.isNotEmpty) {
              if (!_semesterOptions.contains(sem)) {
                _semesterOptions.insert(0, sem);
              }
              _selectedSemester = sem;
            }
          }
          if (data.containsKey('enforceTermVerification')) {
            _enforceTermVerification = data['enforceTermVerification'] != false;
          }

          if (data.containsKey('positions') && data['positions'] is List && (data['positions'] as List).isNotEmpty) {
            List<Map<String, dynamic>> loadedPositions = List<Map<String, dynamic>>.from(data['positions']);

            // Deduplicate loaded positions
            loadedPositions = _deduplicatePositions(loadedPositions);

            // Guarantee every standard college has its elective positions configured
            for (String scope in scopes) {
              bool hasPositions = loadedPositions.any((p) => p['scope'] == scope);
              if (!hasPositions) {
                if (scope == 'University-Wide (USG)') {
                  loadedPositions.addAll([
                    {'position': 'President', 'scope': 'University-Wide (USG)', 'maxElected': 1},
                    {'position': 'Vice President for Internal Affairs', 'scope': 'University-Wide (USG)', 'maxElected': 1},
                    {'position': 'Vice President for External Affairs', 'scope': 'University-Wide (USG)', 'maxElected': 1},
                    {'position': 'Executive Secretary', 'scope': 'University-Wide (USG)', 'maxElected': 1},
                    {'position': 'Treasurer', 'scope': 'University-Wide (USG)', 'maxElected': 1},
                    {'position': 'Auditor', 'scope': 'University-Wide (USG)', 'maxElected': 1},
                    {'position': 'Senator', 'scope': 'University-Wide (USG)', 'maxElected': 12},
                  ]);
                } else {
                  loadedPositions.addAll([
                    {'position': 'Governor', 'scope': scope, 'maxElected': 1},
                    {'position': 'Vice Governor', 'scope': scope, 'maxElected': 1},
                    {'position': 'Secretary Treasurer', 'scope': scope, 'maxElected': 1},
                    {'position': 'College Auditor', 'scope': scope, 'maxElected': 1},
                    {'position': 'Public Information Officer', 'scope': scope, 'maxElected': 2},
                    {'position': 'Business Manager', 'scope': scope, 'maxElected': 2},
                    {'position': 'Sargeant at Arms', 'scope': scope, 'maxElected': 2},
                    {'position': 'Program/Year Level Rep', 'scope': scope, 'maxElected': 4},
                  ]);
                }
              }
            }
            positionRules = _deduplicatePositions(loadedPositions);
          } else {
            positionRules = _generateDefaultPositions();
          }
          
          if (data.containsKey('schedule')) {
            var sched = data['schedule'];
            if (sched['start'] != null) {
              DateTime parsedStart = DateTime.parse(sched['start']);
              startDate = parsedStart;
              startTime = TimeOfDay.fromDateTime(parsedStart);
            }
            if (sched['end'] != null) {
              DateTime parsedEnd = DateTime.parse(sched['end']);
              endDate = parsedEnd;
              endTime = TimeOfDay.fromDateTime(parsedEnd);
            }
          }

          isLoading = false;
        });
      } else {
        setState(() {
          positionRules = _generateDefaultPositions();
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading config: $e");
      setState(() => isLoading = false);
    }
  }

  // --- FIREBASE: SAVE CONFIGURATION ---
  Future<void> _saveConfiguration() async {
    setState(() => _isSaving = true);
    try {
      DateTime? combinedStart;
      if (startDate != null && startTime != null) {
        combinedStart = DateTime(startDate!.year, startDate!.month, startDate!.day, startTime!.hour, startTime!.minute);
      }
      
      DateTime? combinedEnd;
      if (endDate != null && endTime != null) {
        combinedEnd = DateTime(endDate!.year, endDate!.month, endDate!.day, endTime!.hour, endTime!.minute);
      }

      final deduplicated = _deduplicatePositions(positionRules);

      await FirebaseFirestore.instance.collection('config').doc('election_settings').set({
        'positions': deduplicated,
        'schedule': {
          'start': combinedStart?.toIso8601String(),
          'end': combinedEnd?.toIso8601String(),
        },
        'academicYear': _selectedAcademicYear,
        'semester': _selectedSemester,
        'enforceTermVerification': _enforceTermVerification,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await AiOcrService().saveApiKey(_apiKeyController.text.trim(), modelName: _activeModelName);

      if (!mounted) return;
      setState(() {
        positionRules = deduplicated;
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Election Configuration successfully saved to database!'),
            ],
          ),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving settings: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _restoreStandardPositions() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.restart_alt_rounded, color: nemsuBlue, size: 22),
            SizedBox(width: 8),
            Text('Restore Standard Positions?', style: TextStyle(color: nemsuBlue, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'This will reset the elective positions roster to the official COMSELEC template (7 USG positions and 8 positions for each of the 5 colleges, totaling 47 positions).\n\nAre you sure you want to proceed?',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: nemsuBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore All Standard Positions'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        positionRules = _generateDefaultPositions();
        _selectedScopeFilter = 'All';
        _positionSearchQuery = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Standard elective positions restored for USG and all colleges! Click "Save Configuration" to persist.'),
          backgroundColor: nemsuBlue,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _testApiKey() async {
    String key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _lastTestResult = ApiTestResult.failure(
          message: 'Please enter an API key to test.',
          tip: 'Obtain a free Gemini API Key from https://aistudio.google.com/',
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an API key to test.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() {
      _isTestingKey = true;
      _lastTestResult = null;
    });

    ApiTestResult result = await AiOcrService().testApiKey(key, preferredModel: _activeModelName);

    if (!mounted) return;
    setState(() {
      _isTestingKey = false;
      _lastTestResult = result;
      if (result.availableModels != null && result.availableModels!.isNotEmpty) {
        for (var m in result.availableModels!) {
          if (!_availableVisionModels.contains(m)) {
            _availableVisionModels.add(m);
          }
        }
      }
      if (result.isValid && result.detectedModelName != null) {
        _activeModelName = result.detectedModelName!;
        if (!_availableVisionModels.contains(_activeModelName)) {
          _availableVisionModels.insert(0, _activeModelName);
        }
      }
    });

    if (result.isValid) {
      AiOcrService().saveApiKey(key, modelName: _activeModelName).ignore();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${result.message} (Auto-saved)'),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('API Key test failed: ${result.message}'),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _resetElectionData() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text('Reset Election Data?', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const Text(
          'This will permanently delete all cast votes, reset all candidate tallies to zero, and restore voting eligibility for all students.\n\nThis action CANNOT be undone.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Confirm Reset'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      var candidates = await FirebaseFirestore.instance.collection('candidates').get();
      for (var doc in candidates.docs) {
        batch.update(doc.reference, {'voteCount': 0});
      }

      var votes = await FirebaseFirestore.instance.collection('votes').get();
      for (var doc in votes.docs) {
        batch.delete(doc.reference);
      }

      var voters = await FirebaseFirestore.instance.collection('voters').get();
      for (var doc in voters.docs) {
        batch.update(doc.reference, {'hasVoted': false});
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All election votes and candidate tallies reset successfully!'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error resetting: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _pickDateTime(bool isStart) async {
    DateTime initialDate = isStart ? (startDate ?? DateTime.now()) : (endDate ?? DateTime.now());
    TimeOfDay initialTime = isStart ? (startTime ?? TimeOfDay.now()) : (endTime ?? TimeOfDay.now());

    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: nemsuBlue, onPrimary: Colors.white, onSurface: Colors.black),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null) {
      if (!mounted) return;
      TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: initialTime,
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(primary: nemsuBlue, onPrimary: Colors.white, onSurface: Colors.black),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          if (isStart) {
            startDate = pickedDate;
            startTime = pickedTime;
          } else {
            endDate = pickedDate;
            endTime = pickedTime;
          }
        });
      }
    }
  }

  void _showPositionForm({Map<String, dynamic>? existingRule, int? index}) {
    bool isEdit = existingRule != null;
    
    TextEditingController positionController = TextEditingController(text: isEdit ? existingRule['position'] : '');
    TextEditingController maxElectedController = TextEditingController(text: isEdit ? existingRule['maxElected'].toString() : '1');
    String selectedScope = isEdit ? existingRule['scope'] : scopes.first;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              title: Row(
                children: [
                  Icon(isEdit ? Icons.edit_rounded : Icons.add_circle_outline_rounded, color: nemsuBlue, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    isEdit ? 'Edit Elective Position' : 'Add Elective Position',
                    style: const TextStyle(color: nemsuBlue, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 420,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: positionController,
                        decoration: InputDecoration(
                          labelText: 'Position Title (e.g. USG President)',
                          hintText: 'Enter position title',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: selectedScope,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Jurisdiction / Department Scope',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: scopes.map((s) => DropdownMenuItem(
                          value: s, 
                          child: Text(s, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)
                        )).toList(),
                        onChanged: (val) => setDialogState(() => selectedScope = val!),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: maxElectedController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Seats Available (Max Elected)',
                          hintText: 'e.g. 1 for President, 12 for Senators',
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: nemsuBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    if (positionController.text.trim().isEmpty) return;

                    setState(() {
                      Map<String, dynamic> newRule = {
                        'position': positionController.text.trim(),
                        'scope': selectedScope,
                        'maxElected': int.tryParse(maxElectedController.text) ?? 1,
                      };

                      if (isEdit) {
                        positionRules[index!] = newRule;
                      } else {
                        positionRules.add(newRule);
                      }
                      positionRules = _deduplicatePositions(positionRules);
                    });
                    Navigator.pop(context);
                  },
                  child: Text(isEdit ? 'Update Position' : 'Save Position'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _getElectionStatus() {
    if (startDate == null || endDate == null || startTime == null || endTime == null) {
      return 'UNCONFIGURED';
    }
    DateTime now = DateTime.now();
    DateTime start = DateTime(startDate!.year, startDate!.month, startDate!.day, startTime!.hour, startTime!.minute);
    DateTime end = DateTime(endDate!.year, endDate!.month, endDate!.day, endTime!.hour, endTime!.minute);

    if (now.isBefore(start)) {
      return 'UPCOMING';
    } else if (now.isAfter(end)) {
      return 'CONCLUDED';
    } else {
      return 'ACTIVE NOW';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'ACTIVE NOW': return const Color(0xFF10B981);
      case 'UPCOMING': return const Color(0xFF2563EB);
      case 'CONCLUDED': return const Color(0xFF64748B);
      default: return const Color(0xFFF59E0B);
    }
  }

  List<Map<String, dynamic>> _getFilteredPositions() {
    return positionRules.where((rule) {
      final scope = rule['scope']?.toString() ?? '';
      final title = rule['position']?.toString().toLowerCase() ?? '';

      bool matchesScope = _selectedScopeFilter == 'All' || scope == _selectedScopeFilter;
      bool matchesSearch = _positionSearchQuery.isEmpty || title.contains(_positionSearchQuery.toLowerCase());

      return matchesScope && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: nemsuBlue));
    }

    String status = _getElectionStatus();
    Color statusColor = _getStatusColor(status);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Column(
        children: [
          // --- CLEAN INTEGRATED HEADER & TABS BAR ---
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Title & Action Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Election Configuration',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: nemsuBlue, letterSpacing: -0.3),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.35), width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      status,
                                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: statusColor, letterSpacing: 0.3),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Configure schedules, available seats, academic term, and AI OCR',
                            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: nemsuGold,
                        foregroundColor: nemsuBlue,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isSaving ? null : _saveConfiguration,
                      icon: _isSaving
                          ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: nemsuBlue))
                          : const Icon(Icons.cloud_upload_rounded, size: 15),
                      label: Text(
                        _isSaving ? 'Saving...' : 'Save Configuration',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Sleek Segmented Tab Pills
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: nemsuBlue,
                    unselectedLabelColor: const Color(0xFF64748B),
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(7),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1)),
                      ],
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
                    unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5),
                    tabs: [
                      const Tab(
                        height: 32,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule_rounded, size: 14),
                              SizedBox(width: 5),
                              Text('1. Timeline & Term'),
                            ],
                          ),
                        ),
                      ),
                      Tab(
                        height: 32,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.how_to_vote_rounded, size: 14),
                              const SizedBox(width: 5),
                              const Text('2. Elective Positions'),
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: nemsuBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${positionRules.length}',
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: nemsuBlue),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Tab(
                        height: 32,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome_rounded, size: 14),
                              SizedBox(width: 5),
                              Text('3. AI OCR & System'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // --- TAB VIEWS ---
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTimelineAndTermTab(),
                _buildPositionsTab(),
                _buildAiAndSystemTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: TIMELINE & ACADEMIC TERM
  // ==========================================
  Widget _buildTimelineAndTermTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 850;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildScheduleCard()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildAcademicTermCard()),
                  ],
                )
              : Column(
                  children: [
                    _buildScheduleCard(),
                    const SizedBox(height: 16),
                    _buildAcademicTermCard(),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildScheduleCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: nemsuBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.schedule_rounded, color: nemsuBlue, size: 18),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Election Schedule', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: nemsuBlue)),
                  Text('Voting window opening and closing dates/times', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          _buildDateTimeTile(
            label: 'Start of Voting',
            icon: Icons.play_circle_outline_rounded,
            iconColor: const Color(0xFF10B981),
            date: startDate,
            time: startTime,
            onChange: () => _pickDateTime(true),
          ),
          const SizedBox(height: 10),
          _buildDateTimeTile(
            label: 'End of Voting',
            icon: Icons.stop_circle_outlined,
            iconColor: const Color(0xFFE11D48),
            date: endDate,
            time: endTime,
            onChange: () => _pickDateTime(false),
          ),
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Student ballots will automatically lock outside these scheduled hours.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicTermCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: nemsuGold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.school_rounded, color: Color(0xFFB45309), size: 18),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Academic Period & COR Verification', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: nemsuBlue)),
                  Text('Term matching rules for student registrations', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 14),

          _buildAcademicYearDropdown(),
          const SizedBox(height: 12),
          _buildSemesterDropdown(),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _enforceTermVerification ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _enforceTermVerification ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _enforceTermVerification ? Icons.verified_user_rounded : Icons.shield_outlined,
                            size: 16,
                            color: _enforceTermVerification ? const Color(0xFF15803D) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Enforce Term Matching on CORs',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _enforceTermVerification ? const Color(0xFF15803D) : const Color(0xFF334155),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Automatically flag or reject Certificate of Registration (COR) documents from past academic years or semesters.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _enforceTermVerification,
                  activeThumbColor: const Color(0xFF10B981),
                  onChanged: (val) => setState(() => _enforceTermVerification = val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeTile({
    required String label,
    required IconData icon,
    required Color iconColor,
    required DateTime? date,
    required TimeOfDay? time,
    required VoidCallback onChange,
  }) {
    String formattedDate = date != null
        ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
        : 'Not Set';
    String formattedTime = time != null ? time.format(context) : 'Not Set';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '$formattedDate  •  $formattedTime',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: nemsuBlue,
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            onPressed: onChange,
            icon: const Icon(Icons.edit_calendar_rounded, size: 14),
            label: const Text('Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: ELECTIVE POSITIONS
  // ==========================================
  Widget _buildPositionsTab() {
    List<Map<String, dynamic>> filtered = _getFilteredPositions();

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 850;

        return Column(
          children: [
            // --- FULL-WIDTH INTEGRATED TOOLBAR ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isWide)
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: TextField(
                              controller: _searchController,
                              onChanged: (val) => setState(() => _positionSearchQuery = val),
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Search elective positions...',
                                hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
                                suffixIcon: _positionSearchQuery.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 14),
                                        onPressed: () {
                                          _searchController.clear();
                                          setState(() => _positionSearchQuery = '');
                                        },
                                      )
                                    : null,
                                contentPadding: EdgeInsets.zero,
                                filled: true,
                                fillColor: const Color(0xFFF1F5F9),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide.none),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: nemsuBlue,
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                          ),
                          onPressed: _restoreStandardPositions,
                          icon: const Icon(Icons.restart_alt_rounded, size: 15),
                          label: const Text('Restore Template', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: nemsuBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                          ),
                          onPressed: () => _showPositionForm(),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Position', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: (val) => setState(() => _positionSearchQuery = val),
                                  style: const TextStyle(fontSize: 12),
                                  decoration: InputDecoration(
                                    hintText: 'Search position titles...',
                                    hintStyle: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                                    prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF64748B)),
                                    suffixIcon: _positionSearchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 14),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() => _positionSearchQuery = '');
                                            },
                                          )
                                        : null,
                                    contentPadding: EdgeInsets.zero,
                                    filled: true,
                                    fillColor: const Color(0xFFF1F5F9),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(7), borderSide: BorderSide.none),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: nemsuBlue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                              ),
                              onPressed: () => _showPositionForm(),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Add Position', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: nemsuBlue,
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
                              ),
                              onPressed: _restoreStandardPositions,
                              icon: const Icon(Icons.restart_alt_rounded, size: 14),
                              label: const Text('Restore Standard Template', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),

                  // --- HORIZONTAL SCOPE FILTER CHIPS ---
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildScopeFilterChip('All', positionRules.length),
                        const SizedBox(width: 5),
                        ...scopes.map((s) {
                          int count = positionRules.where((r) => r['scope'] == s).length;
                          String shortName = s
                              .replaceAll('University-Wide (USG)', 'USG (Univ-Wide)')
                              .replaceAll('College of Information Technology Education', 'CITE (IT Education)')
                              .replaceAll('College of Business and Management', 'CBM (Business & Mgmt)')
                              .replaceAll('College of Teacher Education', 'CTE (Teacher Ed)')
                              .replaceAll('College of Engineering and Technology', 'CET (Engineering & Tech)')
                              .replaceAll('College of Arts and Sciences', 'CAS (Arts & Sciences)')
                              .replaceAll('College of ', '');
                          return Padding(
                            padding: const EdgeInsets.only(right: 5.0),
                            child: _buildScopeFilterChip(s, count, displayName: shortName),
                          );
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // --- 2-COLUMN RESPONSIVE POSITION CARDS GRID ---
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.rule_folder_rounded, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 6),
                          Text(
                            _positionSearchQuery.isNotEmpty || _selectedScopeFilter != 'All'
                                ? 'No elective positions matching this filter.'
                                : 'No elective positions configured yet.',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: nemsuBlue, foregroundColor: Colors.white),
                            onPressed: _restoreStandardPositions,
                            icon: const Icon(Icons.refresh_rounded, size: 15),
                            label: const Text('Generate Standard Positions', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    )
                  : isWide
                      ? GridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisExtent: 68,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return _buildPositionItemCard(filtered[index]);
                          },
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return _buildPositionItemCard(filtered[index]);
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPositionItemCard(Map<String, dynamic> rule) {
    int originalIndex = positionRules.indexOf(rule);
    int seats = rule['maxElected'] ?? 1;
    String scope = rule['scope'] ?? 'General';
    bool isUSG = scope.contains('USG');
    bool isCITE = scope.contains('Information Technology');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isUSG
                  ? nemsuGold.withValues(alpha: 0.15)
                  : isCITE
                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                      : nemsuBlue.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(
              isUSG
                  ? Icons.stars_rounded
                  : isCITE
                      ? Icons.terminal_rounded
                      : Icons.how_to_vote_rounded,
              color: isUSG
                  ? const Color(0xFFB45309)
                  : isCITE
                      ? const Color(0xFF15803D)
                      : nemsuBlue,
              size: 17,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  rule['position'] ?? 'Unknown',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF1E293B)),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 2),
                Text(
                  scope,
                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFFCBD5E1)),
            ),
            child: Text(
              '$seats ${seats == 1 ? "Seat" : "Seats"}',
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: nemsuBlue),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB), size: 16),
            tooltip: 'Edit Position',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => _showPositionForm(existingRule: rule, index: originalIndex),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48), size: 16),
            tooltip: 'Delete Position',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            onPressed: () => setState(() => positionRules.removeAt(originalIndex)),
          ),
        ],
      ),
    );
  }

  Widget _buildScopeFilterChip(String scopeKey, int count, {String? displayName}) {
    bool isSelected = _selectedScopeFilter == scopeKey;
    String label = displayName ?? scopeKey;

    return FilterChip(
      selected: isSelected,
      label: Text('$label ($count)'),
      labelStyle: TextStyle(
        fontSize: 10.5,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : const Color(0xFF334155),
      ),
      backgroundColor: const Color(0xFFF1F5F9),
      selectedColor: nemsuBlue,
      checkmarkColor: Colors.white,
      side: BorderSide(color: isSelected ? nemsuBlue : const Color(0xFFE2E8F0)),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      visualDensity: VisualDensity.compact,
      onSelected: (val) {
        setState(() => _selectedScopeFilter = scopeKey);
      },
    );
  }

  // ==========================================
  // TAB 3: AI OCR & SYSTEM MAINTENANCE
  // ==========================================
  Widget _buildAiAndSystemTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isWide = constraints.maxWidth > 850;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: _buildAiOcrCard()),
                    const SizedBox(width: 16),
                    Expanded(flex: 4, child: _buildDangerZoneCard()),
                  ],
                )
              : Column(
                  children: [
                    _buildAiOcrCard(),
                    const SizedBox(height: 16),
                    _buildDangerZoneCard(),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildAiOcrCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6366F1), size: 18),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Google Gemini Vision AI OCR Engine', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: nemsuBlue)),
                  Text('Automated student COR verification across platforms', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 14),

          TextFormField(
            controller: _apiKeyController,
            obscureText: !_isApiKeyVisible,
            onChanged: (_) {
              if (_lastTestResult != null) setState(() => _lastTestResult = null);
            },
            decoration: InputDecoration(
              labelText: 'Google Gemini API Key',
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              hintText: 'Enter Gemini API Key (AIzaSy...)',
              hintStyle: const TextStyle(fontSize: 12),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              suffixIcon: IconButton(
                icon: Icon(_isApiKeyVisible ? Icons.visibility : Icons.visibility_off, size: 18, color: Colors.grey),
                onPressed: () => setState(() => _isApiKeyVisible = !_isApiKeyVisible),
              ),
            ),
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            initialValue: _availableVisionModels.contains(_activeModelName) ? _activeModelName : _availableVisionModels.first,
            decoration: InputDecoration(
              labelText: 'Selected Multimodal Model',
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              helperText: 'Select high-throughput vision model (e.g. gemini-2.5-flash)',
              helperStyle: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
              prefixIcon: const Icon(Icons.memory_rounded, size: 18, color: nemsuBlue),
            ),
            items: _availableVisionModels.map((model) {
              return DropdownMenuItem<String>(
                value: model,
                child: Text(model, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              );
            }).toList(),
            onChanged: (newModel) {
              if (newModel != null) {
                setState(() {
                  _activeModelName = newModel;
                  if (_lastTestResult != null) _lastTestResult = null;
                });
              }
            },
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: nemsuBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isTestingKey ? null : _testApiKey,
                icon: _isTestingKey
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.network_check_rounded, size: 16),
                label: const Text('Test Connection', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Active: $_activeModelName',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          if (_lastTestResult != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _lastTestResult!.isValid ? const Color(0xFFF0FDF4) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _lastTestResult!.isValid ? const Color(0xFFBBF7D0) : const Color(0xFFFECACA),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _lastTestResult!.isValid ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                        size: 16,
                        color: _lastTestResult!.isValid ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _lastTestResult!.isValid ? 'Connection Verified' : 'Connection Failed',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: _lastTestResult!.isValid ? const Color(0xFF15803D) : const Color(0xFFB91C1C),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _lastTestResult!.message,
                    style: TextStyle(fontSize: 11, color: _lastTestResult!.isValid ? const Color(0xFF166534) : const Color(0xFF991B1B)),
                  ),
                  if (_lastTestResult!.troubleshootingTip != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Tip: ${_lastTestResult!.troubleshootingTip}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF92400E)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDangerZoneCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECDD3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.dangerous_rounded, color: Color(0xFFE11D48), size: 20),
              SizedBox(width: 8),
              Text('System Danger Zone', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFFBE123C))),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Emergency maintenance action to reset all election tally data for a fresh election run.',
            style: TextStyle(fontSize: 11, color: Color(0xFF9F1239), height: 1.4),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFE11D48),
              side: const BorderSide(color: Color(0xFFE11D48)),
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: _resetElectionData,
            icon: const Icon(Icons.delete_forever_rounded, size: 16),
            label: const Text('Reset All Election Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildAcademicYearDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _academicYearOptions.contains(_selectedAcademicYear)
          ? _selectedAcademicYear
          : _academicYearOptions.first,
      decoration: InputDecoration(
        labelText: 'Academic Year (A.Y.)',
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
        prefixIcon: const Icon(Icons.calendar_today_rounded, size: 16, color: nemsuBlue),
      ),
      items: _academicYearOptions.map((ay) {
        return DropdownMenuItem<String>(
          value: ay,
          child: Text('A.Y. $ay', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        );
      }).toList(),
      onChanged: (newAy) {
        if (newAy != null) setState(() => _selectedAcademicYear = newAy);
      },
    );
  }

  Widget _buildSemesterDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _semesterOptions.contains(_selectedSemester)
          ? _selectedSemester
          : _semesterOptions.first,
      decoration: InputDecoration(
        labelText: 'Semester / Term',
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
        prefixIcon: const Icon(Icons.timelapse_rounded, size: 16, color: nemsuBlue),
      ),
      items: _semesterOptions.map((sem) {
        return DropdownMenuItem<String>(
          value: sem,
          child: Text(sem, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        );
      }).toList(),
      onChanged: (newSem) {
        if (newSem != null) setState(() => _selectedSemester = newSem);
      },
    );
  }
}