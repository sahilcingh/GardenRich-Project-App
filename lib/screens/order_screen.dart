import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late Stream<List<Map<String, dynamic>>> _ordersStream;

  @override
  void initState() {
    super.initState();
    _setupOrdersStream();
  }

  void _setupOrdersStream() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _ordersStream = Stream.value([]);
      return;
    }

    _ordersStream = Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
  }

  Future<void> _handleRefresh() async {
    setState(() {
      _setupOrdersStream();
    });
    await Future.delayed(const Duration(milliseconds: 500));
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
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading orders",
                style: TextStyle(color: textColor),
              ),
            );
          }

          final orders = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: _handleRefresh,
            color: const Color(0xFF16a34a),
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
                  "${orders.length} order${orders.length == 1 ? '' : 's'} placed",
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 24),

                if (orders.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 40.0),
                      child: Text(
                        "You haven't placed any orders yet.",
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ),
                  ),

                ...orders.map((order) {
                  final status = (order['status'] ?? 'pending')
                      .toString()
                      .toLowerCase();
                  final totalAmount = order['total'] ?? 0;
                  final dateStr = _formatDate(order['created_at']);

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

                  return InkWell(
                    onTap: () {
                      context.push('/order-details', extra: order);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      statusIcon,
                                      size: 14,
                                      color: statusColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      statusText,
                                      style: TextStyle(
                                        color: statusColor,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Placed on $dateStr",
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
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
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.arrow_forward_ios,
                            size: 14,
                            color: Colors.grey,
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}
