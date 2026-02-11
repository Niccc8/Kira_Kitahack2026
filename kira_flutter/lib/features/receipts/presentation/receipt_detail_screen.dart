import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../../data/models/receipt.dart';
import '../../../data/models/line_item.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/typography.dart';
import '../../../core/constants/spacing.dart';
import '../../../providers/auth_providers.dart';
import 'package:intl/intl.dart';

enum ReceiptDetailMode {
  emissions, // Focus on CO2 & environmental impact
  gita,      // Focus on GITA tax benefits
}

class ReceiptDetailScreen extends ConsumerWidget {
  final Receipt receipt;
  final ReceiptDetailMode mode;

  const ReceiptDetailScreen({
    super.key,
    required this.receipt,
    this.mode = ReceiptDetailMode.emissions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final userId = ref.watch(userIdProvider);
    
    return Scaffold(
      backgroundColor: KiraColors.background,
      appBar: AppBar(
        title: Text(mode == ReceiptDetailMode.gita ? 'GITA Receipt' : 'Receipt Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Receipt Image/PDF
            _buildReceiptMedia(userId),
            
            // Receipt Details
            Padding(
              padding: const EdgeInsets.all(KiraSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name
                  Text(
                    receipt.name,
                    style: KiraTypography.h2.copyWith(
                      color: KiraColors.text900,
                    ),
                  ),
                  
                  const SizedBox(height: KiraSpacing.xs),
                  
                  // Vendor & Date
                  Text(
                    '${receipt.vendor} • ${dateFormat.format(receipt.date)}',
                    style: KiraTypography.body2.copyWith(
                      color: KiraColors.text600,
                    ),
                  ),
                  
                  const SizedBox(height: KiraSpacing.xl),
                  
                  // Mode-specific content
                  if (mode == ReceiptDetailMode.gita)
                    _buildGITAView()
                  else
                    _buildEmissionsView(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// GITA-focused view
  Widget _buildGITAView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // GITA Highlight Card
        Container(
          padding: const EdgeInsets.all(KiraSpacing.xl),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                KiraColors.primary500,
                KiraColors.primary600,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: KiraColors.primary500.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.verified,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(width: KiraSpacing.sm),
                  Text(
                    'GITA Eligible',
                    style: KiraTypography.h3.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: KiraSpacing.lg),
              
              // Tax Savings - Big Number
              Text(
                'RM ${receipt.gitaAllowance.toStringAsFixed(2)}',
                style: KiraTypography.h1.copyWith(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              Text(
                'Tax Allowance',
                style: KiraTypography.body2.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              
              const SizedBox(height: KiraSpacing.lg),
              
              // Tier & Category
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KiraSpacing.md,
                  vertical: KiraSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  receipt.gitaTier != null && receipt.gitaCategory != null
                      ? 'Tier ${receipt.gitaTier} • ${receipt.gitaCategory}'
                      : 'GITA Eligible',
                  style: KiraTypography.body2.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: KiraSpacing.xl),
        
        // GITA Details
        Text(
          'Investment Details',
          style: KiraTypography.h4.copyWith(
            color: KiraColors.text900,
          ),
        ),
        
        const SizedBox(height: KiraSpacing.md),
        
        _buildInfoCard(
          'Total Investment',
          'RM ${receipt.total.toStringAsFixed(2)}',
          Icons.attach_money,
        ),
        
        const SizedBox(height: KiraSpacing.md),
        
        _buildInfoCard(
          'Category',
          receipt.gitaCategory ?? 'Green Investment',
          Icons.category_outlined,
        ),
        
        // Line Items - GITA eligible only
        const SizedBox(height: KiraSpacing.xl),
        
        Text(
          'GITA Eligible Items',
          style: KiraTypography.h4.copyWith(
            color: KiraColors.text900,
          ),
        ),
        
        const SizedBox(height: KiraSpacing.md),
        
        ...receipt.gitaItems.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: KiraSpacing.md),
          child: _buildLineItemCard(item, showGita: true),
        )),
        
        // Environmental Impact (Secondary)
        const SizedBox(height: KiraSpacing.xl),
        
        Text(
          'Environmental Impact',
          style: KiraTypography.h4.copyWith(
            color: KiraColors.text900,
          ),
        ),
        
        const SizedBox(height: KiraSpacing.md),
        
        _buildInfoCard(
          'CO₂ Savings',
          receipt.co2Kg > 0 
              ? '${receipt.co2Tonnes.toStringAsFixed(2)} tonnes avoided'
              : 'Renewable/Clean energy',
          Icons.eco,
          color: KiraColors.primary500,
        ),
      ],
    );
  }

  /// Emissions-focused view
  Widget _buildEmissionsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CO2 Highlight Card
        Container(
          padding: const EdgeInsets.all(KiraSpacing.xl),
          decoration: BoxDecoration(
            color: KiraColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: KiraColors.primary500.withOpacity(0.3), width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.co2,
                    color: KiraColors.primary500,
                    size: 28,
                  ),
                  const SizedBox(width: KiraSpacing.sm),
                  Text(
                    'Carbon Footprint',
                    style: KiraTypography.h4.copyWith(
                      color: KiraColors.text900,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: KiraSpacing.lg),
              
              // CO2 - Big Number
              Text(
                '${receipt.co2Tonnes.toStringAsFixed(2)}',
                style: KiraTypography.h1.copyWith(
                  color: KiraColors.primary500,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              Text(
                'tonnes CO₂',
                style: KiraTypography.body1.copyWith(
                  color: KiraColors.text700,
                ),
              ),
              
              const SizedBox(height: KiraSpacing.md),
              
              // Scope Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KiraSpacing.md,
                  vertical: KiraSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: KiraColors.primary500.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Scope ${receipt.scope} • ${_getScopeName(receipt.scope)}',
                  style: KiraTypography.body2.copyWith(
                    color: KiraColors.primary500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: KiraSpacing.xl),
        
        // Receipt Details
        Text(
          'Receipt Information',
          style: KiraTypography.h4.copyWith(
            color: KiraColors.text900,
          ),
        ),
        
        const SizedBox(height: KiraSpacing.md),
        
        _buildInfoCard(
          'Amount',
          'RM ${receipt.total.toStringAsFixed(2)}',
          Icons.attach_money,
        ),
        
        const SizedBox(height: KiraSpacing.md),
        
        _buildInfoCard(
          'Line Items',
          '${receipt.lineItems.length} item${receipt.lineItems.length != 1 ? 's' : ''}',
          Icons.inventory,
        ),
        
        const SizedBox(height: KiraSpacing.md),
        
        _buildInfoCard(
          'Category',
          _getCategoryName(receipt.category),
          Icons.category,
        ),
        
        // Line Items Breakdown
        const SizedBox(height: KiraSpacing.xl),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Items (${receipt.lineItems.length})',
              style: KiraTypography.h4.copyWith(
                color: KiraColors.text900,
              ),
            ),
            if (receipt.gitaEligible)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: KiraSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: KiraColors.primary500.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.savings,
                      color: KiraColors.primary500,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${receipt.gitaItems.length} GITA',
                      style: KiraTypography.caption.copyWith(
                        color: KiraColors.primary500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        
        const SizedBox(height: KiraSpacing.md),
        
        ...receipt.lineItems.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: KiraSpacing.md),
          child: _buildLineItemCard(item, showGita: false),
        )),
        
        // GITA Summary (if eligible)
        if (receipt.gitaEligible) ...[ const SizedBox(height: KiraSpacing.xl),
          
          Container(
            padding: const EdgeInsets.all(KiraSpacing.lg),
            decoration: BoxDecoration(
              color: KiraColors.primary500.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: KiraColors.primary500.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.savings,
                  color: KiraColors.primary500,
                  size: 20,
                ),
                const SizedBox(width: KiraSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GITA Eligible',
                        style: KiraTypography.body1.copyWith(
                          color: KiraColors.primary500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'RM ${receipt.gitaAllowance.toStringAsFixed(2)} tax allowance',
                        style: KiraTypography.caption.copyWith(
                          color: KiraColors.text700,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: KiraColors.text400,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReceiptMedia(String? userId) {
    // 1) Prefer URL stored on the receipt (signed URL, etc.)
    if (receipt.imageUrl != null && receipt.imageUrl!.trim().isNotEmpty) {
      return _buildMediaFromUrl(receipt.imageUrl!);
    }

    // 2) Otherwise, try to resolve from Firebase Storage using deterministic path
    if (userId == null || userId.trim().isEmpty) {
      return _buildNoImagePlaceholder();
    }

    final storagePath = 'users/$userId/receipts/${receipt.id}.jpg';
    final futureUrl = FirebaseStorage.instance.ref(storagePath).getDownloadURL();

    return FutureBuilder<String>(
      future: futureUrl,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            height: 200,
            color: KiraColors.surface,
            child: const Center(
              child: CircularProgressIndicator(color: KiraColors.primary500),
            ),
          );
        }

        final url = snapshot.data;
        if (snapshot.hasError || url == null || url.trim().isEmpty) {
          return _buildNoImagePlaceholder();
        }

        return _buildMediaFromUrl(url);
      },
    );
  }

  Widget _buildMediaFromUrl(String url) {
    final isPdf = url.toLowerCase().endsWith('.pdf');
    
    if (isPdf) {
      // PDF Viewer
      return Container(
        width: double.infinity,
        height: 500,
        color: KiraColors.surface,
        child: Column(
          children: [
            // PDF Header
            Container(
              padding: const EdgeInsets.all(KiraSpacing.md),
              decoration: BoxDecoration(
                color: KiraColors.primary500.withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(color: KiraColors.border),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.picture_as_pdf,
                    color: KiraColors.primary500,
                    size: 20,
                  ),
                  const SizedBox(width: KiraSpacing.sm),
                  Text(
                    'PDF Document',
                    style: KiraTypography.body2.copyWith(
                      color: KiraColors.text700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  // Download button could go here
                ],
              ),
            ),
            // PDF Widget
            Expanded(
              child: SfPdfViewer.network(
                url,
                onDocumentLoadFailed: (details) {
                  print('PDF load failed: ${details.error}');
                },
              ),
            ),
          ],
        ),
      );
    } else {
      // Image Viewer
      return Container(
        width: double.infinity,
        height: 400,
        color: KiraColors.surface,
        child: InteractiveViewer(
          panEnabled: true,
          minScale: 0.5,
          maxScale: 4,
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: KiraColors.primary500,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image,
                      size: 64,
                      color: KiraColors.text400,
                    ),
                    const SizedBox(height: KiraSpacing.md),
                    Text(
                      'Image not available',
                      style: KiraTypography.body2.copyWith(
                        color: KiraColors.text600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }
  }

  Widget _buildNoImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 200,
      color: KiraColors.surface,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: KiraColors.text400,
          ),
          const SizedBox(height: KiraSpacing.md),
          Text(
            'No image attached',
            style: KiraTypography.body2.copyWith(
              color: KiraColors.text600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineItemCard(LineItem item, {required bool showGita}) {
    return Container(
      padding: const EdgeInsets.all(KiraSpacing.lg),
      decoration: BoxDecoration(
        color: item.gitaEligible && showGita
            ? KiraColors.primary500.withOpacity(0.05)
            : KiraColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: item.gitaEligible && showGita
              ? KiraColors.primary500.withOpacity(0.3)
              : KiraColors.border,
          width: item.gitaEligible && showGita ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item name and GITA badge
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  style: KiraTypography.body1.copyWith(
                    color: KiraColors.text900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (item.gitaEligible)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: KiraColors.primary500,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'GITA T${item.gitaTier}',
                    style: KiraTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: KiraSpacing.sm),
          
          // Quantity and price
          Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 14,
                color: KiraColors.text600,
              ),
              const SizedBox(width: 4),
              Text(
                '${item.quantity.toStringAsFixed(0)} ${item.unit}',
                style: KiraTypography.caption.copyWith(
                  color: KiraColors.text600,
                ),
              ),
              const SizedBox(width: KiraSpacing.md),
              Icon(
                Icons.attach_money,
                size: 14,
                color: KiraColors.text600,
              ),
              Text(
                'RM ${item.price.toStringAsFixed(2)}',
                style: KiraTypography.caption.copyWith(
                  color: KiraColors.text900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: KiraSpacing.sm),
          
          // CO2 and GITA allowance
          Row(
            children: [
              // CO2
              Icon(
                Icons.co2,
                size: 14,
                color: item.co2Kg > 0 ? Colors.orange : KiraColors.primary500,
              ),
              const SizedBox(width: 4),
              Text(
                item.co2Kg > 0
                    ? '${item.co2Tonnes.toStringAsFixed(3)} t'
                    : 'Clean',
                style: KiraTypography.caption.copyWith(
                  color: item.co2Kg > 0 ? Colors.orange : KiraColors.primary500,
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              // GITA allowance
              if (item.gitaEligible && item.gitaAllowance != null) ...[
                const SizedBox(width: KiraSpacing.md),
                Icon(
                  Icons.payments,
                  size: 14,
                  color: KiraColors.primary500,
                ),
                const SizedBox(width: 4),
                Text(
                  'RM ${item.gitaAllowance!.toStringAsFixed(0)} tax',
                  style: KiraTypography.caption.copyWith(
                    color: KiraColors.primary500,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Container(
      padding: const EdgeInsets.all(KiraSpacing.lg),
      decoration: BoxDecoration(
        color: KiraColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KiraColors.border),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color ?? KiraColors.text600,
            size: 20,
          ),
          const SizedBox(width: KiraSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: KiraTypography.caption.copyWith(
                    color: KiraColors.text600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: KiraTypography.body1.copyWith(
                    color: KiraColors.text900,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getScopeName(int scope) {
    switch (scope) {
      case 1:
        return 'Direct Emissions';
      case 2:
        return 'Purchased Energy';
      case 3:
        return 'Indirect Emissions';
      default:
        return 'Unknown';
    }
  }

  String _getCategoryName(String category) {
    switch (category) {
      case 'electricity':
        return 'Electricity';
      case 'fuel_vehicle':
        return 'Vehicle Fuel';
      case 'natural_gas':
        return 'Natural Gas';
      case 'business_travel':
        return 'Business Travel';
      case 'purchased_goods':
        return 'Purchased Goods';
      case 'waste':
        return 'Waste';
      default:
        return category;
    }
  }
}
