import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import '../widgets/product_card.dart';
import '../widgets/home_footer.dart';
import '../widgets/cart_threshold_banner.dart';

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

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _productsFuture = _fetchProducts();
    _fetchCategories();

    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _silentRefresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _silentRefresh() {
    _fetchCategories();
    setState(() {
      _productsFuture = _fetchProducts();
    });
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

  Widget _buildCartIcon(bool isDark) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          Icons.shopping_bag_outlined,
          size: 28,
          color: isDark ? Colors.white : Colors.black87,
        ),
        if (_cartItems.isNotEmpty)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Color(0xFF16a34a),
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Center(
                child: Text(
                  '${_cartItems.length}',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _navigateToCart() async {
    final returnedData = await context.push('/checkout', extra: _cartItems);

    if (!mounted) return;

    if (returnedData == true) {
      setState(() => _cartItems.clear());
      context.push('/orders');
    } else if (returnedData is List) {
      setState(() {
        _cartItems.clear();
        for (var item in returnedData) {
          _cartItems.add(Map<String, dynamic>.from(item));
        }
      });
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final screenWidth = MediaQuery.of(context).size.width;
    final double textScale = MediaQuery.textScalerOf(context).scale(1.0);

    int crossAxisCount = 3;
    if (screenWidth < 360) {
      crossAxisCount = 2;
    } else if (screenWidth >= 600 && screenWidth < 900) {
      crossAxisCount = 4;
    } else if (screenWidth >= 900) {
      crossAxisCount = 5;
    }

    final double totalHorizontalPadding = 32.0 + ((crossAxisCount - 1) * 16.0);
    final double cardWidth =
        (screenWidth - totalHorizontalPadding) / crossAxisCount;
    final double dynamicExtent = cardWidth + (175.0 * textScale) + 10.0;

    // 👇 FIXED: Safely calculates the cart total without throwing Null errors!
    double currentCartTotal = 0.0;
    for (var item in _cartItems) {
      final int qty = item['qty'] as int? ?? 1;
      currentCartTotal += ((item['price'] as num?)?.toDouble() ?? 0) * qty;
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFf4f4f5),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _cartItems.isNotEmpty
          ? CartThresholdBanner(
              cartTotal: currentCartTotal,
              onViewCart: _navigateToCart,
            )
          : null,

      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(0.1),
        elevation: 0,
        scrolledUnderElevation: 1,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: RichText(
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
        ),
        actions: [
          IconButton(
            icon: _buildCartIcon(isDark),
            onPressed: _navigateToCart,
            splashRadius: 24,
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: InkWell(
              onTap: () => context.push('/profile'),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person,
                  color: isDark ? Colors.white : Colors.black87,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),

      body: RefreshIndicator(
        color: const Color(0xFF16a34a),
        backgroundColor: isDark ? Colors.grey[800] : Colors.white,
        onRefresh: () async {
          setState(() {
            _productsFuture = _fetchProducts();
            _fetchCategories();
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
                  fillColor: isDark ? Colors.grey[900] : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: isDark ? Colors.grey[800]! : Colors.grey.shade300,
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
                  if (snapshot.hasError) {
                    return const Center(child: Text("Error fetching data"));
                  }

                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF16a34a),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text("No products available"));
                  }

                  final products = snapshot.data!.where((item) {
                    final matchesSearch = (item['name'] ?? "")
                        .toString()
                        .toLowerCase()
                        .contains(_searchQuery.trim().toLowerCase());

                    final dbCategory = (item['category'] ?? "")
                        .toString()
                        .trim()
                        .toLowerCase();
                    final selectedCat = _selectedCategory.trim().toLowerCase();
                    final selectedCatSlug = selectedCat.replaceAll(' ', '-');

                    final matchesCategory =
                        _selectedCategory == "All Products" ||
                        dbCategory == selectedCat ||
                        dbCategory == selectedCatSlug;
                    return matchesSearch && matchesCategory;
                  }).toList();

                  return CustomScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
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
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                          sliver: SliverGrid(
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  mainAxisExtent: dynamicExtent,
                                ),
                            delegate: SliverChildBuilderDelegate((
                              context,
                              index,
                            ) {
                              return ProductCard(
                                item: products[index],
                                cartItems: _cartItems,
                                onCartChanged: () => setState(() {}),
                              );
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
