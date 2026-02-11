import 'dart:typed_data';

import 'package:kira_app/data/models/carbon_item.dart';
import 'package:kira_app/data/models/gita_item.dart';
import 'package:kira_app/data/models/line_item.dart';
import 'package:kira_app/data/models/receipt.dart';
import 'package:kira_app/data/repositories/carbon_item_repository.dart';
import 'package:kira_app/data/repositories/gita_item_repository.dart';
import 'package:kira_app/data/repositories/receipt_repository.dart';
import 'package:kira_app/data/services/genkit_service.dart';

class ReceiptService {
  final ReceiptRepository receiptRepository;
  final GitaItemRepository gitaItemRepository;
  final CarbonItemRepository carbonItemRepository;
  final GenkitService genkitService;

  ReceiptService({
    required this.receiptRepository,
    required this.gitaItemRepository,
    required this.carbonItemRepository,
    required this.genkitService,
  });

  Future<void> processReceipt(Uint8List imageBytes, String userId) async {
    final Receipt receipt = await createReceipt(imageBytes);
    await receiptRepository.addReceipt(receipt, userId);

    final List<LineItem> lineItems = await createLineItems(receipt);

    for (final item in lineItems){
      if (item is GitaItem){
        await gitaItemRepository.addGitaItem(item, userId);
      }
      if (item is CarbonItem) {
        await carbonItemRepository.addCarbonItem(item, userId);
      }
    }
  }

  Future<Receipt> createReceipt(Uint8List imageBytes) async {
    final Map<String, dynamic> receiptJson  = await genkitService.extractInvoice(imageBytes);
    // convert to a Receipt object
    // return the Receipt object
    return Receipt.fromJson(receiptJson);
  }

  Future<List<LineItem>> createLineItems(Receipt receipt) async {
    final List<LineItem> lineItems = [];

    for (final item in receipt.lineItems) {
      final Map<String, dynamic> carbonJson = await genkitService.convertToCarbonEntry(item);
      final carbonItem = CarbonItem.fromJson({
        ...item.toJson(),
        ...carbonJson,
      });

      lineItems.add(carbonItem);

      if (item.isGitaEligible) {
        final Map<String, dynamic> gitaJson = await genkitService.convertToGitaEntry(item);
        final gitaItem = GitaItem.fromJson({
          ...item.toJson(),
        ...gitaJson,
        });
        lineItems.add(gitaItem);
      }
    }

    return lineItems;
  }
}