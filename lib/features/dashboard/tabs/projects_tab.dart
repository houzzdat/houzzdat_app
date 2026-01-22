import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProjectsTab extends StatefulWidget {
  final String? accountId;
  const ProjectsTab({super.key, required this.accountId});

  @override
  State<ProjectsTab> createState() => _ProjectsTabState();
}

class _ProjectsTabState extends State<ProjectsTab> {
  final _supabase = Supabase.instance.client;

  Stream<List<Map<String, dynamic>>> _getProjectsStream() {
    return _supabase
        .from('projects')
        .stream(primaryKey: ['id'])
        .eq('account_id', widget.accountId ?? '')
        .order('name');
  }

  Future<void> _showAddProjectDialog() async {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        title: const Text("Create New Site"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController, 
              decoration: const InputDecoration(
                labelText: "Site Name",
                hintText: "e.g., Downtown Office Building"
              )
            ),
            const SizedBox(height: 12),
            TextField(
              controller: locationController, 
              decoration: const InputDecoration(
                labelText: "Location (Optional)",
                hintText: "e.g., 123 Main St"
              )
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isNotEmpty) {
                await _supabase.from('projects').insert({
                  'name': nameController.text.trim(),
                  'location': locationController.text.trim().isEmpty ? null : locationController.text.trim(),
                  'account_id': widget.accountId,
                });
                if (mounted) Navigator.pop(context);
              }
            }, 
            child: const Text("Create")
          )
        ],
      )
    );
  }

  Future<void> _showEditProjectDialog(Map<String, dynamic> project) async {
    final nameController = TextEditingController(text: project['name']);
    final locationController = TextEditingController(text: project['location'] ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Site"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Site Name")),
            const SizedBox(height: 12),
            TextField(controller: locationController, decoration: const InputDecoration(labelText: "Location")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              await _supabase.from('projects').update({
                'name': nameController.text.trim(),
                'location': locationController.text.trim().isEmpty ? null : locationController.text.trim(),
              }).eq('id', project['id']);
              if (mounted) Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignUserDialog(Map<String, dynamic> project) async {
    final users = await _supabase.from('users').select().eq('account_id', widget.accountId ?? '').neq('role', 'admin');
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Assign Users to ${project['name']}"),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: users.length,
            itemBuilder: (context, i) {
              final user = users[i];
              final isAssigned = user['current_project_id'] == project['id'];
              
              return CheckboxListTile(
                title: Text(user['email'] ?? 'User'),
                subtitle: Text(user['role'] ?? 'worker'),
                value: isAssigned,
                onChanged: (bool? value) async {
                  if (value == true) {
                    await _supabase.from('users').update({
                      'current_project_id': project['id']
                    }).eq('id', user['id']);
                  } else {
                    await _supabase.from('users').update({
                      'current_project_id': null
                    }).eq('id', user['id']);
                  }
                  Navigator.pop(context);
                  _showAssignUserDialog(project); // Refresh dialog
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Done")),
        ],
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
            title: const Text("Site Management", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            trailing: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text("New Site"),
              onPressed: _showAddProjectDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFC107),
                foregroundColor: Colors.black,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: _getProjectsStream(), 
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              
              if (snap.data!.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.business, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text("No sites yet", style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text("Create First Site"),
                        onPressed: _showAddProjectDialog,
                      ),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: snap.data!.length, 
                itemBuilder: (context, i) {
                  final project = snap.data![i];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF1A237E),
                        child: Icon(Icons.business, color: Colors.white),
                      ),
                      title: Text(project['name'] ?? 'Site', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(project['location'] ?? 'No location set'),
                      trailing: PopupMenuButton(
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'assign', child: Row(children: [Icon(Icons.person_add), SizedBox(width: 8), Text("Assign Users")])),
                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit), SizedBox(width: 8), Text("Edit")])),
                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text("Delete", style: TextStyle(color: Colors.red))])),
                        ],
                        onSelected: (value) async {
                          if (value == 'assign') {
                            _showAssignUserDialog(project);
                          } else if (value == 'edit') {
                            _showEditProjectDialog(project);
                          } else if (value == 'delete') {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text("Delete Site?"),
                                content: Text("Are you sure you want to delete '${project['name']}'?"),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    child: const Text("Delete"),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await _supabase.from('projects').delete().eq('id', project['id']);
                            }
                          }
                        },
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