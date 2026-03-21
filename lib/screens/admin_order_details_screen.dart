import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminOrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;

  const AdminOrderDetailsScreen({super.key, required this.order});

  @override
  State<AdminOrderDetailsScreen> createState() =>
      _AdminOrderDetailsScreenState();
}

class _AdminOrderDetailsScreenState extends State<AdminOrderDetailsScreen> {
  List<Map<String, dynamic>> _orderItems = [];
  bool _isLoading = true;
  late String _currentStatus;

  final List<String> _statusOptions = [
    'pending',
    'confirmed',
    'shipped',
    'delivered',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _currentStatus = (widget.order['status'] ?? 'pending')
        .toString()
        .toLowerCase();
    if (!_statusOptions.contains(_currentStatus)) {
      _currentStatus = 'pending';
    }
    _fetchOrderItems();
  }

  Future<void> _fetchOrderItems() async {
    try {
      final orderId = widget.order['id'].toString();

      // 1. Fetch items directly from order_items
      final itemsRes = await Supabase.instance.client
          .from('order_items')
          .select()
          .eq('order_id', orderId);

      List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(
        itemsRes,
      );

      // 2. Extract product names to fetch their images
      final productNames = items
          .map((i) => (i['product_name'] ?? i['name'])?.toString())
          .where((n) => n != null)
          .toSet()
          .toList();

      // 3. Fetch Product Images
      if (productNames.isNotEmpty) {
        final productsRes = await Supabase.instance.client
            .from('products')
            .select('name, image')
            .inFilter('name', productNames);

        Map<String, dynamic> imageMap = {};
        for (var p in productsRes) {
          if (p['name'] != null && p['image'] != null) {
            imageMap[p['name'].toString()] = p['image'];
          }
        }

        for (var item in items) {
          final pName = (item['product_name'] ?? item['name'])?.toString();
          if (pName != null && imageMap.containsKey(pName)) {
            item['image'] = imageMap[pName];
          }
        }
      }

      // We completely removed the `product_variants` database query here
      // because we are now pulling the `variant_weight` straight from `order_items`!

      if (mounted) {
        setState(() {
          _orderItems = items;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching items: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    try {
      await Supabase.instance.client
          .from('orders')
          .update({'status': newStatus})
          .eq('id', widget.order['id']);

      setState(() => _currentStatus = newStatus);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Order marked as ${newStatus.toUpperCase()}"),
            backgroundColor: const Color(0xFF16a34a),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error updating status: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'confirmed':
        return Colors.blue[600]!;
      case 'shipped':
        return Colors.purple[500]!;
      case 'delivered':
        return const Color(0xFF00a651);
      case 'cancelled':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange[700]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F4F5);
    final cardColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey.shade200;

    final order = widget.order;
    final total =
        double.tryParse(order['total']?.toString() ?? '0')?.toInt() ?? 0;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        title: Text(
          "Order Details",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF16a34a)),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. STATUS UPDATER CARD
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Order Status:",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            _currentStatus,
                          ).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _getStatusColor(_currentStatus),
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _currentStatus,
                            dropdownColor: cardColor,
                            icon: Icon(
                              Icons.arrow_drop_down,
                              color: _getStatusColor(_currentStatus),
                            ),
                            items: _statusOptions.map((String status) {
                              return DropdownMenuItem<String>(
                                value: status,
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: _getStatusColor(status),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (newVal) {
                              if (newVal != null && newVal != _currentStatus) {
                                _updateOrderStatus(newVal);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 2. CUSTOMER DETAILS CARD
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "CUSTOMER INFO",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey[500],
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoRow(
                        Icons.email_outlined,
                        order['email'] ?? "No Email",
                        textColor,
                        mutedColor,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.phone_outlined,
                        order['phone'] ?? "No Phone",
                        textColor,
                        mutedColor,
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        Icons.location_on_outlined,
                        order['address'] ?? "No Address Provided",
                        textColor,
                        mutedColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // 3. ORDER ITEMS (PACKING LIST)
                Text(
                  "PACKING LIST",
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey[500],
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 8),
                ..._orderItems.map((item) {
                  final qty = item['qty'] ?? 1;
                  final price =
                      double.tryParse(
                        item['price']?.toString() ?? '0',
                      )?.toInt() ??
                      0;
                  final imageUrl = item['image']?.toString() ?? '';
                  final hasImage =
                      imageUrl.isNotEmpty && imageUrl.startsWith('http');

                  // 👇 Automatically grabs the variant_weight directly from order_items
                  final weightStr = item['variant_weight']?.toString() ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(12),
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
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 60,
                            height: 60,
                            color: isDark ? Colors.grey[800] : Colors.grey[100],
                            child: hasImage
                                ? Image.network(imageUrl, fit: BoxFit.cover)
                                : Icon(Icons.image, color: Colors.grey[400]),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['product_name'] ??
                                    item['name'] ??
                                    'Unknown Item',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (weightStr.isNotEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey[800]
                                            : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        weightStr,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.grey[300]
                                              : Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      "×$qty",
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    "@ Rs. $price",
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Rs. ${price * qty}",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: textColor,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 16),

                // 4. TOTAL
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16a34a).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF16a34a).withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total Amount Paid",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        "Rs. $total",
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF16a34a),
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String text,
    Color textColor,
    Color? mutedColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: mutedColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: textColor, fontSize: 14)),
        ),
      ],
    );
  }
}
