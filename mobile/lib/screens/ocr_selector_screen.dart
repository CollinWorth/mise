import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _ordered = widget.ocr.ordered;
    _labels  = List.generate(_ordered.length, (i) => _autoLabel(_ordered[i], i));
  }

  _Label _autoLabel(OcrLine line, int idx) {
    final t = line.text.trim();
    if (t.isEmpty) return _Label.none;

    // Section headers
    if (RegExp(r'^(ingredients?|directions?|instructions?|method|steps?)[\s:]*$',
        caseSensitive: false).hasMatch(t)) return _Label.none; // skip headers

    // Numbered step
    if (RegExp(r'^\d+[.)]\s+[A-Za-z]').hasMatch(t)) return _Label.instructions;

    // Starts with quantity + unit → ingredient
    if (RegExp(
      r'^[\d¼½¾⅓⅔⅛⅜⅝⅞][\d\s\/\.]*\s*'
      r'(?:cup|cups|tbsp|tsp|tablespoon|teaspoon|oz|ounce|lb|pound|g|gram|kg|ml|'
      r'liter|litre|clove|cloves|can|cans|bunch|sprig|pinch|dash|piece|pieces|'
      r'large|medium|small|head|slice|slices|stalk|package|C|T|t)\b',
      caseSensitive: false,
    ).hasMatch(t)) return _Label.ingredients;

    // Long prose → instruction
    if (t.length > 60 && RegExp(r'[a-z]').hasMatch(t)) return _Label.instructions;

    // Short title-like line in first column, near top
    if (idx < 4 && t.split(' ').length <= 6 && !RegExp(r'^\d').hasMatch(t)) {
      return _Label.title;
    }
    return _Label.none;
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
      final t = _ordered[i].text.trim();
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
              : _buildSingleColumn(_ordered, showHeader: false),
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
    final label = idx == 0 ? 'Left column' : 'Right column';
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Text(label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: Color(0xFF888480), letterSpacing: 0.5)),
          const SizedBox(width: 8),
          const Expanded(child: Divider()),
          const SizedBox(width: 8),
          // Quick-label buttons for the whole column
          for (final lbl in [_Label.title, _Label.ingredients, _Label.instructions])
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: GestureDetector(
                onTap: () => _labelColumn(colLines, lbl),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _color(lbl)!.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _color(lbl)!.withOpacity(0.4)),
                  ),
                  child: Text(_labelName(lbl),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: _color(lbl))),
                ),
              ),
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
            decoration: BoxDecoration(
              color: isLabeled ? color!.withOpacity(0.08) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                left: BorderSide(color: isLabeled ? color! : const Color(0xFFE5E2DC), width: isLabeled ? 4 : 1.5),
                top:    BorderSide(color: isLabeled ? color!.withOpacity(0.25) : const Color(0xFFE5E2DC)),
                right:  BorderSide(color: isLabeled ? color!.withOpacity(0.25) : const Color(0xFFE5E2DC)),
                bottom: BorderSide(color: isLabeled ? color!.withOpacity(0.25) : const Color(0xFFE5E2DC)),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
