import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/flashcard_provider.dart';

class AddCardScreen extends StatefulWidget {
  final String deckId; // ← String
  const AddCardScreen({super.key, required this.deckId});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _frontController = TextEditingController();
  final _backController = TextEditingController();
  final _exampleController = TextEditingController();
  final _pronunciationController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _frontController.dispose();
    _backController.dispose();
    _exampleController.dispose();
    _pronunciationController.dispose();
    super.dispose();
  }

  Future<void> _saveCard() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    await context.read<FlashcardProvider>().addFlashcard(
      deckId: widget.deckId,
      front: _frontController.text.trim(),
      back: _backController.text.trim(),
      example: _exampleController.text.trim().isEmpty
          ? null
          : _exampleController.text.trim(),
      pronunciation: _pronunciationController.text.trim().isEmpty
          ? null
          : _pronunciationController.text.trim(),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Đã thêm thẻ!'),
          duration: Duration(seconds: 1),
        ),
      );
      _frontController.clear();
      _backController.clear();
      _exampleController.clear();
      _pronunciationController.clear();
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm thẻ mới'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _frontController,
              decoration: const InputDecoration(
                labelText: 'Từ tiếng Anh *',
                hintText: 'VD: ephemeral',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.translate),
              ),
              textCapitalization: TextCapitalization.none,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Không được để trống' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _backController,
              decoration: const InputDecoration(
                labelText: 'Nghĩa tiếng Việt *',
                hintText: 'VD: phù du, ngắn ngủi',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Không được để trống' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pronunciationController,
              decoration: const InputDecoration(
                labelText: 'Phiên âm',
                hintText: 'VD: /ɪˈfem.ər.əl/',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.record_voice_over),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _exampleController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Câu ví dụ',
                hintText: 'VD: Fame is ephemeral.',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.format_quote),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSaving ? null : _saveCard,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(_isSaving ? 'Đang lưu...' : 'Lưu thẻ'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
