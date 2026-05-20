import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants.dart';

class CandidateManagement extends StatefulWidget {
  const CandidateManagement({super.key});

  @override
  State<CandidateManagement> createState() => _CandidateManagementState();
}

class _CandidateManagementState extends State<CandidateManagement> {
  String selectedFilterPosition = 'All';

  // --- FIREBASE DATA STATES ---
  List<Map<String, dynamic>> _configuredPositions = [];
  List<String> _departmentsList = [];
  bool _isLoadingConfig = true;

  @override
  void initState() {
    super.initState();
    _loadElectionConfig();
  }

  // --- 1. LOAD CONFIGURATION FROM FIREBASE ---
  Future<void> _loadElectionConfig() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('config').doc('election_settings').get();
      
      if (doc.exists && (doc.data() as Map<String, dynamic>).containsKey('positions')) {
        List<dynamic> posData = (doc.data() as Map<String, dynamic>)['positions'];
        List<Map<String, dynamic>> loadedPositions = List<Map<String, dynamic>>.from(posData);

        // Extract unique departments from the configuration
        Set<String> depts = {'University-Wide (USG)'}; // Guarantee USG is always an option
        for(var p in loadedPositions) {
          depts.add(p['scope']);
        }

        setState(() {
          _configuredPositions = loadedPositions;
          _departmentsList = depts.toList();
          _isLoadingConfig = false;
        });
      } else {
        setState(() => _isLoadingConfig = false);
      }
    } catch (e) {
      print("Error loading config: $e");
      setState(() => _isLoadingConfig = false);
    }
  }

  // --- 2. DYNAMIC DROPDOWN LOGIC ---
  List<String> _getPositionsForDepartment(String department) {
    // Finds all positions in the config that match the selected department
    var matching = _configuredPositions
        .where((p) => p['scope'] == department)
        .map((p) => p['position'] as String)
        .toSet()
        .toList();
    
    return matching.isNotEmpty ? matching : ['No Positions Configured'];
  }

  // --- 3. ADD / EDIT CANDIDATE DIALOG ---
  Future<void> _showCandidateForm({String? docId, Map<String, dynamic>? existingCandidate}) async {
    bool isEdit = docId != null;

    TextEditingController nameController = TextEditingController(text: isEdit ? existingCandidate!['name'] : '');
    TextEditingController partyController = TextEditingController(text: isEdit ? existingCandidate!['party'] : '');
    TextEditingController platformController = TextEditingController(text: isEdit ? existingCandidate!['platform'] : '');
    
    // Set initial dropdown values
    String formDept = isEdit ? existingCandidate!['department'] : _departmentsList.first;
    List<String> availablePositions = _getPositionsForDepartment(formDept);
    
    // Ensure the formPos exists in the list, otherwise pick the first available
    String formPos = isEdit && availablePositions.contains(existingCandidate!['position']) 
        ? existingCandidate['position'] 
        : availablePositions.first;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Candidate' : 'Add New Candidate', style: const TextStyle(color: nemsuBlue, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Candidate Full Name', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      
                      // 👉 DEPARTMENT DROPDOWN
                      DropdownButtonFormField<String>(
                        value: formDept,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
                        items: _departmentsList.map((d) => DropdownMenuItem(
                          value: d, 
                          child: Text(d, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (v) {
                          setDialogState(() {
                            formDept = v!;
                            // 👉 MAGIC: When Department changes, update available positions and reset the Position dropdown!
                            availablePositions = _getPositionsForDepartment(formDept);
                            formPos = availablePositions.first;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // 👉 DYNAMIC POSITION DROPDOWN
                      DropdownButtonFormField<String>(
                        value: formPos,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Position', border: OutlineInputBorder()),
                        items: availablePositions.map((pos) => DropdownMenuItem(
                          value: pos, 
                          child: Text(pos, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (val) => setDialogState(() => formPos = val!),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: partyController,
                        decoration: const InputDecoration(labelText: 'Political Party / Independent', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: platformController,
                        maxLines: 3, 
                        decoration: const InputDecoration(labelText: 'Campaign Platform / Goals', border: OutlineInputBorder()),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: nemsuBlue, foregroundColor: Colors.white),
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;

                    Map<String, dynamic> candidatePayload = {
                      'name': nameController.text.trim(),
                      'department': formDept,
                      'position': formPos,
                      'party': partyController.text.trim(),
                      'platform': platformController.text.trim(),
                      'timestamp': FieldValue.serverTimestamp(),
                    };

                    try {
                      if (isEdit) {
                        await FirebaseFirestore.instance.collection('candidates').doc(docId).update(candidatePayload);
                      } else {
                        await FirebaseFirestore.instance.collection('candidates').add(candidatePayload);
                      }
                      if (!mounted) return;
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? 'Candidate updated!' : 'Candidate added!'), backgroundColor: Colors.green));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent));
                    }
                  },
                  child: Text(isEdit ? 'Save Changes' : 'Add Candidate'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- 4. DELETE CANDIDATE ---
  void _confirmDelete(String docId, String candidateName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Candidate?'),
        content: Text('Are you sure you want to remove $candidateName from the election roster?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('candidates').doc(docId).delete();
              if (!mounted) return;
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Candidate removed.'), backgroundColor: Colors.redAccent));
            },
            child: const Text('Remove'),
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

    // Create dynamic filter tabs based on configured positions
    List<String> filterTabs = ['All'];
    filterTabs.addAll(_configuredPositions.map((p) => p['position'] as String).toSet());

    return Padding(
      padding: const EdgeInsets.all(20.0), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER & ADD BUTTON ---
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Candidate Management', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: nemsuBlue)),
              const SizedBox(height: 4),
              const Text('Manage USG and Local Student Council candidates in real-time', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 16),
              
              SizedBox(
                width: double.infinity, 
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: nemsuBlue,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _configuredPositions.isEmpty 
                      ? null // Disable if no config exists
                      : () => _showCandidateForm(), 
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                  label: const Text('Add New Candidate', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5)),
                ),
              ),
              if (_configuredPositions.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: Text('⚠️ Please configure election settings first.', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                )
            ],
          ),
          const SizedBox(height: 24),

          // --- POSITION FILTER TABS ---
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: filterTabs.length,
              itemBuilder: (context, index) {
                final position = filterTabs[index];
                final isSelected = selectedFilterPosition == position;
                return Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: ChoiceChip(
                    label: Text(position, style: TextStyle(color: isSelected ? nemsuBlue : Colors.grey.shade700, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    selected: isSelected, selectedColor: nemsuGold, backgroundColor: Colors.white,
                    side: BorderSide(color: isSelected ? nemsuGold : Colors.grey.shade300),
                    onSelected: (selected) { if (selected) setState(() => selectedFilterPosition = position); },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // --- REAL-TIME FIREBASE STREAM ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('candidates').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: nemsuBlue));
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No candidates registered in the database yet.", style: TextStyle(color: Colors.grey)));
                }

                var docs = snapshot.data!.docs;

                // Apply Filter Tab
                if (selectedFilterPosition != 'All') {
                  docs = docs.where((doc) => doc['position'] == selectedFilterPosition).toList();
                }

                if (docs.isEmpty) {
                  return const Center(child: Text("No candidates found for this position.", style: TextStyle(color: Colors.grey)));
                }

                // Group by Department
                Map<String, List<QueryDocumentSnapshot>> groupedCandidates = {};
                for (var doc in docs) {
                  String dept = doc['department'] ?? 'Unknown';
                  if (!groupedCandidates.containsKey(dept)) groupedCandidates[dept] = [];
                  groupedCandidates[dept]!.add(doc);
                }

                List<String> sortedDepartments = groupedCandidates.keys.toList()..sort((a, b) {
                  if (a == 'University-Wide (USG)') return -1;
                  if (b == 'University-Wide (USG)') return 1;
                  return a.compareTo(b);
                });

                return ListView.builder(
                  itemCount: sortedDepartments.length,
                  itemBuilder: (context, index) {
                    String department = sortedDepartments[index];
                    List<QueryDocumentSnapshot> deptCandidates = groupedCandidates[department]!;
                    IconData deptIcon = department == 'University-Wide (USG)' ? Icons.account_balance_rounded : Icons.domain_rounded;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Department Header
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Icon(deptIcon, color: Colors.grey, size: 20), 
                                const SizedBox(width: 8),
                                Expanded( 
                                  child: Text(department, style: const TextStyle(fontWeight: FontWeight.bold, color: nemsuBlue, fontSize: 15), softWrap: true),
                                ),
                                const SizedBox(width: 10),
                                const SizedBox(width: 40, child: Divider(thickness: 1)),
                              ],
                            ),
                          ),
                          
                          // Candidate Cards
                          ...deptCandidates.map((doc) {
                            Map<String, dynamic> candidateData = doc.data() as Map<String, dynamic>;
                            String docId = doc.id; 

                            return Card(
                              margin: const EdgeInsets.only(bottom: 16),
                              elevation: 2, 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const CircleAvatar(backgroundColor: nemsuGold, radius: 24, child: Icon(Icons.person, color: nemsuBlue)),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(candidateData['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: nemsuBlue)),
                                              const SizedBox(height: 4),
                                              Text('${candidateData['position']} • ${candidateData['party']}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87)),
                                              const SizedBox(height: 8),
                                              Text('Platform: ${candidateData['platform']}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontStyle: FontStyle.italic)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
                                    
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(foregroundColor: Colors.blue, side: const BorderSide(color: Colors.blue), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                          onPressed: () => _showCandidateForm(docId: docId, existingCandidate: candidateData),
                                          icon: const Icon(Icons.edit_outlined, size: 16),
                                          label: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                        const SizedBox(width: 12),
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                          onPressed: () => _confirmDelete(docId, candidateData['name']),
                                          icon: const Icon(Icons.delete_outline, size: 16),
                                          label: const Text('Remove', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    )
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                );
              }
            ),
          ),
        ],
      ),
    );
  }
}