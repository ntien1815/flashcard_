import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/deck_provider.dart';
import '../theme/app_colors.dart';

class AddDeckScreen extends StatefulWidget {
  const AddDeckScreen({super.key});

  @override
  State<AddDeckScreen> createState() => _AddDeckScreenState();
}

class _AddDeckScreenState extends State<AddDeckScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _isLoading = false;
  int _selectedColorIndex = 0;
  int _selectedIconIndex = 0;

  static const _colorBgs = [
    Color(0xFFEEEDFE),
    Color(0xFFE1F5EE),
    Color(0xFFFAEEDA),
    Color(0xFFFAECE7),
    Color(0xFFE6F1FB),
    Color(0xFFEAF3DE),
  ];
  static const _colorAccents = [
    Color(0xFF534AB7),
    Color(0xFF1D9E75),
    Color(0xFFBA7517),
    Color(0xFFD85A30),
    Color(0xFF185FA5),
    Color(0xFF3B6D11),
  ];
  static const _colorNames = [
    'Tím',
    'Xanh lá',
    'Vàng',
    'Cam',
    'Xanh dương',
    'Lục',
  ];

  static const _iconOptions = [
    Icons.menu_book_rounded,
    Icons.chat_bubble_outline_rounded,
    Icons.business_center_outlined,
    Icons.science_outlined,
    Icons.music_note_outlined,
    Icons.sports_soccer_outlined,
    Icons.travel_explore_rounded,
    Icons.computer_outlined,
  ];
  static const _iconLabels = [
    'Học tập',
    'Hội thoại',
    'Kinh doanh',
    'Khoa học',
    'Âm nhạc',
    'Thể thao',
    'Du lịch',
    'Công nghệ',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await context.read<DeckProvider>().addDeck(
        _nameCtrl.text.trim(),
        _descCtrl.text.trim(),
      );
      if (mounted) {
        _showSnack('Đã tạo bộ thẻ "${_nameCtrl.text.trim()}"', isError: false);
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('[AddDeckScreen] save error: $e');
      _showSnack('Không thể tạo bộ thẻ. Vui lòng thử lại.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
          'Tạo bộ thẻ mới',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: TextButton(
              onPressed: _isLoading ? null : _handleSave,
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Lưu',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
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
              'Thông tin',
              Column(
                children: [
                  _buildTextField(
                    c,
                    _nameCtrl,
                    'Tên bộ thẻ (bắt buộc)',
                    Icons.title_rounded,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Vui lòng nhập tên bộ thẻ.';
                      }
                      if (v.trim().length > 50) {
                        return 'Tên không được quá 50 ký tự.';
                      }
                      return null;
                    },
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  _buildTextField(
                    c,
                    _descCtrl,
                    'Mô tả (tuỳ chọn)',
                    Icons.notes_rounded,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildSection(c, 'Màu sắc', _buildColorPicker(c)),
            const SizedBox(height: 12),
            _buildSection(c, 'Biểu tượng', _buildIconPicker(c)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isLoading ? null : _handleSave,
              style: FilledButton.styleFrom(
                backgroundColor: c.primary,
                disabledBackgroundColor: c.primaryLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Tạo bộ thẻ',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard(AppColors c) {
    final accent = _colorAccents[_selectedColorIndex];
    final bg = _colorBgs[_selectedColorIndex];
    final icon = _iconOptions[_selectedIconIndex];
    final name = _nameCtrl.text.trim();
    final isEmpty = name.isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border.withValues(alpha: 0.5), width: 0.5),
      ),
      padding: const EdgeInsets.all(13),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEmpty ? 'Tên bộ thẻ' : name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isEmpty ? c.textTertiary : c.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Xem trước',
                  style: TextStyle(fontSize: 11, color: c.textSecondary),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: 0,
                    minHeight: 4,
                    backgroundColor: c.bodyBg,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '0 thẻ',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker(AppColors c) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(_colorBgs.length, (i) {
        final isSelected = i == _selectedColorIndex;
        return GestureDetector(
          onTap: () => setState(() => _selectedColorIndex = i),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _colorBgs[i],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? _colorAccents[i] : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Icon(
                        Icons.check_rounded,
                        color: _colorAccents[i],
                        size: 18,
                      )
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                _colorNames[i],
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? _colorAccents[i] : c.textSecondary,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildIconPicker(AppColors c) {
    final accent = _colorAccents[_selectedColorIndex];
    final bg = _colorBgs[_selectedColorIndex];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(_iconOptions.length, (i) {
        final isSelected = i == _selectedIconIndex;
        return GestureDetector(
          onTap: () => setState(() => _selectedIconIndex = i),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected ? bg : c.bodyBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? accent : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _iconOptions[i],
                  color: isSelected ? accent : c.textTertiary,
                  size: 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _iconLabels[i],
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? accent : c.textSecondary,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildTextField(
    AppColors c,
    TextEditingController ctrl,
    String hint,
    IconData icon, {
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
        hintText: hint,
        hintStyle: TextStyle(fontSize: 13, color: c.textTertiary),
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
            border: Border.all(
              color: c.border.withValues(alpha: 0.5),
              width: 0.5,
            ),
          ),
          padding: const EdgeInsets.all(14),
          child: child,
        ),
      ],
    );
  }
}
