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

  void _showStockLimitPopup(
    BuildContext context,
    int limit,
    String itemName,
    String weightLabel,
  ) {
    final String productDescription =
        "${weightLabel.isNotEmpty ? '$weightLabel ' : ''}$itemName";

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Stock Limit",
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox(),
      transitionBuilder: (context, anim1, anim2, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final curvedAnimation = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutBack,
        );

        return ScaleTransition(
          scale: Tween<double>(begin: 0.8, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity: anim1,
            child: AlertDialog(
              backgroundColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
              elevation: 0,
              content: Container(
                width: 320,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1c1c1e) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.shopping_basket_outlined,
                        color: Colors.orange,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      "High Demand! 🔥",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        children: [
                          const TextSpan(
                            text:
                                "You've added all our stock to your cart. We currently only have ",
                          ),
                          TextSpan(
                            text: "$limit $productDescription",
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const TextSpan(text: " available right now."),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF92D050),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Got it, thanks!",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleAddToCart(
    Map<String, dynamic> cartItem,
    String itemName,
    String weightLabel,
    int stockLimit,
    int currentCartQty,
  ) async {
    if (currentCartQty >= stockLimit) {
      _showStockLimitPopup(context, stockLimit, itemName, weightLabel);
      return;
    }

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
        }
      }
      return;
    }

    // Instantly add to cart without popups
    widget.cartItems.add(cartItem);
    widget.onCartChanged();
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
      currentVariant = _selectedVariantId != null
          ? availableVariants.firstWhere(
              (v) => v['id'] == _selectedVariantId,
              orElse: () => availableVariants.first,
            )
          : availableVariants.first;
    }

    final int stockLimit =
        int.tryParse(currentVariant['stock']?.toString() ?? '0') ?? 0;

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
      'stock_limit': stockLimit,
    };

    final String imageUrl = item['image']?.toString() ?? "";
    final bool hasValidImage =
        imageUrl.isNotEmpty && imageUrl.startsWith('http');

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
                      width: double.infinity,
                      height: double.infinity,
                      color: isDark ? Colors.black : const Color(0xFFF8F9FA),
                      child: hasValidImage
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Icon(
                                Icons.image,
                                color: Colors.grey[300],
                                size: 40,
                              ),
                            )
                          : Icon(
                              Icons.image,
                              color: Colors.grey[300],
                              size: 40,
                            ),
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
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF92D050),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                        ),
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
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item['name']?.toString() ?? "No Name",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark
                          ? Colors.grey[700]!
                          : (availableVariants.isNotEmpty
                                ? const Color(0xFF92D050).withOpacity(0.5)
                                : Colors.red.shade200),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: availableVariants.isEmpty
                      ? const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Out of Stock",
                            style: TextStyle(
                              fontSize: 11,
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
                              size: 16,
                              color: Colors.grey,
                            ),
                            style: TextStyle(
                              fontSize: 11,
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
                                  if (stock > 0 && stock <= 5) {
                                    label += ' (Only $stock left)';
                                  }
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
                              if (newVariantId != null) {
                                setState(
                                  () => _selectedVariantId = newVariantId,
                                );
                              }
                            },
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6.0,
                  children: [
                    Text(
                      availableVariants.isEmpty
                          ? "Rs. 0"
                          : "Rs. ${price.toInt()}",
                      style: TextStyle(
                        color: availableVariants.isEmpty
                            ? Colors.grey
                            : const Color(0xFF92D050),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                    if (hasDiscount)
                      Text(
                        "Rs. ${originalPrice.toInt()}",
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
                if (hasDiscount && savings > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: Text(
                      "Save Rs. ${savings.toInt()}",
                      style: const TextStyle(
                        color: Color(0xFF92D050),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: Builder(
                    builder: (context) {
                      if (availableVariants.isEmpty) {
                        return ElevatedButton(
                          onPressed: null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.grey[900]
                                : Colors.grey.shade200,
                            foregroundColor: Colors.grey,
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            "SOLD",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }

                      int qtyInCart = widget.cartItems
                          .where((c) => c['variant_id'] == currentVariant['id'])
                          .length;

                      if (qtyInCart == 0) {
                        return ElevatedButton(
                          onPressed: () => _handleAddToCart(
                            cartItem,
                            item['name']?.toString() ?? "Item",
                            weightLabel,
                            stockLimit,
                            qtyInCart,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.white
                                : const Color(0xFF18181b),
                            foregroundColor: isDark
                                ? Colors.black
                                : Colors.white,
                            minimumSize: const Size(0, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
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
                        );
                      } else {
                        return Container(
                          constraints: const BoxConstraints(minHeight: 32),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF18181b),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: InkWell(
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
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                      ),
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
                              ),
                              Text(
                                "$qtyInCart",
                                style: TextStyle(
                                  color: isDark ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _handleAddToCart(
                                    cartItem,
                                    item['name']?.toString() ?? "Item",
                                    weightLabel,
                                    stockLimit,
                                    qtyInCart,
                                  ),
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                      ),
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
                              ),
                            ],
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
