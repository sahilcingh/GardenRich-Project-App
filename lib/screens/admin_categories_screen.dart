import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminCategoriesScreen extends StatefulWidget {
  const AdminCategoriesScreen({super.key});

  @override
  State<AdminCategoriesScreen> createState() => _AdminCategoriesScreenState();
}

class _AdminCategoriesScreenState extends State<AdminCategoriesScreen> {
  final _categoryController = TextEditingController();
  final client = Supabase.instance.client;
  bool _isLoading = false;

  String _generateSlug(String name) {
    return name.toLowerCase().trim().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  }

  Future<void> _addCategory() async {
    final name = _categoryController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await client.from('categories').insert({
        'name': name,
        'slug': _generateSlug(name),
      });
      _categoryController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Category added successfully!"),
            backgroundColor: Color(0xFF16a34a),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<int> _getProductCount(String categoryName) async {
    try {
      final count = await client
          .from('products')
          .count(CountOption.exact)
          .eq('category', categoryName);

      return count;
    } catch (e) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6);
    final cardColor = isDark ? Colors.grey[900]! : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "Categories",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: cardColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. ADD NEW CATEGORY CARD
            Container(
              padding: const EdgeInsets.all(20),
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
                  const Text(
                    "ADD NEW CATEGORY",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _categoryController,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: "Category name — e.g. Beverages",
                            hintStyle: const TextStyle(color: Colors.grey),
                            filled: true,
                            fillColor: isDark
                                ? Colors.black
                                : const Color(0xFFF9FAFB),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _addCategory,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF16a34a),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
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
                              : const Icon(Icons.add, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Slug is auto-generated from the name you enter.",
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 2. ALL CATEGORIES LIST
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
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
                  const Text(
                    "ALL CATEGORIES",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder(
                    stream: client
                        .from('categories')
                        .stream(primaryKey: ['id'])
                        .order('id'),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            "Error loading categories",
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        );
                      }

                      final categories = snapshot.data ?? [];
                      if (categories.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              "No categories found.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: categories.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 32),
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final catName = cat['name'] ?? 'Unknown';
                          final isProtected = catName == "All Products";

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.sell_outlined,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(width: 16),

                              // 👇 FIXED: Bulletproof Text formatting so it never stacks vertically
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      catName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow
                                          .ellipsis, // Adds "..." if it gets too long
                                    ),
                                    Text(
                                      "slug: ${cat['slug'] ?? 'none'}",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 8),

                              // 👇 FIXED: Changed from Row to Column. They now stack vertically, freeing up tons of space!
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FutureBuilder<int>(
                                    future: _getProductCount(catName),
                                    builder: (context, countSnapshot) {
                                      final count = countSnapshot.data ?? 0;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          "$count product${count == 1 ? '' : 's'}",
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  if (isProtected) ...[
                                    const SizedBox(
                                      height: 6,
                                    ), // Spacing between the badges
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.amber.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(
                                            Icons.lock,
                                            size: 10,
                                            color: Colors.amber,
                                          ),
                                          SizedBox(width: 4),
                                          Text(
                                            "Protected",
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.amber,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    IconButton(
                                      padding: const EdgeInsets.only(top: 8),
                                      constraints: const BoxConstraints(),
                                      icon: const Icon(
                                        Icons.delete_outline,
                                        color: Colors.redAccent,
                                        size: 20,
                                      ),
                                      onPressed: () =>
                                          _deleteCategory(cat['id'], catName),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCategory(dynamic id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Category?"),
        content: Text("Are you sure you want to delete '$name'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await client.from('categories').delete().eq('id', id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("'$name' deleted."),
              backgroundColor: Colors.red,
            ),
          );
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Could not delete category. Error: $e"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}
