import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class EmployeeDashboard extends StatelessWidget {
  const EmployeeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      appBar: AppBar(title: const Text('Employee Dashboard'), actions: [
        IconButton(onPressed: () => AuthService.logout(), icon: const Icon(Icons.logout)),
      ]),
      body: uid == null ? const Center(child: Text('Not logged in')) :
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('tasks').where('assignedTo', isEqualTo: uid).orderBy('createdAt', descending: true).snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snap.hasData || snap.data!.docs.isEmpty) return const Center(child: Text('No tasks yet'));
          final docs = snap.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final id = docs[i].id;
              final t = docs[i].data();
              final updateCtrl = TextEditingController();
              return Card(
                margin: const EdgeInsets.all(8),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(t['description'] ?? ''),
                      const SizedBox(height: 8),
                      Row(children: [
                        ElevatedButton(onPressed: () => ApiService.updateTask(id, {'status': 'in_progress'}), child: const Text('Start')),
                        const SizedBox(width: 8),
                        ElevatedButton(onPressed: () => ApiService.updateTask(id, {'status': 'done'}), child: const Text('Complete')),
                      ]),
                      const SizedBox(height: 8),
                      TextField(controller: updateCtrl, decoration: const InputDecoration(labelText: 'Update message')),
                      const SizedBox(height: 8),
                      ElevatedButton(onPressed: () async {
                        if (updateCtrl.text.trim().isEmpty) return;
                        await ApiService.addTaskUpdate(id, updateCtrl.text.trim());
                        updateCtrl.clear();
                      }, child: const Text('Submit Update')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
