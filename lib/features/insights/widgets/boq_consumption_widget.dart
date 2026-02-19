import 'package:flutter/material.dart';
import 'package:houzzdat_app/core/theme/app_theme.dart';
import 'package:houzzdat_app/features/insights/models/material_state.dart';

/// BOQ consumption table: planned quantities vs consumed quantities per material.
class BOQConsumptionWidget extends StatelessWidget {
  final MaterialPipeline state;

  const BOQConsumptionWidget({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    if (!state.hasBOQ) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No BOQ uploaded yet',
            style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary card
        _buildSummaryCard(),

        // Section header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text('MATERIAL ITEMS', style: AppTheme.caption.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          )),
        ),

        // BOQ items
        ...state.boqVariances.map(_buildBOQItemRow),
      ],
    );
  }

  Widget _buildSummaryCard() {
    final utilColor = state.boqUtilization > 100
        ? AppTheme.errorRed
        : state.boqUtilization > 80
            ? AppTheme.warningOrange
            : AppTheme.successGreen;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('BOQ Overview', style: AppTheme.headingSmall),
              if (state.boqItemsOverConsumed > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${state.boqItemsOverConsumed} over-consumed',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.errorRed),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats row
          Row(
            children: [
              Expanded(
                child: _buildStatBlock(
                  '${state.boqItemCount}',
                  'Total Items',
                  AppTheme.textPrimary,
                ),
              ),
              Expanded(
                child: _buildStatBlock(
                  '${state.boqItemsFullyConsumed}',
                  'Fully Used',
                  AppTheme.successGreen,
                ),
              ),
              Expanded(
                child: _buildStatBlock(
                  '${state.boqItemsOverConsumed}',
                  'Over Used',
                  state.boqItemsOverConsumed > 0 ? AppTheme.errorRed : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Budget vs Actual
          Row(
            children: [
              Expanded(
                child: _buildStatBlock(
                  _formatCurrency(state.boqBudgetTotal),
                  'Budgeted',
                  AppTheme.textPrimary,
                ),
              ),
              Expanded(
                child: _buildStatBlock(
                  _formatCurrency(state.boqActualTotal),
                  'Actual',
                  utilColor,
                ),
              ),
              Expanded(
                child: _buildStatBlock(
                  _formatCurrency(state.boqVariance.abs()),
                  state.boqVariance >= 0 ? 'Saved' : 'Over',
                  state.boqVariance >= 0 ? AppTheme.successGreen : AppTheme.errorRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Utilization bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Overall Consumption', style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600)),
              Text('${state.boqUtilization.round()}%',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: utilColor)),
            ],
          ),
          const SizedBox(height: 6),
          Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (state.boqUtilization / 100).clamp(0, 1),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    color: utilColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBlock(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTheme.caption),
      ],
    );
  }

  Widget _buildBOQItemRow(BOQVarianceItem item) {
    final consumption = item.plannedQty > 0
        ? (item.consumedQty / item.plannedQty * 100)
        : 0.0;
    final statusColor = _getStatusColor(item.status);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + category + status
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.materialName,
                      style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.category != null)
                      Text(
                        _formatCategory(item.category!),
                        style: AppTheme.caption,
                      ),
                  ],
                ),
              ),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _statusLabel(item.status),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Consumption bar
          Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              FractionallySizedBox(
                widthFactor: (consumption / 100).clamp(0, 1),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Quantity and cost details
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text('Qty: ', style: AppTheme.caption),
                    Text(
                      '${item.consumedQty.toStringAsFixed(1)} / ${item.plannedQty.toStringAsFixed(1)} ${item.unit}',
                      style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text('Cost: ', style: AppTheme.caption),
                  Text(
                    '${_formatCurrency(item.actualCost)} / ${_formatCurrency(item.plannedCost)}',
                    style: AppTheme.caption.copyWith(fontWeight: FontWeight.w600, color: statusColor),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'over_consumed': return AppTheme.errorRed;
      case 'fully_consumed': return AppTheme.successGreen;
      case 'partially_consumed': return AppTheme.infoBlue;
      case 'planned':
      default:
        return AppTheme.textSecondary;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'over_consumed': return 'OVER';
      case 'fully_consumed': return 'DONE';
      case 'partially_consumed': return 'PARTIAL';
      case 'planned':
      default:
        return 'PLANNED';
    }
  }

  String _formatCategory(String category) {
    return category.replaceAll('_', ' ').split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  String _formatCurrency(double amount) {
    if (amount >= 10000000) return '${(amount / 10000000).toStringAsFixed(1)} Cr';
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)} L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)} K';
    return amount.toStringAsFixed(0);
  }
}
