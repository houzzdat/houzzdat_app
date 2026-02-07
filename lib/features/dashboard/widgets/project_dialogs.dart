import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

class ProjectDialogs {
  /// Create project dialog with optional owner onboarding
  /// Returns: { name, location, ownerEmail?, ownerPhone?, ownerName?, ownerPassword?,
  ///            siteLat?, siteLng?, geofenceRadius? }
  static Future<Map<String, String>?> showAddProjectDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final locationController = TextEditingController();
    final ownerEmailController = TextEditingController();
    final ownerPhoneController = TextEditingController();
    final ownerNameController = TextEditingController();
    final ownerPasswordController = TextEditingController();
    bool showOwnerSection = false;
    bool ownerExists = false;
    String? existingOwnerId;

    // Geofence
    bool geofenceEnabled = false;
    double? siteLat;
    double? siteLng;
    double geofenceRadius = 200;
    bool isFetchingLocation = false;
    String? locationError;

    final supabase = Supabase.instance.client;

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          Future<void> checkExistingOwner() async {
            final email = ownerEmailController.text.trim();
            final phone = ownerPhoneController.text.trim();
            if (email.isEmpty && phone.isEmpty) {
              setState(() {
                ownerExists = false;
                existingOwnerId = null;
              });
              return;
            }

            try {
              Map<String, dynamic>? existing;

              if (email.isNotEmpty) {
                existing = await supabase
                    .from('users')
                    .select('id, full_name, email, role')
                    .eq('email', email)
                    .eq('role', 'owner')
                    .maybeSingle();
              }

              if (existing == null && phone.isNotEmpty) {
                existing = await supabase
                    .from('users')
                    .select('id, full_name, email, role')
                    .eq('phone_number', phone)
                    .eq('role', 'owner')
                    .maybeSingle();
              }

              setState(() {
                ownerExists = existing != null;
                existingOwnerId = existing?['id'];
                if (ownerExists) {
                  ownerNameController.text = existing?['full_name'] ?? '';
                }
              });
            } catch (e) {
              debugPrint('Error checking owner: $e');
            }
          }

          return AlertDialog(
            title: const Text("Create New Site"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Project fields
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: "Site Name",
                      hintText: "e.g., Downtown Office Building",
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingM),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: "Location (Optional)",
                      hintText: "e.g., 123 Main St",
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingL),
                  const Divider(),

                  // Geofence section
                  InkWell(
                    onTap: () => setState(() => geofenceEnabled = !geofenceEnabled),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
                      child: Row(
                        children: [
                          Icon(
                            geofenceEnabled ? Icons.expand_less : Icons.expand_more,
                            color: AppTheme.primaryIndigo,
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Text(
                            "Site Geofence",
                            style: AppTheme.headingSmall.copyWith(
                              color: AppTheme.primaryIndigo,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            geofenceEnabled ? "" : "(Optional)",
                            style: AppTheme.caption,
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (geofenceEnabled) ...[
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      "Set the site boundary for attendance check-in. Workers must be within the radius to mark attendance.",
                      style: AppTheme.bodySmall,
                    ),
                    const SizedBox(height: AppTheme.spacingM),

                    // Use Current Location button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: isFetchingLocation
                            ? const SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(
                                siteLat != null ? Icons.check_circle : Icons.my_location,
                                size: 18,
                              ),
                        label: Text(
                          isFetchingLocation
                              ? 'Getting location...'
                              : siteLat != null
                                  ? 'Location set (${siteLat!.toStringAsFixed(5)}, ${siteLng!.toStringAsFixed(5)})'
                                  : 'Use Current Location',
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: siteLat != null
                              ? AppTheme.successGreen
                              : AppTheme.primaryIndigo,
                          side: BorderSide(
                            color: siteLat != null
                                ? AppTheme.successGreen
                                : AppTheme.primaryIndigo,
                          ),
                        ),
                        onPressed: isFetchingLocation
                            ? null
                            : () async {
                                setState(() {
                                  isFetchingLocation = true;
                                  locationError = null;
                                });

                                try {
                                  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                                  if (!serviceEnabled) {
                                    setState(() {
                                      locationError = 'Location services are disabled.';
                                      isFetchingLocation = false;
                                    });
                                    return;
                                  }

                                  LocationPermission permission = await Geolocator.checkPermission();
                                  if (permission == LocationPermission.denied) {
                                    permission = await Geolocator.requestPermission();
                                  }
                                  if (permission == LocationPermission.denied ||
                                      permission == LocationPermission.deniedForever) {
                                    setState(() {
                                      locationError = 'Location permission denied.';
                                      isFetchingLocation = false;
                                    });
                                    return;
                                  }

                                  final position = await Geolocator.getCurrentPosition(
                                    locationSettings: const LocationSettings(
                                      accuracy: LocationAccuracy.high,
                                      timeLimit: Duration(seconds: 15),
                                    ),
                                  );

                                  setState(() {
                                    siteLat = position.latitude;
                                    siteLng = position.longitude;
                                    isFetchingLocation = false;
                                  });
                                } catch (e) {
                                  setState(() {
                                    locationError = 'Failed to get location.';
                                    isFetchingLocation = false;
                                  });
                                }
                              },
                      ),
                    ),

                    if (locationError != null) ...[
                      const SizedBox(height: AppTheme.spacingS),
                      Text(locationError!,
                        style: TextStyle(fontSize: 12, color: AppTheme.errorRed)),
                    ],

                    const SizedBox(height: AppTheme.spacingM),

                    // Radius slider
                    Row(
                      children: [
                        const Text('Radius: ', style: TextStyle(fontSize: 13)),
                        Expanded(
                          child: Slider(
                            value: geofenceRadius,
                            min: 50,
                            max: 500,
                            divisions: 18,
                            label: '${geofenceRadius.round()}m',
                            activeColor: AppTheme.primaryIndigo,
                            onChanged: (v) => setState(() => geofenceRadius = v),
                          ),
                        ),
                        Text('${geofenceRadius.round()}m',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],

                  const SizedBox(height: AppTheme.spacingS),
                  const Divider(),

                  // Owner section toggle
                  InkWell(
                    onTap: () => setState(() => showOwnerSection = !showOwnerSection),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
                      child: Row(
                        children: [
                          Icon(
                            showOwnerSection ? Icons.expand_less : Icons.expand_more,
                            color: AppTheme.primaryIndigo,
                          ),
                          const SizedBox(width: AppTheme.spacingS),
                          Text(
                            "Link Project Owner",
                            style: AppTheme.headingSmall.copyWith(
                              color: AppTheme.primaryIndigo,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            showOwnerSection ? "" : "(Optional)",
                            style: AppTheme.caption,
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (showOwnerSection) ...[
                    const SizedBox(height: AppTheme.spacingS),
                    Text(
                      "Enter owner details. If an owner with this email/phone already exists, they will be linked automatically.",
                      style: AppTheme.bodySmall,
                    ),
                    const SizedBox(height: AppTheme.spacingM),

                    // Owner email
                    TextField(
                      controller: ownerEmailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: "Owner Email",
                        hintText: "owner@example.com",
                        prefixIcon: Icon(Icons.email),
                      ),
                      onChanged: (_) => checkExistingOwner(),
                    ),
                    const SizedBox(height: AppTheme.spacingM),

                    // Owner phone
                    TextField(
                      controller: ownerPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: "Owner Phone (Optional)",
                        hintText: "+91 9876543210",
                        prefixIcon: Icon(Icons.phone),
                      ),
                      onChanged: (_) => checkExistingOwner(),
                    ),

                    // Existing owner indicator
                    if (ownerExists) ...[
                      const SizedBox(height: AppTheme.spacingM),
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingS),
                        decoration: BoxDecoration(
                          color: AppTheme.successGreen.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                          border: Border.all(color: AppTheme.successGreen.withValues(alpha:0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: AppTheme.successGreen, size: 18),
                            const SizedBox(width: AppTheme.spacingS),
                            Expanded(
                              child: Text(
                                "Owner found: ${ownerNameController.text.isNotEmpty ? ownerNameController.text : 'Existing owner'}. This project will be linked to their account.",
                                style: AppTheme.bodySmall.copyWith(color: AppTheme.successGreen),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // New owner fields (only shown if no existing owner)
                    if (!ownerExists && (ownerEmailController.text.trim().isNotEmpty || ownerPhoneController.text.trim().isNotEmpty)) ...[
                      const SizedBox(height: AppTheme.spacingM),
                      Container(
                        padding: const EdgeInsets.all(AppTheme.spacingS),
                        decoration: BoxDecoration(
                          color: AppTheme.infoBlue.withValues(alpha:0.1),
                          borderRadius: BorderRadius.circular(AppTheme.radiusS),
                          border: Border.all(color: AppTheme.infoBlue.withValues(alpha:0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info, color: AppTheme.infoBlue, size: 18),
                            const SizedBox(width: AppTheme.spacingS),
                            Expanded(
                              child: Text(
                                "New owner account will be created",
                                style: AppTheme.bodySmall.copyWith(color: AppTheme.infoBlue),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      TextField(
                        controller: ownerNameController,
                        decoration: const InputDecoration(
                          labelText: "Owner Name",
                          hintText: "Full name",
                          prefixIcon: Icon(Icons.person),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingM),
                      TextField(
                        controller: ownerPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "Temporary Password",
                          hintText: "Min 6 characters",
                          prefixIcon: Icon(Icons.lock),
                          helperText: "Owner will use this to log in",
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.trim().isNotEmpty) {
                    final result = {
                      'name': nameController.text.trim(),
                      'location': locationController.text.trim(),
                    };

                    // Geofence data
                    if (geofenceEnabled && siteLat != null && siteLng != null) {
                      result['siteLat'] = siteLat.toString();
                      result['siteLng'] = siteLng.toString();
                      result['geofenceRadius'] = geofenceRadius.round().toString();
                    }

                    if (showOwnerSection) {
                      final ownerEmail = ownerEmailController.text.trim();
                      final ownerPhone = ownerPhoneController.text.trim();
                      if (ownerEmail.isNotEmpty) result['ownerEmail'] = ownerEmail;
                      if (ownerPhone.isNotEmpty) result['ownerPhone'] = ownerPhone;

                      if (ownerExists && existingOwnerId != null) {
                        result['existingOwnerId'] = existingOwnerId!;
                      } else {
                        final ownerName = ownerNameController.text.trim();
                        final ownerPassword = ownerPasswordController.text.trim();
                        if (ownerName.isNotEmpty) result['ownerName'] = ownerName;
                        if (ownerPassword.isNotEmpty) result['ownerPassword'] = ownerPassword;
                      }
                    }

                    Navigator.pop(context, result);
                  }
                },
                child: const Text("Create"),
              ),
            ],
          );
        },
      ),
    );
  }

  static Future<Map<String, String>?> showEditProjectDialog(
    BuildContext context,
    Map<String, dynamic> project,
  ) async {
    final nameController = TextEditingController(text: project['name']);
    final locationController = TextEditingController(text: project['location'] ?? '');

    // Geofence — pre-fill from existing project data
    double? siteLat = project['site_latitude'] != null
        ? (project['site_latitude'] as num).toDouble()
        : null;
    double? siteLng = project['site_longitude'] != null
        ? (project['site_longitude'] as num).toDouble()
        : null;
    double geofenceRadius =
        ((project['geofence_radius_m'] as int?) ?? 200).toDouble();
    bool geofenceEnabled = siteLat != null && siteLng != null;
    bool isFetchingLocation = false;
    String? locationError;

    return showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Edit Site"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Site Name"),
                ),
                const SizedBox(height: AppTheme.spacingM),
                TextField(
                  controller: locationController,
                  decoration: const InputDecoration(labelText: "Location"),
                ),

                const SizedBox(height: AppTheme.spacingL),
                const Divider(),

                // Geofence toggle
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("Site Geofence",
                    style: AppTheme.headingSmall.copyWith(color: AppTheme.primaryIndigo)),
                  subtitle: const Text("Require workers to be on-site to check in",
                    style: TextStyle(fontSize: 12)),
                  value: geofenceEnabled,
                  activeColor: AppTheme.primaryIndigo,
                  onChanged: (v) => setState(() => geofenceEnabled = v),
                ),

                if (geofenceEnabled) ...[
                  const SizedBox(height: AppTheme.spacingS),

                  // Use Current Location button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: isFetchingLocation
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(
                              siteLat != null ? Icons.check_circle : Icons.my_location,
                              size: 18,
                            ),
                      label: Text(
                        isFetchingLocation
                            ? 'Getting location...'
                            : siteLat != null
                                ? 'Location set (${siteLat!.toStringAsFixed(5)}, ${siteLng!.toStringAsFixed(5)})'
                                : 'Use Current Location',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: siteLat != null
                            ? AppTheme.successGreen
                            : AppTheme.primaryIndigo,
                        side: BorderSide(
                          color: siteLat != null
                              ? AppTheme.successGreen
                              : AppTheme.primaryIndigo,
                        ),
                      ),
                      onPressed: isFetchingLocation
                          ? null
                          : () async {
                              setState(() {
                                isFetchingLocation = true;
                                locationError = null;
                              });

                              try {
                                bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                                if (!serviceEnabled) {
                                  setState(() {
                                    locationError = 'Location services are disabled.';
                                    isFetchingLocation = false;
                                  });
                                  return;
                                }

                                LocationPermission permission = await Geolocator.checkPermission();
                                if (permission == LocationPermission.denied) {
                                  permission = await Geolocator.requestPermission();
                                }
                                if (permission == LocationPermission.denied ||
                                    permission == LocationPermission.deniedForever) {
                                  setState(() {
                                    locationError = 'Location permission denied.';
                                    isFetchingLocation = false;
                                  });
                                  return;
                                }

                                final position = await Geolocator.getCurrentPosition(
                                  locationSettings: const LocationSettings(
                                    accuracy: LocationAccuracy.high,
                                    timeLimit: Duration(seconds: 15),
                                  ),
                                );

                                setState(() {
                                  siteLat = position.latitude;
                                  siteLng = position.longitude;
                                  isFetchingLocation = false;
                                });
                              } catch (e) {
                                setState(() {
                                  locationError = 'Failed to get location.';
                                  isFetchingLocation = false;
                                });
                              }
                            },
                    ),
                  ),

                  if (locationError != null) ...[
                    const SizedBox(height: AppTheme.spacingS),
                    Text(locationError!,
                      style: TextStyle(fontSize: 12, color: AppTheme.errorRed)),
                  ],

                  const SizedBox(height: AppTheme.spacingM),

                  // Radius slider
                  Row(
                    children: [
                      const Text('Radius: ', style: TextStyle(fontSize: 13)),
                      Expanded(
                        child: Slider(
                          value: geofenceRadius,
                          min: 50,
                          max: 500,
                          divisions: 18,
                          label: '${geofenceRadius.round()}m',
                          activeColor: AppTheme.primaryIndigo,
                          onChanged: (v) => setState(() => geofenceRadius = v),
                        ),
                      ),
                      Text('${geofenceRadius.round()}m',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final result = {
                  'name': nameController.text.trim(),
                  'location': locationController.text.trim(),
                };

                if (geofenceEnabled && siteLat != null && siteLng != null) {
                  result['siteLat'] = siteLat.toString();
                  result['siteLng'] = siteLng.toString();
                  result['geofenceRadius'] = geofenceRadius.round().toString();
                } else {
                  // Explicitly clear geofence if disabled
                  result['clearGeofence'] = 'true';
                }

                Navigator.pop(context, result);
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> showAssignUserDialog(
    BuildContext context,
    Map<String, dynamic> project,
    String accountId,
  ) async {
    final supabase = Supabase.instance.client;
    final users = await supabase
        .from('users')
        .select()
        .eq('account_id', accountId)
        .neq('role', 'admin');

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
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
                      await supabase.from('users').update({
                        'current_project_id': project['id']
                      }).eq('id', user['id']);
                    } else {
                      await supabase.from('users').update({
                        'current_project_id': null
                      }).eq('id', user['id']);
                    }
                    // Refresh the dialog
                    Navigator.pop(context);
                    showAssignUserDialog(context, project, accountId);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Done"),
            ),
          ],
        ),
      ),
    );
  }

  /// Assign an owner to an existing project
  /// Shows existing owners to pick from, or option to invite new one
  static Future<void> showAssignOwnerDialog(
    BuildContext context,
    Map<String, dynamic> project,
    String accountId,
  ) async {
    final supabase = Supabase.instance.client;
    bool isLoading = true;
    List<Map<String, dynamic>> existingOwners = [];
    List<Map<String, dynamic>> currentProjectOwners = [];

    try {
      // Fetch all owners in the system
      existingOwners = await supabase
          .from('users')
          .select('id, email, full_name, phone_number')
          .eq('role', 'owner');

      // Fetch current project owners
      final linked = await supabase
          .from('project_owners')
          .select('owner_id')
          .eq('project_id', project['id']);
      currentProjectOwners = List<Map<String, dynamic>>.from(linked);

      isLoading = false;
    } catch (e) {
      debugPrint('Error loading owners: $e');
      isLoading = false;
    }

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final linkedOwnerIds = currentProjectOwners
              .map((po) => po['owner_id'])
              .toSet();

          return AlertDialog(
            title: Text("Assign Owner to ${project['name']}"),
            content: SizedBox(
              width: double.maxFinite,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (existingOwners.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(AppTheme.spacingM),
                            child: Text(
                              "No owner accounts exist yet. Create a new project with owner details to get started.",
                              style: AppTheme.bodySmall,
                            ),
                          )
                        else
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: existingOwners.length,
                              itemBuilder: (context, i) {
                                final owner = existingOwners[i];
                                final isLinked = linkedOwnerIds.contains(owner['id']);

                                return CheckboxListTile(
                                  title: Text(owner['full_name'] ?? owner['email'] ?? 'Owner'),
                                  subtitle: Text(owner['email'] ?? owner['phone_number'] ?? ''),
                                  value: isLinked,
                                  onChanged: (bool? value) async {
                                    try {
                                      if (value == true) {
                                        await supabase.from('project_owners').insert({
                                          'project_id': project['id'],
                                          'owner_id': owner['id'],
                                        });
                                        setState(() {
                                          currentProjectOwners.add({'owner_id': owner['id']});
                                        });
                                      } else {
                                        await supabase
                                            .from('project_owners')
                                            .delete()
                                            .eq('project_id', project['id'])
                                            .eq('owner_id', owner['id']);
                                        setState(() {
                                          currentProjectOwners.removeWhere(
                                            (po) => po['owner_id'] == owner['id'],
                                          );
                                        });
                                      }
                                    } catch (e) {
                                      debugPrint('Error updating owner link: $e');
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Text('Could not complete the operation. Please try again.'),
                                            backgroundColor: AppTheme.errorRed,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Done"),
              ),
            ],
          );
        },
      ),
    );
  }
}
