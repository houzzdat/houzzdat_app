import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/insights/models/material_state.dart';
import 'package:houzzdat_app/features/insights/widgets/boq_consumption_widget.dart';

/// Full-screen drill-down for a single project's material pipeline.
class MaterialPipelineDetail extends StatefulWidget {
  final MaterialPipeline state;

  const MaterialPipelineDetail({super.key, required this.state});

  @override
  State<MaterialPipelineDetail> createState() => _MaterialPipelineDetailState();
}

class _MaterialPipelineDetailState extends State<MaterialPipelineDetail>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _statusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundGrey,
      appBar: AppBar(
        title: Text(widget.state.projectName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.primaryIndigo,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.accentAmber,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'PIPELINE'),
            Tab(text: 'BOQ'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPipelineTab(),
          SingleChildScrollView(
            child: BOQConsumptionWidget(state: widget.state),
          ),
        ],
      ),
    );
  }

  Widget _buildPipelineTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pipeline visualization (larger version)
          _buildPipelineHero(),

          // Cost summary
          _buildCostCard(),

          // Alerts
          if (widget.state.alerts.isNotEmpty) ...[
            _buildSectionHeader('ALERTS'),
            ...widget.state.alerts.map(_buildAlertRow),
          ],

          // Filter chips
          _buildSectionHeader('MATERIALS'),
          _buildFilterChips(),

          // Filtered items
          ..._filteredItems.map(_buildMaterialItemRow),

          if (_filteredItems.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No materials in this stage',
                  style: AppTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<MaterialItem> get _filteredItems {
    if (_statusFilter == 'all') return widget.state.items;
    return widget.state.items.where((i) => i.status == _statusFilter).toList();
  }

  Widget _buildPipelineHero() {
    final stages = [
      ('Requested', widget.state.requested, const Color(0xFF9E9E9E), Icons.record_voice_over),
      ('Planned', widget.state.planned, const Color(0xFF1565C0), Icons.checklist),
      ('Ordered', widget.state.ordered, const Color(0xFFEF6C00), Icons.shopping_cart),
      ('Delivered', widget.state.delivered, const Color(0xFF2E7D32), Icons.local_shipping),
      ('Installed', widget.state.installed, const Color(0xFF1A237E), Icons.check_circle),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: stages.asMap().entries.map((entry) {
              final i = entry.key;
              final (label, count, color, icon) = entry.value;
              return Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: count > 0 ? color.withValues(alpha: 0.12) : Colors.grey.shade100,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: count > 0 ? color : Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(icon, size: 16, color: count > 0 ? color : Colors.grey.shade400),
                                Text(
                                  '$count',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: count > 0 ? color : Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            label,
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    if (i < stages.length - 1)
                      Icon(Icons.arrow_forward, size: 14, color: Colors.grey.shade300),
                  ],
                ),
              );
            }).toList(),
          ),
          if (widget.state.urgentPending > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.priority_high, size: 14, color: AppTheme.errorRed),
                  const SizedBox(width: 4),
                  Text(
                    '${widget.state.urgentPending} urgent item${widget.state.urgentPending == 1 ? '' : 's'} not yet ordered',
                    style: const TextStyle(fontSize: 12, color: AppTheme.errorRed, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCostCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text('Estimated', style: AppTheme.caption),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(widget.state.estimatedCost),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
          Container(width: 1, height: 36, color: Colors.grey.shade200),
          Expanded(
            child: Column(
              children: [
                Text('Actual Spend', style: AppTheme.caption),
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(widget.state.actualSpend),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: widget.state.actualSpend > widget.state.estimatedCost
                        ? AppTheme.errorRed
                        : AppTheme.successGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertRow(MaterialAlert alert) {
    final color = alert.severity == 'critical' ? AppTheme.errorRed : AppTheme.warningOrange;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            alert.severity == 'critical' ? Icons.error : Icons.warning_amber,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              alert.message,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      ('all', 'All', widget.state.items.length),
      ('requested', 'Requested', widget.state.requested),
      ('planned', 'Planned', widget.state.planned),
      ('ordered', 'Ordered', widget.state.ordered),
      ('delivered', 'Delivered', widget.state.delivered),
      ('installed', 'Installed', widget.state.installed),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: filters.map((f) {
          final (value, label, count) = f;
          final isSelected = _statusFilter == value;
          return ChoiceChip(
            label: Text(
              count > 0 ? '$label ($count)' : label,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            selected: isSelected,
            selectedColor: AppTheme.primaryIndigo,
            onSelected: (_) => setState(() => _statusFilter = value),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMaterialItemRow(MaterialItem item) {
    final statusConfig = _getStatusConfig(item.status);
    final dateFormat = DateFormat('MMM d');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: item.isOverdue
              ? AppTheme.errorRed.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // Status icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: statusConfig.$2.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(statusConfig.$1, size: 18, color: statusConfig.$2),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '${item.quantity.toStringAsFixed(1)} ${item.unit}',
                      style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (item.category != null) ...[
                      const SizedBox(width: 8),
                      Text(item.category!, style: AppTheme.caption),
                    ],
                    if (item.vendor != null) ...[
                      const SizedBox(width: 8),
                      Text(item.vendor!, style: AppTheme.caption),
                    ],
                  ],
                ),
                if (item.deliveryDate != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.local_shipping,
                        size: 12,
                        color: item.isOverdue ? AppTheme.errorRed : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.isOverdue
                            ? 'Overdue (${dateFormat.format(item.deliveryDate!)})'
                            : 'Due ${dateFormat.format(item.deliveryDate!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: item.isOverdue ? AppTheme.errorRed : AppTheme.textSecondary,
                          fontWeight: item.isOverdue ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          // Urgency + price
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (item.urgency != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getUrgencyColor(item.urgency!).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    item.urgency!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: _getUrgencyColor(item.urgency!),
                    ),
                  ),
                ),
              if (item.unitPrice != null) ...[
                const SizedBox(height: 4),
                Text(
                  _formatCurrency(item.unitPrice! * item.quantity),
                  style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  (IconData, Color) _getStatusConfig(String status) {
    switch (status) {
      case 'installed': return (Icons.check_circle, const Color(0xFF1A237E));
      case 'delivered': return (Icons.local_shipping, AppTheme.successGreen);
      case 'ordered': return (Icons.shopping_cart, AppTheme.warningOrange);
      case 'planned': return (Icons.checklist, AppTheme.infoBlue);
      case 'requested':
      default:
        return (Icons.record_voice_over, AppTheme.textSecondary);
    }
  }

  Color _getUrgencyColor(String urgency) {
    switch (urgency.toLowerCase()) {
      case 'critical': return AppTheme.errorRed;
      case 'high': return AppTheme.warningOrange;
      case 'medium': return AppTheme.infoBlue;
      default: return AppTheme.textSecondary;
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title, style: AppTheme.caption.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      )),
    );
  }

  String _formatCurrency(double amount) {
    if (amount >= 10000000) return '${(amount / 10000000).toStringAsFixed(1)} Cr';
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)} L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)} K';
    return amount.toStringAsFixed(0);
  }
}
