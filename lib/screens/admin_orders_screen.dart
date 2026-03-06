import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final client = Supabase.instance.client;
  String _selectedFilter = 'All Orders';

  final List<String> _filters = [
    'All Orders',
    'Pending',
    'Confirmed',
    'Shipped',
    'Delivered',
    'Cancelled',
  ];

  // 👇 FIXED: Safe date formatter that uses 'MMM' instead of 'Mar'
  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Unknown Date';
    try {
      final dateTime = DateTime.parse(dateString).toLocal();
      // 'MMM' correctly gives Jan, Feb, Mar, etc.
      return DateFormat('dd MMM yyyy, hh:mm a').format(dateTime);
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await client
          .from('orders')
          .update({'status': newStatus.toLowerCase()})
          .eq('id', orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Order updated to $newStatus"),
            backgroundColor: const Color(0xFF16a34a),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6);
    final cardColor = isDark ? Colors.grey[900]! : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "ADMIN PANEL",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                color: Colors.grey[500],
              ),
            ),
            const Text(
              "Orders Dashboard",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
            ),
          ],
        ),
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: client
            .from('orders')
            .stream(primaryKey: ['id'])
            .order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
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

          // KPI Calculations
          final now = DateTime.now();
          int todayOrders = 0;
          double todayRevenue = 0;
          int monthOrders = 0;
          double monthRevenue = 0;

          // Filter Counters
          Map<String, int> counts = {
            'All Orders': orders.length,
            'Pending': 0,
            'Confirmed': 0,
            'Shipped': 0,
            'Delivered': 0,
            'Cancelled': 0,
          };

          for (var order in orders) {
            final dateString = order['created_at']?.toString();
            DateTime? date;

            if (dateString != null && dateString.isNotEmpty) {
              try {
                date = DateTime.parse(dateString).toLocal();
              } catch (e) {
                // Ignore parse errors for KPI calculation
              }
            }

            final total =
                double.tryParse(
                  order['total']?.toString() ??
                      order['total_amount']?.toString() ??
                      '0',
                ) ??
                0;

            final rawStatus = (order['status']?.toString() ?? 'pending')
                .toLowerCase();

            String statusKey = 'Pending';
            for (var f in _filters) {
              if (f.toLowerCase() == rawStatus) {
                statusKey = f;
                break;
              }
            }

            if (counts.containsKey(statusKey)) {
              counts[statusKey] = counts[statusKey]! + 1;
            }

            // Time KPIs
            if (date != null) {
              if (date.year == now.year && date.month == now.month) {
                monthOrders++;
                monthRevenue += total;
                if (date.day == now.day) {
                  todayOrders++;
                  todayRevenue += total;
                }
              }
            }
          }

          // Filter the list for display
          final displayedOrders = orders.where((order) {
            if (_selectedFilter == 'All Orders') return true;
            final status = (order['status']?.toString() ?? 'pending')
                .toLowerCase();
            return status == _selectedFilter.toLowerCase();
          }).toList();

          return CustomScrollView(
            slivers: [
              // KPIs Grid
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.5,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildKPICard(
                        "TODAY's ORDERS",
                        todayOrders.toString(),
                        Icons.access_time,
                        Colors.amber,
                        cardColor,
                        isDark,
                      ),
                      _buildKPICard(
                        "TODAY's REVENUE",
                        "Rs. ${todayRevenue.toInt()}",
                        Icons.attach_money,
                        const Color(0xFF16a34a),
                        cardColor,
                        isDark,
                      ),
                      _buildKPICard(
                        "THIS MONTH",
                        monthOrders.toString(),
                        Icons.calendar_today,
                        Colors.blue,
                        cardColor,
                        isDark,
                      ),
                      _buildKPICard(
                        "MONTH REVENUE",
                        "Rs. ${monthRevenue.toInt()}",
                        Icons.trending_up,
                        Colors.purple,
                        cardColor,
                        isDark,
                      ),
                    ],
                  ),
                ),
              ),

              // Filter Tabs
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 50,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filters.length,
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final isSelected = _selectedFilter == filter;
                      final count = counts[filter] ?? 0;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: FilterChip(
                          selected: isSelected,
                          showCheckmark: false,
                          label: Text(
                            "$filter ($count)",
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                        ? Colors.grey[300]
                                        : Colors.black87),
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          backgroundColor: cardColor,
                          selectedColor: isDark
                              ? Colors.white24
                              : Colors.black87,
                          side: BorderSide(
                            color: isDark
                                ? Colors.grey[800]!
                                : Colors.grey.shade300,
                          ),
                          onSelected: (bool selected) {
                            setState(() => _selectedFilter = filter);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Orders List
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: displayedOrders.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40.0),
                          child: Center(
                            child: Text(
                              "No $_selectedFilter orders found.",
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final order = displayedOrders[index];
                          return _buildOrderCard(order, cardColor, isDark);
                        }, childCount: displayedOrders.length),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildKPICard(
    String title,
    String value,
    IconData icon,
    Color color,
    Color cardColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[500],
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(
    Map<String, dynamic> order,
    Color cardColor,
    bool isDark,
  ) {
    final status = (order['status']?.toString() ?? 'pending').toLowerCase();

    // 👇 FIXED: Using our new helper function
    final formattedDate = _formatDate(order['created_at']?.toString());

    // Check both potential column names
    final total =
        double.tryParse(
          order['total']?.toString() ??
              order['total_amount']?.toString() ??
              '0',
        ) ??
        0;

    final email = order['email'] ?? 'Guest Customer';
    final phone = order['phone'] ?? 'No phone provided';
    final orderId = order['id'].toString().substring(
      0,
      8,
    ); // Just show short ID

    Color statusColor;
    switch (status) {
      case 'shipped':
        statusColor = Colors.purpleAccent;
        break;
      case 'confirmed':
        statusColor = Colors.blueAccent;
        break;
      case 'delivered':
        statusColor = const Color(0xFF16a34a);
        break;
      case 'cancelled':
        statusColor = Colors.redAccent;
        break;
      default:
        statusColor = Colors.amber; // pending
    }

    // Safely parse status for the Dropdown UI
    String dropdownValue = 'Pending';
    for (var f in _filters) {
      if (f.toLowerCase() == status) {
        dropdownValue = f;
        break;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Status & Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  dropdownValue,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                formattedDate,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          const Divider(height: 24),

          // Customer Details & Total
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    Text(
                      "#$orderId",
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      "TOTAL",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      "Rs. ${total.toInt()}",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF16a34a),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Status Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: dropdownValue,
                isExpanded: true,
                dropdownColor: cardColor,
                icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                items: _filters.where((f) => f != 'All Orders').map((
                  String value,
                ) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null && newValue != dropdownValue) {
                    _updateOrderStatus(order['id'].toString(), newValue);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
