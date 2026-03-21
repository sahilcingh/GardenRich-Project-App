import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  List<Map<String, dynamic>> _cartItems = [];
  bool _isInitialized = false;

  // 👇 NEW: We start by assuming settings are loading to prevent "ninja clicks"
  bool _isLoadingSettings = true;

  // Store Settings (Dynamically fetched!)
  double _freeShippingThreshold = 500.0;
  double _minOrderValue = 0.0;
  double _shippingCharge = 40.0;

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
        double shipping = 40.0;

        for (var row in response) {
          final key = row['key']?.toString();
          final val = row['value']?.toString() ?? '0';

          if (key == 'minimum_order_value') {
            minOrder = double.tryParse(val) ?? 0.0;
          } else if (key == 'free_shipping_above') {
            freeShipping = double.tryParse(val) ?? 500.0;
          } else if (key == 'shipping_cost') {
            shipping = double.tryParse(val) ?? 40.0;
          }
        }

        setState(() {
          _minOrderValue = minOrder;
          _freeShippingThreshold = freeShipping;
          _shippingCharge = shipping;
        });
      }
    } catch (e) {
      debugPrint("❌ DB error fetching store settings: $e");
    } finally {
      // 👇 NEW: Once the database replies (success or fail), we unlock the UI!
      if (mounted) {
        setState(() => _isLoadingSettings = false);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final rawItems =
          GoRouterState.of(context).extra as List<Map<String, dynamic>>? ?? [];
      Map<String, Map<String, dynamic>> grouped = {};
      for (var item in rawItems) {
        String id = item['variant_id'].toString();
        if (grouped.containsKey(id)) {
          grouped[id]!['qty'] = (grouped[id]!['qty'] as int) + 1;
        } else {
          grouped[id] = Map<String, dynamic>.from(item);
          grouped[id]!['qty'] = 1;
        }
      }
      _cartItems = grouped.values.toList();
      _isInitialized = true;
    }
  }

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
                          backgroundColor: const Color(0xFF16a34a),
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

  List<Map<String, dynamic>> _flattenCart() {
    List<Map<String, dynamic>> flatList = [];
    for (var item in _cartItems) {
      int qty = item['qty'] as int? ?? 1;
      for (int i = 0; i < qty; i++) {
        var flatItem = Map<String, dynamic>.from(item);
        flatItem.remove('qty');
        flatList.add(flatItem);
      }
    }
    return flatList;
  }

  double get _subtotalAmount {
    double total = 0;
    for (var item in _cartItems) {
      total +=
          ((item['price'] as num?)?.toDouble() ?? 0) * (item['qty'] as int);
    }
    return total;
  }

  double get _shippingFee =>
      _subtotalAmount >= _freeShippingThreshold ? 0.0 : _shippingCharge;

  double get _totalAmount {
    if (_cartItems.isEmpty) return 0.0;
    return _subtotalAmount + _shippingFee;
  }

  int get _totalItems {
    int total = 0;
    for (var item in _cartItems) {
      total += item['qty'] as int;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    const greenColor = Color(0xFF16a34a);

    double progress = (_subtotalAmount / _freeShippingThreshold).clamp(
      0.0,
      1.0,
    );
    double remaining = _freeShippingThreshold - _subtotalAmount;

    // 👇 NEW: We calculate if it's below min order, and create a master "locked" status
    final bool isBelowMinOrder = _subtotalAmount < _minOrderValue;
    final bool isButtonLocked = _isLoadingSettings || isBelowMinOrder;

    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        context.pop(_flattenCart());
        return false;
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          elevation: 0,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: greenColor),
            onPressed: () => context.pop(_flattenCart()),
          ),
          title: GestureDetector(
            onTap: () => context.pop(_flattenCart()),
            child: const Text(
              "Continue Shopping",
              style: TextStyle(
                color: greenColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        body: _cartItems.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 80,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Your cart is empty",
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: textColor,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                            ),
                            children: [
                              const TextSpan(text: "Your Cart "),
                              TextSpan(
                                text: "($_totalItems items)",
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 16,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey[800]!
                                  : Colors.grey.shade200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        children: remaining > 0
                                            ? [
                                                const TextSpan(text: "Add "),
                                                TextSpan(
                                                  text:
                                                      "Rs. ${remaining.toInt()}",
                                                  style: const TextStyle(
                                                    color: greenColor,
                                                  ),
                                                ),
                                                const TextSpan(
                                                  text:
                                                      " more for FREE shipping!",
                                                ),
                                              ]
                                            : [
                                                const TextSpan(
                                                  text:
                                                      "You've unlocked FREE shipping!",
                                                  style: TextStyle(
                                                    color: greenColor,
                                                  ),
                                                ),
                                              ],
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "Rs. ${_subtotalAmount.toInt()} / ${_freeShippingThreshold.toInt()}",
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 8,
                                  backgroundColor: isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[200],
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        greenColor,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        ..._cartItems.map((item) {
                          int index = _cartItems.indexOf(item);
                          final itemPrice =
                              (item['price'] as num?)?.toInt() ?? 0;
                          final originalPrice =
                              (item['original_price'] as num?)?.toInt() ??
                              itemPrice;
                          final bool hasDiscount =
                              originalPrice > itemPrice && originalPrice > 0;
                          final int discountPercent = hasDiscount
                              ? (((originalPrice - itemPrice) / originalPrice) *
                                        100)
                                    .round()
                              : 0;

                          int stockLimit = 999;
                          if (item['stock_limit'] != null) {
                            stockLimit = item['stock_limit'] as int;
                          } else if (item['product_variants'] != null) {
                            try {
                              final variant = (item['product_variants'] as List)
                                  .firstWhere(
                                    (v) => v['id'] == item['variant_id'],
                                  );
                              stockLimit =
                                  int.tryParse(
                                    variant['stock']?.toString() ?? '0',
                                  ) ??
                                  999;
                            } catch (e) {}
                          }

                          final String imageUrl =
                              item['image']?.toString() ?? "";
                          final bool hasValidImage =
                              imageUrl.isNotEmpty &&
                              imageUrl.startsWith('http');

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? Colors.grey[800]!
                                    : Colors.grey.shade200,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: 70,
                                    height: 70,
                                    color: isDark
                                        ? Colors.black
                                        : Colors.grey[100],
                                    child: hasValidImage
                                        ? Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (c, e, s) => Icon(
                                              Icons.image_not_supported,
                                              color: Colors.grey[400],
                                            ),
                                          )
                                        : Icon(
                                            Icons.image,
                                            color: Colors.grey[400],
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['name'] ?? "Unknown",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: textColor,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item['weight']?.toString() ?? "",
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          Text(
                                            "Rs. $itemPrice",
                                            style: const TextStyle(
                                              color: greenColor,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          if (hasDiscount) ...[
                                            Text(
                                              "Rs. $originalPrice",
                                              style: const TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                                decoration:
                                                    TextDecoration.lineThrough,
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: greenColor.withOpacity(
                                                  0.1,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                "$discountPercent% OFF",
                                                style: const TextStyle(
                                                  color: greenColor,
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (stockLimit <= 5)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 4.0,
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.warning_amber_rounded,
                                                color: Colors.orange,
                                                size: 12,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                "Only $stockLimit left!",
                                                style: const TextStyle(
                                                  color: Colors.orange,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "SUBTOTAL",
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Rs. ${itemPrice * (item['qty'] as int)}",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14,
                                        color: textColor,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey[800]
                                            : const Color(0xFF18181B),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              setState(() {
                                                if (item['qty'] > 1) {
                                                  item['qty']--;
                                                } else {
                                                  _cartItems.removeAt(index);
                                                }
                                              });
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              child: Text(
                                                "-",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Text(
                                            "${item['qty']}",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              if (item['qty'] >= stockLimit) {
                                                _showStockLimitPopup(
                                                  context,
                                                  stockLimit,
                                                  item['name']?.toString() ??
                                                      "This item",
                                                  item['weight']?.toString() ??
                                                      "",
                                                );
                                                return;
                                              }
                                              setState(() => item['qty']++);
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 6,
                                              ),
                                              child: Text(
                                                "+",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: 24),

                        Text(
                          "PROMO CODE",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: "ENTER CODE",
                                    hintStyle: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[400],
                                      fontWeight: FontWeight.normal,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 36,
                                child: ElevatedButton(
                                  onPressed: () {},
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isDark
                                        ? Colors.grey[700]
                                        : Colors.black,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                  ),
                                  child: const Text(
                                    "Apply",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.grey[800]!
                                  : Colors.grey.shade200,
                            ),
                            boxShadow: [
                              if (!isDark)
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Order Summary",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(height: 20),

                              ..._cartItems.map((item) {
                                final itemPrice =
                                    (item['price'] as num?)?.toInt() ?? 0;
                                final qty = item['qty'] as int;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 13,
                                            ),
                                            children: [
                                              TextSpan(
                                                text: "${item['name']} ",
                                              ),
                                              TextSpan(
                                                text: "(${item['weight']}) ",
                                                style: TextStyle(
                                                  color: Colors.grey[400],
                                                  fontSize: 11,
                                                ),
                                              ),
                                              TextSpan(
                                                text: "×$qty",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Rs. ${itemPrice * qty}",
                                        style: TextStyle(
                                          color: textColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                child: Divider(
                                  color: isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[200],
                                ),
                              ),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Subtotal",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    "Rs. ${_subtotalAmount.toInt()}",
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Shipping",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    _shippingFee == 0
                                        ? "FREE"
                                        : "Rs. ${_shippingFee.toInt()}",
                                    style: TextStyle(
                                      color: _shippingFee == 0
                                          ? greenColor
                                          : textColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Taxes",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    "Included",
                                    style: TextStyle(
                                      color: Colors.grey[500],
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),

                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                child: Divider(
                                  color: isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[200],
                                ),
                              ),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    "Total Amount",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: textColor,
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "Rs. ${_totalAmount.toInt()}",
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w900,
                                          color: textColor,
                                        ),
                                      ),
                                      Text(
                                        "Inclusive of all taxes",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[500],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 16,
                          runSpacing: 12,
                          children: [
                            _buildTrustBadge(
                              Icons.verified_user_outlined,
                              "Secure",
                              greenColor,
                            ),
                            _buildTrustBadge(
                              Icons.local_shipping_outlined,
                              "Fast Delivery",
                              greenColor,
                            ),
                            _buildTrustBadge(
                              Icons.currency_rupee_outlined,
                              "COD",
                              greenColor,
                            ),
                          ],
                        ),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ],
              ),
        bottomSheet: _cartItems.isEmpty
            ? null
            : Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: bgColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -5),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 👇 NEW: Hides the text completely while loading so it doesn't flash falsely
                      if (!_isLoadingSettings &&
                          isBelowMinOrder &&
                          _minOrderValue > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Text(
                            "Add Rs. ${(_minOrderValue - _subtotalAmount).toInt()} more to proceed to checkout",
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          // 👇 NEW: Locked immediately if it's loading OR below minimum
                          onPressed: isButtonLocked
                              ? null
                              : () async {
                                  final success = await context.push(
                                    '/place-order',
                                    extra: {
                                      'items': _cartItems,
                                      'total': _totalAmount,
                                    },
                                  );
                                  if (success == true && context.mounted) {
                                    context.pop(true);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isButtonLocked
                                ? (isDark ? Colors.grey[800] : Colors.grey[300])
                                : greenColor,
                            foregroundColor: isButtonLocked
                                ? (isDark ? Colors.grey[500] : Colors.grey[500])
                                : Colors.white,
                            elevation: isButtonLocked ? 0 : 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          // 👇 NEW: Shows a subtle loading spinner instead of text while it checks the rules
                          child: _isLoadingSettings
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.grey,
                                  ),
                                )
                              : const Text(
                                  "PROCEED TO CHECKOUT",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    letterSpacing: 0.5,
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
  }

  Widget _buildTrustBadge(IconData icon, String label, Color iconColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
