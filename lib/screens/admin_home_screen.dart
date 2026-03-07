import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  List<Map<String, dynamic>> _products = [];
  List<String> _categories = ['All Products'];
  String _selectedCategory = 'All Products';
  String _searchQuery = "";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    final client = Supabase.instance.client;
    try {
      // 1. Fetch Categories dynamically
      final catsResponse = await client
          .from('categories')
          .select('name')
          .order('id');
      final List<String> loadedCats = ['All Products'];
      loadedCats.addAll(
        catsResponse
            .map((c) => c['name'].toString())
            .where((n) => n != 'All Products'),
      );

      // 2. Fetch Products & Variants
      final productsResponse = await client
          .from('products')
          .select()
          .order('created_at', ascending: false);
      final variantsResponse = await client.from('product_variants').select();

      final List<Map<String, dynamic>> combinedProducts = [];
      for (var product in productsResponse) {
        final mutableProduct = Map<String, dynamic>.from(product);
        final matchingVariants = variantsResponse
            .where(
              (v) => v['product_id'].toString() == product['id'].toString(),
            )
            .toList();
        mutableProduct['product_variants'] = matchingVariants;
        combinedProducts.add(mutableProduct);
      }

      if (mounted) {
        setState(() {
          _categories = loadedCats;
          _products = combinedProducts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
      if (mounted) setState(() => _isLoading = false);
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
            child: const Text("Cancel"),
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
      await Supabase.instance.client
          .from('products')
          .delete()
          .eq('id', product['id']);
      _fetchData(); // Refresh the grid
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6);
    final cardColor = isDark ? Colors.grey[900]! : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF18181b);

    // Apply Search and Category Filters
    final filteredProducts = _products.where((p) {
      final matchesSearch = p['name'].toString().toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final matchesCategory =
          _selectedCategory == 'All Products' ||
          p['category'] == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,

      // Floating Action Button (+ Add Product)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: ElevatedButton.icon(
        onPressed: () => context.push('/admin-dashboard'),
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

      // Proper GardenRich App Bar with Avatar Dropdown
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
        title: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.0,
              fontFamily: 'Roboto',
            ),
            children: [
              TextSpan(
                text: 'Garden',
                style: TextStyle(color: textColor),
              ),
              const TextSpan(
                text: 'Rich',
                style: TextStyle(color: Color(0xFF16a34a)),
              ),
            ],
          ),
        ),
        actions: [
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
                  // Already here
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
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.logout,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      const Text(
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
                      const SizedBox(width: 8),
                      Text(
                        "Admin",
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
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

      // Hamburger Drawer
      drawer: Drawer(
        backgroundColor: cardColor,
        child: SafeArea(
          child: _buildSidebarMenu(
            textColor,
            isDark,
            cardColor,
            isDrawer: true,
          ),
        ),
      ),

      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: "Search products...",
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                filled: true,
                fillColor: isDark ? Colors.black : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
                  ),
                ),
              ),
            ),
          ),

          // 2. Category Filter Chips
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
                  child: ChoiceChip(
                    label: Text(
                      category,
                      style: TextStyle(
                        color: isSelected
                            ? (isDark ? Colors.black : Colors.black)
                            : (isDark ? Colors.white : Colors.black),
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected)
                        setState(() => _selectedCategory = category);
                    },
                    backgroundColor: isDark ? Colors.black : Colors.white,
                    selectedColor: isDark ? Colors.white : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(
                        color: isSelected
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark
                                  ? Colors.grey[800]!
                                  : Colors.grey.shade300),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // 3. Products Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredProducts.isEmpty
                ? Center(
                    child: Text(
                      "No products found.",
                      style: TextStyle(color: textColor),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      100,
                    ), // Padding at bottom for FAB
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 16,
                          crossAxisSpacing: 16,
                          mainAxisExtent:
                              320, // Provides enough height so it won't overflow
                        ),
                    itemCount: filteredProducts.length,
                    // 👇 Calls the new Stateful Widget for each product!
                    itemBuilder: (context, index) => AdminProductCard(
                      key: ValueKey(filteredProducts[index]['id']),
                      product: filteredProducts[index],
                      cardColor: cardColor,
                      textColor: textColor,
                      isDark: isDark,
                      onDelete: _deleteProduct,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SIDEBAR WIDGET
  // ---------------------------------------------------------------------------
  Widget _buildSidebarMenu(
    Color textColor,
    bool isDark,
    Color cardColor, {
    bool isDrawer = false,
  }) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "ADMIN",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Dashboard",
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: Icon(Icons.add, color: Colors.grey[600]),
            title: Text(
              "Add Product",
              style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
            ),
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              context.push('/admin-dashboard');
            },
          ),
          ListTile(
            leading: Icon(Icons.sell_outlined, color: Colors.grey[600]),
            title: Text(
              "Categories",
              style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
            ),
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              context.push('/admin-categories');
            },
          ),
          ListTile(
            leading: Icon(Icons.settings_outlined, color: Colors.grey[600]),
            title: Text(
              "Store Settings",
              style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
            ),
            onTap: () {},
          ),
          ListTile(
            leading: Icon(Icons.assignment_outlined, color: Colors.grey[600]),
            title: Text(
              "Orders",
              style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
            ),
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              context.push('/admin-orders');
            },
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(),
          ),
          ListTile(
            leading: Icon(Icons.arrow_back, color: Colors.grey[600]),
            title: Text(
              "View Store",
              style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
            ),
            onTap: () {
              if (isDrawer) Navigator.pop(context);
              context.go('/home');
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FIXED: INDEPENDENT STATEFUL WIDGET FOR PRODUCT CARDS
// ---------------------------------------------------------------------------
class AdminProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final Color cardColor;
  final Color textColor;
  final bool isDark;
  final Function(Map<String, dynamic>) onDelete;

  const AdminProductCard({
    super.key,
    required this.product,
    required this.cardColor,
    required this.textColor,
    required this.isDark,
    required this.onDelete,
  });

  @override
  State<AdminProductCard> createState() => _AdminProductCardState();
}

class _AdminProductCardState extends State<AdminProductCard> {
  int _selectedVariantIndex = 0;

  @override
  Widget build(BuildContext context) {
    final variants = widget.product['product_variants'] as List? ?? [];

    if (_selectedVariantIndex >= variants.length && variants.isNotEmpty) {
      _selectedVariantIndex = 0;
    }

    double price = 0;
    double mrp = 0;
    String weight = "1 pc";
    int stock = 0;

    if (variants.isNotEmpty) {
      final v = variants[_selectedVariantIndex];
      price = double.tryParse(v['price']?.toString() ?? '0') ?? 0;
      mrp = double.tryParse(v['mrp']?.toString() ?? '0') ?? price;
      stock = int.tryParse(v['stock']?.toString() ?? '0') ?? 0;
      weight = "${v['unit_size'] ?? v['qty'] ?? '1'} ${v['unit'] ?? 'pc'}";
    }

    int discount = (mrp > price) ? (((mrp - price) / mrp) * 100).round() : 0;
    double savings = mrp - price;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isDark ? Colors.grey[800]! : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 12,
            child: Stack(
              fit: StackFit.expand,
              children: [
                widget.product['image'] != null &&
                        widget.product['image'].toString().isNotEmpty
                    ? Image.network(widget.product['image'], fit: BoxFit.cover)
                    : Container(
                        color: widget.isDark
                            ? Colors.grey[850]
                            : Colors.grey[100],
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),

                Positioned(
                  top: 8,
                  right: 8,
                  child: Column(
                    children: [
                      _actionCircle(
                        Icons.delete_outline,
                        Colors.redAccent,
                        () => widget.onDelete(widget.product),
                      ),
                      const SizedBox(height: 6),
                      _actionCircle(
                        Icons.edit_outlined,
                        Colors.blueAccent,
                        () {},
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            flex: 12,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Text(
                    widget.product['name'] ?? 'Unknown',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: widget.textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // 👇 FIXED: This is your exact code snippet, wrapped in a PopupMenuButton!
                  PopupMenuButton<int>(
                    padding: EdgeInsets.zero,
                    color: widget.cardColor,
                    onSelected: (int index) {
                      setState(() => _selectedVariantIndex = index);
                    },
                    itemBuilder: (context) => variants.asMap().entries.map((
                      entry,
                    ) {
                      int idx = entry.key;
                      var v = entry.value;
                      String w =
                          "${v['unit_size'] ?? v['qty'] ?? '1'} ${v['unit'] ?? 'pc'}";
                      return PopupMenuItem<int>(value: idx, child: Text(w));
                    }).toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? const Color(0xFF2C2C2E)
                            : Colors.grey.shade100,
                        border: Border.all(
                          color: widget.isDark
                              ? Colors.grey[700]!
                              : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "$weight (Only $stock left)",
                            style: TextStyle(
                              color: widget.textColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: widget.textColor,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),

                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "Rs. ${price.toInt()}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF16a34a),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (mrp > price)
                              Text(
                                "Rs. ${mrp.toInt()}",
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                  decoration: TextDecoration.lineThrough,
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
          ),
        ],
      ),
    );
  }

  Widget _actionCircle(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }
}
