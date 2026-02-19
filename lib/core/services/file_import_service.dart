import 'dart:convert';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Parsed result from a CSV import, ready for preview and commit.
class ImportResult<T> {
  final List<T> rows;
  final List<String> warnings;
  final int totalParsed;
  final int validRows;

  const ImportResult({
    required this.rows,
    this.warnings = const [],
    required this.totalParsed,
    required this.validRows,
  });
}

/// A parsed milestone row from CSV.
class MilestoneImportRow {
  final String name;
  final String? description;
  final DateTime? plannedStart;
  final DateTime? plannedEnd;
  final double weightPercent;
  final int sortOrder;

  const MilestoneImportRow({
    required this.name,
    this.description,
    this.plannedStart,
    this.plannedEnd,
    this.weightPercent = 0,
    this.sortOrder = 0,
  });

  Map<String, dynamic> toInsertMap({
    required String planId,
    required String projectId,
    required String accountId,
  }) {
    return {
      'plan_id': planId,
      'project_id': projectId,
      'account_id': accountId,
      'name': name,
      'description': description,
      'planned_start': plannedStart?.toIso8601String().split('T').first,
      'planned_end': plannedEnd?.toIso8601String().split('T').first,
      'weight_percent': weightPercent,
      'sort_order': sortOrder,
    };
  }
}

/// A parsed budget line item from CSV.
class BudgetImportRow {
  final String category;
  final String lineItem;
  final double budgetedAmount;
  final double? budgetedQuantity;
  final String? unit;

  const BudgetImportRow({
    required this.category,
    required this.lineItem,
    required this.budgetedAmount,
    this.budgetedQuantity,
    this.unit,
  });

  Map<String, dynamic> toInsertMap({
    required String planId,
    required String projectId,
    required String accountId,
  }) {
    return {
      'plan_id': planId,
      'project_id': projectId,
      'account_id': accountId,
      'category': category,
      'line_item': lineItem,
      'budgeted_amount': budgetedAmount,
      'budgeted_quantity': budgetedQuantity,
      'unit': unit,
    };
  }
}

/// A parsed BOQ item from CSV.
class BOQImportRow {
  final String materialName;
  final String? category;
  final double plannedQuantity;
  final String unit;
  final double? budgetedRate;

  const BOQImportRow({
    required this.materialName,
    this.category,
    required this.plannedQuantity,
    required this.unit,
    this.budgetedRate,
  });

  Map<String, dynamic> toInsertMap({
    required String planId,
    required String projectId,
    required String accountId,
  }) {
    return {
      'plan_id': planId,
      'project_id': projectId,
      'account_id': accountId,
      'material_name': materialName,
      'category': category,
      'planned_quantity': plannedQuantity,
      'unit': unit,
      'budgeted_rate': budgetedRate,
      // budgeted_total is auto-computed by DB trigger
    };
  }
}

/// Service for importing CSV files for project plans, budgets, and BOQ.
class FileImportService {
  final _supabase = Supabase.instance.client;

  static const _validBudgetCategories = [
    'material',
    'labour',
    'overhead',
    'equipment',
    'other',
  ];

  /// Pick a CSV file from the device.
  Future<PlatformFile?> pickCSVFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    return result?.files.firstOrNull;
  }

  /// Parse CSV bytes into rows of string lists.
  List<List<dynamic>> _parseCSV(Uint8List bytes) {
    final content = utf8.decode(bytes);
    return const CsvToListConverter(eol: '\n').convert(content);
  }

  /// Try to parse a date from various common formats.
  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    // Try ISO format first
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;
    // Try DD/MM/YYYY
    final parts = s.split(RegExp(r'[/\-]'));
    if (parts.length == 3) {
      final d = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (d != null && m != null && y != null) {
        // Heuristic: if first part > 12, assume DD/MM/YYYY
        if (d > 12) return DateTime(y > 100 ? y : 2000 + y, m, d);
        // Otherwise assume MM/DD/YYYY
        return DateTime(y > 100 ? y : 2000 + y, d, m);
      }
    }
    return null;
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    final s = value.toString().trim().replaceAll(',', '');
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  // ─── MILESTONE IMPORT ──────────────────────────────────────

  /// Parse milestones from CSV file.
  /// Expected columns: Name, Description (optional), Start Date, End Date, Weight %
  ImportResult<MilestoneImportRow> parseMilestones(Uint8List bytes) {
    final rows = _parseCSV(bytes);
    if (rows.isEmpty) {
      return const ImportResult(rows: [], totalParsed: 0, validRows: 0);
    }

    // Skip header row
    final dataRows = rows.length > 1 ? rows.sublist(1) : rows;
    final parsed = <MilestoneImportRow>[];
    final warnings = <String>[];

    for (var i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      if (row.isEmpty || (row.length == 1 && row[0].toString().trim().isEmpty)) {
        continue; // Skip empty rows
      }

      final name = row.isNotEmpty ? row[0].toString().trim() : '';
      if (name.isEmpty) {
        warnings.add('Row ${i + 2}: Missing name, skipped');
        continue;
      }

      parsed.add(MilestoneImportRow(
        name: name,
        description: row.length > 1 ? row[1].toString().trim() : null,
        plannedStart: row.length > 2 ? _parseDate(row[2]) : null,
        plannedEnd: row.length > 3 ? _parseDate(row[3]) : null,
        weightPercent: row.length > 4 ? (_parseDouble(row[4]) ?? 0) : 0,
        sortOrder: i,
      ));
    }

    return ImportResult(
      rows: parsed,
      warnings: warnings,
      totalParsed: dataRows.length,
      validRows: parsed.length,
    );
  }

  /// Save parsed milestones to the database.
  Future<void> saveMilestones({
    required List<MilestoneImportRow> milestones,
    required String planId,
    required String projectId,
    required String accountId,
  }) async {
    final inserts = milestones
        .map((m) => m.toInsertMap(
              planId: planId,
              projectId: projectId,
              accountId: accountId,
            ))
        .toList();

    await _supabase.from('project_milestones').insert(inserts);
  }

  // ─── BUDGET IMPORT ─────────────────────────────────────────

  /// Parse budget line items from CSV.
  /// Expected columns: Category, Line Item, Amount, Quantity (optional), Unit (optional)
  ImportResult<BudgetImportRow> parseBudget(Uint8List bytes) {
    final rows = _parseCSV(bytes);
    if (rows.isEmpty) {
      return const ImportResult(rows: [], totalParsed: 0, validRows: 0);
    }

    final dataRows = rows.length > 1 ? rows.sublist(1) : rows;
    final parsed = <BudgetImportRow>[];
    final warnings = <String>[];

    for (var i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      if (row.isEmpty || (row.length == 1 && row[0].toString().trim().isEmpty)) {
        continue;
      }

      final rawCategory = row.isNotEmpty ? row[0].toString().trim().toLowerCase() : '';
      final lineItem = row.length > 1 ? row[1].toString().trim() : '';
      final amount = row.length > 2 ? _parseDouble(row[2]) : null;

      if (lineItem.isEmpty || amount == null) {
        warnings.add('Row ${i + 2}: Missing line item or amount, skipped');
        continue;
      }

      // Normalize category
      final category = _validBudgetCategories.contains(rawCategory)
          ? rawCategory
          : 'other';
      if (!_validBudgetCategories.contains(rawCategory)) {
        warnings.add('Row ${i + 2}: Unknown category "$rawCategory", defaulting to "other"');
      }

      parsed.add(BudgetImportRow(
        category: category,
        lineItem: lineItem,
        budgetedAmount: amount,
        budgetedQuantity: row.length > 3 ? _parseDouble(row[3]) : null,
        unit: row.length > 4 ? row[4].toString().trim() : null,
      ));
    }

    return ImportResult(
      rows: parsed,
      warnings: warnings,
      totalParsed: dataRows.length,
      validRows: parsed.length,
    );
  }

  /// Save parsed budget items to the database.
  Future<void> saveBudget({
    required List<BudgetImportRow> items,
    required String planId,
    required String projectId,
    required String accountId,
  }) async {
    final inserts = items
        .map((b) => b.toInsertMap(
              planId: planId,
              projectId: projectId,
              accountId: accountId,
            ))
        .toList();

    await _supabase.from('project_budgets').insert(inserts);
  }

  // ─── BOQ IMPORT ────────────────────────────────────────────

  /// Parse BOQ items from CSV.
  /// Expected columns: Material Name, Category, Quantity, Unit, Rate (per unit)
  ImportResult<BOQImportRow> parseBOQ(Uint8List bytes) {
    final rows = _parseCSV(bytes);
    if (rows.isEmpty) {
      return const ImportResult(rows: [], totalParsed: 0, validRows: 0);
    }

    final dataRows = rows.length > 1 ? rows.sublist(1) : rows;
    final parsed = <BOQImportRow>[];
    final warnings = <String>[];

    for (var i = 0; i < dataRows.length; i++) {
      final row = dataRows[i];
      if (row.isEmpty || (row.length == 1 && row[0].toString().trim().isEmpty)) {
        continue;
      }

      final materialName = row.isNotEmpty ? row[0].toString().trim() : '';
      final quantity = row.length > 2 ? _parseDouble(row[2]) : null;
      final unit = row.length > 3 ? row[3].toString().trim() : '';

      if (materialName.isEmpty || quantity == null || unit.isEmpty) {
        warnings.add('Row ${i + 2}: Missing material name, quantity, or unit, skipped');
        continue;
      }

      parsed.add(BOQImportRow(
        materialName: materialName,
        category: row.length > 1 ? row[1].toString().trim() : null,
        plannedQuantity: quantity,
        unit: unit,
        budgetedRate: row.length > 4 ? _parseDouble(row[4]) : null,
      ));
    }

    return ImportResult(
      rows: parsed,
      warnings: warnings,
      totalParsed: dataRows.length,
      validRows: parsed.length,
    );
  }

  /// Save parsed BOQ items to the database.
  Future<void> saveBOQ({
    required List<BOQImportRow> items,
    required String planId,
    required String projectId,
    required String accountId,
  }) async {
    final inserts = items
        .map((b) => b.toInsertMap(
              planId: planId,
              projectId: projectId,
              accountId: accountId,
            ))
        .toList();

    await _supabase.from('boq_items').insert(inserts);
  }

  // ─── PROJECT PLAN CRUD ─────────────────────────────────────

  /// Create a new project plan and return its ID.
  Future<String> createProjectPlan({
    required String projectId,
    required String accountId,
    required String name,
    double? totalBudget,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final result = await _supabase.from('project_plans').insert({
      'project_id': projectId,
      'account_id': accountId,
      'name': name,
      'total_budget': totalBudget,
      'start_date': startDate?.toIso8601String().split('T').first,
      'end_date': endDate?.toIso8601String().split('T').first,
      'uploaded_by': _supabase.auth.currentUser?.id,
    }).select('id').single();

    return result['id'] as String;
  }

  /// Get existing project plan for a project (most recent).
  Future<Map<String, dynamic>?> getProjectPlan(String projectId) async {
    final result = await _supabase
        .from('project_plans')
        .select()
        .eq('project_id', projectId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return result;
  }
}
