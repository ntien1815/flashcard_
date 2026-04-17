import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/flashcard_provider.dart';
import '../theme/app_colors.dart';

class AddCardScreen extends StatefulWidget {
  final String deckId;
  const AddCardScreen({super.key, required this.deckId});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _frontCtrl = TextEditingController();
  final _backCtrl = TextEditingController();
  final _exampleCtrl = TextEditingController();
  final _pronunciationCtrl = TextEditingController();
  bool _isSaving = false;
  int _savedCount = 0;

  @override
  void dispose() {
    _frontCtrl.dispose();
    _backCtrl.dispose();
    _exampleCtrl.dispose();
    _pronunciationCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveCard() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await context.read<FlashcardProvider>().addFlashcard(
        deckId: widget.deckId,
        front: _frontCtrl.text.trim(),
        back: _backCtrl.text.trim(),
        example: _exampleCtrl.text.trim().isEmpty
            ? null
            : _exampleCtrl.text.trim(),
        pronunciation: _pronunciationCtrl.text.trim().isEmpty
            ? null
            : _pronunciationCtrl.text.trim(),
      );
      if (mounted) {
        setState(() {
          _savedCount++;
          _isSaving = false;
        });
        _showSnack('Đã thêm thẻ "${_frontCtrl.text.trim()}"', isError: false);
        _frontCtrl.clear();
        _backCtrl.clear();
        _exampleCtrl.clear();
        _pronunciationCtrl.clear();
      }
    } catch (e) {
      debugPrint('[AddCardScreen] save error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        _showSnack('Không thể thêm thẻ. Vui lòng thử lại.', isError: true);
      }
    }
  }

  void _showSnack(String msg, {required bool isError}) {
    if (!mounted) return;
    final c = AppColors.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? c.error : c.teal,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      backgroundColor: c.bodyBg,
      appBar: AppBar(
        backgroundColor: c.primary,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: c.primaryLighter,
            size: 18,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Thêm thẻ mới',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        actions: [
          if (_savedCount > 0)
            Center(
              child: Container(
                margin: const EdgeInsets.only(right: 14),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Đã thêm $_savedCount',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _buildPreviewCard(c),
            const SizedBox(height: 14),
            _buildSection(
              c,
              'Nội dung thẻ',
              Column(
                children: [
                  _buildTextField(
                    c,
                    _frontCtrl,
                    'Từ tiếng Anh *',
                    Icons.translate_rounded,
                    hint: 'VD: ephemeral',
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Không được để trống'
                        : null,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    c,
                    _backCtrl,
                    'Nghĩa tiếng Việt *',
                    Icons.note_alt_outlined,
                    hint: 'VD: phù du, ngắn ngủi',
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Không được để trống'
                        : null,
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildSection(
              c,
              'Thông tin bổ sung (tuỳ chọn)',
              Column(
                children: [
                  _buildTextField(
                    c,
                    _pronunciationCtrl,
                    'Phiên âm',
                    Icons.record_voice_over_outlined,
                    hint: 'VD: /ɪˈfem.ər.əl/',
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    c,
                    _exampleCtrl,
                    'Câu ví dụ',
                    Icons.format_quote_rounded,
                    hint: 'VD: Fame is ephemeral.',
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _saveCard,
              style: FilledButton.styleFrom(
                backgroundColor: c.primary,
                disabledBackgroundColor: c.primaryLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded, size: 18, color: Colors.white),
                        SizedBox(width: 6),
                        Text(
                          'Lưu & thêm tiếp',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Thẻ sẽ được lưu và bạn có thể thêm thẻ tiếp theo',
                style: TextStyle(fontSize: 11, color: c.textTertiary),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(AppColors c) {
    final front = _frontCtrl.text.trim();
    final back = _backCtrl.text.trim();
    final hasFront = front.isNotEmpty;
    final hasBack = back.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        // ✅ Dùng c.border thay vì Colors.black hardcode
        border: Border.all(color: c.border.withValues(alpha: 0.3), width: 0.5),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.primaryBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              hasFront ? Icons.style_rounded : Icons.style_outlined,
              color: hasFront ? c.primary : c.primaryLight,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasFront ? front : 'Mặt trước',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: hasFront ? c.textPrimary : c.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  hasBack ? back : 'Mặt sau',
                  style: TextStyle(
                    fontSize: 12,
                    color: hasBack ? c.primary : c.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            'Xem trước',
            style: TextStyle(fontSize: 10, color: c.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(AppColors c, String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: c.textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(12),
            // ✅ Dùng c.border thay vì Colors.black hardcode
            border: Border.all(
              color: c.border.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: child,
        ),
      ],
    );
  }

  Widget _buildTextField(
    AppColors c,
    TextEditingController ctrl,
    String label,
    IconData icon, {
    String? hint,
    int maxLines = 1,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
  }) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      onChanged: onChanged,
      textInputAction: maxLines > 1
          ? TextInputAction.done
          : TextInputAction.next,
      decoration: InputDecoration(
        hintText: hint ?? label,
        hintStyle: TextStyle(fontSize: 13, color: c.textTertiary),
        labelText: label,
        labelStyle: TextStyle(fontSize: 13, color: c.textSecondary),
        prefixIcon: Icon(icon, size: 18, color: c.textSecondary),
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.border, width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.border, width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.primary, width: 1.2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.error, width: 0.8),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.error, width: 1.2),
        ),
        errorStyle: TextStyle(fontSize: 11, color: c.error),
      ),
      validator: validator,
    );
  }
}
