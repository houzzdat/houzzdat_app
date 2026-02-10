import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';

/// Wraps a widget in MaterialApp for testing
Widget createTestableWidget(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: Scaffold(body: child),
  );
}

/// Wraps a widget in MaterialApp with a Scaffold already wrapping it
Widget createTestableWidgetWithScaffold(Widget child) {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    home: child,
  );
}

/// Creates a minimal voice note map for testing
Map<String, dynamic> createTestVoiceNote({
  String id = 'test-note-1',
  String status = 'completed',
  String? transcription,
  String? transcriptFinal,
  String? transcriptRaw,
  String? audioUrl = 'https://example.com/audio.m4a',
  String? userId = 'user-1',
  String? recipientId,
  String? recipientName,
  String? category,
  String? detectedLanguageCode = 'en',
  String? createdAt,
  Map<String, dynamic>? actionItem,
  List<Map<String, dynamic>>? managerResponses,
}) {
  return {
    'id': id,
    'status': status,
    'transcription': transcription,
    'transcript_final': transcriptFinal,
    'transcript_raw': transcriptRaw,
    'audio_url': audioUrl,
    'user_id': userId,
    'recipient_id': recipientId,
    'recipient_name': recipientName,
    'category': category,
    'detected_language_code': detectedLanguageCode,
    'created_at': createdAt ?? DateTime.now().toIso8601String(),
    'action_item': actionItem,
    'manager_responses': managerResponses,
  };
}

/// Creates a test approval request map
Map<String, dynamic> createTestApproval({
  String id = 'approval-1',
  String status = 'pending',
  String? category = 'spending',
  String? title = 'Test Approval',
  String? description = 'Test description',
  double? amount = 5000.0,
  String? currency = 'INR',
  String? requestedByName = 'John Manager',
  String? projectName = 'Test Site',
  String? ownerResponse,
}) {
  return {
    'id': id,
    'status': status,
    'category': category,
    'title': title,
    'description': description,
    'amount': amount,
    'currency': currency,
    'requested_by_name': requestedByName,
    'project_name': projectName,
    'owner_response': ownerResponse,
  };
}

/// Creates a test invoice map
Map<String, dynamic> createTestInvoice({
  String id = 'inv-1',
  String status = 'submitted',
  double amount = 10000.0,
  String vendor = 'Test Vendor',
  String invoiceNumber = 'INV-001',
  String? dueDate,
  String? description = 'Test invoice',
  String? notes,
  String? rejectionReason,
  Map<String, dynamic>? projects,
  Map<String, dynamic>? users,
}) {
  return {
    'id': id,
    'status': status,
    'amount': amount,
    'vendor': vendor,
    'invoice_number': invoiceNumber,
    'due_date': dueDate,
    'description': description,
    'notes': notes,
    'rejection_reason': rejectionReason,
    'projects': projects ?? {'name': 'Test Site'},
    'users': users ?? {'full_name': 'Test User'},
  };
}

/// Creates a test project map
Map<String, dynamic> createTestProject({
  String id = 'project-1',
  String name = 'Test Site',
  String? location = 'Mumbai',
  String? accountId = 'account-1',
}) {
  return {
    'id': id,
    'name': name,
    'location': location,
    'account_id': accountId,
  };
}
