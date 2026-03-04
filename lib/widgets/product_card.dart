import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class ProductCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> cartItems;
  final VoidCallback onCartChanged;

  const ProductCard({
    super.key,
    required this.item,
    required this.cartItems,
    required this.onCartChanged,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  dynamic _selectedVariantId;

  Future<void> _handleAddToCart(
    Map<String, dynamic> cartItem,
    String itemName,
    String weightLabel,
  ) async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      final shouldLogin = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? Colors.grey[900] : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              "Login Required",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              "Please log in to your account to add items to your cart.",
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.black87,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  "Cancel",
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1b5e20),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  "Log In",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      );

      if (shouldLogin == true && mounted) {
        await context.push('/login', extra: true);
        if (Supabase.instance.client.auth.currentUser != null) {
          widget.cartItems.add(cartItem);
          widget.onCartChanged();
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("$itemName ($weightLabel) added to cart!"),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
                margin: const EdgeInsets.only(bottom: 70, left: 16, right: 16),
              ),
            );
        }
      }
      return;
    }

    widget.cartItems.add(cartItem);
    widget.onCartChanged();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("$itemName ($weightLabel) added to cart!"),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 70, left: 16, right: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.item;

    final List<dynamic> rawVariants = item['product_variants'] ?? [];
    final List<Map<String, dynamic>> availableVariants = rawVariants
        .map((v) => Map<String, dynamic>.from(v))
        .where((v) => (int.tryParse(v['stock']?.toString() ?? '0') ?? 0) > 0)
        .toList();

    Map<String, dynamic> currentVariant = {};
    if (availableVariants.isNotEmpty) {
      if (_selectedVariantId != null) {
        currentVariant = availableVariants.firstWhere(
          (v) => v['id'] == _selectedVariantId,
          orElse: () => availableVariants.first,
        );
      } else {
        currentVariant = availableVariants.first;
      }
    }

    final double price =
        double.tryParse(currentVariant['price']?.toString() ?? '0') ?? 0.0;
    final double originalPrice =
        double.tryParse(currentVariant['mrp']?.toString() ?? '0') ?? 0.0;
    final String weightLabel = currentVariant['weight']?.toString() ?? "";

    final bool hasDiscount = originalPrice > price && originalPrice > 0;
    final double discountPercent = hasDiscount
        ? ((originalPrice - price) / originalPrice) * 100
        : 0.0;
    final double savings = hasDiscount ? (originalPrice - price) : 0.0;
    final bool isFeatured = item['is_featured'] == true;

    final cartItem = {
      ...item,
      'variant_id': currentVariant['id'],
      'price': price,
      'original_price': originalPrice,
      'weight': weightLabel,
    };

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1c1c1e) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. IMAGE & BADGES
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(11),
                    ),
                    child: Container(
                      color: Colors.white,
                      child:
                          item['image'] != null &&
                              item['image'].toString().isNotEmpty
                          ? Image.network(
                              item['image'],
                              fit: BoxFit.contain,
                              width: double.infinity,
                              errorBuilder: (c, e, s) =>
                                  const Icon(Icons.eco, color: Colors.green),
                            )
                          : const Icon(Icons.image, color: Colors.grey),
                    ),
                  ),
                ),
                if (isFeatured)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.amber, size: 10),
                          SizedBox(width: 4),
                          Text(
                            "BEST SELLER",
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (hasDiscount && availableVariants.isNotEmpty)
                  Positioned(
                    bottom: -10,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00a651),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "${discountPercent.toStringAsFixed(0)}% OFF",
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 2. DETAILS
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item['name']?.toString() ?? "No Name",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 10),

                // DROPDOWN
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark
                          ? Colors.grey[700]!
                          : availableVariants.isNotEmpty
                          ? const Color(0xFF00a651).withOpacity(0.5)
                          : Colors.red.shade200,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: availableVariants.isEmpty
                      ? const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Out of Stock",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        )
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<dynamic>(
                            value: currentVariant['id'],
                            isExpanded: true,
                            isDense: true,
                            dropdownColor: isDark
                                ? const Color(0xFF1c1c1e)
                                : Colors.white,
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              size: 18,
                              color: Colors.grey,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            items: availableVariants
                                .map<DropdownMenuItem<dynamic>>((v) {
                                  final int stock =
                                      int.tryParse(
                                        v['stock']?.toString() ?? '0',
                                      ) ??
                                      0;
                                  String label =
                                      v['weight']?.toString() ?? '1 pc';
                                  if (stock > 0 && stock <= 5)
                                    label += ' (Only $stock left)';
                                  return DropdownMenuItem<dynamic>(
                                    value: v['id'],
                                    child: Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                })
                                .toList(),
                            onChanged: (newVariantId) {
                              if (newVariantId != null)
                                setState(
                                  () => _selectedVariantId = newVariantId,
                                );
                            },
                          ),
                        ),
                ),
                const SizedBox(height: 12),

                // PRICE ROW & ADD
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: availableVariants.isEmpty
                          ? const Text(
                              "Rs. 0",
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "Rs. ${price.toInt()}",
                                        style: const TextStyle(
                                          color: Color(0xFF00a651),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 17,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      if (hasDiscount)
                                        // 👇 FIXED: Custom Pixel-Perfect Strikethrough
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 2.0,
                                          ), // Nudges the small text to perfectly align with the big text baseline
                                          child: Stack(
                                            alignment: Alignment.center,
                                            children: [
                                              Text(
                                                "Rs. ${originalPrice.toInt()}",
                                                style: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ), // Notice no decoration here!
                                              ),
                                              Positioned(
                                                left: 0,
                                                right: 0,
                                                child: Container(
                                                  margin: const EdgeInsets.only(
                                                    bottom: 1.5,
                                                  ), // 👇 Magically bumps the line up to exactly bisect the numbers!
                                                  height: 1.2,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (hasDiscount)
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        "Save Rs. ${savings.toInt()}",
                                        style: const TextStyle(
                                          color: Color(0xFF00a651),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(width: 4),

                    // BUTTONS
                    Builder(
                      builder: (context) {
                        if (availableVariants.isEmpty) {
                          return SizedBox(
                            height: 32,
                            child: ElevatedButton(
                              onPressed: null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? Colors.grey[900]
                                    : Colors.grey.shade200,
                                foregroundColor: Colors.grey,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                "SOLD",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }

                        int qtyInCart = widget.cartItems
                            .where(
                              (c) => c['variant_id'] == currentVariant['id'],
                            )
                            .length;
                        if (qtyInCart == 0) {
                          return SizedBox(
                            height: 32,
                            child: ElevatedButton(
                              onPressed: () => _handleAddToCart(
                                cartItem,
                                item['name']?.toString() ?? "Item",
                                weightLabel,
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDark
                                    ? Colors.white
                                    : const Color(0xFF18181b),
                                foregroundColor: isDark
                                    ? Colors.black
                                    : Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                "ADD",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        } else {
                          return Container(
                            height: 32,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF18181b),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                InkWell(
                                  onTap: () {
                                    final index = widget.cartItems.indexWhere(
                                      (c) =>
                                          c['variant_id'] ==
                                          currentVariant['id'],
                                    );
                                    if (index != -1) {
                                      widget.cartItems.removeAt(index);
                                      widget.onCartChanged();
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Center(
                                      child: Text(
                                        "-",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.black
                                              : Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    "$qtyInCart",
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.black
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _handleAddToCart(
                                    cartItem,
                                    item['name']?.toString() ?? "Item",
                                    weightLabel,
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    child: Center(
                                      child: Text(
                                        "+",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.black
                                              : Colors.white,
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
