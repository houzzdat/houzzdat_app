import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:houzzdat_app/features/insights/models/material_state.dart';

/// Tracks materials through the procurement pipeline with BOQ consumption tracking.
class MaterialStateAgent {
  final _supabase = Supabase.instance.client;

  /// Compute material pipeline for all projects + company-wide summary.
  Future<List<MaterialPipeline>> computeAllProjects(String accountId) async {
    final projects = await _supabase
        .from('projects')
        .select('id, name')
        .eq('account_id', accountId);

    final results = <MaterialPipeline>[];
    for (final project in projects) {
      final state = await computeProject(
        project['id'] as String,
        project['name'] as String? ?? 'Unnamed',
        accountId,
      );
      results.add(state);
    }

    // Company-wide summary
    if (results.isNotEmpty) {
      results.insert(0, _computeCompanyWide(results));
    }

    return results;
  }

  /// Compute material pipeline for a single project.
  Future<MaterialPipeline> computeProject(
    String projectId,
    String projectName,
    String accountId,
  ) async {
    final results = await Future.wait([
      _safeFetch('materialRequests', () => _fetchMaterialRequests(projectId, accountId)),
      _safeFetch('materialSpecs', () => _fetchMaterialSpecs(projectId, accountId)),
      _safeFetch('boqItems', () => _fetchBOQItems(projectId)),
      _safeFetch('transactions', () => _fetchMaterialTransactions(projectId)),
    ]);

    final requests = results[0] as List<Map<String, dynamic>>;
    final specs = results[1] as List<Map<String, dynamic>>;
    final boqItems = results[2] as List<Map<String, dynamic>>;
    final transactions = results[3] as List<Map<String, dynamic>>;

    // Pipeline counts from material_specs
    final planned = specs.where((s) => s['status'] == 'planned').length;
    final ordered = specs.where((s) => s['status'] == 'ordered').length;
    final delivered = specs.where((s) => s['status'] == 'delivered').length;
    final installed = specs.where((s) => s['status'] == 'installed').length;
    final requested = requests.length;

    // Build material items list
    final items = <MaterialItem>[];
    for (final r in requests) {
      items.add(MaterialItem(
        name: r['material_name']?.toString() ?? 'Unknown',
        category: r['material_category']?.toString(),
        status: 'requested',
        quantity: (r['quantity'] as num?)?.toDouble() ?? 0,
        unit: r['unit']?.toString() ?? '',
        urgency: r['urgency']?.toString(),
      ));
    }
    for (final s in specs) {
      items.add(MaterialItem(
        id: s['id']?.toString(),
        name: s['material_name']?.toString() ?? 'Unknown',
        category: s['category']?.toString(),
        status: s['status']?.toString() ?? 'planned',
        quantity: (s['quantity'] as num?)?.toDouble() ?? 0,
        unit: s['unit']?.toString() ?? '',
        unitPrice: (s['unit_price'] as num?)?.toDouble(),
        vendor: s['vendor']?.toString(),
      ));
    }

    // Urgency: high/critical requests not yet in specs
    final urgentPending = requests.where((r) {
      final urgency = r['urgency']?.toString()?.toLowerCase() ?? '';
      return urgency == 'high' || urgency == 'critical';
    }).length;

    // Cost calculations
    final estimatedCost = specs.fold(0.0, (sum, s) {
      final price = (s['unit_price'] as num?)?.toDouble() ?? 0;
      final qty = (s['quantity'] as num?)?.toDouble() ?? 0;
      return sum + price * qty;
    });
    final actualSpend = transactions.fold(0.0, (sum, t) =>
        sum + ((t['amount'] as num?)?.toDouble() ?? 0));

    // BOQ vs Consumption
    final hasBOQ = boqItems.isNotEmpty;
    final boqVariances = <BOQVarianceItem>[];
    int boqFullyConsumed = 0;
    int boqOverConsumed = 0;
    double boqBudgetTotal = 0;
    double boqActualTotal = 0;
    final alerts = <MaterialAlert>[];

    for (final boq in boqItems) {
      final plannedQty = (boq['planned_quantity'] as num?)?.toDouble() ?? 0;
      final consumedQty = (boq['consumed_quantity'] as num?)?.toDouble() ?? 0;
      final budgetedRate = (boq['budgeted_rate'] as num?)?.toDouble() ?? 0;
      final budgetedTotal = (boq['budgeted_total'] as num?)?.toDouble() ?? (budgetedRate * plannedQty);
      final actualCost = (boq['actual_spend'] as num?)?.toDouble() ?? 0;
      final status = boq['status']?.toString() ?? 'planned';
      final materialName = boq['material_name']?.toString() ?? 'Unknown';

      boqBudgetTotal += budgetedTotal;
      boqActualTotal += actualCost;

      if (status == 'fully_consumed') boqFullyConsumed++;
      if (status == 'over_consumed') {
        boqOverConsumed++;
        alerts.add(MaterialAlert(
          message: '$materialName: consumed ${consumedQty.toStringAsFixed(1)} of ${plannedQty.toStringAsFixed(1)} ${boq['unit'] ?? ''} (over by ${(consumedQty - plannedQty).toStringAsFixed(1)})',
          severity: 'critical',
          materialName: materialName,
        ));
      }

      boqVariances.add(BOQVarianceItem(
        materialName: materialName,
        category: boq['category']?.toString(),
        plannedQty: plannedQty,
        consumedQty: consumedQty,
        unit: boq['unit']?.toString() ?? '',
        plannedCost: budgetedTotal,
        actualCost: actualCost,
        qtyVariance: plannedQty - consumedQty,
        costVariance: budgetedTotal - actualCost,
        status: status,
      ));
    }

    final boqVariance = boqBudgetTotal - boqActualTotal;
    final boqUtilization = boqBudgetTotal > 0 ? (boqActualTotal / boqBudgetTotal * 100) : 0.0;

    // Add alerts for urgent unordered
    if (urgentPending > 0) {
      alerts.add(MaterialAlert(
        message: '$urgentPending urgent material request(s) not yet ordered',
        severity: 'warning',
      ));
    }

    return MaterialPipeline(
      projectId: projectId,
      projectName: projectName,
      requested: requested,
      planned: planned,
      ordered: ordered,
      delivered: delivered,
      installed: installed,
      hasBOQ: hasBOQ,
      boqItemCount: boqItems.length,
      boqItemsFullyConsumed: boqFullyConsumed,
      boqItemsOverConsumed: boqOverConsumed,
      boqBudgetTotal: boqBudgetTotal,
      boqActualTotal: boqActualTotal,
      boqVariance: boqVariance,
      boqUtilization: boqUtilization,
      boqVariances: boqVariances,
      urgentPending: urgentPending,
      alerts: alerts,
      estimatedCost: estimatedCost,
      actualSpend: actualSpend,
      items: items,
    );
  }

  MaterialPipeline _computeCompanyWide(List<MaterialPipeline> projects) {
    int req = 0, plan = 0, ord = 0, del = 0, inst = 0;
    int boqCount = 0, boqFull = 0, boqOver = 0;
    double boqBudget = 0, boqActual = 0, estCost = 0, actSpend = 0;
    int urgent = 0;
    bool anyBOQ = false;
    final allAlerts = <MaterialAlert>[];

    for (final p in projects) {
      req += p.requested;
      plan += p.planned;
      ord += p.ordered;
      del += p.delivered;
      inst += p.installed;
      boqCount += p.boqItemCount;
      boqFull += p.boqItemsFullyConsumed;
      boqOver += p.boqItemsOverConsumed;
      boqBudget += p.boqBudgetTotal;
      boqActual += p.boqActualTotal;
      estCost += p.estimatedCost;
      actSpend += p.actualSpend;
      urgent += p.urgentPending;
      if (p.hasBOQ) anyBOQ = true;
      allAlerts.addAll(p.alerts);
    }

    return MaterialPipeline(
      projectId: null,
      projectName: 'All Projects',
      requested: req,
      planned: plan,
      ordered: ord,
      delivered: del,
      installed: inst,
      hasBOQ: anyBOQ,
      boqItemCount: boqCount,
      boqItemsFullyConsumed: boqFull,
      boqItemsOverConsumed: boqOver,
      boqBudgetTotal: boqBudget,
      boqActualTotal: boqActual,
      boqVariance: boqBudget - boqActual,
      boqUtilization: boqBudget > 0 ? (boqActual / boqBudget * 100) : 0,
      boqVariances: [],
      urgentPending: urgent,
      alerts: allAlerts,
      estimatedCost: estCost,
      actualSpend: actSpend,
      items: [],
    );
  }

  // ─── Safe Fetch Wrapper ────────────────────────────────────
  /// Wraps a DB query so one failure doesn't crash all parallel fetches.
  Future<List<Map<String, dynamic>>> _safeFetch(
    String label,
    Future<List<Map<String, dynamic>>> Function() fetcher,
  ) async {
    try {
      final result = await fetcher();
      debugPrint('MaterialStateAgent.$label: ${result.length} rows');
      return result;
    } catch (e) {
      debugPrint('MaterialStateAgent.$label FAILED: $e');
      return []; // Return empty instead of crashing Future.wait
    }
  }

  // ─── Data Fetchers ──────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _fetchMaterialRequests(String projectId, String accountId) async {
    return await _supabase
        .from('voice_note_material_requests')
        .select('material_name, material_category, quantity, unit, urgency, confidence_score')
        .eq('project_id', projectId);
  }

  Future<List<Map<String, dynamic>>> _fetchMaterialSpecs(String projectId, String accountId) async {
    return await _supabase
        .from('material_specs')
        .select('id, material_name, category, quantity, unit, unit_price, vendor, status')
        .eq('project_id', projectId);
  }

  Future<List<Map<String, dynamic>>> _fetchBOQItems(String projectId) async {
    return await _supabase
        .from('boq_items')
        .select()
        .eq('project_id', projectId);
  }

  Future<List<Map<String, dynamic>>> _fetchMaterialTransactions(String projectId) async {
    return await _supabase
        .from('finance_transactions')
        .select('amount, created_at')
        .eq('project_id', projectId)
        .eq('type', 'purchase');
  }
}
