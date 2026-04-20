import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/api_service.dart';
import '../services/data_service.dart';
import '../services/translation_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DataService _dataService = DataService();
  final ApiService _apiService = ApiService();
  final AppTranslations _tr = AppTranslations();
  late TextEditingController _urlController;
  bool _testing = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: _dataService.getServerUrl());
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    await _dataService.setServerUrl(url);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr.t('settings_saved'))),
    );
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    await _dataService.setServerUrl(url);
    setState(() { _testing = true; _testResult = null; });
    final ok = await _apiService.checkHealth();
    setState(() {
      _testing = false;
      _testResult = ok ? '✅  Connected successfully!' : '❌  Cannot connect. Check the URL and server.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tr.t('settings')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Server URL section
            Text(
              _tr.t('server_url'),
              style: const TextStyle(
                fontSize: AppTheme.fontMD,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              style: const TextStyle(fontSize: AppTheme.fontSM),
              decoration: InputDecoration(
                hintText: _tr.t('server_url_hint'),
                prefixIcon: const Icon(Icons.dns_rounded, color: AppTheme.primary, size: 28),
              ),
            ),
            const SizedBox(height: 16),

            // Test connection button
            OutlinedButton.icon(
              onPressed: _testing ? null : _testConnection,
              icon: _testing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Icon(Icons.wifi_tethering_rounded, size: 26),
              label: Text(_testing ? 'Testing...' : 'Test Connection'),
            ),

            if (_testResult != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _testResult!.startsWith('✅')
                      ? AppTheme.success.withOpacity(0.1)
                      : AppTheme.danger.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _testResult!.startsWith('✅') ? AppTheme.success : AppTheme.danger,
                    width: 1.5,
                  ),
                ),
                child: Text(
                  _testResult!,
                  style: TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: _testResult!.startsWith('✅') ? AppTheme.success : AppTheme.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded, size: 28),
              label: Text(_tr.t('save_settings')),
            ),

            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 20),

            // Info section
            const Text(
              'How to connect',
              style: TextStyle(
                fontSize: AppTheme.fontMD,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            _infoRow('1.', 'Start the Node.js server on your computer.'),
            _infoRow('2.', 'Make sure your phone and computer are on the same Wi-Fi.'),
            _infoRow('3.', 'Find your computer\'s local IP (e.g. 192.168.1.100).'),
            _infoRow('4.', 'Enter: http://192.168.1.100:3000 in the field above.'),
            _infoRow('5.', 'For Android emulator use: http://10.0.2.2:3000'),
            _infoRow('6.', 'For iOS simulator use: http://localhost:3000'),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(num,
              style: const TextStyle(
                  fontSize: AppTheme.fontSM,
                  color: AppTheme.accent,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: AppTheme.fontSM,
                    color: AppTheme.textMedium,
                    height: 1.5)),
          ),
        ],
      ),
    );
  }
}
