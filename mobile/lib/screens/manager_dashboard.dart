import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});
  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard> {
  List<dynamic> employees = [];
  final _title = TextEditingController();
  final _desc = TextEditingController();
  String? _assignedTo;

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final list = await ApiService.listEmployees();
      setState(() => employees = list);
    } catch (e) {
      // ignore for brevity
    }
  }

  Future<void> _createTask() async {
    if (_assignedTo == null || _title.text.isEmpty) return;
    await ApiService.createTask({'title': _title.text, 'description': _desc.text, 'assignedTo': _assignedTo});
    _title.clear(); _desc.clear(); setState(() => _assignedTo = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manager Dashboard'), actions: [
        IconButton(onPressed: () => AuthService.logout(), icon: const Icon(Icons.logout)),
      ]),
      body: Row(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('tasks').orderBy('createdAt', descending: true).snapshots(),
              builder: (_, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snap.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final t = docs[i].data();
                    final id = docs[i].id;
                    return ListTile(
                      title: Text(t['title'] ?? ''),
                      subtitle: Text('Status: ${t['status']} • For: ${t['assignedTo']}'),
                      trailing: IconButton(icon: const Icon(Icons.check),
                        onPressed: () => ApiService.updateTask(id, {'status':'done'}),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const VerticalDivider(width: 1),
          SizedBox(
            width: 360,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Assign Task', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  DropdownButtonFormField(
                    value: _assignedTo,
                    items: employees.map((e) => DropdownMenuItem(
                      value: e['id'], child: Text((e['name'] ?? e['email'] ?? e['id']).toString()))).toList(),
                    onChanged: (v) => setState(() => _assignedTo = v),
                    decoration: const InputDecoration(labelText: 'Employee'),
                  ),
                  TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title')),
                  TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description')),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _createTask, child: const Text('Create Task')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
