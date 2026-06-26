import re

filepath = r'c:\SP\sp 2b\MAD\code\text_scanner\lib\screens\home_screen.dart'
with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Add import for saved_text_screen.dart
if "import 'saved_text_screen.dart';" not in content:
    content = content.replace("import 'login_screen.dart';", "import 'login_screen.dart';\nimport 'saved_text_screen.dart';")

# 1. Replace _pickImage to only pick image and set _selectedImage state
pick_image_old = """  Future<void> _pickImage(ImageSource source) async {
    // If the user has explicitly chosen local scan in Settings, bypass the
    // AI quota check entirely.
    if (_useLocalScan) {
      await _pickImageWithLocalOcr(source);
      return;
    }

    // Check internet connection; if offline, auto-fallback to local scan.
    final netResults = await Connectivity().checkConnectivity();
    if (netResults.contains(ConnectivityResult.none) || netResults.isEmpty) {
      await _pickImageWithLocalOcr(source);
      return;
    }

    // AI mode: enforce daily limit.
    if (!_canScan()) {
      _showScanLimitDialog(source: source);
      return;
    }

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (picked == null) return;
      await _processImage(File(picked.path), useLocalOcr: false);
    } catch (e) {
      _showError(_tr.t('error_generic'));
    }
  }"""

pick_image_new = """  File? _selectedImage;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      if (picked != null) {
        setState(() {
          _selectedImage = File(picked.path);
        });
      }
    } catch (e) {
      _showError(_tr.t('error_generic'));
    }
  }

  Future<void> _confirmScan() async {
    if (_selectedImage == null) return;
    
    if (_useLocalScan) {
      await _processImage(_selectedImage!, useLocalOcr: true);
      return;
    }

    final netResults = await Connectivity().checkConnectivity();
    if (netResults.contains(ConnectivityResult.none) || netResults.isEmpty) {
      await _processImage(_selectedImage!, useLocalOcr: true);
      return;
    }

    if (!_canScan()) {
      _showScanLimitDialog(source: null);
      return;
    }
    
    await _processImage(_selectedImage!, useLocalOcr: false);
  }"""
content = content.replace(pick_image_old, pick_image_new)

# 2. _pickImageWithLocalOcr shouldn't process immediately either, but actually it's only called from limit dialog now?
# Wait, let's fix _showScanLimitDialog in home_screen.dart to use _selectedImage
limit_dialog_old_continue = """            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                if (source != null) {
                  await _pickImageWithLocalOcr(source);
                }
              },"""
limit_dialog_new_continue = """            OutlinedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                if (_selectedImage != null) {
                  await _processImage(_selectedImage!, useLocalOcr: true);
                }
              },"""
content = content.replace(limit_dialog_old_continue, limit_dialog_new_continue)

# 3. Replace _buildBody with Camera UI
build_body_old_start = "  Widget _buildBody() {"
build_body_old_end = "  Widget _buildNoResults() {"
import re
pattern = re.compile(r"  Widget _buildBody\(\) \{.*?(?=  Widget _buildNoResults\(\) \{)", re.DOTALL)

build_body_new = """  Widget _buildBody() {
    final isPremium = _premium.isPremium;
    final scansUsed = _dataService.getFreeScanCount();
    final scansLeft = (_freeDailyLimit - scansUsed).clamp(0, _freeDailyLimit);
    final limitText = isPremium ? _tr.t('settings_unlimited') : "$scansLeft ${_tr.t('home_of')} $_freeDailyLimit ${_tr.t('home_scans_left')}";

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.cardBorder),
            ),
            child: Column(
              children: [
                Text(
                  "${_tr.t('home_current_scan_mode')} ${_useLocalScan ? _tr.t('home_scan_mode_local') : _tr.t('home_scan_mode_ai')}",
                  style: const TextStyle(fontSize: AppTheme.fontSM, fontWeight: FontWeight.bold, color: AppTheme.primary),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  limitText,
                  style: TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: scansLeft == 0 && !isPremium ? AppTheme.danger : AppTheme.textDark,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_rounded, size: 24),
                  label: Text(_tr.t('take_photo')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    minimumSize: const Size(0, 60),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_rounded, size: 24),
                  label: Text(_tr.t('upload_image')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    minimumSize: const Size(0, 60),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_selectedImage != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(_selectedImage!, height: 300, fit: BoxFit.cover),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _confirmScan,
              icon: const Icon(Icons.check_circle_rounded, size: 30),
              label: Text("Confirm"),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.success,
                minimumSize: const Size(double.infinity, 68),
              ),
            ),
          ] else ...[
            Container(
              height: 300,
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.cardBorder, style: BorderStyle.solid),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_search_rounded, size: 60, color: AppTheme.primary.withOpacity(0.3)),
                    const SizedBox(height: 16),
                    Text(
                      _tr.t('home_no_saved_texts_guest'),
                      style: TextStyle(color: AppTheme.textMedium, fontSize: AppTheme.fontSM),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

"""
content = pattern.sub(build_body_new, content)

# 4. Remove _buildBottomButtons completely (replace it and its usage)
content = content.replace("bottomNavigationBar: _loading ? null : _buildBottomButtons(),", "bottomNavigationBar: null,")
content = re.sub(r"  Widget _buildBottomButtons\(\) \{.*?(^\})$", "", content, flags=re.DOTALL | re.MULTILINE)

# 5. Add "Saved Texts" to drawer
drawer_search_old = """            // ── Search button ────────────────────────────────────────────
            _drawerButton(
              icon: Icons.search_rounded,
              label: _tr.t('home_search'),
              onTap: _savedTexts.isEmpty
                  ? null
                  : () {
                Navigator.pop(context);
                _openSearch();
              },
              enabled: _savedTexts.isNotEmpty,
            ),"""
drawer_search_new = """            // ── Saved Texts button ────────────────────────────────────────────
            _drawerButton(
              icon: Icons.history_rounded,
              label: _tr.t('saved_texts'),
              onTap: () async {
                Navigator.pop(context);
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SavedTextScreen(onLanguageChanged: widget.onLanguageChanged)),
                );
                setState(() => _currentLang = _dataService.getLanguage());
                await _loadSavedTexts();
              },
            ),"""
content = content.replace(drawer_search_old, drawer_search_new)

# Since we might have deleted _buildNoResults but left its definition, let's keep it just in case, or delete it.
# Actually the regex stopped AT _buildNoResults. That's fine. It's unused but won't crash.

# Wait, the translation for "Confirm" was hardcoded in English. I'll change it to use a tr key if I added one. I didn't add "confirm", but there is already "confirm_delete" as "Delete", let's just use "OK" or something? No, I will use "settings_ok" which is "OK" or "save" which is "Save". Wait, "Confirm" is not localized. I should add "confirm" to translations or use a generic one. Let's write the updated json script.
# Actually I can just write "Confirm" as English for now since the user said "a confirm button", wait, "make sure the text translation is correct and no text is hardcoded to english". I will add "confirm" to the translations using another py script before running this.
content = content.replace('Text("Confirm")', "Text(_tr.t('confirm'))")

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)

print("HomeScreen modified successfully.")
