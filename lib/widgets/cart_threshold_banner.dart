import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CartThresholdBanner extends StatefulWidget {
  final double cartTotal;
  final VoidCallback onViewCart;

  const CartThresholdBanner({
    super.key,
    required this.cartTotal,
    required this.onViewCart,
  });

  @override
  State<CartThresholdBanner> createState() => _CartThresholdBannerState();
}

class _CartThresholdBannerState extends State<CartThresholdBanner> {
  double _minOrderValue = 0.0;
  double _freeShippingThreshold = 500.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStoreSettings();
  }

  Future<void> _fetchStoreSettings() async {
    try {
      final response = await Supabase.instance.client
          .from('settings')
          .select('key, value');

      if (response.isNotEmpty && mounted) {
        double minOrder = 0.0;
        double freeShipping = 500.0;

        for (var row in response) {
          final key = row['key']?.toString();
          final val = row['value']?.toString() ?? '0';

          if (key == 'minimum_order_value') {
            minOrder = double.tryParse(val) ?? 0.0;
          } else if (key == 'free_shipping_above') {
            freeShipping = double.tryParse(val) ?? 500.0;
          }
        }

        setState(() {
          _minOrderValue = minOrder;
          _freeShippingThreshold = freeShipping;
        });
      }
    } catch (e) {
      debugPrint("Error fetching settings for banner: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // If cart is empty, or settings are loading, hide the banner completely
    if (widget.cartTotal == 0 || _isLoading) return const SizedBox.shrink();

    String message = "";
    Color bannerColor = Colors.grey;
    IconData icon = Icons.shopping_basket;

    // SCENARIO 1: Below Minimum Order Value
    if (widget.cartTotal < _minOrderValue) {
      final difference = _minOrderValue - widget.cartTotal;
      message = "Add Rs. ${difference.toInt()} more to place order";
      bannerColor = Colors.orange.shade700;
      icon = Icons.lock_outline;
    }
    // SCENARIO 2: Can Order, but below Free Shipping
    else if (widget.cartTotal >= _minOrderValue &&
        widget.cartTotal < _freeShippingThreshold) {
      final difference = _freeShippingThreshold - widget.cartTotal;
      message =
          "Order unlocked! Add Rs. ${difference.toInt()} for Free Shipping";
      bannerColor = Colors.blue.shade600;
      icon = Icons.local_shipping_outlined;
    }
    // SCENARIO 3: Free Shipping Unlocked!
    else {
      message = "🎉 Free Shipping Unlocked!";
      bannerColor = const Color(0xFF16a34a); // GardenRich Green
      icon = Icons.celebration;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: bannerColor.withOpacity(0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          InkWell(
            onTap: widget.onViewCart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                "View Cart",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
