import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import '../widgets/product_card.dart';
import '../widgets/home_footer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = "";
  final List<Map<String, dynamic>> _cartItems = [];
  String _selectedCategory = "All Products";
  List<String> _categories = ["All Products"];
  late Future<List<Map<String, dynamic>>> _productsFuture;

  bool _isAdmin = false;
  late final StreamSubscription<AuthState> _authSubscription;

  @override
  void initState() {
    super.initState();
    _productsFuture = _fetchProducts();
    _fetchCategories();

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null && user.email != null) {
      _checkAdminRole(user.email!);
    }

    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      final session = data.session;
      if (session != null && session.user.email != null) {
        _checkAdminRole(session.user.email!);
      } else {
        if (mounted) setState(() => _isAdmin = false);
      }
    });
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  Future<void> _checkAdminRole(String email) async {
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('email', email.trim().toLowerCase())
          .maybeSingle();

      if (response != null && mounted) {
        final userRole =
            response['role']?.toString().trim().toUpperCase() ?? 'USER';
        setState(() {
          _isAdmin = (userRole == 'ADMIN');
        });
      } else if (mounted) {
        setState(() => _isAdmin = false);
      }
    } catch (e) {
      debugPrint("Error checking admin role: $e");
      if (mounted) setState(() => _isAdmin = false);
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await Supabase.instance.client
          .from('categories')
          .select('name')
          .order('id', ascending: true);
      if (mounted) {
        setState(() {
          final dbCategories = response
              .map((c) => c['name'].toString())
              .toList();
          final Set<String> uniqueCategories = {"All Products"};
          uniqueCategories.addAll(dbCategories);
          _categories = uniqueCategories.toList();
        });
      }
    } catch (e) {
      debugPrint("Could not fetch categories: $e");
    }
  }

  Future<List<Map<String, dynamic>>> _fetchProducts() async {
    final client = Supabase.instance.client;
    final productsResponse = await client
        .from('products')
        .select()
        .order('name', ascending: true);
    final variantsResponse = await client.from('product_variants').select();
    final List<Map<String, dynamic>> combinedProducts = [];

    for (var product in productsResponse) {
      final mutableProduct = Map<String, dynamic>.from(product);
      final matchingVariants = variantsResponse
          .where(
            (variant) =>
                variant['product_id'].toString() == product['id'].toString(),
          )
          .toList();
      mutableProduct['product_variants'] = matchingVariants;
      combinedProducts.add(mutableProduct);
    }
    return combinedProducts;
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

    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('products')
          .delete()
          .eq('id', product['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("${product['name']} deleted."),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _productsFuture = _fetchProducts());
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  Widget _buildAdminProductCard(Map<String, dynamic> product, bool isDark) {
    final cardColor = isDark ? Colors.grey[900]! : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final variants = product['product_variants'] as List?;
    final price = variants != null && variants.isNotEmpty
        ? (variants.first['price'] ?? 0)
        : 0;

    String weight = "1 pc";
    if (variants != null && variants.isNotEmpty) {
      final unitSize = variants.first['unit_size'];
      final unit = variants.first['unit'];
      if (unitSize != null && unit != null)
        weight = "$unitSize $unit";
      else if (unitSize != null)
        weight = "$unitSize";
    }

    final imageUrl = product['image'];

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageUrl != null && imageUrl.toString().isNotEmpty
                          ? Image.network(imageUrl, fit: BoxFit.cover)
                          : Icon(
                              Icons.image,
                              size: 50,
                              color: Colors.grey[700],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  product['name'] ?? 'Unknown',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  weight,
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  "Rs. $price",
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF16a34a),
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Column(
              children: [
                GestureDetector(
                  onTap: () => _deleteProduct(product),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final double safeWidth = screenWidth > 50 ? screenWidth : 400.0;
    final int crossAxisCount = safeWidth > 600 ? 3 : 2;

    return Scaffold(
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isAdmin
          ? ElevatedButton.icon(
              onPressed: () {
                // 👇 FIXED: Route directly to your new Dashboard!
                context.push('/admin-dashboard');
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            )
          : (_cartItems.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: InkWell(
                      onTap: () async {
                        final success = await context.push(
                          '/checkout',
                          extra: _cartItems,
                        );
                        if (success == true && mounted) {
                          setState(() => _cartItems.clear());
                          context.push('/orders');
                        }
                      },
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1b5e20),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child:
                                    _cartItems.first['image'] != null &&
                                        _cartItems.first['image']
                                            .toString()
                                            .isNotEmpty
                                    ? Image.network(
                                        _cartItems.first['image'],
                                        width: 40,
                                        height: 40,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => Container(
                                          width: 40,
                                          height: 40,
                                          color: Colors.white.withOpacity(0.2),
                                          child: const Icon(
                                            Icons.shopping_bag,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        width: 40,
                                        height: 40,
                                        color: Colors.white.withOpacity(0.2),
                                        child: const Icon(
                                          Icons.shopping_bag,
                                          color: Colors.white,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "View cart",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    "${_cartItems.length} item${_cartItems.length > 1 ? 's' : ''}",
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(right: 16.0),
                              child: Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : null),
      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(0.1),
        scrolledUnderElevation: 1,
        title: RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
              fontFamily: 'Roboto',
            ),
            children: [
              TextSpan(
                text: 'Garden',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF18181b),
                ),
              ),
              const TextSpan(
                text: 'Rich',
                style: TextStyle(color: Color(0xFF16a34a)),
              ),
            ],
          ),
        ),
        actions: [
          if (_isAdmin)
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
                    // 👇 FIXED: Route directly to your new Dashboard!
                    context.push('/admin-dashboard');
                  } else if (value == 'orders') {
                    // Route to Manage Orders
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
                            color: isDark ? Colors.white : Colors.black87,
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
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.grey[500],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 16.0, left: 8.0),
              child: InkWell(
                onTap: () => context.push('/profile'),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.person,
                    color: isDark ? Colors.white : Colors.black,
                    size: 24,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _productsFuture = _fetchProducts();
            _fetchCategories();
            final user = Supabase.instance.client.auth.currentUser;
            if (user != null && user.email != null)
              _checkAdminRole(user.email!);
          });
        },
        child: Column(
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
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF71717a),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? Colors.grey[900]
                      : const Color(0xFFf4f4f5),
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
                  final isSelected = category == _selectedCategory;
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
                                  : (isDark
                                        ? Colors.grey[300]
                                        : Colors.black87),
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
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError)
                    return const Center(child: Text("Error fetching data"));
                  if (snapshot.connectionState == ConnectionState.waiting)
                    return const Center(child: CircularProgressIndicator());
                  if (!snapshot.hasData || snapshot.data!.isEmpty)
                    return const Center(child: Text("No products available"));

                  final products = snapshot.data!.where((item) {
                    final matchesSearch = (item['name'] ?? "")
                        .toString()
                        .toLowerCase()
                        .startsWith(_searchQuery.trim().toLowerCase());
                    final dbCategory = (item['category'] ?? "")
                        .toString()
                        .trim()
                        .toLowerCase();
                    final selectedCat = _selectedCategory.trim().toLowerCase();
                    final matchesCategory =
                        _selectedCategory == "All Products" ||
                        dbCategory == selectedCat;
                    return matchesSearch && matchesCategory;
                  }).toList();

                  return CustomScrollView(
                    slivers: [
                      if (products.isEmpty)
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
                                    color: isDark
                                        ? Colors.white
                                        : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? "We couldn't find anything matching '$_searchQuery'."
                                      : "There are currently no products under '$_selectedCategory'.",
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisExtent: _isAdmin ? 280 : 345,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              if (_isAdmin) {
                                return _buildAdminProductCard(
                                  products[index],
                                  isDark,
                                );
                              } else {
                                return ProductCard(
                                  item: products[index],
                                  cartItems: _cartItems,
                                  onCartChanged: () => setState(() {}),
                                );
                              }
                            }, childCount: products.length),
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
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
