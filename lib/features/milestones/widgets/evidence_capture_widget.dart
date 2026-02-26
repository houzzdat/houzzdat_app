import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/models/models.dart';

/// A compact widget that allows capturing photo, document, or voice evidence
/// for a checklist item. Displays a thumbnail if evidence is already uploaded.
class EvidenceCaptureWidget extends StatelessWidget {
  final EvidenceRequiredType type;
  final String? existingUrl;
  final bool isCompleted;
  final void Function(XFile photo)? onPhotoCaptured;
  final void Function(File file)? onDocumentPicked;

  const EvidenceCaptureWidget({
    super.key,
    required this.type,
    this.existingUrl,
    required this.isCompleted,
    this.onPhotoCaptured,
    this.onDocumentPicked,
  });

  @override
  Widget build(BuildContext context) {
    if (type == EvidenceRequiredType.none) return const SizedBox.shrink();

    final hasEvidence = existingUrl != null;

    return GestureDetector(
      onTap: hasEvidence ? () => _viewEvidence(context) : () => _captureEvidence(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: hasEvidence
              ? AppTheme.successGreen.withValues(alpha: 0.1)
              : _evidenceColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: hasEvidence ? AppTheme.successGreen : _evidenceColor,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasEvidence ? LucideIcons.checkCircle : _evidenceIcon,
              size: 13,
              color: hasEvidence ? AppTheme.successGreen : _evidenceColor,
            ),
            const SizedBox(width: 4),
            Text(
              hasEvidence ? 'Evidence' : _evidenceLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: hasEvidence ? AppTheme.successGreen : _evidenceColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _captureEvidence(BuildContext context) async {
    switch (type) {
      case EvidenceRequiredType.photo:
        await _capturePhoto(context);
        break;
      case EvidenceRequiredType.document:
        await _pickDocument(context);
        break;
      case EvidenceRequiredType.voice:
        // Voice evidence handled by parent (uses AudioRecorderService)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Use voice recording to add evidence')),
        );
        break;
      default:
        break;
    }
  }

  Future<void> _capturePhoto(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(LucideIcons.camera),
                title: const Text('Take Photo'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(LucideIcons.image),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (photo != null) onPhotoCaptured?.call(photo);
  }

  Future<void> _pickDocument(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null && result.files.single.path != null) {
      onDocumentPicked?.call(File(result.files.single.path!));
    }
  }

  void _viewEvidence(BuildContext context) {
    if (existingUrl == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: Row(
                children: [
                  const Text('Evidence', style: TextStyle(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            if (existingUrl!.contains('.pdf'))
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(LucideIcons.file, color: AppTheme.primaryIndigo),
                    const SizedBox(width: 8),
                    const Text('PDF Document attached'),
                  ],
                ),
              )
            else
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  existingUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(LucideIcons.imageOff, size: 48),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Color get _evidenceColor {
    switch (type) {
      case EvidenceRequiredType.photo: return AppTheme.primaryIndigo;
      case EvidenceRequiredType.document: return const Color(0xFFE65100);
      case EvidenceRequiredType.voice: return AppTheme.accentAmber;
      default: return AppTheme.textSecondary;
    }
  }

  IconData get _evidenceIcon {
    switch (type) {
      case EvidenceRequiredType.photo: return LucideIcons.camera;
      case EvidenceRequiredType.document: return LucideIcons.fileText;
      case EvidenceRequiredType.voice: return LucideIcons.mic;
      default: return LucideIcons.paperclip;
    }
  }

  String get _evidenceLabel {
    switch (type) {
      case EvidenceRequiredType.photo: return 'Add Photo';
      case EvidenceRequiredType.document: return 'Add Doc';
      case EvidenceRequiredType.voice: return 'Add Voice';
      default: return 'Evidence';
    }
  }
}
