import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../api.dart';
import '../storage/storage.dart';
import '../models/recipe.dart';
import '../services/vision_ocr.dart';
import 'ocr_selector_screen.dart';


class AddRecipeScreen extends StatefulWidget {
  final Map<String, dynamic> user;
  final String? initialUrl;
  final Recipe? existingRecipe; // non-null = edit mode

  const AddRecipeScreen({super.key, required this.user, this.initialUrl, this.existingRecipe});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  _ImportMode? _mode;
  bool _importing = false;
  bool _saving = false;
  String _error = '';
  Map<String, dynamic>? _importedData;

  // Form controllers
  final _nameCtrl = TextEditingController();
  final _cuisineCtrl = TextEditingController();
  final _prepCtrl = TextEditingController();
  final _cookCtrl = TextEditingController();
  final _servingsCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();
  final _tagsCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  List<Map<String, String>> _ingredients = [{'name': '', 'quantity': '', 'unit': '', '_id': '0'}];
  int _nextIngId = 1;
  File? _pickedImage;
  bool _uploadingImage = false;

  final _urlCtrl = TextEditingController();
  final _rawTextCtrl = TextEditingController();
  bool _ocrLoading = false; // OCR is running (separate from server _importing)
  String _category = '';
  bool _isPublic = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingRecipe != null) {
      final r = widget.existingRecipe!;
      _mode = _ImportMode.manual; // skip method picker, go straight to form
      _nameCtrl.text = r.name;
      _cuisineCtrl.text = r.cuisine;
      _prepCtrl.text = r.prepTime > 0 ? r.prepTime.toString() : '';
      _cookCtrl.text = r.cookTime > 0 ? r.cookTime.toString() : '';
      _servingsCtrl.text = r.servings > 0 ? r.servings.toString() : '';
      _imageCtrl.text = r.imageUrl ?? '';
      _instructionsCtrl.text = r.instructions;
      _category = r.category;
      _isPublic = r.isPublic;
      _ingredients = r.ingredients.isNotEmpty
          ? r.ingredients.map((i) => {'name': i.name, 'quantity': i.quantity, 'unit': i.unit, '_id': '${_nextIngId++}'}).toList()
          : [{'name': '', 'quantity': '', 'unit': '', '_id': '0'}];
    } else if (widget.initialUrl != null) {
      _urlCtrl.text = widget.initialUrl!;
      _mode = _ImportMode.url;
      WidgetsBinding.instance.addPostFrameCallback((_) => _doImport());
    }
  }

  void _fillForm(Map<String, dynamic> data) {
    _nameCtrl.text = data['recipe_name'] ?? '';
    _cuisineCtrl.text = data['cuisine'] ?? '';
    _prepCtrl.text = (data['prep_time'] ?? 0).toString();
    _cookCtrl.text = (data['cook_time'] ?? 0).toString();
    _servingsCtrl.text = data['servings']?.toString() ?? '';
    _imageCtrl.text = data['image_url'] ?? '';
    _tagsCtrl.text = data['tags'] ?? '';
    _category = data['category'] ?? _category;
    _instructionsCtrl.text = data['instructions'] ?? '';
    final ings = (data['ingredients'] as List? ?? []);
    if (ings.isNotEmpty) {
      _ingredients = ings.map<Map<String, String>>((i) => {
        'name': i['name']?.toString() ?? '',
        'quantity': i['quantity']?.toString() ?? '',
        'unit': i['unit']?.toString() ?? '',
        '_id': '${_nextIngId++}',
      }).toList();
    }
  }

  Future<void> _doImport() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) return;
    setState(() { _importing = true; _error = ''; });
    try {
      final r = await Api.post('/recipes/scrape-smart', {'url': url});
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        // TikTok: take the raw description through the OCR labeling flow
        if (_mode == _ImportMode.tiktok && data['raw_text'] != null) {
          setState(() => _importing = false);
          await _labelTikTokDescription(
            data['raw_text'] as String,
            data['image_url'] as String? ?? '',
          );
          return;
        }
        setState(() { _importedData = data; _fillForm(data); });
      } else {
        final body = jsonDecode(r.body);
        setState(() => _error = body['detail'] ?? 'Could not import recipe');
      }
    } catch (_) {
      setState(() => _error = 'Could not reach server');
    }
    setState(() => _importing = false);
  }

  /// Split a TikTok description into OcrLines and open the same labeling
  /// screen used for photo OCR so the user can tag title/ingredients/steps.
  Future<void> _labelTikTokDescription(String description, String imageUrl) async {
    final lines = _splitTikTokDescription(description);

    if (lines.isEmpty) {
      setState(() => _error = 'No text found in description.');
      return;
    }

    // Build OcrResult with fake positional data (stacked top-to-bottom)
    double y = 0.0;
    const lineH = 0.05;
    final ocrLines = lines.map((text) {
      final line = OcrLine(text: text, x: 0.0, y: y, w: 1.0, h: lineH);
      y += lineH + 0.01;
      return line;
    }).toList();
    final ocr = OcrResult(lines: ocrLines, columns: [ocrLines]);

    if (!mounted) return;
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    final selections = await Navigator.push<OcrSelections>(
      context,
      MaterialPageRoute(builder: (_) => OcrSelectorScreen(ocr: ocr)),
    );
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);

    if (selections != null && mounted) {
      await _applyOcrSelections(selections);
      // Set thumbnail after _applyOcrSelections so _fillForm doesn't overwrite it
      if (imageUrl.isNotEmpty && mounted) {
        setState(() => _imageCtrl.text = imageUrl);
      }
    }
  }

  /// Parse a raw TikTok description into individual lines for the labeling UI.
  /// Handles both well-formatted descriptions (newline-separated) and single-blob
  /// descriptions where everything runs together.
  static List<String> _splitTikTokDescription(String raw) {
    // Step 1: strip hashtags and @mentions (social noise, not recipe content)
    String text = raw.replaceAll(RegExp(r'\s*#\w+'), '').replaceAll(RegExp(r'@\w+'), '').trim();

    // Step 2: inject breaks before section headers (works on both blobs and multi-line)
    text = text.replaceAllMapped(
      RegExp(r'(?<!\n)\s*(INGREDIENTS?|INSTRUCTIONS?|DIRECTIONS?|STEPS?|METHOD|OPTIONAL\b[^:]*)\s*:', caseSensitive: false),
      (m) => '\n${m.group(0)}',
    );
    // Before numbered steps: "1." "2." etc.
    text = text.replaceAllMapped(
      RegExp(r'(?<!\n)\s+(\d+[.)]\s+[A-Z])'),
      (m) => '\n${m.group(1)}',
    );
    // Before bullet points: "•" "-" "·"
    text = text.replaceAllMapped(
      RegExp(r'(?<!\n)\s+([•·\-]\s+\S)'),
      (m) => '\n${m.group(1)}',
    );

    // Step 3: split by newlines
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    // Step 4: split packed ingredient lines and long prose instruction paragraphs
    final result = <String>[];
    for (final line in lines) {
      final packed = _splitPackedIngredients(line);
      if (packed.length > 1) {
        result.addAll(packed);
      } else {
        result.addAll(_splitSentences(line));
      }
    }
    return result;
  }

  /// Split a long prose line into individual sentences.
  /// Used for instruction paragraphs like "Preheat oven. Mix ingredients. Bake 30 min."
  static List<String> _splitSentences(String line) {
    if (line.length <= 80) return [line];
    // Split on sentence-ending punctuation followed by space + capital letter
    final sentences = line.split(RegExp(r'(?<=[.!?])\s+(?=[A-Z])'));
    if (sentences.length > 1) {
      return sentences.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    return [line];
  }

  /// Split a line that has multiple ingredients crammed together, separated only
  /// by the start of the next quantity. Paren-aware: won't split inside "(about 2)".
  ///
  /// Splits before: digits, unicode fractions, and unitless measure words
  /// (Pinch, Dash, Handful, etc.) that aren't inside parentheses.
  static List<String> _splitPackedIngredients(String line) {
    final parts = <String>[];
    int depth = 0;
    int start = 0;

    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '(') { depth++; continue; }
      if (c == ')') { depth = (depth - 1).clamp(0, 99); continue; }
      if (depth > 0 || c != ' ') continue;

      // We're at a space outside parens. Check if what follows starts a new ingredient.
      final rest = line.substring(i + 1);
      if (_startsIngredient(rest)) {
        final part = line.substring(start, i).trim();
        // Don't split if the current segment is just a number —
        // it's the whole-number part of a mixed fraction like "2 1/2"
        if (part.isNotEmpty && !_bareNumberRe.hasMatch(part)) {
          parts.add(part);
          start = i + 1;
        }
      }
    }

    final tail = line.substring(start).trim();
    if (tail.isNotEmpty) parts.add(tail);
    return parts.length > 1 ? parts : [line];
  }

  // A segment that is just a bare number — the whole-number part of "2 1/2", not a full ingredient.
  static final _bareNumberRe = RegExp(r'^[\d¼½¾⅓⅔⅛⅜⅝⅞]+$');

  // Matches the beginning of a new ingredient: a quantity (digit/fraction) or
  // a known unitless measure word.
  static final _ingredientStartRe = RegExp(
    r'^[\d¼½¾⅓⅔⅛⅜⅝⅞]'
    r'|^(?:pinch|dash|handful|drizzle|splash|knob|sprig|squeeze|bunch|spray)\b',
    caseSensitive: false,
  );

  static bool _startsIngredient(String text) => _ingredientStartRe.hasMatch(text);

  Future<void> _doParseText() async {
    final text = _rawTextCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() { _importing = true; _error = ''; });
    try {
      final r = await Api.post('/recipes/parse-text', {'text': text});
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        setState(() { _importedData = data; _fillForm(data); });
      } else {
        setState(() => _error = 'Could not parse text');
      }
    } catch (_) {
      setState(() => _error = 'Could not reach server');
    }
    setState(() => _importing = false);
  }

  // OCR a photo → open the line-labelling selector screen
  Future<void> _ocrIntoTextBox(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90, maxWidth: 2048);
    if (picked == null) return;

    setState(() { _ocrLoading = true; _error = ''; });
    OcrResult? ocr;
    try {
      ocr = await VisionOCR.recognize(File(picked.path));
    } catch (_) {
      setState(() { _error = 'Could not read photo.'; _ocrLoading = false; });
      return;
    }
    setState(() => _ocrLoading = false);

    if (ocr == null || ocr.lines.isEmpty) {
      setState(() => _error = 'No text found — try a clearer photo.');
      return;
    }

    if (!mounted) return;
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    final selections = await Navigator.push<OcrSelections>(
      context,
      MaterialPageRoute(builder: (_) => OcrSelectorScreen(ocr: ocr!)),
    );
    await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    if (selections != null && mounted) {
      final hasContent = _ingredients.any((i) => i['name']!.isNotEmpty) ||
          _instructionsCtrl.text.isNotEmpty;
      if (hasContent) {
        final append = await showModalBottomSheet<bool>(
          context: context,
          builder: (_) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.add_circle_outline),
                  title: const Text('Add to recipe', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Append ingredients and steps to what\'s already here'),
                  onTap: () => Navigator.pop(context, true),
                ),
                ListTile(
                  leading: const Icon(Icons.refresh_outlined),
                  title: const Text('Replace recipe', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Overwrite current content'),
                  onTap: () => Navigator.pop(context, false),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
        if (append == null || !mounted) return;
        _applyOcrSelections(selections, append: append);
      } else {
        _applyOcrSelections(selections);
      }
    }
  }

  /// Build structured text from labelled sections and send to backend.
  Future<void> _applyOcrSelections(OcrSelections sel, {bool append = false}) async {
    // Build well-structured text so backend parse-text works cleanly
    final buf = StringBuffer();
    if (sel.title.isNotEmpty) {
      buf.writeln(sel.title);
      buf.writeln();
    }
    if (sel.ingredientLines.isNotEmpty) {
      buf.writeln('Ingredients:');
      for (final l in sel.ingredientLines) buf.writeln(l);
      buf.writeln();
    }
    if (sel.instructionLines.isNotEmpty) {
      buf.writeln('Instructions:');
      for (final l in sel.instructionLines) buf.writeln(l);
    }
    final structured = buf.toString().trim();
    if (structured.isEmpty) return;

    // Switch to pasteText mode so the form is visible, then parse
    setState(() { _mode = _ImportMode.pasteText; _importing = true; _error = ''; });
    try {
      final r = await Api.post('/recipes/parse-text', {'text': structured});
      if (r.statusCode == 200) {
        final data = jsonDecode(r.body) as Map<String, dynamic>;
        if (!append) {
          setState(() { _importedData = data; _fillForm(data); });
        } else {
          setState(() {
            _importedData = data;
            // Fill name only if empty
            if (_nameCtrl.text.isEmpty) _nameCtrl.text = data['recipe_name'] ?? '';
            // Append ingredients
            final newIngs = (data['ingredients'] as List? ?? []);
            final toAdd = newIngs.map<Map<String, String>>((i) => {
              'name': i['name']?.toString() ?? '',
              'quantity': i['quantity']?.toString() ?? '',
              'unit': i['unit']?.toString() ?? '',
              '_id': '${_nextIngId++}',
            }).toList();
            final hasBlankOnly = _ingredients.length == 1 && _ingredients[0]['name']!.isEmpty;
            if (hasBlankOnly) {
              _ingredients = toAdd.isNotEmpty ? toAdd : _ingredients;
            } else {
              _ingredients = [..._ingredients, ...toAdd];
            }
            // Append instructions
            final newInst = (data['instructions'] as String? ?? '').trim();
            if (newInst.isNotEmpty) {
              final existing = _instructionsCtrl.text.trim();
              _instructionsCtrl.text = existing.isEmpty ? newInst : '$existing\n$newInst';
            }
          });
        }
      } else {
        setState(() => _error = 'Could not parse text');
      }
    } catch (_) {
      setState(() => _error = 'Could not reach server');
    }
    setState(() => _importing = false);
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      final text = data!.text!.trim();
      if (_mode == _ImportMode.pasteText) {
        setState(() => _rawTextCtrl.text = text);
      } else {
        setState(() => _urlCtrl.text = text);
      }
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 1200);
    if (picked == null) return;
    final file = File(picked.path);
    setState(() { _pickedImage = file; _uploadingImage = true; });
    try {
      final r = await Api.uploadImage('/recipes/upload-image', file);
      if (r.statusCode == 200) {
        final url = jsonDecode(r.body)['url'] as String;
        setState(() { _imageCtrl.text = url; _uploadingImage = false; });
      } else {
        setState(() { _uploadingImage = false; _error = 'Image upload failed'; });
      }
    } catch (_) {
      setState(() { _uploadingImage = false; _error = 'Image upload failed'; });
    }
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E2DC), borderRadius: BorderRadius.circular(99))),
          const SizedBox(height: 16),
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('Choose from library'), onTap: () { Navigator.pop(context); _pickImage(ImageSource.gallery); }),
          ListTile(leading: const Icon(Icons.camera_alt_outlined), title: const Text('Take a photo'), onTap: () { Navigator.pop(context); _pickImage(ImageSource.camera); }),
          if (_imageCtrl.text.isNotEmpty)
            ListTile(leading: const Icon(Icons.link), title: const Text('Enter URL instead'), onTap: () { Navigator.pop(context); _showUrlDialog(); }),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _showUrlDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Image URL'),
        content: TextField(
          controller: _imageCtrl,
          decoration: const InputDecoration(hintText: 'https://...'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () { setState(() { _pickedImage = null; }); Navigator.pop(context); },
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE8622A)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _openInstructionsEditor() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _InstructionsEditorScreen(controller: _instructionsCtrl),
      ),
    );
    setState(() {}); // refresh the preview
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Recipe name is required');
      return;
    }
    setState(() { _saving = true; _error = ''; });
    final uid = widget.user['id'] ?? widget.user['_id'];
    final body = {
      'recipe_name': _nameCtrl.text.trim(),
      'cuisine': _cuisineCtrl.text.trim(),
      'prep_time': int.tryParse(_prepCtrl.text) ?? 0,
      'cook_time': int.tryParse(_cookCtrl.text) ?? 0,
      'servings': int.tryParse(_servingsCtrl.text) ?? 0,
      'image_url': _imageCtrl.text.trim(),
      'tags': _tagsCtrl.text.trim(),
      'category': _category,
      'is_public': _isPublic,
      'instructions': _instructionsCtrl.text.trim(),
      'ingredients': _ingredients
          .where((i) => i['name']!.isNotEmpty)
          .map((i) => {'name': i['name']!, 'quantity': i['quantity']!, 'unit': i['unit']!})
          .toList(),
      'user_id': uid,
    };
    try {
      final isEdit = widget.existingRecipe != null;
      if (isEdit) {
        await Store.i.updateRecipe(widget.existingRecipe!.id, body);
      } else {
        await Store.i.createRecipe(body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      setState(() => _error = 'Failed to save recipe');
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F6F3),
        elevation: 0,
        title: Text(widget.existingRecipe != null ? 'Edit Recipe' : 'Add Recipe',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        actions: [
          if (_mode != null)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFE8622A)))
                  : const Text('Save', style: TextStyle(color: Color(0xFFE8622A), fontWeight: FontWeight.w700, fontSize: 16)),
            ),
        ],
      ),
      body: _mode == null ? _buildMethodPicker() : _buildForm(),
    );
  }

  Widget _buildMethodPicker() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('How would you like to\nadd a recipe?',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.15)),
          const SizedBox(height: 32),
          if (Store.i.supportsImport) ...[
            _methodCard(
              icon: '🔗',
              title: 'Import from URL',
              subtitle: 'Paste a link from any recipe website or blog',
              onTap: () => setState(() => _mode = _ImportMode.url),
            ),
            const SizedBox(height: 14),
            _methodCard(
              icon: '🎵',
              title: 'Import from TikTok',
              subtitle: 'Share a TikTok video link — we\'ll pull the recipe from the description',
              onTap: () => setState(() { _mode = _ImportMode.tiktok; }),
            ),
            const SizedBox(height: 14),
          ],
          _methodCard(
            icon: '📋',
            title: 'Scan or paste text',
            subtitle: 'Photo a cookbook page, screenshot, or paste copied text — we\'ll parse it',
            onTap: () => setState(() => _mode = _ImportMode.pasteText),
          ),
          const SizedBox(height: 14),
          _methodCard(
            icon: '✍️',
            title: 'Enter manually',
            subtitle: 'Type in the recipe yourself',
            onTap: () => setState(() => _mode = _ImportMode.manual),
          ),
        ],
      ),
    );
  }

  Widget _methodCard({required String icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E2DC), width: 1.5),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: Color(0xFF888480), height: 1.3)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFCCC9C3), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final isImport = _mode == _ImportMode.url || _mode == _ImportMode.tiktok;
    final isTikTok = _mode == _ImportMode.tiktok;
    final isPasteText = _mode == _ImportMode.pasteText;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Import bar (shown for URL/TikTok modes before import succeeds)
          if (isImport && _importedData == null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E2DC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isTikTok ? 'Paste your TikTok link' : 'Paste recipe URL',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  if (isTikTok)
                    const Padding(
                      padding: EdgeInsets.only(top: 4, bottom: 10),
                      child: Text('In TikTok → tap Share → Copy link, then paste it here.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF888480))),
                    )
                  else
                    const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlCtrl,
                          decoration: InputDecoration(
                            hintText: isTikTok ? 'https://www.tiktok.com/...' : 'https://...',
                            filled: true,
                            fillColor: const Color(0xFFF7F6F3),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E2DC))),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E2DC))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8622A))),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _iconBtn(Icons.paste_outlined, _pasteFromClipboard),
                    ],
                  ),
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _importing ? null : _doImport,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE8622A),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _importing
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(isTikTok ? 'Extract recipe' : 'Import', style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Success banner after import
          if (_importedData != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFEDF7F1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF2D9D5C).withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle, color: Color(0xFF2D9D5C), size: 18),
                const SizedBox(width: 8),
                const Expanded(child: Text('Recipe imported — review and save.', style: TextStyle(fontSize: 13, color: Color(0xFF2D9D5C), fontWeight: FontWeight.w600))),
                TextButton(
                  onPressed: () => setState(() { _importedData = null; _urlCtrl.clear(); }),
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(40, 32)),
                  child: const Text('Re-import', style: TextStyle(fontSize: 12, color: Color(0xFF2D9D5C))),
                ),
              ]),
            ),
          ],

          if (_error.isNotEmpty && _importedData != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),

          // ── Scan / paste panel ───────────────────────────────────
          if (isPasteText && _importedData == null) ...[
            _buildScanPastePanel(),
            const SizedBox(height: 20),
          ],

          // ── Recipe form ───────────────────────────────────────────
          _sectionLabel('Recipe name'),
          _textField(_nameCtrl, 'e.g. Spaghetti Carbonara'),
          const SizedBox(height: 16),

          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionLabel('Cuisine'),
              _textField(_cuisineCtrl, 'e.g. Italian'),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionLabel('Servings'),
              _textField(_servingsCtrl, '4', type: TextInputType.number),
            ])),
          ]),
          const SizedBox(height: 16),

          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionLabel('Prep time (min)'),
              _textField(_prepCtrl, '10', type: TextInputType.number),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionLabel('Cook time (min)'),
              _textField(_cookCtrl, '20', type: TextInputType.number),
            ])),
          ]),
          const SizedBox(height: 16),

          _sectionLabel('Photo'),
          _buildImagePicker(),
          const SizedBox(height: 20),

          // Ingredients
          Row(
            children: [
              const Expanded(child: Text('Ingredients', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
              TextButton.icon(
                onPressed: () => setState(() => _ingredients.add({'name': '', 'quantity': '', 'unit': '', '_id': '${_nextIngId++}'})),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add', style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFE8622A), padding: EdgeInsets.zero),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._ingredients.asMap().entries.map((e) {
            final i = e.key;
            final ing = e.value;
            return Padding(
              key: ValueKey(ing['_id']),
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                  flex: 4,
                  child: _inlineField(ing['name'] ?? '', 'Ingredient', (v) => _ingredients[i]['name'] = v),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: _inlineField(ing['quantity'] ?? '', 'Qty', (v) => _ingredients[i]['quantity'] = v),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: _inlineField(ing['unit'] ?? '', 'Unit', (v) => _ingredients[i]['unit'] = v),
                ),
                if (_ingredients.length > 1)
                  IconButton(
                    onPressed: () => setState(() => _ingredients.removeAt(i)),
                    icon: const Icon(Icons.remove_circle_outline, size: 18, color: Color(0xFFCCC9C3)),
                    padding: const EdgeInsets.only(left: 4),
                    constraints: const BoxConstraints(),
                  ),
              ]),
            );
          }),
          const SizedBox(height: 20),

          Row(children: [
            const Expanded(child: Text('Instructions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
            TextButton.icon(
              onPressed: _openInstructionsEditor,
              icon: const Icon(Icons.open_in_full, size: 14),
              label: const Text('Expand', style: TextStyle(fontSize: 13)),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFE8622A), padding: EdgeInsets.zero),
            ),
          ]),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _openInstructionsEditor,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 90),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E2DC)),
              ),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _instructionsCtrl,
                builder: (_, val, __) => Text(
                  val.text.isEmpty ? 'Tap to add step-by-step instructions…' : val.text,
                  style: TextStyle(
                    fontSize: 13, height: 1.5,
                    color: val.text.isEmpty ? const Color(0xFFBBB8B2) : const Color(0xFF3A3836),
                  ),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          _sectionLabel('Tags'),
          _textField(_tagsCtrl, 'quick, vegetarian, weeknight…'),
          const SizedBox(height: 20),

          // ── Category ───────────────────────────────────────────
          _sectionLabel('Category'),
          _buildCategoryPicker(),
          const SizedBox(height: 20),

          // ── Share publicly ─────────────────────────────────────
          if (Store.isReady && Store.i.mode == StorageMode.server) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E2DC)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Share publicly', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('Visible to anyone on Explore', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  Switch(
                    value: _isPublic,
                    onChanged: (v) => setState(() => _isPublic = v),
                    activeColor: const Color(0xFFE8622A),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ] else
            const SizedBox(height: 32),
        ],
      ),
    );
  }

  static const _kSuggestedCategories = [
    'Soup', 'Stew', 'Chili', 'Salad', 'Bowl', 'Pasta', 'Rice', 'Curry',
    'Stir-fry', 'Tacos', 'Burger', 'Pizza', 'Sandwich', 'Wrap', 'Roast',
    'Grilled', 'Seafood', 'Breakfast', 'Brunch', 'Eggs', 'Pancakes',
    'Oatmeal', 'Smoothie', 'Snack', 'Appetizer', 'Side dish', 'Dip',
    'Bread', 'Cake', 'Cookies', 'Muffins', 'Pie', 'Dessert', 'Drink',
  ];

  Widget _buildCategoryPicker() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _kSuggestedCategories.map((cat) {
        final active = _category == cat;
        return GestureDetector(
          onTap: () => setState(() => _category = active ? '' : cat),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: active ? const Color(0xFF1A1918) : Colors.white,
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: active ? const Color(0xFF1A1918) : const Color(0xFFE5E2DC), width: 1.5),
            ),
            child: Text(cat, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: active ? Colors.white : const Color(0xFF555250),
            )),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildScanPastePanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E2DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input method buttons
          Row(children: [
            _inputSourceBtn(Icons.camera_alt_outlined, 'Camera',
              _ocrLoading ? null : () => _ocrIntoTextBox(ImageSource.camera)),
            const SizedBox(width: 8),
            _inputSourceBtn(Icons.photo_library_outlined, 'Library',
              _ocrLoading ? null : () => _ocrIntoTextBox(ImageSource.gallery)),
            const SizedBox(width: 8),
            _inputSourceBtn(Icons.paste_outlined, 'Paste',
              _ocrLoading ? null : _pasteFromClipboard),
          ]),
          const SizedBox(height: 12),

          // Text area — OCR or pasted text, user can edit freely
          Stack(
            children: [
              TextField(
                controller: _rawTextCtrl,
                maxLines: 9,
                style: const TextStyle(fontSize: 13, height: 1.45),
                decoration: InputDecoration(
                  hintText: 'Take a photo of a recipe, paste text, or type it in…',
                  hintStyle: const TextStyle(color: Color(0xFFBBB8B2)),
                  filled: true,
                  fillColor: const Color(0xFFF7F6F3),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E2DC))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E2DC))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8622A))),
                  contentPadding: const EdgeInsets.all(14),
                ),
              ),
              // OCR spinner overlay
              if (_ocrLoading)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.75),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        CircularProgressIndicator(color: Color(0xFFE8622A), strokeWidth: 2.5),
                        SizedBox(height: 10),
                        Text('Reading photo…', style: TextStyle(fontSize: 12, color: Color(0xFF888480), fontWeight: FontWeight.w500)),
                      ]),
                    ),
                  ),
                ),
            ],
          ),

          if (_error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error, style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
          const SizedBox(height: 12),

          // Parse button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_importing || _ocrLoading) ? null : _doParseText,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE8622A),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _importing
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Parse recipe', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputSourceBtn(IconData icon, String label, VoidCallback? onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F6F3),
            border: Border.all(color: const Color(0xFFE5E2DC), width: 1.5),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 20, color: onTap == null ? const Color(0xFFCCC9C3) : const Color(0xFF555250)),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: onTap == null ? const Color(0xFFCCC9C3) : const Color(0xFF888480))),
          ]),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    final hasImage = _pickedImage != null || _imageCtrl.text.isNotEmpty;
    return GestureDetector(
      onTap: _showImagePicker,
      child: Container(
        height: 160,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E2DC), width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.hardEdge,
        child: _uploadingImage
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFE8622A)))
            : _pickedImage != null
                ? Stack(fit: StackFit.expand, children: [
                    Image.file(_pickedImage!, fit: BoxFit.cover),
                    Positioned(top: 8, right: 8, child: _editBadge()),
                  ])
                : _imageCtrl.text.isNotEmpty
                    ? Stack(fit: StackFit.expand, children: [
                        Image.network(_imageCtrl.text, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _emptyPicker()),
                        Positioned(top: 8, right: 8, child: _editBadge()),
                      ])
                    : _emptyPicker(),
      ),
    );
  }

  Widget _emptyPicker() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.add_photo_alternate_outlined, size: 36, color: Color(0xFFBBB8B2)),
      const SizedBox(height: 8),
      const Text('Tap to add photo', style: TextStyle(fontSize: 13, color: Color(0xFF888480), fontWeight: FontWeight.w500)),
      const SizedBox(height: 2),
      const Text('Camera or library', style: TextStyle(fontSize: 11, color: Color(0xFFBBB8B2))),
    ]);
  }

  Widget _editBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(99)),
      child: const Text('Change', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF555250))),
  );

  Widget _textField(TextEditingController ctrl, String hint, {TextInputType? type}) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      decoration: InputDecoration(
        hintText: hint,
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E2DC))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E2DC))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8622A))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _inlineField(String value, String hint, Function(String) onChanged) {
    return TextFormField(
      initialValue: value,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E2DC))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE5E2DC))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFE8622A))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        isDense: true,
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE5E2DC), width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF666360)),
      ),
    );
  }
}

enum _ImportMode { url, tiktok, pasteText, manual }

class _InstructionsEditorScreen extends StatefulWidget {
  final TextEditingController controller;
  const _InstructionsEditorScreen({required this.controller});

  @override
  State<_InstructionsEditorScreen> createState() => _InstructionsEditorScreenState();
}

class _InstructionsEditorScreenState extends State<_InstructionsEditorScreen> {
  late List<TextEditingController> _steps;

  @override
  void initState() {
    super.initState();
    final raw = widget.controller.text.trim();
    final lines = raw.isEmpty
        ? <String>[]
        : raw.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    // Strip any existing "1. " / "1) " numbering — cook mode re-adds it at display time
    final cleaned = lines.map((s) => s.replaceFirst(RegExp(r'^\d+[.)]\s*'), '')).toList();
    _steps = cleaned.map((s) => TextEditingController(text: s)).toList();
    if (_steps.isEmpty) _steps.add(TextEditingController());
  }

  @override
  void dispose() {
    for (final c in _steps) c.dispose();
    super.dispose();
  }

  void _save() {
    final text = _steps
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .join('\n');
    widget.controller.text = text;
    Navigator.pop(context);
  }

  void _addStep() => setState(() => _steps.add(TextEditingController()));

  void _deleteStep(int i) {
    setState(() {
      _steps[i].dispose();
      _steps.removeAt(i);
      if (_steps.isEmpty) _steps.add(TextEditingController());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F3),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F6F3),
        elevation: 0,
        title: const Text('Instructions',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        leading: IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Done',
              style: TextStyle(color: Color(0xFFE8622A), fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: _steps.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) newIndex--;
            final item = _steps.removeAt(oldIndex);
            _steps.insert(newIndex, item);
          });
        },
        itemBuilder: (context, i) => _StepCard(
          key: ValueKey(i),
          number: i + 1,
          controller: _steps[i],
          onDelete: () => _deleteStep(i),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStep,
        backgroundColor: const Color(0xFFE8622A),
        icon: const Icon(Icons.add),
        label: const Text('Add step'),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final int number;
  final TextEditingController controller;
  final VoidCallback onDelete;

  const _StepCard({
    super.key,
    required this.number,
    required this.controller,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E2DC)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step number badge
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
            child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFFE8622A),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Center(
                child: Text('$number',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
          // Editable step text
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: null,
              style: const TextStyle(fontSize: 14, height: 1.5),
              decoration: const InputDecoration(
                hintText: 'Describe this step…',
                hintStyle: TextStyle(color: Color(0xFFBBB8B2)),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          // Delete + drag handle
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.close, size: 16, color: Color(0xFFCCC9C3)),
                onPressed: onDelete,
                padding: const EdgeInsets.fromLTRB(4, 12, 12, 4),
                constraints: const BoxConstraints(),
              ),
              ReorderableDragStartListener(
                index: number - 1,
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(4, 4, 12, 12),
                  child: Icon(Icons.drag_handle, size: 18, color: Color(0xFFCCC9C3)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
