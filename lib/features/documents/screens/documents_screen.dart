import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/core/widgets/page_transitions.dart';
import 'package:houzzdat_app/features/documents/services/document_service.dart';
import 'package:houzzdat_app/features/documents/widgets/document_card.dart';
import 'package:houzzdat_app/features/documents/widgets/upload_document_sheet.dart';
import 'package:houzzdat_app/features/documents/screens/document_detail_screen.dart';
import 'package:houzzdat_app/models/models.dart';

/// Embedded tab body for Document Management — no Scaffold/AppBar,
/// used inside the manager dashboard's IndexedStack.
class DocumentsTabBody extends StatefulWidget {
  final String accountId;

  const DocumentsTabBody({super.key, required this.accountId});

  @override
  State<DocumentsTabBody> createState() => _DocumentsTabBodyState();
}

class _DocumentsTabBodyState extends State<DocumentsTabBody>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final _service = DocumentService();
  final _supabase = Supabase.instance.client;

  String? _currentProjectId;
  String _userRole = 'manager';
  String _searchQuery = '';
  DocumentApprovalStatus? _statusFilter;
  bool _isLoading = true;
  List<Document> _documents = [];
  List<Map<String, dynamic>> _projects = [];

  final _categories = [null, ...DocumentCategory.values];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _initializeUser();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) _loadDocuments();
  }

  Future<void> _initializeUser() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final userData = await _supabase
          .from('users')
          .select('role, current_project_id')
          .eq('id', userId)
          .maybeSingle();

      final projectsData = await _supabase
          .from('projects')
          .select('id, name')
          .eq('account_id', widget.accountId)
          .order('name', ascending: true);

      if (mounted) {
        setState(() {
          _userRole = userData?['role'] as String? ?? 'manager';
          _currentProjectId = userData?['current_project_id'] as String?;
          _projects = (projectsData as List)
              .map((p) => {'id': p['id'] as String, 'name': p['name'] as String})
              .toList();
          if (_currentProjectId == null && _projects.isNotEmpty) {
            _currentProjectId = _projects.first['id'] as String;
          }
        });
      }
      await _loadDocuments();
    } catch (e) {
      debugPrint('[DocumentsTabBody] _initializeUser error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDocuments() async {
    if (_currentProjectId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final selectedCat = _tabController.index == 0
          ? null
          : _categories[_tabController.index];

      final docs = await _service.getDocuments(
        projectId: _currentProjectId!,
        category: selectedCat,
        status: _statusFilter,
        search: _searchQuery.isEmpty ? null : _searchQuery,
      );

      if (mounted) setState(() { _documents = docs; _isLoading = false; });
    } catch (e) {
      debugPrint('[DocumentsTabBody] _loadDocuments error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openUploadSheet() async {
    if (_currentProjectId == null) return;
    final result = await UploadDocumentSheet.show(
      context,
      projectId: _currentProjectId!,
      accountId: widget.accountId,
    );
    if (result != null) {
      await _loadDocuments();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"${result.name}" uploaded successfully')),
        );
      }
    }
  }

  Future<void> _openDocument(Document doc) async {
    final updated = await Navigator.push<bool>(
      context,
      FadeSlideRoute(
        page: DocumentDetailScreen(document: doc, userRole: _userRole),
      ),
    );
    if (updated == true) await _loadDocuments();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        // Header bar with indigo background (matches Insights tab style)
        Material(
          color: AppTheme.primaryIndigo,
          child: Column(
            children: [
              // Project selector + stats
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    const Icon(LucideIcons.folderOpen, color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _projects.isEmpty
                          ? const Text('Documents', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                          : DropdownButton<String>(
                              value: _currentProjectId,
                              dropdownColor: AppTheme.primaryIndigo,
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              underline: const SizedBox.shrink(),
                              icon: const Icon(LucideIcons.chevronDown, color: Colors.white70, size: 16),
                              items: _projects.map((p) => DropdownMenuItem<String>(
                                value: p['id'] as String,
                                child: Text(p['name'] as String,
                                    style: const TextStyle(color: Colors.white, fontSize: 14)),
                              )).toList(),
                              onChanged: (val) {
                                setState(() => _currentProjectId = val);
                                _loadDocuments();
                              },
                            ),
                    ),
                    Text(
                      '${_documents.length} docs',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),

              // Category tab bar
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppTheme.accentAmber,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                tabAlignment: TabAlignment.start,
                tabs: [
                  const Tab(text: 'ALL'),
                  ...DocumentCategory.values.map((cat) => Tab(text: cat.shortLabel.toUpperCase())),
                ],
              ),
            ],
          ),
        ),

        // Filter bar
        _buildFilterBar(),

        // Document list
        Expanded(
          child: _buildDocumentList(),
        ),
      ],
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                  _loadDocuments();
                },
                decoration: InputDecoration(
                  hintText: 'Search documents...',
                  hintStyle: const TextStyle(fontSize: 13),
                  prefixIcon: const Icon(LucideIcons.search, size: 16),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _StatusFilterChip(
            selected: _statusFilter,
            onChanged: (val) {
              setState(() => _statusFilter = val);
              _loadDocuments();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentList() {
    if (_isLoading) {
      return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: 4,
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: ShimmerLoadingCard(),
        ),
      );
    }

    if (_documents.isEmpty) {
      return Stack(
        children: [
          EmptyStateWidget(
            icon: LucideIcons.folderOpen,
            title: 'No documents yet',
            subtitle: 'Upload the first document for this project',
            action: ElevatedButton(
              onPressed: _openUploadSheet,
              child: const Text('Upload Document'),
            ),
          ),
          Positioned(
            bottom: 24,
            right: 24,
            child: FloatingActionButton(
              heroTag: 'documents_fab',
              onPressed: _openUploadSheet,
              backgroundColor: AppTheme.primaryIndigo,
              child: const Icon(LucideIcons.upload, color: Colors.white),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _loadDocuments,
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: _documents.length,
            itemBuilder: (_, i) => DocumentCard(
              document: _documents[i],
              onTap: () => _openDocument(_documents[i]),
            ),
          ),
        ),
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton(
            heroTag: 'documents_fab',
            onPressed: _openUploadSheet,
            backgroundColor: AppTheme.primaryIndigo,
            child: const Icon(LucideIcons.upload, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  final DocumentApprovalStatus? selected;
  final ValueChanged<DocumentApprovalStatus?> onChanged;

  const _StatusFilterChip({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DocumentApprovalStatus?>(
      onSelected: onChanged,
      itemBuilder: (_) => [
        const PopupMenuItem(value: null, child: Text('All')),
        const PopupMenuItem(value: DocumentApprovalStatus.pendingApproval, child: Text('Pending')),
        const PopupMenuItem(value: DocumentApprovalStatus.approved, child: Text('Approved')),
        const PopupMenuItem(value: DocumentApprovalStatus.rejected, child: Text('Rejected')),
        const PopupMenuItem(value: DocumentApprovalStatus.draft, child: Text('Draft')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[350]!),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.filter, size: 14, color: AppTheme.textSecondary),
            const SizedBox(width: 4),
            Text(
              selected?.label ?? 'Status',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
