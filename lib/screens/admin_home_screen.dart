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
          .where((v) => v['product_id'].toString() == product['id'].toString())
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
      setState(() => _productsFuture = _fetchProducts());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: ElevatedButton.icon(
        onPressed: () => context.push('/admin-dashboard'),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Add Product",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF16a34a),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        title: const Text(
          "Admin Dashboard",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
              if (mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: "Search products...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: isDark ? Colors.grey[900] : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _productsFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                final products = snapshot.data!
                    .where(
                      (p) => p['name'].toString().toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ),
                    )
                    .toList();

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    // 👇 FIXED: This prevents the "Squashing" on restart by forcing a set height
                    mainAxisExtent: 310,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) =>
                      _buildAdminCard(products[index], isDark),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminCard(Map<String, dynamic> product, bool isDark) {
    final cardColor = isDark ? const Color(0xFF1c1c1e) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final variants = product['product_variants'] as List?;

    double price = 0;
    double mrp = 0;
    String weight = "1 pc";
    int stock = 0;

    if (variants != null && variants.isNotEmpty) {
      final v = variants.first;
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
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. IMAGE AREA (Takes 55% of the card height)
          Expanded(
            flex: 55,
            child: Stack(
              fit: StackFit.expand,
              children: [
                product['image'] != null &&
                        product['image'].toString().isNotEmpty
                    ? Image.network(product['image'], fit: BoxFit.cover)
                    : Container(
                        color: isDark ? Colors.grey[850] : Colors.grey[100],
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),

                // Best Seller Badge
                if (product['is_featured'] == true)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.star, color: Colors.amber, size: 10),
                          SizedBox(width: 4),
                          Text(
                            "BEST SELLER",
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Admin Actions
                Positioned(
                  top: 8,
                  right: 8,
                  child: Column(
                    children: [
                      _actionBtn(
                        Icons.delete_outline,
                        Colors.redAccent,
                        () => _deleteProduct(product),
                      ),
                      const SizedBox(height: 6),
                      _actionBtn(Icons.edit_outlined, Colors.blueAccent, () {}),
                    ],
                  ),
                ),

                // Discount Badge
                if (discount > 0)
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
                        "$discount% OFF",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 2. DYNAMIC TEXT AREA (Takes 45% of the card height)
          Expanded(
            flex: 45,
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 👇 TEXT OVERFLOW: Cuts off super long names safely
                  Text(
                    product['name'] ?? 'Unknown',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // 👇 FITTEDBOX 1: Safely shrinks the weight container if the phone is narrow
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "$weight (Only $stock left)",
                        style: TextStyle(color: textColor, fontSize: 11),
                      ),
                    ),
                  ),

                  // 👇 FITTEDBOX 2: Safely shrinks the price row so Rs. doesn't trigger the red stripe
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
                        if (savings > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              "Save Rs. ${savings.toInt()}",
                              style: const TextStyle(
                                color: Color(0xFF16a34a),
                                fontSize: 10,
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

Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}
