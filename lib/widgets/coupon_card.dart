import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';
import '../models/coupon.dart';

class CouponCard extends StatelessWidget {
  final Coupon coupon;
  final VoidCallback onTap;
  final VoidCallback? onMarkUsed;
  final VoidCallback? onMarkActive;
  final VoidCallback onDelete;

  const CouponCard({
    super.key,
    required this.coupon,
    required this.onTap,
    this.onMarkUsed,
    this.onMarkActive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Slidable(
        key: ValueKey(coupon.id),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          children: [
            if (onMarkUsed != null)
              SlidableAction(
                onPressed: (_) => onMarkUsed!(),
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                icon: Icons.check_circle_outline,
                label: '사용 완료',
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            if (onMarkActive != null)
              SlidableAction(
                onPressed: (_) => onMarkActive!(),
                backgroundColor: const Color(0xFF4F46E5),
                foregroundColor: Colors.white,
                icon: Icons.restore,
                label: '복원',
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              icon: Icons.delete_outline,
              label: '삭제',
              borderRadius: onMarkUsed == null && onMarkActive == null
                  ? const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    )
                  : BorderRadius.zero,
            ),
          ],
        ),
        child: GestureDetector(
          onTap: onTap,
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
            child: Row(
              children: [
                _buildThumbnail(),
                Expanded(child: _buildInfo()),
                _buildStatusBadge(),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final file = File(coupon.imagePath);
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(12),
        bottomLeft: Radius.circular(12),
      ),
      child: SizedBox(
        width: 84,
        height: 84,
        child: file.existsSync()
            ? Image.file(
                file,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholderImage(),
              )
            : _placeholderImage(),
      ),
    );
  }

  Widget _placeholderImage() {
    return Container(
      color: const Color(0xFFF3F4F6),
      child: Center(
        child: Icon(
          Icons.local_offer_outlined,
          color: Colors.grey[400],
          size: 32,
        ),
      ),
    );
  }

  Widget _buildInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            coupon.displayName,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            coupon.displayDetail,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          _buildExpiryLabel(),
        ],
      ),
    );
  }

  Widget _buildExpiryLabel() {
    if (coupon.expiryDate == null) {
      return const SizedBox.shrink();
    }

    final dateStr = DateFormat('yyyy.MM.dd').format(coupon.expiryDate!);
    final days = coupon.daysUntilExpiry;

    Color color;
    String label;

    if (coupon.status == CouponStatus.used) {
      color = Colors.grey;
      label = '만료: $dateStr';
    } else if (coupon.isExpired || coupon.status == CouponStatus.expired) {
      color = const Color(0xFFEF4444);
      label = '만료됨 ($dateStr)';
    } else if (coupon.isExpiringSoon) {
      color = const Color(0xFFF59E0B);
      label = days == 0 ? '오늘 만료!' : 'D-$days ($dateStr)';
    } else {
      color = const Color(0xFF6B7280);
      label = '$dateStr 까지';
    }

    return Row(
      children: [
        Icon(Icons.schedule, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: coupon.isExpiringSoon ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    if (coupon.status == CouponStatus.used) {
      return _badge('사용 완료', Colors.grey);
    }
    if (coupon.isExpired || coupon.status == CouponStatus.expired) {
      return _badge('만료', const Color(0xFFEF4444));
    }
    if (coupon.isExpiringSoon) {
      return _badge('임박!', const Color(0xFFF59E0B));
    }
    return const SizedBox(width: 4);
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
