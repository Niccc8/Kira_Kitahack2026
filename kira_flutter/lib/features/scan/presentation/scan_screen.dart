/// Scan Screen (Upload)
/// 
/// Receipt upload screen with camera/gallery access,
/// Gemini AI extraction, and recent uploads list.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/spacing.dart';
import '../../../core/constants/typography.dart';
import '../../../shared/widgets/kira_card.dart';
import '../../../shared/widgets/kira_button.dart';
import '../../../shared/widgets/kira_badge.dart';
import '../../../providers/receipt_providers.dart';
import '../../../providers/auth_providers.dart';
import '../../../data/models/receipt.dart';
import '../../receipts/presentation/receipt_detail_screen.dart';

/// Scan screen implementation
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  Future<void> _pickImage(ImageSource source) async {
    try {
      print('📸 Starting image picker...');
      final XFile? image = await _picker.pickImage(source: source);
      
      print('📸 Image picker result: ${image?.path ?? "null"}');
      
      if (image == null) {
        print('❌ User cancelled image selection');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No image selected'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }
      
      print('✅ Image selected: ${image.path}');
      print('📏 Image size: ${await image.length()} bytes');
      
      setState(() => _isProcessing = true);
      
      print('🤖 Reading image bytes...');
      // Read bytes from XFile (works for both web blob URLs and file paths)
      final imageBytes = await image.readAsBytes();
      print('🤖 Read ${imageBytes.length} bytes, sending to Gemini...');
      
      // Upload to Gemini  
     try {
        await ref.read(receiptUploadProvider.notifier).uploadReceiptBytes(imageBytes, image.path);
        print('✅ Gemini processing complete - receipt saved!');
        
        // Force refresh receipts list
        ref.invalidate(receiptsStreamProvider);
        ref.invalidate(totalCO2Provider);
        
        setState(() => _isProcessing = false);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Receipt processed successfully!'),
              backgroundColor: KiraColors.success,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (uploadError, uploadStack) {
        print('❌ Upload error: $uploadError');
        print('Stack: $uploadStack');
        
        setState(() => _isProcessing = false);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Failed to process: $uploadError'),
              backgroundColor: KiraColors.primary600,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }
      
    } catch (e, stackTrace) {
      print('❌ ERROR in _pickImage: $e');
      print('Stack trace: $stackTrace');
      
      setState(() => _isProcessing = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: ${e.toString()}'),
            backgroundColor: KiraColors.primary600,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final receiptsAsync = ref.watch(receiptsStreamProvider);
    
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          
          // Title - matching Reports page
          Text('Scan Receipt', style: KiraTypography.h3),
          const SizedBox(height: 6),
          Text(
            'Upload receipts to calculate carbon footprint',
            style: KiraTypography.bodySmall.copyWith(
              color: KiraColors.textSecondary,
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Upload Zone
          _buildUploadZone(),
          
          const SizedBox(height: 24),
          
          // AI Info Card
          _buildAiInfoCard(),
          
          const SizedBox(height: 24),
          
          // Recent Uploads
          receiptsAsync.when(
            data: (receipts) => _buildRecentUploads(receipts),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: KiraColors.primary500),
              ),
            ),
            error: (err, stack) => KiraCard(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Error loading receipts',
                  style: KiraTypography.bodySmall.copyWith(
                    color: KiraColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: KiraSpacing.screenBottom),
        ],
      ),
    );
  }
  
  /// Upload zone with buttons
  Widget _buildUploadZone() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(KiraSpacing.radiusLg),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          if (_isProcessing) ...[
            const CircularProgressIndicator(color: KiraColors.primary500),
            const SizedBox(height: 16),
            Text(
              'Processing with Gemini AI...',
              style: KiraTypography.bodyMedium.copyWith(
                color: KiraColors.primary400,
              ),
            ),
          ] else ...[
            const Icon(
              Icons.camera_alt_outlined,
              size: 32,
              color: KiraColors.primary400,
            ),
            const SizedBox(height: 16),
            Text(
              'Tap to scan receipt',
              style: KiraTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'JPG, PNG • Automatic AI extraction',
              style: KiraTypography.bodySmall.copyWith(
                color: KiraColors.textTertiary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 16),
            
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                KiraButton.primary(
                  label: 'Camera',
                  icon: Icons.camera_alt,
                  onPressed: () => _pickImage(ImageSource.camera),
                ),
                const SizedBox(width: 12),
                KiraButton.secondary(
                  label: 'Gallery',
                  icon: Icons.photo_library,
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  /// AI info card
  Widget _buildAiInfoCard() {
    return KiraCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const Icon(
            Icons.smart_toy_outlined,
            size: 20,
            color: KiraColors.success,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: KiraTypography.bodySmall.copyWith(
                  color: KiraColors.textSecondary,
                  fontSize: 13,
                ),
                children: const [
                  TextSpan(
                    text: 'Gemini AI ',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(
                    text: 'extracts vendor, amount, and calculates carbon using Malaysian emission factors.',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// Recent uploads section
  Widget _buildRecentUploads(List<Receipt> receipts) {
    if (receipts.isEmpty) {
      return KiraCard(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 32, color: KiraColors.textTertiary),
              const SizedBox(height: 12),
              Text(
                'No receipts yet',
                style: KiraTypography.bodyMedium.copyWith(
                  color: KiraColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Upload your first receipt to get started',
                style: KiraTypography.bodySmall.copyWith(
                  color: KiraColors.textTertiary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('YOUR RECEIPTS', style: KiraTypography.sectionTitle),
        const SizedBox(height: 12),
        ...receipts.map((receipt) => _buildUploadItem(receipt)),
      ],
    );
  }
  
  Widget _buildUploadItem(Receipt receipt) {
    final scope = receipt.scope;
    final co2Kg = receipt.co2Kg;
    final vendor = receipt.vendor;
    final category = receipt.category;
    final userId = ref.watch(userIdProvider);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: KiraCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReceiptDetailScreen(receipt: receipt),
              ),
            );
          },
          child: Row(
            children: [
              _buildReceiptThumb(userId, receipt, category: category, scope: scope),
              const SizedBox(width: 12),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(vendor, style: KiraTypography.bodyMedium),
                    const SizedBox(height: 2),
                    Text(
                      'Scope $scope • $category',
                      style: KiraTypography.labelSmall,
                    ),
                  ],
                ),
              ),
              
              // CO2
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  KiraBadge.success(
                    label: 'Done',
                    icon: Icons.check_circle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${co2Kg.toStringAsFixed(1)} kg',
                    style: KiraTypography.labelSmall.copyWith(
                      color: KiraColors.textAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptThumb(String? userId, Receipt receipt, {required String category, required int scope}) {
    Widget frame(Widget child) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white.withValues(alpha: 0.03),
          ),
          child: child,
        ),
      );
    }

    final url = receipt.imageUrl;
    if (url != null && url.trim().isNotEmpty) {
      return frame(
        Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(
            _getCategoryIcon(category),
            size: 20,
            color: _getScopeColor(scope),
          ),
        ),
      );
    }

    if (userId == null || userId.trim().isEmpty) {
      return frame(
        Icon(
          _getCategoryIcon(category),
          size: 20,
          color: _getScopeColor(scope),
        ),
      );
    }

    final path = 'users/$userId/receipts/${receipt.id}.jpg';
    final futureUrl = FirebaseStorage.instance.ref(path).getDownloadURL();

    return FutureBuilder<String>(
      future: futureUrl,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return frame(
            const Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: KiraColors.primary500,
                ),
              ),
            ),
          );
        }

        final resolved = snapshot.data;
        if (snapshot.hasError || resolved == null || resolved.trim().isEmpty) {
          return frame(
            Icon(
              _getCategoryIcon(category),
              size: 20,
              color: _getScopeColor(scope),
            ),
          );
        }

        return frame(
          Image.network(
            resolved,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Icon(
              _getCategoryIcon(category),
              size: 20,
              color: _getScopeColor(scope),
            ),
          ),
        );
      },
    );
  }
  
  /// Get icon based on category
  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'utilities':
        return Icons.bolt;
      case 'transport':
        return Icons.directions_car;
      case 'materials':
        return Icons.factory;
      case 'waste':
        return Icons.delete_outline;
      case 'office':
        return Icons.business_center;
      case 'travel':
        return Icons.flight;
      default:
        return Icons.receipt_long;
    }
  }
  
  /// Get color based on scope
  Color _getScopeColor(int scope) {
    switch (scope) {
      case 1:
        return KiraColors.scope1;
      case 2:
        return KiraColors.scope2;
      case 3:
        return KiraColors.scope3;
      default:
        return KiraColors.textSecondary;
    }
  }
}
