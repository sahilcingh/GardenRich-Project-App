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
  late Future<List<Map<String, dynamic>>> _orderItemsFuture;

  @override
  void initState() {
    super.initState();
    _orderItemsFuture = _fetchOrderItems();
  }

  Future<List<Map<String, dynamic>>> _fetchOrderItems() async {
    // This fetches the items from your 'order_items' table for this specific order.
    // If your product details (like name/image) are linked via foreign key,
    // you might need to adjust this query to join the products table!
    final response = await Supabase.instance.client
        .from('order_items')
        .select()
        .eq('order_id', widget.order['id']);

    return List<Map<String, dynamic>>.from(response);
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return "Unknown date";
    try {
      final date = DateTime.parse(isoString).toLocal();
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
      final hour = date.hour == 0
          ? 12
          : (date.hour > 12 ? date.hour - 12 : date.hour);
      final amPm = date.hour >= 12 ? 'pm' : 'am';
      final minute = date.minute.toString().padLeft(2, '0');
      return '${date.day} ${months[date.month - 1]} ${date.year}, $hour:$minute $amPm';
    } catch (e) {
      return "Recently";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final bgColor = isDark ? Colors.grey[900] : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey.shade200;

    final status = (widget.order['status'] ?? 'pending')
        .toString()
        .toLowerCase();

    // 👇 UPDATE THIS KEY if your database column is named differently!
    final totalAmount = widget.order['total'] ?? 0;

    final dateStr = _formatDate(widget.order['created_at']);
    final orderId = widget.order['id'].toString().substring(0, 8).toUpperCase();

    Color statusColor = Colors.orange[700]!;
    String statusText = "Pending";

    switch (status) {
      case 'confirmed':
        statusColor = Colors.blue[600]!;
        statusText = "Confirmed";
        break;
      case 'shipped':
        statusColor = Colors.purple[500]!;
        statusText = "Shipped";
        break;
      case 'delivered':
        statusColor = const Color(0xFF00a651);
        statusText = "Delivered";
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = "Cancelled";
        break;
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF9FAFB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          "Order #$orderId",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Order Status Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Status",
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 30),
                Text(
                  "Date",
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Total Amount",
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  "Rs. $totalAmount",
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 22,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Items List
          Text(
            "Items in this order",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 12),

          FutureBuilder<List<Map<String, dynamic>>>(
            future: _orderItemsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    "Could not load items.",
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                );
              }

              final items = snapshot.data ?? [];

              if (items.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Center(
                    child: Text(
                      "No item details found.",
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                );
              }

              return Container(
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    // Adjust keys based on your 'order_items' table schema!
                    final itemName = item['product_name'] ?? 'Product Item';
                    final qty = item['quantity'] ?? 1;
                    final price = item['price'] ?? 0;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      title: Text(
                        itemName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      subtitle: Text(
                        "Qty: $qty",
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      trailing: Text(
                        "Rs. $price",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
