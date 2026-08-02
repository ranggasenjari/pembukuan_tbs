import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/ocr_settings_model.dart';
import '../../providers/providers.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _webhookUrlController = TextEditingController();
  final _webhookKeyController = TextEditingController();
  final _mistralApiKeyController = TextEditingController();
  final _mistralPromptController = TextEditingController();
  final _mistralSchemaController = TextEditingController();
  OcrMode _mode = OcrMode.webhook;
  OcrSettingsModel? _current;
  bool _initialized = false;
  bool _saving = false;

  @override
  void dispose() {
    _webhookUrlController.dispose();
    _webhookKeyController.dispose();
    _mistralApiKeyController.dispose();
    _mistralPromptController.dispose();
    _mistralSchemaController.dispose();
    super.dispose();
  }

  void _hydrate(OcrSettingsModel settings) {
    if (_initialized) return;
    _initialized = true;
    _current = settings;
    _mode = settings.mode;
    _webhookUrlController.text = settings.webhookUrl;
    _mistralPromptController.text = settings.mistralPrompt;
    _mistralSchemaController.text = settings.mistralOutputSchema;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _current == null) return;
    setState(() => _saving = true);
    try {
      final saved = await ref.read(ocrSettingsRepositoryProvider).saveSettings(
            current: _current!,
            mode: _mode,
            webhookUrl: _webhookUrlController.text,
            webhookKey: _webhookKeyController.text,
            mistralApiKey: _mistralApiKeyController.text,
            mistralPrompt: _mistralPromptController.text,
            mistralOutputSchema: _mistralSchemaController.text,
          );
      ref.invalidate(ocrSettingsProvider);
      if (!mounted) return;
      setState(() {
        _current = saved;
        _webhookKeyController.clear();
        _mistralApiKeyController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Setting OCR berhasil disimpan'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan setting: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsValue = ref.watch(ocrSettingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FE),
      appBar: AppBar(
        title: const Text('Setting'),
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1B2559),
        elevation: 0,
      ),
      body: settingsValue.when(
        data: (settings) {
          _hydrate(settings);
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _sectionCard(
                  title: 'OCR Bon',
                  icon: Icons.document_scanner_outlined,
                  children: [
                    DropdownButtonFormField<OcrMode>(
                      initialValue: _mode,
                      decoration: _inputDecoration('Mode OCR'),
                      items: const [
                        DropdownMenuItem(
                          value: OcrMode.webhook,
                          child: Text('OCR Webhook API'),
                        ),
                        DropdownMenuItem(
                          value: OcrMode.internal,
                          child: Text('Internal OCR'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) setState(() => _mode = value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  title: 'OCR Webhook API',
                  icon: Icons.api_outlined,
                  children: [
                    TextFormField(
                      controller: _webhookUrlController,
                      decoration: _inputDecoration('URL'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'URL wajib diisi';
                        }
                        final uri = Uri.tryParse(value.trim());
                        return uri != null &&
                                uri.hasScheme &&
                                uri.host.isNotEmpty
                            ? null
                            : 'URL tidak valid';
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _webhookKeyController,
                      obscureText: true,
                      decoration: _inputDecoration(
                        settings.webhookKey.isEmpty
                            ? 'Key'
                            : 'Key (tersimpan, kosongkan jika tidak diganti)',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _sectionCard(
                  title: 'Internal OCR',
                  icon: Icons.auto_awesome_outlined,
                  children: [
                    TextFormField(
                      controller: _mistralApiKeyController,
                      obscureText: true,
                      decoration: _inputDecoration(
                        settings.mistralApiKey.isEmpty
                            ? 'Mistral API Key'
                            : 'Mistral API Key (tersimpan, kosongkan jika tidak diganti)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _mistralPromptController,
                      decoration: _inputDecoration('Prompt'),
                      minLines: 5,
                      maxLines: 10,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Prompt wajib diisi'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _mistralSchemaController,
                      decoration: _inputDecoration('Output JSON Schema'),
                      minLines: 10,
                      maxLines: 18,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Schema wajib diisi'
                              : null,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Simpan Setting'),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Gagal memuat setting: $e')),
      ),
    );
  }

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF4318FF), size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1B2559),
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4318FF), width: 1.5),
      ),
    );
  }
}
