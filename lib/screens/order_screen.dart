import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  /// Fetches orders, items, and images lightning fast using bulk database queries (3 trips total!)
  Future<void> _fetchOrders() async {
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _orders = [];
          _isLoading = false;
        });
        return;
      }

      // TRIP 1: Fetch all orders for this user
      final ordersResponse = await Supabase.instance.client
          .from('orders')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> orders = List<Map<String, dynamic>>.from(
        ordersResponse,
      );

      if (orders.isNotEmpty) {
        // Extract all the order IDs into a list
        final orderIds = orders.map((o) => o['id']).toList();

        // TRIP 2: Fetch ALL items for ALL orders in ONE single query!
        final itemsResponse = await Supabase.instance.client
            .from('order_items')
            .select()
            .inFilter(
              'order_id',
              orderIds,
            ); // Gets items matching any ID in our list

        final List<Map<String, dynamic>> allItems =
            List<Map<String, dynamic>>.from(itemsResponse);

        // Extract all unique product names from the items
        final productNames = allItems
            .map((i) => (i['product_name'] ?? i['name'])?.toString())
            .where((n) => n != null)
            .toSet()
            .toList();

        // TRIP 3: Fetch ALL images for those products in ONE single query!
        Map<String, dynamic> imageMap = {};
        if (productNames.isNotEmpty) {
          final productsResponse = await Supabase.instance.client
              .from('products')
              .select('name, image')
              .inFilter('name', productNames);

          // Build a super-fast lookup dictionary in memory (e.g., {"Milk": "http...", "Apple": "http..."})
          for (var p in productsResponse) {
            if (p['name'] != null && p['image'] != null) {
              imageMap[p['name'].toString()] = p['image'];
            }
          }
        }

        // MAGIC: Stitch everything together instantly in the phone's memory
        for (var order in orders) {
          final orderId = order['id'].toString();

          // 1. Find the items belonging to this specific order
          final itemsForThisOrder = allItems
              .where((item) => item['order_id'].toString() == orderId)
              .toList();

          // 2. Attach the images to those items using our super-fast lookup dictionary
          for (var item in itemsForThisOrder) {
            final pName = (item['product_name'] ?? item['name'])?.toString();
            if (pName != null && imageMap.containsKey(pName)) {
              item['image'] = imageMap[pName];
            }
          }

          // 3. Save the items back into the order map
          order['order_items'] = itemsForThisOrder;
        }
      }

      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching orders: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return "Unknown date";
    try {
      String safeDate = isoString;
      if (!safeDate.endsWith('Z')) safeDate += 'Z';
      final date = DateTime.parse(safeDate).toLocal();
      const months = [
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
    } catch (_) {
      return "Recently";
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final bgColor = isDark ? Colors.grey[900] : Colors.white;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey.shade200;
    final mutedColor = isDark ? Colors.grey[400] : Colors.grey[600];

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          "Back to Shop",
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: false,
        titleSpacing: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF92D050)),
            )
          : RefreshIndicator(
              onRefresh: _fetchOrders,
              color: const Color(0xFF92D050),
              backgroundColor: isDark ? Colors.grey[800] : Colors.white,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                children: [
                  Text(
                    "My Orders",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${_orders.length} order${_orders.length == 1 ? '' : 's'} placed",
                    style: TextStyle(color: mutedColor, fontSize: 14),
                  ),
                  const SizedBox(height: 24),

                  if (_orders.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40.0),
                        child: Text(
                          "You haven't placed any orders yet.",
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                    ),

                  ..._orders.map((order) {
                    final status = (order['status'] ?? 'pending')
                        .toString()
                        .toLowerCase();
                    final totalAmount = order['total'] ?? 0;
                    final dateStr = _formatDate(order['created_at']);
                    final List<Map<String, dynamic>> items =
                        List<Map<String, dynamic>>.from(
                          order['order_items'] ?? [],
                        );

                    // Status styling
                    Color statusColor;
                    IconData statusIcon;
                    String statusText;

                    switch (status) {
                      case 'confirmed':
                        statusColor = Colors.blue[600]!;
                        statusIcon = Icons.verified_outlined;
                        statusText = "Confirmed";
                        break;
                      case 'shipped':
                        statusColor = Colors.purple[500]!;
                        statusIcon = Icons.local_shipping_outlined;
                        statusText = "Shipped";
                        break;
                      case 'delivered':
                        statusColor = const Color(0xFF00a651);
                        statusIcon = Icons.check_circle;
                        statusText = "Delivered";
                        break;
                      case 'cancelled':
                        statusColor = Colors.red;
                        statusIcon = Icons.cancel_outlined;
                        statusText = "Cancelled";
                        break;
                      case 'pending':
                      default:
                        statusColor = Colors.orange[700]!;
                        statusIcon = Icons.access_time;
                        statusText = "Pending";
                        break;
                    }

                    // Show up to 4 item images, then a "+N more" tile
                    final visibleItems = items.take(4).toList();
                    final extraCount = items.length - visibleItems.length;

                    return InkWell(
                      onTap: () => context.push('/order-details', extra: order),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            if (!isDark)
                              BoxShadow(
                                color: Colors.black.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Top row: status · date · total → ──
                            Row(
                              children: [
                                Icon(statusIcon, size: 14, color: statusColor),
                                const SizedBox(width: 6),
                                Text(
                                  statusText,
                                  style: TextStyle(
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  "·",
                                  style: TextStyle(color: Colors.grey[300]),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    dateStr,
                                    style: TextStyle(
                                      color: mutedColor,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  "Rs. $totalAmount",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.arrow_forward_ios,
                                  size: 13,
                                  color: Colors.grey[400],
                                ),
                              ],
                            ),

                            // ── Product image thumbnails ──
                            if (items.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  ...visibleItems.map((item) {
                                    final imageUrl =
                                        item['image']?.toString() ?? '';
                                    return Container(
                                      width: 56,
                                      height: 56,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.grey.shade200,
                                        ),
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child: imageUrl.isNotEmpty
                                          ? Image.network(
                                              imageUrl,
                                              fit: BoxFit.contain,
                                              errorBuilder: (c, e, s) => Icon(
                                                Icons
                                                    .image_not_supported_outlined,
                                                size: 20,
                                                color: Colors.grey.shade300,
                                              ),
                                            )
                                          : Icon(
                                              Icons.image_outlined,
                                              size: 20,
                                              color: Colors.grey.shade300,
                                            ),
                                    );
                                  }),

                                  // "+N more" tile
                                  if (extraCount > 0)
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.grey[800]
                                            : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: borderColor),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            "+$extraCount",
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                              color: textColor,
                                            ),
                                          ),
                                          Text(
                                            "more",
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: mutedColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }
}
