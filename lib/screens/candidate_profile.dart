import 'package:flutter/material.dart';
import '../constants.dart';

class CandidateProfileScreen extends StatelessWidget {
  final Map<String, String> candidate;
  final String position;

  const CandidateProfileScreen({
    super.key,
    required this.candidate,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Candidate Profile', style: TextStyle(color: Colors.white)),
        backgroundColor: nemsuBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- HEADER ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 30, top: 20),
              decoration: const BoxDecoration(
                color: nemsuBlue,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  // SAFE HERO AVATAR (No Network Image needed for testing)
                  Hero(
                    tag: 'avatar_${candidate["name"]}',
                    child: const CircleAvatar(
                      radius: 60,
                      backgroundColor: nemsuGold,
                      child: Icon(Icons.person, size: 60, color: nemsuBlue), 
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    candidate["name"] ?? "Unknown Candidate",
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    position.toUpperCase(),
                    style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.8), letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: nemsuGold,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      candidate["party"] ?? "Independent",
                      style: const TextStyle(color: nemsuBlue, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  )
                ],
              ),
            ),

            // --- PLATFORM ---
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.menu_book_rounded, color: nemsuBlue),
                      SizedBox(width: 8),
                      Text(
                        'Platform & Goals',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: nemsuBlue),
                      ),
                    ],
                  ),
                  const Divider(color: nemsuGold, thickness: 1.5, height: 24),
                  
                  // SAFE TEXT FALLBACK
                  Text(
                    candidate["platform"] ?? "This candidate has not provided a platform yet.",
                    style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
                    textAlign: TextAlign.justify,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: nemsuBlue, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: nemsuBlue),
                      label: const Text('Return to Ballot', style: TextStyle(color: nemsuBlue, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}