import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  late Future<List<Map<String, dynamic>>> _productsFuture;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _productsFuture = _fetchProducts();
  }

  Future<List<Map<String, dynamic>>> _fetchProducts() async {
    final client = Supabase.instance.client;
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
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Product?"),
          content: Text(
            "Are you sure you want to delete '${product['name']}'?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text(
                "Delete",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
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
            content: Text("${product['name']} deleted successfully."),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _productsFuture = _fetchProducts();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final cardColor = isDark ? Colors.grey[900]! : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,

      // Floating button so you can still add products easily!
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: ElevatedButton.icon(
        onPressed: () {
          // 👇 FIXED: Routes directly to your new Dashboard screen
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
          backgroundColor: const Color(0xFF16a34a), // GardenRich Green
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),

      appBar: AppBar(
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withOpacity(0.1),
        backgroundColor: bgColor,
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
          // 👇 The Web-Style Admin Dropdown Menu
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
                  // 👇 FIXED: Route to the new Dashboard!
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
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: "Search products to edit...",
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey.shade300,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey.shade300,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting)
                  return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError)
                  return const Center(child: Text("Error loading products"));

                final allProducts = snapshot.data ?? [];
                final filteredProducts = allProducts.where((p) {
                  final name = (p['name'] ?? "").toString().toLowerCase();
                  return name.contains(_searchQuery.toLowerCase());
                }).toList();

                if (filteredProducts.isEmpty)
                  return Center(
                    child: Text(
                      "No products found.",
                      style: TextStyle(color: textColor),
                    ),
                  );

                return GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ).copyWith(bottom: 100),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 280,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
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
                          color: isDark
                              ? Colors.grey[800]!
                              : Colors.grey.shade200,
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
                                      child:
                                          imageUrl != null &&
                                              imageUrl.toString().isNotEmpty
                                          ? Image.network(
                                              imageUrl,
                                              fit: BoxFit.cover,
                                            )
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
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
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
                                  onTap: () {}, // TODO: Edit Screen
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
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
