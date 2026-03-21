import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final client = Supabase.instance.client;

  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;

  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String _selectedFilter = 'All Orders';
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  final List<String> _filters = [
    'All Orders',
    'Pending',
    'Confirmed',
    'Shipped',
    'Delivered',
    'Cancelled',
  ];

  static const List<String> _shortMonths = [
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
  static const List<String> _fullMonths = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    try {
      final response = await client
          .from('orders')
          .select('*, addresses(*)')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _orders = response.map((e) => Map<String, dynamic>.from(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching orders: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Unknown Date';
    try {
      String safeDate = dateString;
      if (!safeDate.endsWith('Z')) safeDate += 'Z';
      final dateTime = DateTime.parse(safeDate).toLocal();
      return DateFormat('dd MMM yyyy, h:mm a').format(dateTime);
    } catch (e) {
      return dateString;
    }
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      final res = await client
          .from('orders')
          .update({'status': newStatus.toLowerCase()})
          .eq('id', orderId)
          .select();

      if (res.isEmpty) throw Exception("Update blocked. Check RLS policies.");

      if (mounted) {
        setState(() {
          final index = _orders.indexWhere(
            (o) => o['id'].toString() == orderId,
          );
          if (index != -1) _orders[index]['status'] = newStatus.toLowerCase();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Marked as $newStatus"),
            backgroundColor: const Color(0xFF16a34a),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $e"),
            backgroundColor: Colors.redAccent,
          ),
        );
    }
  }

  void _showOrderDetailsPopup(Map<String, dynamic> order) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => _AdminOrderDetailsDialog(
        order: order,
        formattedDate: _formatDate(order['created_at']?.toString()),
      ),
    );
  }

  List<int> _getVisiblePages(int totalPages) {
    if (totalPages <= 5) return List.generate(totalPages, (i) => i + 1);
    if (_currentPage <= 3) return [1, 2, 3, 4, 5];
    if (_currentPage >= totalPages - 2)
      return [
        totalPages - 4,
        totalPages - 3,
        totalPages - 2,
        totalPages - 1,
        totalPages,
      ];
    return [
      _currentPage - 2,
      _currentPage - 1,
      _currentPage,
      _currentPage + 1,
      _currentPage + 2,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6);
    final cardColor = isDark ? Colors.grey[900]! : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey.shade200;

    final screenWidth = MediaQuery.of(context).size.width;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF16a34a)),
        ),
      );
    }

    final now = DateTime.now();

    int todayOrders = 0;
    double todayRevenue = 0;
    int monthOrders = 0;
    double monthRevenue = 0;
    List<int> monthlyCounts = List.filled(12, 0);

    for (var order in _orders) {
      final dateStr = order['created_at']?.toString();
      if (dateStr == null || dateStr.isEmpty) continue;

      try {
        String safeDate = dateStr.endsWith('Z') ? dateStr : '${dateStr}Z';
        final date = DateTime.parse(safeDate).toLocal();
        final total =
            double.tryParse(
              order['total']?.toString() ??
                  order['total_amount']?.toString() ??
                  '0',
            ) ??
            0;

        if (date.year == _selectedYear) {
          monthlyCounts[date.month - 1]++;
        }

        if (date.year == now.year && date.month == now.month) {
          monthOrders++;
          monthRevenue += total;
          if (date.day == now.day) {
            todayOrders++;
            todayRevenue += total;
          }
        }
      } catch (e) {}
    }

    final dateAndSearchFiltered = _orders.where((order) {
      final dateStr = order['created_at']?.toString();
      if (dateStr == null || dateStr.isEmpty) return false;

      try {
        String safeDate = dateStr.endsWith('Z') ? dateStr : '${dateStr}Z';
        final date = DateTime.parse(safeDate).toLocal();
        if (date.year != _selectedYear || date.month != _selectedMonth)
          return false;
      } catch (e) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final id = order['id']?.toString().toLowerCase() ?? '';
        final email = order['email']?.toString().toLowerCase() ?? '';
        String phone = order['phone']?.toString().toLowerCase() ?? '';

        String name = (order['name'] ?? order['customer_name'] ?? '')
            .toString()
            .toLowerCase();
        final addrData = order['addresses'];
        if (addrData != null && addrData is Map) {
          final fName = addrData['first_name'] ?? '';
          final lName = addrData['last_name'] == 'EMPTY'
              ? ''
              : (addrData['last_name'] ?? '');
          name = '$fName $lName'.trim().toLowerCase();
          if (addrData['phone'] != null) phone += ' ${addrData['phone']}';
        }

        if (!id.contains(q) &&
            !email.contains(q) &&
            !name.contains(q) &&
            !phone.contains(q))
          return false;
      }

      return true;
    }).toList();

    int selectedMonthOrderCount = dateAndSearchFiltered.length;
    double selectedMonthRevenueCount = 0;

    Map<String, int> filterCounts = {
      'All Orders': dateAndSearchFiltered.length,
      'Pending': 0,
      'Confirmed': 0,
      'Shipped': 0,
      'Delivered': 0,
      'Cancelled': 0,
    };

    for (var order in dateAndSearchFiltered) {
      selectedMonthRevenueCount +=
          double.tryParse(order['total']?.toString() ?? '0') ?? 0;
      final rawStatus = (order['status']?.toString() ?? 'pending')
          .toLowerCase();
      String statusKey = 'Pending';
      for (var f in _filters) {
        if (f.toLowerCase() == rawStatus) {
          statusKey = f;
          break;
        }
      }
      if (filterCounts.containsKey(statusKey))
        filterCounts[statusKey] = filterCounts[statusKey]! + 1;
    }

    final displayedOrders = dateAndSearchFiltered.where((order) {
      if (_selectedFilter == 'All Orders') return true;
      final status = (order['status']?.toString() ?? 'pending').toLowerCase();
      return status == _selectedFilter.toLowerCase();
    }).toList();

    int totalPages = (displayedOrders.length / _itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;
    if (_currentPage > totalPages) _currentPage = totalPages;

    final int startIndex = (_currentPage - 1) * _itemsPerPage;
    final int endIndex = (startIndex + _itemsPerPage > displayedOrders.length)
        ? displayedOrders.length
        : startIndex + _itemsPerPage;
    final paginatedOrders = displayedOrders.sublist(startIndex, endIndex);

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
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchOrders,
        color: const Color(0xFF16a34a),
        backgroundColor: cardColor,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // KPI CARDS
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: screenWidth > 800
                    ? Row(
                        children: [
                          Expanded(
                            child: _buildKPICard(
                              "TODAY'S ORDERS",
                              todayOrders.toString(),
                              "Orders placed today",
                              Icons.access_time,
                              Colors.amber.shade700,
                              cardColor,
                              borderColor,
                              isDark,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildKPICard(
                              "TODAY'S REVENUE",
                              "Rs. ${todayRevenue.toInt()}",
                              "Collected today",
                              Icons.attach_money,
                              const Color(0xFF16a34a),
                              cardColor,
                              borderColor,
                              isDark,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildKPICard(
                              "THIS MONTH",
                              monthOrders.toString(),
                              "Orders this month",
                              Icons.calendar_today,
                              Colors.blue.shade600,
                              cardColor,
                              borderColor,
                              isDark,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildKPICard(
                              "MONTH REVENUE",
                              "Rs. ${monthRevenue.toInt()}",
                              "Revenue this month",
                              Icons.trending_up,
                              Colors.purple.shade600,
                              cardColor,
                              borderColor,
                              isDark,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildKPICard(
                                  "TODAY'S ORDERS",
                                  todayOrders.toString(),
                                  "Orders placed today",
                                  Icons.access_time,
                                  Colors.amber.shade700,
                                  cardColor,
                                  borderColor,
                                  isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildKPICard(
                                  "TODAY'S REVENUE",
                                  "Rs. ${todayRevenue.toInt()}",
                                  "Collected today",
                                  Icons.attach_money,
                                  const Color(0xFF16a34a),
                                  cardColor,
                                  borderColor,
                                  isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildKPICard(
                                  "THIS MONTH",
                                  monthOrders.toString(),
                                  "Orders this month",
                                  Icons.calendar_today,
                                  Colors.blue.shade600,
                                  cardColor,
                                  borderColor,
                                  isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildKPICard(
                                  "MONTH REVENUE",
                                  "Rs. ${monthRevenue.toInt()}",
                                  "Revenue this month",
                                  Icons.trending_up,
                                  Colors.purple.shade600,
                                  cardColor,
                                  borderColor,
                                  isDark,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
              ),
            ),

            // YEAR & MONTH SELECTOR CARD
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: borderColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.chevron_left,
                                  color: textColor,
                                  size: 20,
                                ),
                                onPressed: () => setState(() {
                                  _selectedYear--;
                                  _currentPage = 1;
                                }),
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // 👇 FIXED BUG 1: Wrapped the center text in Expanded + FittedBox to prevent pushing arrows off screen
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    "$_selectedYear",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      "SELECT A MONTH BELOW",
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[500],
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: borderColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  Icons.chevron_right,
                                  color: textColor,
                                  size: 20,
                                ),
                                onPressed: () => setState(() {
                                  _selectedYear++;
                                  _currentPage = 1;
                                }),
                                constraints: const BoxConstraints(
                                  minWidth: 40,
                                  minHeight: 40,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: screenWidth > 600 ? 6 : 4,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                                childAspectRatio: screenWidth > 600 ? 2.5 : 1.3,
                              ),
                          itemCount: 12,
                          itemBuilder: (context, index) {
                            final monthInt = index + 1;
                            final isSelected = _selectedMonth == monthInt;
                            final count = monthlyCounts[index];

                            return InkWell(
                              onTap: () => setState(() {
                                _selectedMonth = monthInt;
                                _currentPage = 1;
                              }),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF16a34a)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _shortMonths[index],
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.grey[500],
                                        ),
                                      ),
                                    ),
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        count == 0 ? "—" : "$count orders",
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isSelected
                                              ? Colors.white.withOpacity(0.9)
                                              : Colors.grey[400],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 16),
                      Divider(height: 1, color: borderColor),

                      // SUMMARY FOOTER
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF16a34a),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "${_fullMonths[_selectedMonth - 1]} $_selectedYear",
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: textColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "ORDERS",
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    Text(
                                      "$selectedMonthOrderCount",
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      "REVENUE",
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                    Text(
                                      "Rs. ${selectedMonthRevenueCount.toInt()}",
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFF16a34a),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // SEARCH BAR & FILTER CHIPS
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (val) => setState(() {
                        _searchQuery = val;
                        _currentPage = 1;
                      }),
                      decoration: InputDecoration(
                        hintText: "Search by name, email or order ID...",
                        hintStyle: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Colors.grey,
                        ),
                        filled: true,
                        fillColor: cardColor,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF16a34a),
                          ),
                        ),
                      ),
                      style: TextStyle(color: textColor),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        itemBuilder: (context, index) {
                          final filter = _filters[index];
                          final isSelected = _selectedFilter == filter;
                          final count = filterCounts[filter] ?? 0;

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
                                color: isSelected
                                    ? Colors.transparent
                                    : borderColor,
                              ),
                              onSelected: (bool selected) => setState(() {
                                _selectedFilter = filter;
                                _currentPage = 1;
                              }),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ORDER LIST
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: paginatedOrders.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40.0, bottom: 40.0),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 60,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "No results found.",
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return _buildOrderCard(
                          context,
                          paginatedOrders[index],
                          cardColor,
                          isDark,
                        );
                      }, childCount: paginatedOrders.length),
                    ),
            ),

            // PAGINATION CONTROLS
            if (totalPages > 1)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40, top: 10),
                  // 👇 FIXED BUG 2: Wrapped entire pagination in FittedBox. It will smoothly scale down if the screen is too narrow.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(
                            Icons.chevron_left,
                            color: _currentPage > 1 ? textColor : Colors.grey,
                          ),
                          onPressed: _currentPage > 1
                              ? () => setState(() => _currentPage--)
                              : null,
                        ),
                        Row(
                          children: _getVisiblePages(totalPages).map((page) {
                            final isSelected = page == _currentPage;
                            return InkWell(
                              onTap: () => setState(() => _currentPage = page),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF16a34a)
                                      : (isDark
                                            ? Colors.grey[800]
                                            : Colors.grey[200]),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '$page',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : textColor,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.chevron_right,
                            color: _currentPage < totalPages
                                ? textColor
                                : Colors.grey,
                          ),
                          onPressed: _currentPage < totalPages
                              ? () => setState(() => _currentPage++)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildKPICard(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
    Color cardColor,
    Color borderColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(
    BuildContext context,
    Map<String, dynamic> order,
    Color cardColor,
    bool isDark,
  ) {
    final status = (order['status']?.toString() ?? 'pending').toLowerCase();
    final formattedDate = _formatDate(order['created_at']?.toString());
    final total =
        double.tryParse(
          order['total']?.toString() ??
              order['total_amount']?.toString() ??
              '0',
        ) ??
        0;
    final email = order['email'] ?? 'Guest Customer';

    final addrData = order['addresses'];
    String phone = order['phone']?.toString() ?? 'No phone provided';
    String customerName = order['name'] ?? order['customer_name'] ?? email;

    if (addrData != null && addrData is Map) {
      final fName = addrData['first_name'] ?? '';
      final lName = addrData['last_name'] == 'EMPTY'
          ? ''
          : (addrData['last_name'] ?? '');
      final fullName = '$fName $lName'.trim();
      if (fullName.isNotEmpty) customerName = fullName;
      if (addrData['phone'] != null) phone = addrData['phone'].toString();
    }

    String orderId = order['id'].toString();
    String displayId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;

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
        statusColor = Colors.amber;
    }

    String dropdownValue = 'Pending';
    for (var f in _filters) {
      if (f.toLowerCase() == status) {
        dropdownValue = f;
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showOrderDetailsPopup(order),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
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
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "$formattedDate · #$displayId",
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customerName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            phone,
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[850] : Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Click to view details",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
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
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.grey,
                      ),
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
                        if (newValue != null && newValue != dropdownValue)
                          _updateOrderStatus(orderId, newValue);
                      },
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
}

// ============================================================================
// THE POPUP DIALOG (REMAINS EXACTLY THE SAME)
// ============================================================================
class _AdminOrderDetailsDialog extends StatefulWidget {
  final Map<String, dynamic> order;
  final String formattedDate;

  const _AdminOrderDetailsDialog({
    required this.order,
    required this.formattedDate,
  });

  @override
  State<_AdminOrderDetailsDialog> createState() =>
      _AdminOrderDetailsDialogState();
}

class _AdminOrderDetailsDialogState extends State<_AdminOrderDetailsDialog> {
  List<Map<String, dynamic>> _orderItems = [];
  bool _isLoading = true;

  String _customerAddress = "No Address Provided";
  String _customerName = "Guest Customer";
  String _customerPhone = "No Phone";

  @override
  void initState() {
    super.initState();
    _fetchOrderItemsAndParseAddress();
  }

  Future<void> _fetchOrderItemsAndParseAddress() async {
    try {
      final orderId = widget.order['id'].toString();

      final itemsRes = await Supabase.instance.client
          .from('order_items')
          .select()
          .eq('order_id', orderId);
      List<Map<String, dynamic>> items = List<Map<String, dynamic>>.from(
        itemsRes,
      );

      final productNames = items
          .map((i) => (i['product_name'] ?? i['name'])?.toString())
          .where((n) => n != null)
          .toSet()
          .toList();

      if (productNames.isNotEmpty) {
        final productsRes = await Supabase.instance.client
            .from('products')
            .select('name, image')
            .inFilter('name', productNames);
        Map<String, dynamic> imageMap = {};
        for (var p in productsRes) {
          if (p['name'] != null && p['image'] != null)
            imageMap[p['name'].toString()] = p['image'];
        }
        for (var item in items) {
          final pName = (item['product_name'] ?? item['name'])?.toString();
          if (pName != null && imageMap.containsKey(pName))
            item['image'] = imageMap[pName];
        }
      }

      String fetchedAddress = "No Address Provided";
      String fetchedName =
          widget.order['email']?.toString() ?? "Guest Customer";
      String fetchedPhone = widget.order['phone']?.toString() ?? "No Phone";

      final addrData = widget.order['addresses'];
      if (addrData != null && addrData is Map) {
        final street = addrData['address'] ?? '';
        final city = addrData['city'] ?? '';
        final pin = addrData['pin_code'] ?? '';
        final fName = addrData['first_name'] ?? '';
        final lName = addrData['last_name'] == 'EMPTY'
            ? ''
            : (addrData['last_name'] ?? '');
        final fullName = '$fName $lName'.trim();

        fetchedAddress = '$street, $city, $pin'
            .replaceAll(RegExp(r'^, |, $'), '')
            .trim();
        if (fullName.isNotEmpty) fetchedName = fullName;
        if (addrData['phone'] != null &&
            addrData['phone'].toString().isNotEmpty)
          fetchedPhone = addrData['phone'].toString();
      }

      if (mounted) {
        setState(() {
          _orderItems = items;
          _customerAddress = fetchedAddress;
          _customerName = fetchedName;
          _customerPhone = fetchedPhone;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey[900]! : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey.shade200;

    final order = widget.order;
    String orderId = order['id'].toString();
    String displayId = orderId.length > 8 ? orderId.substring(0, 8) : orderId;
    final total =
        double.tryParse(order['total']?.toString() ?? '0')?.toInt() ?? 0;
    int totalQty = 0;
    for (var item in _orderItems) totalQty += (item['qty'] as int?) ?? 1;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "ORDER DETAILS",
                          style: TextStyle(
                            color: Color(0xFF16a34a),
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _customerName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "#$displayId · ${widget.formattedDate}",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[850] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 14,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _customerAddress,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.grey[400]
                                            : Colors.grey[700],
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.phone_outlined,
                                    size: 14,
                                    color: Colors.grey[500],
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _customerPhone,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close,
                        size: 20,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: borderColor),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF16a34a),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _orderItems.length,
                      itemBuilder: (context, index) {
                        final item = _orderItems[index];
                        final qty = item['qty'] ?? 1;
                        final price =
                            double.tryParse(
                              item['price']?.toString() ?? '0',
                            )?.toInt() ??
                            0;
                        final imageUrl = item['image']?.toString() ?? '';
                        final hasImage =
                            imageUrl.isNotEmpty && imageUrl.startsWith('http');
                        final weightStr =
                            item['variant_weight']?.toString() ?? '';

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: bgColor,
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
                                  color: isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[100],
                                  child: hasImage
                                      ? Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                        )
                                      : Icon(
                                          Icons.image,
                                          color: Colors.grey[400],
                                        ),
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
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
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
                                              borderRadius:
                                                  BorderRadius.circular(4),
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
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
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
                      },
                    ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[50],
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "ORDER TOTAL",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.grey[500],
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "${_orderItems.length} item${_orderItems.length == 1 ? '' : 's'} · Total qty: $totalQty",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    "Rs. $total",
                    style: const TextStyle(
                      color: Color(0xFF00a651),
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
