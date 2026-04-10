import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/vision_ocr.dart';

enum _Label { none, title, ingredients, instructions }

typedef OcrSelections = ({
  String title,
  List<String> ingredientLines,
  List<String> instructionLines,
});

class OcrSelectorScreen extends StatefulWidget {
  final OcrResult ocr;
  const OcrSelectorScreen({super.key, required this.ocr});

  @override
  State<OcrSelectorScreen> createState() => _OcrSelectorScreenState();
}

class _OcrSelectorScreenState extends State<OcrSelectorScreen> {
  _Label _active = _Label.ingredients;

  // Map from OcrLine identity → label (use index in flat ordered list)
  late final List<OcrLine> _ordered;
  late final List<_Label> _labels;

  static const _kTitle = Color(0xFFE8622A);
  static const _kIng   = Color(0xFF2D9D5C);
  static const _kInst  = Color(0xFF4A7EC7);

  static final _kIngHeaderRe  = RegExp(r'^ingredients?[\s:]*$', caseSensitive: false);
  static final _kInstHeaderRe = RegExp(r'^(directions?|instructions?|method|steps?|preparation)[\s:]*$', caseSensitive: false);
  static final _kAnyHeaderRe  = RegExp(r'^(ingredients?|directions?|instructions?|method|steps?|preparation)[\s:]*$', caseSensitive: false);
  static final _kQtyRe = RegExp(
    r'^[\d¼½¾⅓⅔⅛⅜⅝⅞][\d\s\/\.]*\s*'
    r'(?:cup|cups|tbsp|tsp|tablespoon|teaspoon|oz|ounce|lb|pound|g|gram|kg|ml|'
    r'liter|litre|clove|cloves|can|cans|bunch|sprig|pinch|dash|piece|pieces|'
    r'large|medium|small|head|slice|slices|stalk|package|C|T|t)\b',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _ordered = widget.ocr.ordered;
    _labels  = List.filled(_ordered.length, _Label.none);
    _autoLabelAll();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  static final _kBulletRe = RegExp(r'^[•\-\*]\s*');
  static final _kSubheadRe = RegExp(r'^[A-Z][^:]{2,40}:\s*$'); // "Slow Roasted Tomatoes:"

  void _autoLabelAll() {
    // ── Pass 1: section-header scan ──────────────────────────────────
    // If the OCR text contains explicit section headers ("Ingredients", "Directions"),
    // everything after a header inherits that section's label until the next header.
    bool foundAnyHeader = false;
    _Label current = _Label.none;
    for (int i = 0; i < _ordered.length; i++) {
      final t = _ordered[i].text.trim();
      if (t.isEmpty) continue;
      if (_kIngHeaderRe.hasMatch(t)) {
        current = _Label.ingredients; foundAnyHeader = true;
        _labels[i] = _Label.none; // header itself not included in output
        continue;
      }
      if (_kInstHeaderRe.hasMatch(t)) {
        current = _Label.instructions; foundAnyHeader = true;
        _labels[i] = _Label.none;
        continue;
      }
      // Title: short unlabeled line before the first header
      if (!foundAnyHeader && t.split(' ').length <= 8 &&
          !RegExp(r'^\d').hasMatch(t) && t.length < 70) {
        _labels[i] = _Label.title;
        continue;
      }
      _labels[i] = current;
    }

    if (foundAnyHeader) return; // header-based labels are good enough

    // ── Pass 2: per-line heuristics (headerless / bullet-list recipes) ──
    for (int i = 0; i < _ordered.length; i++) {
      final raw = _ordered[i].text.trim();
      if (raw.isEmpty) continue;
      // Strip leading bullet chars before matching
      final t = raw.replaceFirst(_kBulletRe, '').trim();
      if (t.isEmpty) { _labels[i] = _Label.none; continue; } // lone bullet
      if (_kAnyHeaderRe.hasMatch(t)) { _labels[i] = _Label.none; continue; }
      // Sub-section header ("Slow Roasted Tomatoes:") — skip, don't propagate
      if (_kSubheadRe.hasMatch(raw)) { _labels[i] = _Label.none; continue; }
      if (RegExp(r'^\d+[.)]\s+[A-Za-z]').hasMatch(t)) { _labels[i] = _Label.instructions; continue; }
      if (_kQtyRe.hasMatch(t)) { _labels[i] = _Label.ingredients; continue; }
      if (t.length > 80 && RegExp(r'[a-z]').hasMatch(t)) { _labels[i] = _Label.instructions; continue; }
      if (i < 4 && t.split(' ').length <= 6 && !RegExp(r'^\d').hasMatch(t)) {
        _labels[i] = _Label.title; continue;
      }
    }

    // ── Pass 3: propagate — pull unlabeled lines into neighboring section ──
    // Handles continuation lines ("Modena") and no-qty ingredients ("Salt & pepper to taste").
    // Does NOT propagate into sub-section headers (they end with ':').
    for (int i = 0; i < _ordered.length; i++) {
      if (_labels[i] != _Label.none) continue;
      final raw = _ordered[i].text.trim();
      if (raw.isEmpty) continue;
      if (_kSubheadRe.hasMatch(raw)) continue; // keep sub-headers unlabeled
      // Find nearest labeled non-empty line before and after
      _Label prev = _Label.none;
      for (int j = i - 1; j >= 0; j--) {
        if (_ordered[j].text.trim().isEmpty) continue;
        if (_labels[j] != _Label.none) { prev = _labels[j]; break; }
      }
      _Label next = _Label.none;
      for (int j = i + 1; j < _ordered.length; j++) {
        if (_ordered[j].text.trim().isEmpty) continue;
        if (_labels[j] != _Label.none) { next = _labels[j]; break; }
      }
      // Inherit if both neighbors agree, or if only one side is labeled
      if (prev == next && prev != _Label.none) { _labels[i] = prev; continue; }
      if (prev == _Label.ingredients || next == _Label.ingredients) _labels[i] = _Label.ingredients;
      if (prev == _Label.instructions || next == _Label.instructions) _labels[i] = _Label.instructions;
    }
  }

  void _tapLine(int i) {
    setState(() => _labels[i] = _labels[i] == _active ? _Label.none : _active);
  }

  void _labelColumn(List<OcrLine> colLines, _Label label) {
    setState(() {
      for (final line in colLines) {
        final i = _ordered.indexOf(line);
        if (i >= 0) _labels[i] = label;
      }
    });
  }

  void _done() {
    final titleParts = <String>[];
    final ingLines   = <String>[];
    final instLines  = <String>[];
    for (int i = 0; i < _ordered.length; i++) {
      final raw = _ordered[i].text.trim();
      if (raw.isEmpty) continue;
      // Strip bullets; skip lines that are just a bullet char
      final t = raw.replaceFirst(_kBulletRe, '').trim();
      if (t.isEmpty) continue;
      switch (_labels[i]) {
        case _Label.title:        titleParts.add(t);
        case _Label.ingredients:  ingLines.add(t);
        case _Label.instructions: instLines.add(t);
        case _Label.none:         break;
      }
    }
    Navigator.pop<OcrSelections>(context, (
      title: titleParts.join(' '),
      ingredientLines: ingLines,
      instructionLines: instLines,
    ));
  }

  Color? _color(_Label l) => switch (l) {
    _Label.title        => _kTitle,
    _Label.ingredients  => _kIng,
    _Label.instructions => _kInst,
    _Label.none         => null,
  };

  String _labelName(_Label l) => switch (l) {
    _Label.title        => 'Title',
    _Label.ingredients  => 'Ingr.',
    _Label.instructions => 'Steps',
    _Label.none         => '',
  };

  int _count(_Label l) => _labels.where((x) => x == l).length;

  @override
  Widget build(BuildContext context) {
    final isMultiCol = widget.ocr.columns.length > 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F6F3),
        elevation: 0,
        title: const Text('Label your text',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        actions: [
          TextButton(
            onPressed: _done,
            child: const Text('Use',
              style: TextStyle(color: Color(0xFFE8622A), fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Mode chips ──────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMultiCol
                    ? 'Two columns detected — tap a column header to label all at once, or tap individual lines.'
                    : 'Tap lines to label them, then tap Use.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF888480)),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  _modeChip(_Label.title,        'Title',        _count(_Label.title)),
                  const SizedBox(width: 8),
                  _modeChip(_Label.ingredients,  'Ingredients',  _count(_Label.ingredients)),
                  const SizedBox(width: 8),
                  _modeChip(_Label.instructions, 'Instructions', _count(_Label.instructions)),
                ]),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Content ─────────────────────────────────────────────────
          Expanded(
            child: isMultiCol
              ? _buildMultiColumn()
              : SingleChildScrollView(child: _buildSingleColumn(_ordered, showHeader: false)),
          ),

          // ── Use button ───────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _done,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE8622A),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    [
                      if (_count(_Label.ingredients) > 0) '${_count(_Label.ingredients)} ingredients',
                      if (_count(_Label.instructions) > 0) '${_count(_Label.instructions)} steps',
                    ].join('  •  ').let((s) => s.isEmpty ? 'Use selections' : 'Use  •  $s'),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiColumn() {
    return ListView(
      children: [
        for (int c = 0; c < widget.ocr.columns.length; c++) ...[
          _columnHeader(c, widget.ocr.columns[c]),
          _buildSingleColumn(widget.ocr.columns[c], showHeader: false),
          if (c < widget.ocr.columns.length - 1)
            const Divider(height: 24, indent: 16, endIndent: 16),
        ],
      ],
    );
  }

  Widget _columnHeader(int idx, List<OcrLine> colLines) {
    final colLabel = idx == 0 ? 'Left column' : 'Right column';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(colLabel.toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                color: Color(0xFF888480), letterSpacing: 1.0)),
            const SizedBox(width: 8),
            const Expanded(child: Divider()),
          ]),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Label all as:',
                style: TextStyle(fontSize: 12, color: Color(0xFF888480))),
              const SizedBox(width: 8),
              // Quick-label buttons for the whole column
              for (final lbl in [_Label.title, _Label.ingredients, _Label.instructions])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => _labelColumn(colLines, lbl),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: _color(lbl)!.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _color(lbl)!.withOpacity(0.5), width: 1.5),
                      ),
                      child: Text(_labelName(lbl),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: _color(lbl))),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleColumn(List<OcrLine> colLines, {required bool showHeader}) {
    return Column(
      children: colLines.map((line) {
        final i = _ordered.indexOf(line);
        if (i < 0 || line.text.trim().isEmpty) return const SizedBox.shrink();
        final label = _labels[i];
        final color = _color(label);
        final isLabeled = label != _Label.none;

        return GestureDetector(
          onTap: () => _tapLine(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: isLabeled ? color!.withOpacity(0.08) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isLabeled ? color!.withOpacity(0.35) : const Color(0xFFE5E2DC),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(isLabeled ? 12 : 12, 8, 12, 8),
                  child: Row(children: [
                    Expanded(
                      child: Text(line.text,
                        style: TextStyle(
                          fontSize: 13, height: 1.4,
                          color: isLabeled ? color!.withOpacity(0.85) : const Color(0xFF3A3836),
                          fontWeight: isLabeled ? FontWeight.w600 : FontWeight.w400,
                        )),
                    ),
                    if (isLabeled) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: color!.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(_labelName(label),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                      ),
                    ],
                  ]),
                ),
                if (isLabeled)
                  Positioned(left: 0, top: 0, bottom: 0,
                    child: Container(width: 4, color: color)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _modeChip(_Label label, String text, int count) {
    final isActive = _active == label;
    final color = _color(label)!;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _active = label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isActive ? color : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isActive ? color : color.withOpacity(0.3), width: 1.5),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: isActive ? Colors.white : color)),
            if (count > 0) ...[
              const SizedBox(height: 2),
              Text('$count selected', style: TextStyle(fontSize: 10,
                color: isActive ? Colors.white.withOpacity(0.8) : color.withOpacity(0.7))),
            ],
          ]),
        ),
      ),
    );
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
