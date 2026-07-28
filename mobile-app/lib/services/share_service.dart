import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

/// Captures a widget wrapped in a [RepaintBoundary] as a PNG and opens the
/// native share sheet — the basis of the shareable cosmic card (a cheap viral
/// loop). No account or backend upload required.
class ShareService {
  /// Renders the boundary behind [repaintKey] to a PNG and shares it via the
  /// system share sheet. Returns false if the capture failed (e.g. the widget
  /// was not laid out yet).
  static Future<bool> shareBoundary(
    GlobalKey repaintKey, {
    String? text,
    String? subject,
  }) async {
    try {
      // Make sure the current frame is fully painted before capturing.
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
          repaintKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return false;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) return false;
      final bytes = byteData.buffer.asUint8List();

      final file = await File(
        '${Directory.systemTemp.path}/cosmic_card_${DateTime.now().millisecondsSinceEpoch}.png',
      ).create();
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: text,
        subject: subject,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
