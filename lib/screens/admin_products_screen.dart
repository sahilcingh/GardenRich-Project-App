import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  late Future<List<Map<String, dynamic>>> _productsFuture;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _productsFuture = _fetchProducts();
  }

  // Fetch all products just like the Home Screen
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

  // The Delete Logic
  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Product?"),
          content: Text(
            "Are you sure you want to delete '${product['name']}'? This action cannot be undone.",
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
      // Delete from Supabase. (If your database is set up with cascading deletes,
      // deleting the product will also delete its variants automatically!)
      await Supabase.instance.client
          .from('products')
          .delete()
          .eq('id', product['id']);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("${product['name']} deleted successfully."),
          backgroundColor: Colors.red,
        ),
      );

      // Refresh the list
      setState(() {
        _productsFuture = _fetchProducts();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error deleting product: $e")));
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
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Text(
          "Manage Products",
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to store settings or general admin dashboard later
            },
          ),
        ],
      ),
      // 👇 Floating Action Button for Add Product
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Navigate to Add Product Screen
          // context.push('/admin/add-product');
        },
        backgroundColor: const Color(0xFF16a34a),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Add Product",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: "Search products to edit...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Center(child: Text("Error loading products"));
                }

                final allProducts = snapshot.data ?? [];
                final filteredProducts = allProducts.where((p) {
                  final name = (p['name'] ?? "").toString().toLowerCase();
                  return name.contains(_searchQuery.toLowerCase());
                }).toList();

                if (filteredProducts.isEmpty) {
                  return const Center(child: Text("No products found."));
                }

                // The Product Grid
                return GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ).copyWith(bottom: 100),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisExtent: 280, // Height of each card
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    final variants = product['product_variants'] as List?;
                    final price = variants != null && variants.isNotEmpty
                        ? variants.first['price']
                        : 0;
                    final weight = variants != null && variants.isNotEmpty
                        ? "${variants.first['unit_size']} ${variants.first['unit']}"
                        : "N/A";

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
                          // Product Info
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Image
                                Expanded(
                                  child: Center(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: product['image_url'] != null
                                          ? Image.network(
                                              product['image_url'],
                                              fit: BoxFit.cover,
                                            )
                                          : const Icon(
                                              Icons.image,
                                              size: 50,
                                              color: Colors.grey,
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Text Details
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
                                    color: Colors.grey[600],
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

                          // 👇 The Floating Admin Action Buttons (Matches your Web Design!)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Column(
                              children: [
                                // Delete Button (Red)
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
                                // Edit Button (Blue)
                                GestureDetector(
                                  onTap: () {
                                    // TODO: Pass product data to Edit Screen
                                  },
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
