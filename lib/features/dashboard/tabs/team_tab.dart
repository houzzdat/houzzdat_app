import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeamTab extends StatefulWidget {
  final String? accountId;
  const TeamTab({super.key, required this.accountId});

  @override
  State<TeamTab> createState() => _TeamTabState();
}

class _TeamTabState extends State<TeamTab> {
  final _supabase = Supabase.instance.client;

  Stream<List<Map<String, dynamic>>> _getTeamStream() {
    return _supabase
        .from('users')
        .stream(primaryKey: ['id'])
        .eq('account_id', widget.accountId ?? '')
        .order('role');
  }

  Future<void> _showInviteStaffDialog() async {
    final emailC = TextEditingController();
    final passC = TextEditingController();
    final roles = await _supabase.from('roles').select().eq('account_id', widget.accountId ?? '');
    String? selRole;
    
    if (!mounted) return;
    
    showDialog(
      context: context, 
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Invite New Staff Member"),
          content: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              TextField(
                controller: emailC, 
                decoration: const InputDecoration(
                  labelText: "Email Address",
                  hintText: "user@example.com"
                )
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passC, 
                decoration: const InputDecoration(
                  labelText: "Temporary Password",
                  hintText: "Min 6 characters"
                ), 
                obscureText: true
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Select Role"),
                value: selRole,
                items: roles.map<DropdownMenuItem<String>>(
                  (r) => DropdownMenuItem(value: r['name'], child: Text(r['name'] ?? ''))
                ).toList(),
                onChanged: (v) => setDialogState(() => selRole = v),
              ),
            ]
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: selRole == null ? null : () async {
                try {
                  await _supabase.functions.invoke('invite-user', body: {
                    'email': emailC.text.trim(), 
                    'password': passC.text.trim(), 
                    'role': selRole, 
                    'account_id': widget.accountId,
                  });
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('User invited successfully!'))
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'))
                    );
                  }
                }
              }, 
              child: const Text("Send Invite")
            )
          ],
        )
      )
    );
  }

  Future<void> _showEditUserDialog(Map<String, dynamic> user) async {
    final projects = await _supabase.from('projects').select().eq('account_id', widget.accountId ?? '');
    String? selectedProject = user['current_project_id'];
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text("Edit ${user['email']}"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text("Role"),
                subtitle: Text(user['role'] ?? 'worker'),
                leading: const Icon(Icons.badge),
              ),
              const Divider(),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: "Assigned Project"),
                value: selectedProject,
                items: [
                  const DropdownMenuItem(value: null, child: Text("No Assignment")),
                  ...projects.map((p) => DropdownMenuItem(
                    value: p['id'].toString(),
                    child: Text(p['name'])
                  )),
                ],
                onChanged: (v) => setDialogState(() => selectedProject = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () async {
                await _supabase.from('users').update({
                  'current_project_id': selectedProject,
                }).eq('id', user['id']);
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          child: ListTile(
            title: const Text("Team Management", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            trailing: ElevatedButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text("Invite User"),
              onPressed: _showInviteStaffDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.black,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getTeamStream(), 
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              
              if (snap.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text("No team members yet", style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.person_add),
                        label: const Text("Invite First Member"),
                        onPressed: _showInviteStaffDialog,
                      ),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: snap.data!.length, 
                itemBuilder: (context, i) {
                  final user = snap.data![i];
                  final role = user['role'] ?? 'worker';
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: role == 'manager' ? Colors.blue : const Color(0xFF1A237E),
                        child: Icon(
                          role == 'manager' ? Icons.admin_panel_settings : Icons.person,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(user['email'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Role: $role"),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditUserDialog(user),
                      ),
                    ),
                  );
                }
              );
            }
          ),
        ),
      ],
    );
  }
}