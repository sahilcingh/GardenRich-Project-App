import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Form Controllers
  final _nameController = TextEditingController();

  // Dynamic categories list
  List<String> _categories = [];
  String? _selectedCategory;
  bool _isLoadingCategories = true;

  // Image Picker State
  XFile? _imageFile;
  bool _isLoading = false;

  // Dynamic Variant Rows
  final List<Map<String, TextEditingController>> _variants = [];
  bool _isFeatured = false;

  @override
  void initState() {
    super.initState();
    _addVariantRow(); // Add one empty row by default
    _fetchCategories(); // Fetch dynamic categories on load
  }

  // Function to grab categories from Supabase
  Future<void> _fetchCategories() async {
    try {
      final response = await Supabase.instance.client
          .from('categories')
          .select('name')
          .order('id');

      if (mounted) {
        setState(() {
          // Extract names, ignoring "All Products"
          _categories = response
              .map((cat) => cat['name'].toString())
              .where((name) => name != 'All Products')
              .toList();

          // Auto-select the first one if available
          if (_categories.isNotEmpty) {
            _selectedCategory = _categories.first;
          }

          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
      if (mounted) setState(() => _isLoadingCategories = false);
    }
  }

  void _addVariantRow() {
    setState(() {
      _variants.add({
        'qty': TextEditingController(),
        'unit': TextEditingController(text: 'g'),
        'price': TextEditingController(),
        'mrp': TextEditingController(),
        'stock': TextEditingController(),
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    for (var variant in _variants) {
      for (var controller in variant.values) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  // Bottom Sheet to choose Camera or Gallery
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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

  // Actually opens the camera/gallery and grabs the image
  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context); // Close the bottom sheet first
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80,
      ); // compress slightly for speed
      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Failed to pick image: $e")));
      }
    }
  }

  // SAVING TO SUPABASE
  Future<void> _submitProduct() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a product name")),
      );
      return;
    }
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select a category")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final client = Supabase.instance.client;
      String imageUrl = '';

      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        final fileExt = _imageFile!.name.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        await client.storage
            .from('product-images')
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: FileOptions(contentType: 'image/$fileExt'),
            );
        imageUrl = client.storage.from('product-images').getPublicUrl(fileName);
      }

      final productData = {
        'name': _nameController.text.trim(),
        'category': _selectedCategory,
        'image': imageUrl,
      };

      final productResponse = await client
          .from('products')
          .insert(productData)
          .select()
          .single();
      final productId = productResponse['id'];

      final List<Map<String, dynamic>> variantsData = [];
      for (var variant in _variants) {
        final qty = variant['qty']!.text.trim();
        final unit = variant['unit']!.text.trim();
        final price = variant['price']!.text.trim();
        final mrp = variant['mrp']!.text.trim();
        final stock = variant['stock']!.text.trim();

        if (qty.isNotEmpty && price.isNotEmpty) {
          variantsData.add({
            'product_id': productId,
            'weight': '$qty $unit',
            'price': double.tryParse(price) ?? 0,
            'mrp': double.tryParse(mrp) ?? 0,
            'stock': int.tryParse(stock) ?? 0,
          });
        }
      }

      if (variantsData.isNotEmpty) {
        await client.from('product_variants').insert(variantsData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Product listed successfully!"),
            backgroundColor: Color(0xFF16a34a),
          ),
        );
        context.go('/admin-home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6);
    final cardColor = isDark ? Colors.grey[900]! : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF18181b);

    // 👇 Grab screen width to make dynamic layout decisions
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: cardColor,
        elevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
        title: FittedBox(
          // 👇 FIXED: Prevents title from wrapping onto two lines
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: RichText(
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
                  context.go('/admin-home');
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
                      // 👇 FIXED: Hides "Admin" text on small screens to save space
                      if (screenWidth > 400) ...[
                        const SizedBox(width: 8),
                        Text(
                          "Admin",
                          style: TextStyle(
                            color: textColor,
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

      // Mobile Only Drawer
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

      // Responsive Layout
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth > 900;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isWideScreen)
                Container(
                  width: 250,
                  margin: const EdgeInsets.fromLTRB(20, 20, 0, 20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
                    ),
                  ),
                  child: _buildSidebarMenu(
                    textColor,
                    isDark,
                    cardColor,
                    isDrawer: false,
                  ),
                ),

              Expanded(child: _buildFormContent(textColor, isDark, cardColor)),
            ],
          );
        },
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
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : const Color(0xFF18181b),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListTile(
                leading: const Icon(Icons.add, color: Colors.white),
                title: const Text(
                  "Add Product",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  if (isDrawer) {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
          ),
          ListTile(
            leading: Icon(Icons.sell_outlined, color: Colors.grey[600]),
            title: Text(
              "Categories",
              style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
            ),
            onTap: () async {
              if (isDrawer) {
                Navigator.pop(context);
              }
              await context.push('/admin-categories');
              _fetchCategories();
            },
          ),
          ListTile(
            leading: Icon(Icons.settings_outlined, color: Colors.grey[600]),
            title: Text(
              "Store Settings",
              style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
            ),
            onTap: () async {
              if (isDrawer) {
                Navigator.pop(context);
              }
              await context.push('/admin-settings');
            },
          ),
          ListTile(
            leading: Icon(Icons.assignment_outlined, color: Colors.grey[600]),
            title: Text(
              "Orders",
              style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
            ),
            onTap: () {
              if (isDrawer) {
                Navigator.pop(context);
              }
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
              if (isDrawer) {
                Navigator.pop(context);
              }
              context.go('/admin-home');
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ADD PRODUCT FORM WIDGET
  // ---------------------------------------------------------------------------
  Widget _buildFormContent(Color textColor, bool isDark, Color cardColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Add New Product",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Fill in the details to list a new item in the GardenRich store.",
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(24),
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
                _buildLabel("PRODUCT NAME"),
                _buildTextField(
                  _nameController,
                  "e.g. Amul Fresh Milk",
                  isDark,
                ),
                const SizedBox(height: 20),

                _buildLabel("CATEGORY"),
                _isLoadingCategories
                    ? const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(
                          child: SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDark
                                ? Colors.grey[700]!
                                : Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            isExpanded: true,
                            dropdownColor: cardColor,
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Colors.grey,
                            ),
                            items: _categories.map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value,
                                  style: TextStyle(color: textColor),
                                ),
                              );
                            }).toList(),
                            onChanged: (newValue) {
                              if (newValue != null) {
                                setState(() => _selectedCategory = newValue);
                              }
                            },
                          ),
                        ),
                      ),
                const SizedBox(height: 24),

                _buildLabel("PACK SIZES / VARIANTS"),
                Text(
                  "Each size will appear as a dropdown option on the product card.",
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(height: 16),

                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildColumnHeader("QTY", 80),
                          _buildColumnHeader("UNIT", 100),
                          _buildColumnHeader("PRICE ₹", 100),
                          _buildColumnHeader("MRP ₹", 100),
                          _buildColumnHeader("STOCK", 100),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ..._variants.map((variant) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            children: [
                              _buildGridTextField(
                                variant['qty']!,
                                "500",
                                80,
                                isDark,
                              ),
                              _buildGridTextField(
                                variant['unit']!,
                                "g",
                                110,
                                isDark,
                              ),
                              _buildGridTextField(
                                variant['price']!,
                                "0",
                                100,
                                isDark,
                                isNumber: true,
                              ),
                              _buildGridTextField(
                                variant['mrp']!,
                                "0",
                                100,
                                isDark,
                                isNumber: true,
                              ),
                              _buildGridTextField(
                                variant['stock']!,
                                "0",
                                100,
                                isDark,
                                isNumber: true,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),

                TextButton.icon(
                  onPressed: _addVariantRow,
                  icon: const Icon(
                    Icons.add,
                    color: Color(0xFF16a34a),
                    size: 18,
                  ),
                  label: const Text(
                    "Add Another Size",
                    style: TextStyle(
                      color: Color(0xFF16a34a),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    alignment: Alignment.centerLeft,
                  ),
                ),
                const SizedBox(height: 24),

                _buildLabel("PRODUCT IMAGE"),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      ElevatedButton(
                        onPressed: _showImageSourceDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.grey[800]
                              : const Color(0xFF18181b),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        child: const Text(
                          "Choose File",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _imageFile != null
                              ? _imageFile!.name
                              : "No file chosen",
                          style: TextStyle(
                            color: _imageFile != null
                                ? const Color(0xFF16a34a)
                                : Colors.grey[600],
                            fontSize: 14,
                            fontWeight: _imageFile != null
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CheckboxListTile(
                    value: _isFeatured,
                    onChanged: (val) =>
                        setState(() => _isFeatured = val ?? false),
                    activeColor: const Color(0xFF16a34a),
                    title: Text(
                      "Mark as Featured / Best Seller",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: textColor,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      "Featured products appear at the top of the store",
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.white
                          : const Color(0xFF18181b),
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(
                            color: Color(0xFF16a34a),
                          )
                        : const Text(
                            "List Product",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER WIDGETS
  // ---------------------------------------------------------------------------
  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Colors.grey[500],
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    bool isDark,
  ) {
    return TextField(
      controller: controller,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF16a34a), width: 2),
        ),
      ),
    );
  }

  Widget _buildColumnHeader(String title, double width) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.only(right: 8.0),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: Colors.grey[500],
          ),
        ),
      ),
    );
  }

  Widget _buildGridTextField(
    TextEditingController controller,
    String hint,
    double width,
    bool isDark, {
    bool isNumber = false,
  }) {
    if (hint == "g") {
      final units = ['g', 'kg', 'ml', 'L', 'pc', 'bunch', 'dozen'];
      if (!units.contains(controller.text)) controller.text = 'g';

      return Container(
        width: width,
        padding: const EdgeInsets.only(right: 8.0),
        child: DropdownButtonFormField<String>(
          value: controller.text,
          isExpanded: true,
          dropdownColor: isDark ? Colors.grey[800] : Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down, size: 16),
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF16a34a)),
            ),
          ),
          items: units.map((String u) {
            return DropdownMenuItem(
              value: u,
              child: Text(u, overflow: TextOverflow.ellipsis, maxLines: 1),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) setState(() => controller.text = val);
          },
        ),
      );
    }

    return Container(
      width: width,
      padding: const EdgeInsets.only(right: 8.0),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400]),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(
              color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFF16a34a)),
          ),
        ),
      ),
    );
  }
}
