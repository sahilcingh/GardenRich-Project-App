import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart'; // 👇 NEW: For Camera/Gallery

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // Form Controllers
  final _nameController = TextEditingController();
  String _selectedCategory = "Select a category";
  final List<String> _categories = [
    "Select a category",
    "Food",
    "Skincare",
    "Dairy",
    "Grocery",
  ];

  // Image Picker State
  XFile? _imageFile;

  // Dynamic Variant Rows
  final List<Map<String, TextEditingController>> _variants = [];
  bool _isFeatured = false;

  @override
  void initState() {
    super.initState();
    _addVariantRow(); // Add one empty row by default
  }

  void _addVariantRow() {
    setState(() {
      _variants.add({
        'qty': TextEditingController(),
        'unit': TextEditingController(text: 'ml'),
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

  // 👇 NEW: Bottom Sheet to choose Camera or Gallery
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

  // 👇 NEW: Actually opens the camera/gallery and grabs the image
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6);
    final cardColor = isDark ? Colors.grey[900]! : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF18181b);

    return Scaffold(
      backgroundColor: bgColor,
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
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white : const Color(0xFF18181b),
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
              ],
            ),
          ),
        ],
      ),

      // Mobile Only Drawer (Hidden on wide screens automatically by our layout)
      drawer: Drawer(
        backgroundColor: cardColor,
        child: SafeArea(child: _buildSidebarMenu(textColor, isDark, cardColor)),
      ),

      // 👇 NEW: Responsive Layout (Side-by-side on Web/Tablet, Stacked on Mobile)
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWideScreen = constraints.maxWidth > 900;

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Show the permanent sidebar ONLY if the screen is wide enough
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
                  child: _buildSidebarMenu(textColor, isDark, cardColor),
                ),

              // The actual form takes up the rest of the space
              Expanded(child: _buildFormContent(textColor, isDark, cardColor)),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SIDEBAR WIDGET (Shared between wide-screen mode and mobile Drawer)
  // ---------------------------------------------------------------------------
  Widget _buildSidebarMenu(Color textColor, bool isDark, Color cardColor) {
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
                  if (Scaffold.of(context).isDrawerOpen)
                    Navigator.pop(context); // Close drawer if open
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
            onTap: () {},
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
            onTap: () {},
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
              if (Scaffold.of(context).isDrawerOpen) Navigator.pop(context);
              context.go('/home'); // Back to main store
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
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
                        if (newValue != null)
                          setState(() => _selectedCategory = newValue);
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
                          _buildColumnHeader("UNIT", 80),
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
                                "ml",
                                80,
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
                        onPressed:
                            _showImageSourceDialog, // 👇 NEW: Opens Camera/Gallery menu!
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
                          // 👇 NEW: Displays the selected file name dynamically
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
                    onPressed: () {
                      // TODO: Map controllers and insert into Supabase
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? Colors.white
                          : const Color(0xFF18181b),
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
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
