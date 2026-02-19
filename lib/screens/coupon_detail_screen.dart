import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/coupon.dart';
import '../providers/coupon_provider.dart';

class CouponDetailScreen extends StatefulWidget {
  final Coupon coupon;
  final bool isNew;

  const CouponDetailScreen({
    super.key,
    required this.coupon,
    this.isNew = false,
  });

  @override
  State<CouponDetailScreen> createState() => _CouponDetailScreenState();
}

class _CouponDetailScreenState extends State<CouponDetailScreen> {
  late TextEditingController _storeController;
  late TextEditingController _itemController;
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  DateTime? _expiryDate;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _storeController =
        TextEditingController(text: widget.coupon.storeName ?? '');
    _itemController =
        TextEditingController(text: widget.coupon.itemName ?? '');
    _amountController =
        TextEditingController(text: widget.coupon.amount?.toString() ?? '');
    _notesController =
        TextEditingController(text: widget.coupon.notes ?? '');
    _expiryDate = widget.coupon.expiryDate;

    // 새 쿠폰이면 편집 모드로 시작
    if (widget.isNew) _isEditing = true;
  }

  @override
  void dispose() {
    _storeController.dispose();
    _itemController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(widget.isNew ? '쿠폰 추가' : '쿠폰 상세'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (!widget.isNew)
            IconButton(
              icon: Icon(_isEditing ? Icons.close : Icons.edit_outlined),
              onPressed: () => setState(() => _isEditing = !_isEditing),
            ),
          if (_isEditing)
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      '저장',
                      style: TextStyle(
                        color: Color(0xFF4F46E5),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildImageSection(),
            const SizedBox(height: 16),
            _buildInfoCard(),
            const SizedBox(height: 12),
            _buildBarcodeCard(),
            const SizedBox(height: 12),
            if (!widget.isNew) _buildActionButtons(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    final file = File(widget.coupon.imagePath);
    return Container(
      width: double.infinity,
      color: Colors.black,
      constraints: const BoxConstraints(maxHeight: 300),
      child: file.existsSync()
          ? Image.file(
              file,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => _imagePlaceholder(),
            )
          : _imagePlaceholder(),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 200,
      color: const Color(0xFFF3F4F6),
      child: Center(
        child: Icon(
          Icons.local_offer_outlined,
          size: 64,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            _buildField(
              label: '브랜드 / 매장',
              controller: _storeController,
              hint: '예) 스타벅스, CU',
              icon: Icons.store_outlined,
            ),
            _buildDivider(),
            _buildField(
              label: '품목 / 내용',
              controller: _itemController,
              hint: '예) 아이스 아메리카노, 5000원권',
              icon: Icons.coffee_outlined,
            ),
            _buildDivider(),
            _buildField(
              label: '금액',
              controller: _amountController,
              hint: '숫자만 입력 (원)',
              icon: Icons.payments_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            _buildDivider(),
            _buildExpiryField(),
            _buildDivider(),
            _buildField(
              label: '메모',
              controller: _notesController,
              hint: '추가 메모 (선택)',
              icon: Icons.notes_outlined,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF4F46E5)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                _isEditing
                    ? TextField(
                        controller: controller,
                        decoration: InputDecoration(
                          hintText: hint,
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: const TextStyle(fontSize: 15),
                        keyboardType: keyboardType,
                        inputFormatters: inputFormatters,
                        maxLines: maxLines,
                      )
                    : Text(
                        controller.text.isEmpty ? '-' : controller.text,
                        style: TextStyle(
                          fontSize: 15,
                          color: controller.text.isEmpty
                              ? Colors.grey[400]
                              : const Color(0xFF111827),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiryField() {
    final dateStr = _expiryDate != null
        ? DateFormat('yyyy년 M월 d일').format(_expiryDate!)
        : '-';

    Color textColor = const Color(0xFF111827);
    if (_expiryDate != null) {
      final days = _expiryDate!.difference(DateTime.now()).inDays;
      if (days < 0) {
        textColor = const Color(0xFFEF4444);
      } else if (days <= 7) {
        textColor = const Color(0xFFF59E0B);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(
            Icons.event_outlined,
            size: 20,
            color: Color(0xFF4F46E5),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '유효기간',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateStr,
                  style: TextStyle(
                    fontSize: 15,
                    color: textColor,
                    fontWeight: _expiryDate != null &&
                            _expiryDate!.difference(DateTime.now()).inDays <= 7
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (_isEditing)
            TextButton(
              onPressed: _pickExpiryDate,
              child: Text(
                _expiryDate == null ? '날짜 선택' : '변경',
                style: const TextStyle(color: Color(0xFF4F46E5)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      indent: 48,
      endIndent: 0,
      color: Colors.grey[100],
    );
  }

  Widget _buildBarcodeCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.qr_code,
                  size: 18,
                  color: Color(0xFF4F46E5),
                ),
                const SizedBox(width: 8),
                Text(
                  '바코드 정보',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Text(
                    widget.coupon.barcodeValue,
                    style: const TextStyle(
                      fontSize: 16,
                      fontFamily: 'monospace',
                      letterSpacing: 2,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.coupon.barcodeType,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: widget.coupon.barcodeValue),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('바코드가 클립보드에 복사됐어요.')),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('복사'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final isActive = widget.coupon.status == CouponStatus.active &&
        !widget.coupon.isExpired;
    final isUsed = widget.coupon.status == CouponStatus.used;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (isActive)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _markAsUsed,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('사용 완료로 표시'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          if (isUsed) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _markAsActive,
                icon: const Icon(Icons.restore),
                label: const Text('사용 가능으로 복원'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4F46E5),
                  side: const BorderSide(color: Color(0xFF4F46E5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('쿠폰 삭제'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickExpiryDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now.add(const Duration(days: 30)),
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) {
      setState(() {
        _expiryDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59);
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);

    final updated = widget.coupon.copyWith(
      storeName: _storeController.text.trim().isEmpty
          ? null
          : _storeController.text.trim(),
      itemName: _itemController.text.trim().isEmpty
          ? null
          : _itemController.text.trim(),
      amount: _amountController.text.trim().isEmpty
          ? null
          : int.tryParse(_amountController.text.trim()),
      expiryDate: _expiryDate,
      clearExpiryDate: _expiryDate == null && widget.coupon.expiryDate != null,
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
    );

    final provider = context.read<CouponProvider>();

    if (widget.isNew) {
      await provider.addCoupon(updated);
      if (mounted) Navigator.pop(context);
    } else {
      await provider.updateCoupon(updated);
      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장됐어요.')),
        );
      }
    }
  }

  Future<void> _markAsUsed() async {
    await context.read<CouponProvider>().markAsUsed(widget.coupon);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _markAsActive() async {
    await context.read<CouponProvider>().markAsActive(widget.coupon);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('쿠폰 삭제'),
        content: const Text('이 쿠폰을 삭제할까요?\n삭제된 쿠폰은 복구할 수 없어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              '삭제',
              style: TextStyle(color: Color(0xFFEF4444)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<CouponProvider>();
      await provider.deleteCoupon(widget.coupon);
      if (mounted) Navigator.pop(context);
    }
  }
}
