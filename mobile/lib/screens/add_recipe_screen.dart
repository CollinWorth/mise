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
    final selections = await Navigator.push<OcrSelections>(
      context,
      MaterialPageRoute(builder: (_) => OcrSelectorScreen(ocr: ocr!)),
    );
    if (selections != null && mounted) {
      _applyOcrSelections(selections);
    }
  }

  /// Build structured text from labelled sections and send to backend.
  Future<void> _applyOcrSelections(OcrSelections sel) async {
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
        setState(() { _importedData = data; _fillForm(data); });
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
                  child: _inlineField(ing['name'] ?? '', 'Ingredient', (v) => setState(() => _ingredients[i]['name'] = v)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: _inlineField(ing['quantity'] ?? '', 'Qty', (v) => setState(() => _ingredients[i]['quantity'] = v)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: _inlineField(ing['unit'] ?? '', 'Unit', (v) => setState(() => _ingredients[i]['unit'] = v)),
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

          const Text('Instructions', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          TextField(
            controller: _instructionsCtrl,
            maxLines: 8,
            decoration: InputDecoration(
              hintText: 'Step-by-step instructions…',
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E2DC))),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E2DC))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE8622A))),
              contentPadding: const EdgeInsets.all(14),
            ),
          ),
          const SizedBox(height: 16),

          _sectionLabel('Tags'),
          _textField(_tagsCtrl, 'quick, vegetarian, weeknight…'),
          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE8622A),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Recipe', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
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
