import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class OrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const OrderDetailsScreen({super.key, required this.order});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  List<Map<String, dynamic>> _orderItems = [];
  Map<String, dynamic>? _addressData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrderDetails();
  }

  Future<void> _fetchOrderDetails() async {
    try {
      final String orderId = widget.order['id'].toString().trim();

      // 1. Fetch the Order Items
      final itemsResponse = await Supabase.instance.client
          .from('order_items')
          .select()
          .eq('order_id', orderId);

      debugPrint("🔍 Order ID queried: $orderId");
      debugPrint("🔍 Items response: $itemsResponse");
      List<Map<String, dynamic>> itemsList = List<Map<String, dynamic>>.from(
        itemsResponse,
      );

      // 2. Fetch the images for these items using the Product NAME (Your bulletproof method)
      for (var i = 0; i < itemsList.length; i++) {
        try {
          final productName =
              itemsList[i]['product_name'] ?? itemsList[i]['name'];
          if (productName != null) {
            final productData = await Supabase.instance.client
                .from('products')
                .select('image')
                .eq('name', productName)
                .maybeSingle();

            if (productData != null && productData['image'] != null) {
              itemsList[i]['image'] = productData['image'];
            }
          }
        } catch (e) {
          debugPrint("Could not fetch image for product: $e");
        }
      }

      // 3. Fetch the full Shipping Address using the address_id
      final addressId = widget.order['address_id'];
      if (addressId != null) {
        try {
          final addressResponse = await Supabase.instance.client
              .from('addresses')
              .select()
              .eq('id', addressId)
              .maybeSingle(); // Made safe so it doesn't crash if address is deleted
          _addressData = addressResponse;
        } catch (e) {
          debugPrint("Could not fetch address details: $e");
        }
      }

      if (mounted) {
        setState(() {
          _orderItems = itemsList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching order details: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper to determine the active step in the tracker
  int _getStatusIndex(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 0;
      case 'confirmed':
        return 1;
      case 'shipped':
        return 2;
      case 'delivered':
        return 3;
      default:
        return 0;
    }
  }

  // Format date helper
  String _formatDate(String? isoDate) {
    if (isoDate == null) return "Unknown Date";
    try {
      final date = DateTime.parse(isoDate).toLocal();
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final month = months[date.month - 1];
      final hour = date.hour > 12
          ? date.hour - 12
          : (date.hour == 0 ? 12 : date.hour);
      final amPm = date.hour >= 12 ? 'pm' : 'am';
      final minute = date.minute.toString().padLeft(2, '0');
      return "${date.day.toString().padLeft(2, '0')} $month ${date.year} at $hour:$minute $amPm";
    } catch (e) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey.shade200;
    final greenColor = const Color(0xFF00C853);

    final String status =
        widget.order['status']?.toString().toUpperCase() ?? 'PENDING';
    final int currentStep = _getStatusIndex(status);

    final totalRaw = widget.order['total'] ?? widget.order['total_amount'] ?? 0;
    final double totalAmount = double.tryParse(totalRaw.toString()) ?? 0.0;

    // Added safety null-checks here so it never crashes on missing address data
    final String address = _addressData != null
        ? "${_addressData!['address'] ?? ''}, ${_addressData!['city'] ?? ''}, ${_addressData!['pin_code'] ?? ''}"
        : "Loading address...";

    final String firstName = _addressData?['first_name'] ?? '';
    final String lastName = _addressData?['last_name'] == 'EMPTY'
        ? ''
        : (_addressData?['last_name'] ?? '');
    final String userName = _addressData != null
        ? "$firstName $lastName".trim()
        : "Customer";

    final String mobile = widget.order['phone']?.toString() ?? "";

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          "Order #${widget.order['id'].toString().substring(0, 8).toUpperCase()}",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00C853)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. TRACKER CARD
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                      boxShadow: [
                        if (!isDark)
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: greenColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: greenColor,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            Text(
                              _formatDate(widget.order['created_at']),
                              style: TextStyle(
                                color: mutedColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),
                        Row(
                          children: [
                            _buildStepNode(
                              "PENDING",
                              0,
                              currentStep,
                              greenColor,
                              isDark,
                            ),
                            _buildStepLine(0, currentStep, greenColor, isDark),
                            _buildStepNode(
                              "CONFIRMED",
                              1,
                              currentStep,
                              greenColor,
                              isDark,
                            ),
                            _buildStepLine(1, currentStep, greenColor, isDark),
                            _buildStepNode(
                              "SHIPPED",
                              2,
                              currentStep,
                              greenColor,
                              isDark,
                            ),
                            _buildStepLine(2, currentStep, greenColor, isDark),
                            _buildStepNode(
                              "DELIVERED",
                              3,
                              currentStep,
                              greenColor,
                              isDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 2. ITEMS ORDERED CARD
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "ITEMS ORDERED",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: mutedColor,
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (_orderItems.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            child: Text(
                              "No items found for this order.",
                              style: TextStyle(color: mutedColor),
                            ),
                          )
                        else
                          ..._orderItems.map((itemMap) {
                            final qty =
                                itemMap['quantity'] ?? itemMap['qty'] ?? 1;
                            final price =
                                double.tryParse(
                                  itemMap['price']?.toString() ?? '0',
                                ) ??
                                0;
                            final totalItemPrice = price * qty;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Image Box
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child:
                                        itemMap['image'] != null &&
                                            itemMap['image']
                                                .toString()
                                                .isNotEmpty
                                        ? Image.network(
                                            itemMap['image'],
                                            fit: BoxFit.contain,
                                            errorBuilder: (c, e, s) => Icon(
                                              Icons.image,
                                              color: Colors.grey.shade300,
                                            ),
                                          )
                                        : Icon(
                                            Icons.image,
                                            color: Colors.grey.shade300,
                                          ),
                                  ),
                                  const SizedBox(width: 16),

                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          itemMap['product_name'] ??
                                              itemMap['name'] ??
                                              'Product',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "Qty: $qty",
                                          style: TextStyle(
                                            color: mutedColor,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Price
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "Rs. ${totalItemPrice.toInt()}",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          color: textColor,
                                        ),
                                      ),
                                      if (qty > 1)
                                        Text(
                                          "Rs. ${price.toInt()} each",
                                          style: TextStyle(
                                            color: mutedColor,
                                            fontSize: 10,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),

                        Divider(color: borderColor, height: 24),

                        // Total Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Total",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                color: textColor,
                              ),
                            ),
                            Text(
                              "Rs. ${totalAmount.toInt()}",
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                                color: greenColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 3. ADDRESS CARD
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "DELIVERING TO",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: mutedColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          userName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          address,
                          style: TextStyle(
                            color: mutedColor,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        if (mobile.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            mobile,
                            style: TextStyle(color: mutedColor, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 4. PAYMENT CARD
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "PAYMENT",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.0,
                            color: mutedColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Cash On Delivery",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: textColor,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                "COD",
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildStepNode(
    String title,
    int stepIndex,
    int currentIndex,
    Color activeColor,
    bool isDark,
  ) {
    final bool isCompleted = stepIndex <= currentIndex;
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCompleted ? activeColor : Colors.transparent,
            border: Border.all(
              color: isCompleted
                  ? activeColor
                  : (isDark ? Colors.grey[700]! : Colors.grey.shade300),
              width: 2,
            ),
          ),
          child: isCompleted
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
            color: isCompleted
                ? activeColor
                : (isDark ? Colors.grey[600] : Colors.grey.shade400),
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(
    int stepIndex,
    int currentIndex,
    Color activeColor,
    bool isDark,
  ) {
    final bool isLineActive = stepIndex < currentIndex;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        height: 2,
        color: isLineActive
            ? activeColor
            : (isDark ? Colors.grey[800] : Colors.grey.shade200),
      ),
    );
  }
}
