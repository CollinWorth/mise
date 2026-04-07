import 'dart:io';
import 'package:flutter/services.dart';

class OcrLine {
  final String text;
  final double x, y, w, h; // normalised 0-1, top-left origin

  const OcrLine({
    required this.text,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
  });

  double get midX => x + w / 2;
  double get midY => y + h / 2;
}

class OcrResult {
  final List<OcrLine> lines;
  final List<List<OcrLine>> columns; // grouped by detected column, left→right

  const OcrResult({required this.lines, required this.columns});

  /// All lines in natural reading order (column-aware top→bottom left→right).
  List<OcrLine> get ordered {
    if (columns.length <= 1) return lines;
    return [for (final col in columns) ...col];
  }
}

class VisionOCR {
  static const _channel = MethodChannel('mise/vision_ocr');

  static Future<OcrResult> recognize(File imageFile) async {
    final raw = await _channel.invokeMethod<List>('recognizeText', {
      'path': imageFile.path,
    });
    if (raw == null || raw.isEmpty) return const OcrResult(lines: [], columns: []);

    final lines = raw.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return OcrLine(
        text: m['text'] as String,
        x: (m['x'] as num).toDouble(),
        y: (m['y'] as num).toDouble(),
        w: (m['w'] as num).toDouble(),
        h: (m['h'] as num).toDouble(),
      );
    }).toList();

    final columns = _detectColumns(lines);
    return OcrResult(lines: lines, columns: columns);
  }

  /// Cluster lines into columns by their horizontal midpoint.
  /// Uses a gap-finding approach: sort midX values, find large gaps.
  static List<List<OcrLine>> _detectColumns(List<OcrLine> lines) {
    if (lines.isEmpty) return [];

    final sorted = List.of(lines)..sort((a, b) => a.midX.compareTo(b.midX));
    final midXs = sorted.map((l) => l.midX).toList();

    // Find the largest gap in X distribution
    double maxGap = 0;
    int gapIdx = -1;
    for (int i = 1; i < midXs.length; i++) {
      final gap = midXs[i] - midXs[i - 1];
      if (gap > maxGap) { maxGap = gap; gapIdx = i; }
    }

    // Only split into columns if the gap is significant (> 15% of page width)
    // and each side has at least 3 lines
    if (maxGap < 0.15 || gapIdx < 3 || gapIdx > lines.length - 3) {
      // Single column — sort top to bottom
      final col = List.of(lines)..sort((a, b) => a.midY.compareTo(b.midY));
      return [col];
    }

    final boundary = (midXs[gapIdx - 1] + midXs[gapIdx]) / 2;
    final left  = lines.where((l) => l.midX <= boundary).toList()
      ..sort((a, b) => a.midY.compareTo(b.midY));
    final right = lines.where((l) => l.midX >  boundary).toList()
      ..sort((a, b) => a.midY.compareTo(b.midY));

    return [left, right];
  }
}
