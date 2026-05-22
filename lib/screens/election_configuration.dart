import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';

class ElectionConfiguration extends StatefulWidget {
  const ElectionConfiguration({super.key});

  @override
  State<ElectionConfiguration> createState() => _ElectionConfigurationState();
}

class _ElectionConfigurationState extends State<ElectionConfiguration> {
  // --- SETTINGS STATE ---
  DateTime? startDate = DateTime.now();
  TimeOfDay? startTime = const TimeOfDay(hour: 8, minute: 0);
  DateTime? endDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay? endTime = const TimeOfDay(hour: 17, minute: 0);

  List<Map<String, dynamic>> positionRules = [];
  bool isLoading = true;

  final List<String> scopes = [
    'University-Wide (USG)',
    'College of Information Technology Education',
    'College of Business Management',
    'College of Teacher Education',
    'College of Engineering Technology',
    'College of Arts and Sciences',
  ];

  @override
  void initState() {
    super.initState();
    _loadConfiguration();
  }

  // --- FIREBASE: LOAD CONFIGURATION ---
  Future<void> _loadConfiguration() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('config').doc('election_settings').get();
      
      if (doc.exists && (doc.data() as Map<String, dynamic>).containsKey('positions')) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        
        setState(() {
          positionRules = List<Map<String, dynamic>>.from(data['positions']);
          
          // 👉 NEW: Load the saved schedule from Firebase if it exists
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
        // --- DYNAMIC GENERATOR FOR ALL COLLEGES ---
        List<Map<String, dynamic>> generatedPositions = [
          // USG Executive
          {'position': 'President', 'scope': 'University-Wide (USG)', 'maxElected': 1},
          {'position': 'Vice President for Internal Affairs', 'scope': 'University-Wide (USG)', 'maxElected': 1},
          {'position': 'Vice President for External Affairs', 'scope': 'University-Wide (USG)', 'maxElected': 1},
          {'position': 'Executive Secretary', 'scope': 'University-Wide (USG)', 'maxElected': 1},
          {'position': 'Treasurer', 'scope': 'University-Wide (USG)', 'maxElected': 1},
          {'position': 'Auditor', 'scope': 'University-Wide (USG)', 'maxElected': 1},
          // USG Legislative
          {'position': 'Senator', 'scope': 'University-Wide (USG)', 'maxElected': 12},
        ];

        // Automatically loop through all colleges and attach the CLSG positions
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

        setState(() {
          positionRules = generatedPositions;
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
    try {
      // 👉 NEW: Format dates to ISO strings so Firebase can store them easily
      DateTime? combinedStart;
      if (startDate != null && startTime != null) {
        combinedStart = DateTime(startDate!.year, startDate!.month, startDate!.day, startTime!.hour, startTime!.minute);
      }
      
      DateTime? combinedEnd;
      if (endDate != null && endTime != null) {
        combinedEnd = DateTime(endDate!.year, endDate!.month, endDate!.day, endTime!.hour, endTime!.minute);
      }

      await FirebaseFirestore.instance.collection('config').doc('election_settings').set({
        'positions': positionRules,
        // 👉 NEW: Save the schedule payload
        'schedule': {
          'start': combinedStart?.toIso8601String(),
          'end': combinedEnd?.toIso8601String(),
        },
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('COMSELEC Election Settings saved to database!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving settings: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }


  Future<void> _resetElectionData() async {
    // 1. Show confirmation dialog
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Election Data?', style: TextStyle(color: Colors.redAccent)),
        content: const Text('This will delete all current votes, set candidate counts to zero, and allow students to vote again. This action CANNOT be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Confirm Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      WriteBatch batch = FirebaseFirestore.instance.batch();

      // 1. Reset Candidates to 0
      var candidates = await FirebaseFirestore.instance.collection('candidates').get();
      for (var doc in candidates.docs) {
        batch.update(doc.reference, {'voteCount': 0});
      }

      // 2. Clear actual ballot records (the 'votes' collection)
      var votes = await FirebaseFirestore.instance.collection('votes').get();
      for (var doc in votes.docs) {
        batch.delete(doc.reference);
      }

      // 3. Reset Voters' ability to vote
      var voters = await FirebaseFirestore.instance.collection('voters').get();
      for (var doc in voters.docs) {
        batch.update(doc.reference, {'hasVoted': false});
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Election data reset successfully!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error resetting: $e'), backgroundColor: Colors.redAccent));
      }
    }
  }

  // 👉 NEW: DATE & TIME PICKER LOGIC
  Future<void> _pickDateTime(bool isStart) async {
    DateTime initialDate = isStart ? (startDate ?? DateTime.now()) : (endDate ?? DateTime.now());
    TimeOfDay initialTime = isStart ? (startTime ?? TimeOfDay.now()) : (endTime ?? TimeOfDay.now());

    // 1. Pick the Date
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)), // Allow minor past adjustments
      lastDate: DateTime.now().add(const Duration(days: 365)), // Max 1 year in the future
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
      // 2. Pick the Time
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

  // --- ADD/EDIT POSITION DIALOG ---
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
              title: Text(isEdit ? 'Edit Position' : 'Add Elective Position', style: const TextStyle(color: nemsuBlue, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: positionController,
                        decoration: const InputDecoration(labelText: 'Position Title (e.g., USG President)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      
                      DropdownButtonFormField<String>(
                        value: selectedScope,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Jurisdiction / Scope', border: OutlineInputBorder()),
                        items: scopes.map((s) => DropdownMenuItem(
                          value: s, 
                          child: Text(s, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)
                        )).toList(),
                        onChanged: (val) => setDialogState(() => selectedScope = val!),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: maxElectedController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Seats Available (Max Elected)', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 8),
                      const Text('Example: Set to 1 for President, or 12 for Senators.', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: nemsuBlue, foregroundColor: Colors.white),
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
                    });
                    Navigator.pop(context);
                  },
                  child: Text(isEdit ? 'Update' : 'Add Position'),
                ),
              ],
              
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator(color: nemsuBlue));
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Election Configuration', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: nemsuBlue)),
            const Text('Set schedules, available seats, and align with the COMSELEC Electoral Code.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),

            // --- SECTION: SCHEDULING ---
            _buildSectionHeader('Election Schedule', Icons.calendar_month_rounded),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildDateTimeTile('Start Voting', startDate, startTime, () => _pickDateTime(true)),
                    const Divider(),
                    _buildDateTimeTile('End Voting', endDate, endTime, () => _pickDateTime(false)),
                  ],
                ),
                
              ),
            ),
            const SizedBox(height: 32),

            // --- SECTION: VOTING RULES & POSITIONS ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildSectionHeader('Elective Positions & Available Seats', Icons.rule_rounded),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: nemsuBlue, side: const BorderSide(color: nemsuBlue)),
                  onPressed: () => _showPositionForm(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Position'),
                ),
              ],
            ),
            
            positionRules.isEmpty 
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                  child: const Text('No positions configured yet. Click "Add Position" to begin.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: positionRules.length,
                  itemBuilder: (context, index) {
                    final rule = positionRules[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade300)),
                      child: ListTile(
                        title: Text(rule['position'], style: const TextStyle(fontWeight: FontWeight.bold, color: nemsuBlue)),
                        subtitle: Text('${rule['scope']} • Seats Available: ${rule['maxElected']}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                              onPressed: () => _showPositionForm(existingRule: rule, index: index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                              onPressed: () => setState(() => positionRules.removeAt(index)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            
            const SizedBox(height: 40),

            // --- SAVE SETTINGS BUTTON ---
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: nemsuGold,
                  foregroundColor: nemsuBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saveConfiguration, 
                icon: const Icon(Icons.cloud_upload_rounded),
                label: const Text('Save COMSELEC Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            // --- ADD THIS "DANGER ZONE" BLOCK BELOW ---
            const SizedBox(height: 60),
            const Divider(color: Colors.redAccent, thickness: 1),
            const SizedBox(height: 20),
            const Center(
              child: Text("Danger Zone", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
            Center(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
                ),
                onPressed: _resetElectionData,
                icon: const Icon(Icons.delete_forever),
                label: const Text('Reset All Election Data'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Icon(icon, color: nemsuGold, size: 18),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title, 
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: nemsuBlue, height: 1.2),
          ),
        ),
      ],
    );
  }

  // 👉 NEW: Added the VoidCallback so we can trigger the function when "Change" is pressed
  Widget _buildDateTimeTile(String label, DateTime? date, TimeOfDay? time, VoidCallback onChange) {
    return ListTile(
      title: Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
      subtitle: Text('${date?.year}-${date?.month.toString().padLeft(2, '0')}-${date?.day.toString().padLeft(2, '0')} at ${time?.format(context)}', 
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black)),
      trailing: TextButton(
        onPressed: onChange, // Call the picker method here
        child: const Text('Change', style: TextStyle(color: Colors.blue)),
      ),
    );
  }
}