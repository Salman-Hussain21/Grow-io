import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportBugPage extends StatefulWidget {
  const ReportBugPage({super.key});

  @override
  State<ReportBugPage> createState() => _ReportBugPageState();
}

class _ReportBugPageState extends State<ReportBugPage> {
  final TextEditingController _bugController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _reportBug() async {
    if (_bugController.text.isEmpty) return;

    try {
      final user = _auth.currentUser;
      await _firestore.collection('bug_reports').add({
        'userId': user?.uid,
        'email': user?.email,
        'bugDescription': _bugController.text,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'new',
        'appVersion': '1.0.0',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bug report submitted. Thank you!')),
      );
      _bugController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error submitting bug report: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report a Bug'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Found a bug? Let us know!',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            const Text(
              'Please describe the issue you encountered in detail:',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _bugController,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Bug Description',
                border: OutlineInputBorder(),
                hintText: 'What happened? What were you trying to do?',
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _reportBug,
              child: const Text('Submit Bug Report'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bugController.dispose();
    super.dispose();
  }
}