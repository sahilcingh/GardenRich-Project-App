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
  String? _dbError;

  // Pagination State
  int _currentPage = 0;
  final int _pageSize = 10;
  bool _hasMore = true;
  bool _isFetchingMore = false;
  int _totalOrderCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _currentPage = 0;
      _hasMore = true;
      _dbError = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _orders = [];
          _isLoading = false;
        });
        return;
      }

      final countResponse = await Supabase.instance.client
          .from('orders')
          .select('id')
          .eq('user_id', user.id);

      _totalOrderCount = List.from(countResponse).length;

      final ordersResponse = await Supabase.instance.client
          .from('orders')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .range(0, _pageSize - 1);

      final List<Map<String, dynamic>> orders = List<Map<String, dynamic>>.from(
        ordersResponse,
      );

      if (orders.length < _pageSize) _hasMore = false;

      if (orders.isNotEmpty) {
        await _attachItemsToOrders(orders);
      }

      if (mounted) {
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching initial orders: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _dbError = "Orders Table Error: $e";
        });
      }
    }
  }

  Future<void> _fetchMoreOrders() async {
    if (_isFetchingMore || !_hasMore) return;

    setState(() => _isFetchingMore = true);

    _currentPage++;
    final start = _currentPage * _pageSize;
    final end = start + _pageSize - 1;

    try {
      final user = Supabase.instance.client.auth.currentUser;
      final ordersResponse = await Supabase.instance.client
          .from('orders')
          .select()
          .eq('user_id', user!.id)
          .order('created_at', ascending: false)
          .range(start, end);

      final List<Map<String, dynamic>> newOrders =
          List<Map<String, dynamic>>.from(ordersResponse);

      if (newOrders.length < _pageSize) {
        _hasMore = false;
      }

      if (newOrders.isNotEmpty) {
        await _attachItemsToOrders(newOrders);
      }

      if (mounted) {
        setState(() {
          _orders.addAll(newOrders);
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching more orders: $e");
      if (mounted) {
        setState(() {
          _isFetchingMore = false;
          _hasMore = false;
          _dbError = "Pagination Error: $e";
        });
      }
    }
  }

  Future<void> _attachItemsToOrders(
    List<Map<String, dynamic>> targetOrders,
  ) async {
    if (targetOrders.isEmpty) return;

    try {
      final orderIds = targetOrders.map((o) => o['id']).toList();

      final itemsResponse = await Supabase.instance.client
          .from('order_items')
          .select()
          .inFilter('order_id', orderIds);

      final List<Map<String, dynamic>> allItems =
          List<Map<String, dynamic>>.from(itemsResponse);

      final productNames = allItems
          .map((i) => (i['product_name'] ?? i['name'])?.toString())
          .where((n) => n != null)
          .toSet()
          .toList();

      Map<String, dynamic> imageMap = {};
      if (productNames.isNotEmpty) {
        final productsResponse = await Supabase.instance.client
            .from('products')
            .select('name, image')
            .inFilter('name', productNames);

        for (var p in productsResponse) {
          if (p['name'] != null && p['image'] != null) {
            imageMap[p['name'].toString()] = p['image'];
          }
        }
      }

      for (var order in targetOrders) {
        final orderId = order['id'].toString();
        final itemsForThisOrder = allItems
            .where((item) => item['order_id'].toString() == orderId)
            .toList();
        for (var item in itemsForThisOrder) {
          final pName = (item['product_name'] ?? item['name'])?.toString();
          if (pName != null && imageMap.containsKey(pName)) {
            item['image'] = imageMap[pName];
          }
        }
        order['order_items'] = itemsForThisOrder;
      }
    } catch (e) {
      debugPrint("Error attaching items: $e");
    }
  }

  String _formatDate(String? isoString) {
    if (isoString == null) return "Unknown date";
    try {
      String safeDate = isoString;
      if (!safeDate.endsWith('Z') && !safeDate.contains('+')) safeDate += 'Z';
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
              child: CircularProgressIndicator(color: Color(0xFF16a34a)),
            )
          : _dbError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                      size: 60,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Data Error",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _dbError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchOrders,
              color: const Color(0xFF16a34a),
              backgroundColor: isDark ? Colors.grey[800] : Colors.white,
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                itemCount: _orders.length + 2,
                itemBuilder: (context, index) {
                  // 1. Order History Header
                  if (index == 0) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                          "$_totalOrderCount order${_totalOrderCount == 1 ? '' : 's'} placed",
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
                      ],
                    );
                  }

                  // 2. Load More Button Section
                  if (index == _orders.length + 1) {
                    if (!_hasMore) {
                      if (_orders.isEmpty) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32.0),
                        child: Center(
                          child: Text(
                            "You've caught up with all orders!",
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.only(top: 16.0, bottom: 40.0),
                      child: Center(
                        child: SizedBox(
                          width: 180,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: _isFetchingMore
                                ? null
                                : _fetchMoreOrders,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey.shade300!,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: isDark
                                  ? Colors.grey[800]!.withOpacity(0.5)
                                  : Colors.white,
                            ),
                            child: _isFetchingMore
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF16a34a),
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 20,
                                        color: isDark
                                            ? Colors.white
                                            : Colors.black87,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Load More",
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black87,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    );
                  }

                  // 3. Actual Order Cards
                  final order = _orders[index - 1];
                  final status = (order['status'] ?? 'pending')
                      .toString()
                      .toLowerCase();
                  final totalAmount = order['total'] ?? 0;
                  final dateStr = _formatDate(order['created_at']);
                  final List<Map<String, dynamic>> items =
                      List<Map<String, dynamic>>.from(
                        order['order_items'] ?? [],
                      );

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

                  final visibleItems = items.take(4).toList();
                  final extraCount = items.length - visibleItems.length;

                  final String itemsSummary = items
                      .map((i) {
                        final name = i['product_name'] ?? i['name'] ?? 'Item';
                        final variant = i['variant_weight']?.toString() ?? '';
                        final qty = i['quantity'] ?? i['qty'] ?? 1;
                        if (variant.isNotEmpty && variant != 'null')
                          return "$name ($variant) x$qty";
                        return "$name x$qty";
                      })
                      .join(', ');

                  return InkWell(
                    onTap: () => context.push('/order-details', extra: order),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[850] : Colors.white,
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
                            const SizedBox(height: 12),
                            Text(
                              itemsSummary,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontSize: 13,
                                height: 1.4,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
