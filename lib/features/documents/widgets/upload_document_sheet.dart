import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/core/widgets/shared_widgets.dart';
import 'package:houzzdat_app/features/documents/services/document_service.dart';
import 'package:houzzdat_app/models/models.dart';

class UploadDocumentSheet extends StatefulWidget {
  final String projectId;
  final String accountId;

  const UploadDocumentSheet({
    super.key,
    required this.projectId,
    required this.accountId,
  });

  static Future<Document?> show(
    BuildContext context, {
    required String projectId,
    required String accountId,
  }) {
    return showModalBottomSheet<Document>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => UploadDocumentSheet(
        projectId: projectId,
        accountId: accountId,
      ),
    );
  }

  @override
  State<UploadDocumentSheet> createState() => _UploadDocumentSheetState();
}

class _UploadDocumentSheetState extends State<UploadDocumentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _versionNotesController = TextEditingController();
  final _service = DocumentService();

  File? _selectedFile;
  String? _selectedFileName;
  DocumentCategory _category = DocumentCategory.other;
  String? _subcategory;
  bool _requiresOwnerApproval = false;
  DateTime? _expiresAt;
  bool _isUploading = false;
  int _existingVersionCount = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _versionNotesController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'dwg'],
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final rawName = result.files.single.name;
      final nameWithoutExt = rawName.contains('.')
          ? rawName.substring(0, rawName.lastIndexOf('.'))
          : rawName;

      setState(() {
        _selectedFile = file;
        _selectedFileName = rawName;
        if (_nameController.text.isEmpty) {
          _nameController.text = nameWithoutExt;
        }
      });

      // Check for existing versions
      if (_nameController.text.isNotEmpty) {
        await _checkExistingVersion(_nameController.text);
      }
    }
  }

  Future<void> _checkExistingVersion(String name) async {
    final count = await _service.getExistingVersionCount(widget.projectId, name);
    if (mounted) setState(() => _existingVersionCount = count);
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _upload() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file to upload')),
      );
      return;
    }

    setState(() => _isUploading = true);
    try {
      final doc = await _service.uploadDocument(
        file: _selectedFile!,
        projectId: widget.projectId,
        accountId: widget.accountId,
        name: _nameController.text.trim(),
        category: _category,
        subcategory: _subcategory,
        versionNotes: _versionNotesController.text.trim().isEmpty
            ? null
            : _versionNotesController.text.trim(),
        requiresOwnerApproval: _requiresOwnerApproval,
        expiresAt: _expiresAt,
      );
      if (mounted) Navigator.pop(context, doc);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: 20 + viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Upload Document',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              // File picker
              _buildFilePicker(),
              const SizedBox(height: 16),

              // Document name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Document Name *',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Floor Plan - Ground Floor',
                ),
                onChanged: (val) {
                  if (val.trim().isNotEmpty) {
                    _checkExistingVersion(val.trim());
                  }
                },
                validator: (v) => (v?.trim().isEmpty ?? true) ? 'Required' : null,
              ),

              if (_existingVersionCount > 0) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryIndigo.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.info, size: 14, color: AppTheme.primaryIndigo),
                      const SizedBox(width: 8),
                      Text(
                        'This will create v${_existingVersionCount + 1} of "${ _nameController.text}"',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.primaryIndigo,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Category
              DropdownButtonFormField<DocumentCategory>(
                value: _category,
                decoration: const InputDecoration(
                  labelText: 'Category *',
                  border: OutlineInputBorder(),
                ),
                items: DocumentCategory.values.map((cat) => DropdownMenuItem(
                  value: cat,
                  child: Text(cat.label),
                )).toList(),
                onChanged: (val) => setState(() {
                  _category = val ?? DocumentCategory.other;
                  _subcategory = null;
                }),
              ),
              const SizedBox(height: 16),

              // Subcategory
              if (_category.subcategories.length > 1)
                DropdownButtonFormField<String>(
                  value: _subcategory,
                  decoration: const InputDecoration(
                    labelText: 'Subcategory',
                    border: OutlineInputBorder(),
                  ),
                  items: _category.subcategories.map((sub) => DropdownMenuItem(
                    value: sub,
                    child: Text(sub),
                  )).toList(),
                  onChanged: (val) => setState(() => _subcategory = val),
                ),
              if (_category.subcategories.length > 1) const SizedBox(height: 16),

              // Version notes
              TextFormField(
                controller: _versionNotesController,
                decoration: const InputDecoration(
                  labelText: 'Version Notes',
                  border: OutlineInputBorder(),
                  hintText: 'What changed in this version?',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Expiry date
              InkWell(
                onTap: _pickExpiryDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.calendar, size: 18, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        _expiresAt != null
                            ? 'Expires: ${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}'
                            : 'Set expiry date (optional)',
                        style: TextStyle(
                          color: _expiresAt != null ? null : AppTheme.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      if (_expiresAt != null) ...[
                        const Spacer(),
                        GestureDetector(
                          onTap: () => setState(() => _expiresAt = null),
                          child: const Icon(LucideIcons.x, size: 16, color: AppTheme.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Owner approval toggle
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Requires Owner Approval',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                subtitle: const Text(
                  'Owner will be notified to review and approve',
                  style: TextStyle(fontSize: 12),
                ),
                value: _requiresOwnerApproval,
                activeColor: AppTheme.primaryIndigo,
                onChanged: (val) => setState(() => _requiresOwnerApproval = val),
              ),
              const SizedBox(height: 20),

              // Upload button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isUploading ? null : _upload,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(LucideIcons.upload),
                  label: Text(_isUploading ? 'Uploading...' : 'Upload Document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilePicker() {
    return InkWell(
      onTap: _pickFile,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          border: Border.all(
            color: _selectedFile != null ? AppTheme.successGreen : Colors.grey[350]!,
            width: _selectedFile != null ? 1.5 : 1,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(10),
          color: _selectedFile != null
              ? AppTheme.successGreen.withValues(alpha: 0.04)
              : Colors.grey[50],
        ),
        child: Column(
          children: [
            Icon(
              _selectedFile != null ? LucideIcons.checkCircle : LucideIcons.uploadCloud,
              size: 32,
              color: _selectedFile != null ? AppTheme.successGreen : AppTheme.textSecondary,
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFile != null ? _selectedFileName! : 'Tap to select file',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _selectedFile != null ? AppTheme.successGreen : AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'PDF, JPG, PNG, DWG — max 50 MB',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}
