import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:intl/intl.dart';

import '../widgets/home_footer.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final client = Supabase.instance.client;
  RealtimeChannel? _realtimeChannel;
  Timer? _refreshTimer;

  List<Map<String, dynamic>> _products = [];
  List<String> _categories = ['All Products'];
  String _selectedCategory = 'All Products';
  String _searchQuery = "";
  bool _isLoading = true;

  List<Map<String, dynamic>> _recentOrders = [];
  int _unreadCount = 0;

  SharedPreferences? _prefs;

  String _lastSeenTimeStr = DateTime.fromMillisecondsSinceEpoch(
    0,
    isUtc: true,
  ).toIso8601String();

  @override
  void initState() {
    super.initState();
    _fetchData(showSpinner: true);
    _initPrefsAndOrders();

    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _fetchRecentOrders();
      _fetchData(showSpinner: false);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  DateTime _parseDatabaseTime(String? dateStr) {
    if (dateStr == null) return DateTime.now().toUtc();
    String formattedDate = dateStr;
    if (!formattedDate.endsWith('Z') && !formattedDate.contains('+')) {
      formattedDate += 'Z';
    }
    return DateTime.parse(formattedDate).toUtc();
  }

  Future<void> _initPrefsAndOrders() async {
    _prefs = await SharedPreferences.getInstance();
    final String? savedTime = _prefs?.getString('admin_last_seen_order_time');

    if (savedTime != null) {
      _lastSeenTimeStr = savedTime;
    } else {
      _lastSeenTimeStr = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 1))
          .toIso8601String();
      await _prefs?.setString('admin_last_seen_order_time', _lastSeenTimeStr);
    }

    _fetchRecentOrders();
    _listenToDatabase();
  }

  Future<void> _fetchRecentOrders() async {
    try {
      final res = await client
          .from('orders')
          .select('*, addresses(*)')
          .order('created_at', ascending: false)
          .limit(50);

      if (mounted) {
        setState(() {
          _recentOrders = List<Map<String, dynamic>>.from(res);

          final lastSeen = DateTime.parse(_lastSeenTimeStr).toUtc();
          _unreadCount = _recentOrders.where((o) {
            final orderTime = _parseDatabaseTime(o['created_at']);
            return orderTime.isAfter(lastSeen);
          }).length;
        });
      }
    } catch (e) {
      debugPrint("Fetch orders error: $e");
    }
  }

  Future<void> _fetchData({bool showSpinner = true}) async {
    if (!mounted) return;
    if (showSpinner) setState(() => _isLoading = true);

    try {
      final catsRes = await client
          .from('categories')
          .select('name')
          .order('id');
      final List<String> loadedCats = ['All Products'];
      loadedCats.addAll(
        catsRes
            .map((c) => c['name'].toString())
            .where((n) => n != 'All Products'),
      );

      final prodsRes = await client
          .from('products')
          .select()
          .order('created_at', ascending: false);
      final varsRes = await client.from('product_variants').select();

      final List<Map<String, dynamic>> combined = [];
      for (var p in prodsRes) {
        final Map<String, dynamic> product = Map.from(p);
        product['product_variants'] = varsRes
            .where((v) => v['product_id'].toString() == p['id'].toString())
            .toList();
        combined.add(product);
      }

      if (mounted) {
        setState(() {
          _categories = loadedCats;
          _products = combined;
          if (showSpinner) _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && showSpinner) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Product?"),
        content: Text("Are you sure you want to delete '${product['name']}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await client.from('products').delete().eq('id', product['id']);
        _fetchData(showSpinner: true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  void _openEditDialog(Map<String, dynamic> product) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EditProductDialog(
        product: product,
        isDark: Theme.of(context).brightness == Brightness.dark,
        onRefresh: () => _fetchData(showSpinner: true),
      ),
    );
  }

  String _timeAgo(String? dateTimeStr) {
    if (dateTimeStr == null) return '';
    final localDate = _parseDatabaseTime(dateTimeStr).toLocal();
    final now = DateTime.now();
    final diff = now.difference(localDate);

    if (diff.isNegative) return 'Just now';
    if (diff.inDays >= 1) return '${diff.inDays}d ago';
    if (diff.inHours >= 1) return '${diff.inHours}h ago';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m ago';
    return 'Just now';
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

  void _listenToDatabase() {
    _realtimeChannel = client.channel('admin_public_changes');

    _realtimeChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'products',
          callback: (payload) => _fetchData(showSpinner: false),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'product_variants',
          callback: (payload) => _fetchData(showSpinner: false),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            FlutterRingtonePlayer().playNotification();
            _fetchRecentOrders();
          },
        )
        .subscribe();
  }

  void _markAllRead() {
    if (_recentOrders.isNotEmpty) {
      _lastSeenTimeStr = _parseDatabaseTime(
        _recentOrders.first['created_at'],
      ).toIso8601String();
      _prefs?.setString('admin_last_seen_order_time', _lastSeenTimeStr);
    }
    setState(() {
      _unreadCount = 0;
    });
  }

  void _showNotifications() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Notifications",
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark ? const Color(0xFF1c1c1e) : Colors.white;
        final textColor = isDark ? Colors.white : Colors.black87;

        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;

        return Align(
          alignment: Alignment.topRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.only(top: 60, right: 16, left: 16),
              width: screenWidth > 400 ? 360 : screenWidth - 32,
              constraints: BoxConstraints(maxHeight: screenHeight * 0.7),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "NOTIFICATIONS",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[800],
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Recent orders are listed here",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_unreadCount > 0)
                              InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  _markAllRead();
                                },
                                child: const Padding(
                                  padding: EdgeInsets.only(right: 16.0),
                                  child: Text(
                                    "MARK ALL READ",
                                    style: TextStyle(
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ),
                            InkWell(
                              onTap: () => Navigator.pop(context),
                              child: const Text(
                                "CLOSE",
                                style: TextStyle(
                                  color: Color(0xFFE53935),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (_recentOrders.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40.0),
                      child: Text(
                        "No recent notifications",
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: _recentOrders.length,
                        separatorBuilder: (context, index) => Divider(
                          height: 1,
                          color: isDark
                              ? Colors.grey[800]
                              : Colors.grey.shade100,
                        ),
                        itemBuilder: (context, index) {
                          final order = _recentOrders[index];

                          final orderTime = _parseDatabaseTime(
                            order['created_at'],
                          );
                          final lastSeen = DateTime.parse(
                            _lastSeenTimeStr,
                          ).toUtc();
                          final isUnread = orderTime.isAfter(lastSeen);

                          final itemBgColor = isUnread
                              ? (isDark
                                    ? const Color(0xFF1A2A1A)
                                    : const Color(0xFFF2FAF2))
                              : Colors.transparent;

                          final total =
                              double.tryParse(
                                order['total']?.toString() ?? '0',
                              )?.toInt() ??
                              0;

                          return InkWell(
                            onTap: () {
                              Navigator.pop(context);

                              final clickedOrderTime = _parseDatabaseTime(
                                order['created_at'],
                              );
                              final currentLastSeen = DateTime.parse(
                                _lastSeenTimeStr,
                              ).toUtc();

                              if (clickedOrderTime.isAfter(currentLastSeen)) {
                                setState(() {
                                  _lastSeenTimeStr = clickedOrderTime
                                      .toIso8601String();
                                  _prefs?.setString(
                                    'admin_last_seen_order_time',
                                    _lastSeenTimeStr,
                                  );

                                  _unreadCount = _recentOrders.where((o) {
                                    return _parseDatabaseTime(
                                      o['created_at'],
                                    ).isAfter(clickedOrderTime);
                                  }).length;
                                });
                              }

                              _showOrderDetailsPopup(order);
                            },
                            child: Container(
                              color: itemBgColor,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (isUnread)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(
                                        top: 10,
                                        right: 8,
                                      ),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF16a34a),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? const Color(
                                              0xFF16a34a,
                                            ).withOpacity(isUnread ? 0.3 : 0.1)
                                          : (isUnread
                                                ? const Color(0xFFE8F5E9)
                                                : Colors.grey.shade100),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isUnread
                                            ? const Color(0xFF81C784)
                                            : Colors.grey.shade300,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Icon(
                                      Icons.shopping_bag_outlined,
                                      color: isUnread
                                          ? const Color(0xFF4CAF50)
                                          : Colors.grey.shade400,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "New Order — Rs. $total",
                                          style: TextStyle(
                                            fontWeight: isUnread
                                                ? FontWeight.w900
                                                : FontWeight.w600,
                                            fontSize: 13,
                                            color: textColor,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          order['email'] ?? 'Unknown customer',
                                          style: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _timeAgo(order['created_at']),
                                          style: TextStyle(
                                            color: isUnread
                                                ? const Color(0xFF4CAF50)
                                                : Colors.grey.shade400,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: isDark
                              ? Colors.grey[800]!
                              : Colors.grey.shade200,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _unreadCount > 0
                              ? "$_unreadCount unread"
                              : "All caught up!",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/admin-orders');
                          },
                          child: const Text(
                            "VIEW ALL ORDERS →",
                            style: TextStyle(
                              color: Color(0xFF388E3C),
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFf4f4f5);
    final textColor = isDark ? Colors.white : const Color(0xFF18181b);

    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount;
    if (screenWidth < 360) {
      crossAxisCount = 2;
    } else if (screenWidth < 600) {
      crossAxisCount = 3;
    } else {
      crossAxisCount = 4;
    }

    double cardWidth = screenWidth / crossAxisCount;
    double dynamicExtent = max(310.0, cardWidth * 1.65);

    final filteredProducts = _products.where((p) {
      final matchesSearch = (p['name'] ?? '').toString().toLowerCase().contains(
        _searchQuery.trim().toLowerCase(),
      );

      final String productCategory = (p['category'] ?? '')
          .toString()
          .trim()
          .toLowerCase();

      final String selectedCatName = _selectedCategory.trim().toLowerCase();
      final String selectedCatSlug = selectedCatName.replaceAll(' ', '-');

      final matchesCategory =
          _selectedCategory == 'All Products' ||
          productCategory == selectedCatName ||
          productCategory == selectedCatSlug;

      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: ElevatedButton.icon(
        onPressed: () async {
          await context.push('/admin-dashboard');
          _fetchData(showSpinner: true);
        },
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Add Product",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16a34a),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Garden',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                  fontFamily: 'Roboto',
                  color: isDark ? Colors.white : const Color(0xFF18181b),
                ),
              ),
              const Text(
                'Rich',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                  fontFamily: 'Roboto',
                  color: Color(0xFF16a34a),
                ),
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: InkWell(
              onTap: _showNotifications,
              borderRadius: BorderRadius.circular(50),
              child: Container(
                padding: const EdgeInsets.all(8.0),
                child: Badge(
                  isLabelVisible: _unreadCount > 0,
                  label: Text(
                    '$_unreadCount',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  backgroundColor: const Color(0xFFE53935),
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: isDark ? Colors.grey[300] : Colors.black87,
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
          Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
            ),
            child: PopupMenuButton<String>(
              offset: const Offset(0, 50),
              color: isDark ? Colors.grey[900] : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              onSelected: (value) async {
                if (value == 'dashboard') {
                  context.push('/admin-dashboard');
                } else if (value == 'orders') {
                  context.push('/admin-orders');
                } else if (value == 'logout') {
                  await Supabase.instance.client.auth.signOut();
                  if (context.mounted) context.go('/login');
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  enabled: false,
                  height: 30,
                  child: Text(
                    "ADMIN PANEL",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: Colors.grey[500],
                    ),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'dashboard',
                  child: Row(
                    children: [
                      Icon(
                        Icons.grid_view_outlined,
                        color: isDark ? Colors.grey[300] : Colors.black87,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Dashboard",
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'orders',
                  child: Row(
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        color: isDark ? Colors.grey[300] : Colors.black87,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Manage Orders",
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.redAccent, size: 20),
                      SizedBox(width: 12),
                      Text(
                        "Log Out",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 4,
                  ),
                  color: Colors.transparent,
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF18181b),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            "A",
                            style: TextStyle(
                              color: isDark ? Colors.black : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if (screenWidth > 350) ...[
                        const SizedBox(width: 8),
                        Text(
                          "Admin",
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black87,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF18181b),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "ADMIN",
                          style: TextStyle(
                            color: isDark ? Colors.black : Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.keyboard_arrow_down, color: Colors.grey[500]),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: "Search products...",
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF71717a)),
                filled: true,
                fillColor: isDark ? Colors.grey[900] : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: Color(0xFF16a34a),
                    width: 1,
                  ),
                ),
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = _selectedCategory == category;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: InkWell(
                    onTap: () => setState(() => _selectedCategory = category),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? (isDark ? Colors.white : Colors.black)
                              : (isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey.shade300),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          category,
                          style: TextStyle(
                            color: isSelected
                                ? (isDark ? Colors.black : Colors.white)
                                : (isDark ? Colors.grey[300] : Colors.black87),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () => _fetchData(showSpinner: true),
                    color: const Color(0xFF16a34a),
                    backgroundColor: isDark ? Colors.grey[800] : Colors.white,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        if (filteredProducts.isEmpty)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 80.0,
                                horizontal: 20.0,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off_rounded,
                                    size: 80,
                                    color: isDark
                                        ? Colors.grey[800]
                                        : Colors.grey[300],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "No products found",
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            sliver: SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    mainAxisSpacing: 16,
                                    crossAxisSpacing: 16,
                                    mainAxisExtent: dynamicExtent,
                                  ),
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => AdminProductCard(
                                  key: ValueKey(filteredProducts[index]['id']),
                                  product: filteredProducts[index],
                                  isDark: isDark,
                                  onDelete: _deleteProduct,
                                  onEdit: _openEditDialog,
                                ),
                                childCount: filteredProducts.length,
                              ),
                            ),
                          ),
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          fillOverscroll: true,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: HomeFooter(),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class AdminProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final bool isDark;
  final Function(Map<String, dynamic>) onDelete;
  final Function(Map<String, dynamic>) onEdit;

  const AdminProductCard({
    super.key,
    required this.product,
    required this.isDark,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  State<AdminProductCard> createState() => _AdminProductCardState();
}

class _AdminProductCardState extends State<AdminProductCard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final item = widget.product;
    final isDark = widget.isDark;
    final cardColor = isDark ? const Color(0xFF1c1c1e) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    final List<dynamic> variants = item['product_variants'] ?? [];
    if (_selectedIndex >= variants.length) _selectedIndex = 0;

    Map<String, dynamic> currentVariant = variants.isNotEmpty
        ? variants[_selectedIndex]
        : {};

    final double price =
        double.tryParse(currentVariant['price']?.toString() ?? '0') ?? 0;
    final double mrp =
        double.tryParse(currentVariant['mrp']?.toString() ?? '0') ?? price;

    final bool hasDiscount = mrp > price && mrp > 0;
    final int discountPercent = hasDiscount
        ? (((mrp - price) / mrp) * 100).round()
        : 0;
    final double savings = mrp - price;
    final bool isFeatured = item['is_featured'] == true || discountPercent > 10;

    final String imageUrl = item['image']?.toString() ?? "";
    final bool hasValidImage =
        imageUrl.isNotEmpty && imageUrl.startsWith('http');

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
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
                      color: isDark ? Colors.black : const Color(0xFFF8F9FA),
                      child: hasValidImage
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => const Icon(
                                Icons.image,
                                color: Colors.grey,
                                size: 40,
                              ),
                            )
                          : const Icon(
                              Icons.image,
                              color: Colors.grey,
                              size: 40,
                            ),
                    ),
                  ),
                ),
                if (isFeatured)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 2,
                            offset: Offset(0, 1),
                          ),
                        ],
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
                if (hasDiscount)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFF16a34a),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                        ),
                      ),
                      child: Text(
                        "$discountPercent% OFF",
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildCircularButton(
                        icon: Icons.delete_outline,
                        color: Colors.redAccent,
                        onTap: () => widget.onDelete(item),
                      ),
                      const SizedBox(height: 6),
                      _buildCircularButton(
                        icon: Icons.edit_outlined,
                        color: Colors.blueAccent,
                        onTap: () => widget.onEdit(item),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item['name'] ?? 'Unknown',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.grey.shade50,
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: variants.isEmpty
                      ? const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "Out of stock",
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedIndex,
                            isExpanded: true,
                            isDense: true,
                            dropdownColor: cardColor,
                            icon: Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.grey[600],
                              size: 14,
                            ),
                            selectedItemBuilder: (BuildContext context) {
                              return variants.map<Widget>((vItem) {
                                final v = Map<String, dynamic>.from(vItem);
                                final weight =
                                    v['weight']?.toString() ??
                                    "${v['unit_size'] ?? v['qty'] ?? '1'} ${v['unit'] ?? 'pc'}";
                                return Container(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    weight,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                );
                              }).toList();
                            },
                            items: List.generate(variants.length, (index) {
                              final v = variants[index];
                              final weight =
                                  v['weight']?.toString() ??
                                  "${v['unit_size'] ?? v['qty'] ?? '1'} ${v['unit'] ?? 'pc'}";
                              final s = v['stock']?.toString() ?? '0';
                              return DropdownMenuItem(
                                value: index,
                                child: Text(
                                  "$weight (Only $s left)",
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: textColor,
                                  ),
                                ),
                              );
                            }),
                            onChanged: (val) {
                              if (val != null)
                                setState(() => _selectedIndex = val);
                            },
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        variants.isEmpty ? "Rs. 0" : "Rs. ${price.toInt()}",
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: variants.isEmpty
                              ? Colors.grey
                              : const Color(0xFF16a34a),
                          fontSize: 16,
                        ),
                      ),
                      if (hasDiscount) ...[
                        const SizedBox(height: 2),
                        Text(
                          "Rs. ${mrp.toInt()}",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Save Rs. ${savings.toInt()}",
                          style: const TextStyle(
                            color: Color(0xFF16a34a),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 17),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: widget.isDark ? Colors.grey[900] : Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: const BoxDecoration(shape: BoxShape.circle),
          child: Icon(icon, size: 16, color: color),
        ),
      ),
    );
  }
}

class EditProductDialog extends StatefulWidget {
  final Map<String, dynamic> product;
  final bool isDark;
  final VoidCallback onRefresh;

  const EditProductDialog({
    super.key,
    required this.product,
    required this.isDark,
    required this.onRefresh,
  });

  @override
  State<EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<EditProductDialog> {
  final _nameController = TextEditingController();
  String? _selectedCategory;
  List<String> _categories = [];
  final List<Map<String, dynamic>> _variants = [];
  final List<dynamic> _deletedVariantIds = [];

  XFile? _newImageFile;
  bool _isLoading = false;
  bool _isLoadingCats = true;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.product['name'] ?? '';
    _selectedCategory = widget.product['category'];

    final existingVars = widget.product['product_variants'] as List? ?? [];
    for (var v in existingVars) {
      _variants.add({
        'id': v['id'],
        'weight': TextEditingController(
          text:
              v['weight']?.toString() ??
              "${v['unit_size'] ?? v['qty'] ?? '1'} ${v['unit'] ?? 'pc'}",
        ),
        'price': TextEditingController(text: v['price']?.toString() ?? '0'),
        'mrp': TextEditingController(text: v['mrp']?.toString() ?? '0'),
        'stock': TextEditingController(text: v['stock']?.toString() ?? '0'),
      });
    }
    if (_variants.isEmpty) _addEmptyVariant();

    _fetchCategories();
  }

  void _addEmptyVariant() {
    _variants.add({
      'id': null,
      'weight': TextEditingController(text: '1 pc'),
      'price': TextEditingController(text: '0'),
      'mrp': TextEditingController(text: '0'),
      'stock': TextEditingController(text: '0'),
    });
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await Supabase.instance.client
          .from('categories')
          .select('name, slug');

      if (mounted) {
        setState(() {
          _categories = res.map((c) => c['name'].toString()).toSet().toList();

          if (_selectedCategory != null) {
            for (var c in res) {
              if (c['slug']?.toString().toLowerCase() ==
                      _selectedCategory?.toLowerCase() ||
                  c['name']?.toString().toLowerCase() ==
                      _selectedCategory?.toLowerCase()) {
                _selectedCategory = c['name'];
                break;
              }
            }
          }

          if (_selectedCategory != null &&
              !_categories.contains(_selectedCategory)) {
            _categories.add(_selectedCategory!);
          }
          if (_selectedCategory == null && _categories.isNotEmpty) {
            _selectedCategory = _categories.first;
          }

          _isLoadingCats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCats = false);
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: widget.isDark ? Colors.grey[900] : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: Color(0xFF16a34a),
                  ),
                  title: const Text(
                    'Choose from Gallery',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () => _pickImage(ImageSource.gallery),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                    color: Color(0xFF16a34a),
                  ),
                  title: const Text(
                    'Take a Photo',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () => _pickImage(ImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context);
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (pickedFile != null) setState(() => _newImageFile = pickedFile);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to pick image: $e")));
    }
  }

  Future<void> _saveChanges() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      String? imageUrl;

      if (_newImageFile != null) {
        final bytes = await _newImageFile!.readAsBytes();
        final ext = _newImageFile!.name.split('.').last;
        final name = '${DateTime.now().millisecondsSinceEpoch}.$ext';
        await client.storage
            .from('product-images')
            .uploadBinary(
              name,
              bytes,
              fileOptions: FileOptions(contentType: 'image/$ext'),
            );
        imageUrl = client.storage.from('product-images').getPublicUrl(name);
      }

      String categorySlug = _selectedCategory ?? '';
      if (_selectedCategory != null) {
        try {
          final slugResponse = await client
              .from('categories')
              .select('slug')
              .eq('name', _selectedCategory!)
              .maybeSingle();

          if (slugResponse != null && slugResponse['slug'] != null) {
            categorySlug = slugResponse['slug'];
          } else {
            categorySlug = _selectedCategory!.toLowerCase().replaceAll(
              ' ',
              '-',
            );
          }
        } catch (e) {
          debugPrint("Error fetching category slug: $e");
          categorySlug = _selectedCategory!.toLowerCase().replaceAll(' ', '-');
        }
      }

      final prodData = {
        'name': _nameController.text.trim(),
        'category': categorySlug,
      };

      if (imageUrl != null) {
        prodData['image'] = imageUrl;
      }

      await client
          .from('products')
          .update(prodData)
          .eq('id', widget.product['id']);

      for (var v in _variants) {
        final vData = {
          'product_id': widget.product['id'],
          'weight': v['weight'].text.trim(),
          'price': double.tryParse(v['price'].text) ?? 0,
          'mrp': double.tryParse(v['mrp'].text) ?? 0,
          'stock': int.tryParse(v['stock'].text) ?? 0,
        };
        if (v['id'] != null) {
          await client.from('product_variants').update(vData).eq('id', v['id']);
        } else {
          await client.from('product_variants').insert(vData);
        }
      }

      for (var id in _deletedVariantIds)
        await client.from('product_variants').delete().eq('id', id);

      if (mounted) {
        widget.onRefresh();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Updated successfully!"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDark ? Colors.grey[900]! : Colors.white;
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    final hintColor = widget.isDark ? Colors.grey[400] : Colors.grey[600];

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Edit Product",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                children: [
                  TextField(
                    controller: _nameController,
                    style: TextStyle(color: textColor),
                    decoration: const InputDecoration(
                      labelText: "Product Name",
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!_isLoadingCats)
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(labelText: "Category"),
                      dropdownColor: bgColor,
                      style: TextStyle(color: textColor),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v),
                    ),
                  const SizedBox(height: 24),
                  Text(
                    "Product Image",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: widget.isDark
                            ? Colors.grey[700]!
                            : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 80,
                            height: 80,
                            color: widget.isDark
                                ? Colors.grey[800]
                                : Colors.grey.shade100,
                            child: _newImageFile != null
                                ? Image.file(
                                    File(_newImageFile!.path),
                                    fit: BoxFit.cover,
                                  )
                                : ((widget.product['image'] != null)
                                      ? Image.network(
                                          widget.product['image'],
                                          fit: BoxFit.cover,
                                          errorBuilder: (c, e, s) => Icon(
                                            Icons.image_not_supported,
                                            color: hintColor,
                                          ),
                                        )
                                      : Icon(
                                          Icons.add_photo_alternate_outlined,
                                          size: 40,
                                          color: hintColor,
                                        )),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "To display correctly, images should be square (1:1 aspect ratio) and less than 2MB.",
                                style: TextStyle(
                                  color: hintColor,
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton(
                                onPressed: _showImageSourceDialog,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF18181b),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text(
                                  "Change Image",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "Variants",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: textColor.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._variants.map(
                    (v) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: v['weight'],
                              style: TextStyle(color: textColor, fontSize: 12),
                              decoration: const InputDecoration(
                                hintText: "Weight",
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 0,
                                  horizontal: 4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: v['price'],
                              style: TextStyle(color: textColor, fontSize: 12),
                              decoration: const InputDecoration(
                                hintText: "Price",
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 0,
                                  horizontal: 4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: v['mrp'],
                              style: TextStyle(color: textColor, fontSize: 12),
                              decoration: const InputDecoration(
                                hintText: "MRP",
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 0,
                                  horizontal: 4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: v['stock'],
                              style: TextStyle(color: textColor, fontSize: 12),
                              decoration: const InputDecoration(
                                hintText: "Stock",
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 0,
                                  horizontal: 4,
                                ),
                              ),
                            ),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(
                              Icons.remove_circle,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () => setState(() {
                              if (v['id'] != null)
                                _deletedVariantIds.add(v['id']);
                              _variants.remove(v);
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => _addEmptyVariant()),
                    icon: const Icon(Icons.add),
                    label: const Text("Add Variant"),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _saveChanges,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: const Color(0xFF16a34a),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      "Save Changes",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

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
            addrData['phone'].toString().isNotEmpty) {
          fetchedPhone = addrData['phone'].toString();
        }
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
      debugPrint("Error: $e");
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
    for (var item in _orderItems) {
      totalQty +=
          int.tryParse(
            item['quantity']?.toString() ?? item['qty']?.toString() ?? '1',
          ) ??
          1;
    }

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

                        final int qty =
                            int.tryParse(
                              item['quantity']?.toString() ??
                                  item['qty']?.toString() ??
                                  '1',
                            ) ??
                            1;

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
