import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../l10n/l10n.dart';
import '../data/receipt_scan_repository.dart';
import '../logic/trip_controller.dart';
import 'trip_ui.dart';

/// Photo of a receipt (camera or library) → read on the device → the
/// review screen, where the payer checks the lines before saving.
Future<void> startReceiptScan(
    BuildContext context, WidgetRef ref, String groupId) async {
  final l10n = context.l10n;
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: Text(l10n.receiptTakePhoto),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: Text(l10n.receiptFromLibrary),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return;

  final XFile? photo;
  try {
    // Sharp enough for small print; the photo is read on the device and
    // never uploaded.
    photo = await ImagePicker().pickImage(
        source: source, maxWidth: 2400, maxHeight: 3600, imageQuality: 95);
  } catch (_) {
    if (context.mounted) {
      showTripSnack(context, l10n.journalPickError, error: true);
    }
    return;
  }
  if (photo == null || !context.mounted) return;

  final navigator = Navigator.of(context, rootNavigator: true);
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(l10n.receiptReading)),
          ],
        ),
      ),
    ),
  ));
  try {
    final receipt = await ref
        .read(tripActionsProvider.notifier)
        .scanReceipt(photo);
    navigator.pop();
    if (context.mounted) {
      unawaited(context.push('/trip/$groupId/costs/receipt', extra: receipt));
    }
  } catch (e) {
    navigator.pop();
    if (!context.mounted) return;
    final message = switch (e) {
      ReceiptNotReadableException() => l10n.receiptNotReadable,
      _ => l10n.receiptScanError,
    };
    debugPrint('Receipt scan failed: $e');
    showTripSnack(context, message, error: true);
  }
}
