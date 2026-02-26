import 'package:houzzdat_app/models/models.dart';
import 'package:houzzdat_app/repositories/base_repository.dart';

/// CI-09: Repository for `projects` table operations.
///
/// Abstracts project queries from projects_tab.dart, owner_projects_tab.dart,
/// filter dropdowns, and site detail screens.
class ProjectsRepository extends BaseRepository {
  /// Fetch all projects for an account (sorted by name).
  Future<List<Project>> getByAccount(String accountId) async {
    final data = await safeQuery(
      () => supabase
          .from(DbTables.projects)
          .select('*')
          .eq(DbColumns.accountId, accountId)
          .order(DbColumns.name, ascending: true),
      label: 'getProjectsByAccount',
    );
    return (data as List).map((e) => Project.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Fetch project names only (lightweight for dropdowns).
  Future<List<Project>> getProjectNames(String accountId) async {
    final data = await safeQuery(
      () => supabase
          .from(DbTables.projects)
          .select('${DbColumns.id}, ${DbColumns.name}')
          .eq(DbColumns.accountId, accountId)
          .order(DbColumns.name, ascending: true),
      label: 'getProjectNames',
    );
    return (data as List).map((e) => Project.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Fetch a single project by ID.
  Future<Project?> getById(String projectId) async {
    final data = await safeQueryOrNull(
      () => supabase
          .from(DbTables.projects)
          .select('*')
          .eq(DbColumns.id, projectId)
          .maybeSingle(),
      label: 'getProjectById',
    );
    if (data == null) return null;
    return Project.fromJson(data);
  }

  /// Fetch projects linked to an owner via project_owners table.
  Future<List<Project>> getByOwner(String ownerId) async {
    final data = await safeQuery(
      () => supabase
          .from(DbTables.projectOwners)
          .select('${DbColumns.projectId}, projects(${DbColumns.id}, ${DbColumns.name}, ${DbColumns.location}, ${DbColumns.createdAt})')
          .eq(DbColumns.ownerId, ownerId),
      label: 'getProjectsByOwner',
    );

    final projects = <Project>[];
    for (final row in (data as List)) {
      final proj = row['projects'];
      if (proj != null && proj is Map<String, dynamic>) {
        projects.add(Project.fromJson(proj));
      }
    }
    return projects;
  }

  /// Get project name by ID (lightweight).
  Future<String?> getProjectName(String projectId) async {
    final data = await safeQueryOrNull(
      () => supabase
          .from(DbTables.projects)
          .select(DbColumns.name)
          .eq(DbColumns.id, projectId)
          .maybeSingle(),
      label: 'getProjectName',
    );
    return data?[DbColumns.name]?.toString();
  }

  /// Get project with geofence data (for attendance).
  Future<Project?> getWithGeofence(String projectId) async {
    final data = await safeQueryOrNull(
      () => supabase
          .from(DbTables.projects)
          .select('${DbColumns.name}, ${DbColumns.siteLatitude}, ${DbColumns.siteLongitude}, ${DbColumns.geofenceRadiusM}')
          .eq(DbColumns.id, projectId)
          .maybeSingle(),
      label: 'getProjectWithGeofence',
    );
    if (data == null) return null;
    return Project.fromJson({...data, DbColumns.id: projectId});
  }
}
