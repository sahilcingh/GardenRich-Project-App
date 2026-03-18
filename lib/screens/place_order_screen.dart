import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

// 👇 IMPORT FOR EMAIL SERVICE
import '../services/email_service.dart';

class PlaceOrderScreen extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final double total;

  const PlaceOrderScreen({super.key, required this.items, required this.total});

  @override
  State<PlaceOrderScreen> createState() => _PlaceOrderScreenState();
}

class _PlaceOrderScreenState extends State<PlaceOrderScreen> {
  late Future<List<Map<String, dynamic>>> _addressesFuture;
  Map<String, dynamic>? _selectedAddress;
  bool _isProcessing = false;

  late final TextEditingController _emailController = TextEditingController(
    text: Supabase.instance.client.auth.currentUser?.email ?? '',
  );
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _addressesFuture = _fetchAddresses();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // --- CALCULATION HELPERS ---
  double get _subtotalAmount {
    double total = 0;
    for (var item in widget.items) {
      total +=
          ((item['price'] as num?)?.toDouble() ?? 0) * (item['qty'] as int);
    }
    return total;
  }

  double get _shippingFee => 40.0;

  int get _totalItems {
    int total = 0;
    for (var item in widget.items) {
      total += item['qty'] as int;
    }
    return total;
  }

  Future<List<Map<String, dynamic>>> _fetchAddresses() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    final response = await Supabase.instance.client
        .from('addresses')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final addresses = List<Map<String, dynamic>>.from(response);

    if (addresses.isNotEmpty) {
      _selectedAddress = addresses.first;
      _phoneController.text = _selectedAddress!['phone']?.toString() ?? '';
    }

    return addresses;
  }

  void _showErrorPopup(String title, String message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(color: isDark ? Colors.grey[300] : Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "OK",
                style: TextStyle(
                  color: Color(0xFF92D050),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showConfirmationDialog() {
    // 1. We check if all fields are filled BEFORE showing the popup
    final email = _emailController.text.trim();
    final rawPhone = _phoneController.text.trim();
    final cleanPhone = rawPhone.replaceAll(RegExp(r'\D'), '');

    if (email.isEmpty ||
        rawPhone.isEmpty ||
        cleanPhone.length != 10 ||
        _selectedAddress == null) {
      // If data is missing, we just trigger the normal order function
      // so it can show your existing error popups!
      _placeOrderNow();
      return;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 2. Show the beautiful confirmation dialog
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.shopping_bag_outlined, color: Color(0xFF92D050)),
            const SizedBox(width: 10),
            Text(
              "Confirm Order",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to place this order for Rs. ${widget.total.toInt()}? You will pay via Cash on Delivery.",
          style: TextStyle(
            color: isDark ? Colors.grey[300] : Colors.grey[700],
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx), // Closes the dialog, does nothing
            child: Text(
              "Cancel",
              style: TextStyle(
                color: Colors.grey[500],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx); // Closes the dialog
              _placeOrderNow(); // 👇 ACTUALLY PLACES THE ORDER!
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF92D050),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              "Yes, Place Order",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _placeOrderNow() async {
    final email = _emailController.text.trim();
    final rawPhone = _phoneController.text.trim();

    // Clean the phone number (removes any spaces, dashes, or brackets the user might type)
    final cleanPhone = rawPhone.replaceAll(RegExp(r'\D'), '');

    if (email.isEmpty || rawPhone.isEmpty) {
      _showErrorPopup(
        "Missing Information",
        "Please provide both your Email Address and Phone Number in the Contact Information section.",
      );
      return;
    }

    // 10-Digit Phone Number Validation
    if (cleanPhone.length != 10) {
      _showErrorPopup(
        "Invalid Phone Number",
        "Please enter a valid 10-digit mobile number.",
      );
      return;
    }

    if (_selectedAddress == null) {
      _showErrorPopup(
        "Missing Address",
        "Please select a Shipping Address before placing your order.",
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("User not logged in");

      final addressId =
          _selectedAddress!['address_id'] ??
          _selectedAddress!['uuid'] ??
          _selectedAddress!['id'];

      final orderData = {
        'user_id': user.id,
        'address_id': addressId,
        'email': email,
        'phone': cleanPhone, // Save the cleanly formatted 10-digit number
        'status': 'pending',
        'total': widget.total,
      };

      final orderResponse = await Supabase.instance.client
          .from('orders')
          .insert(orderData)
          .select()
          .single();

      final newOrderId = orderResponse['id'];

      final List<Map<String, dynamic>> orderItems = widget.items.map((item) {
        return {
          'order_id': newOrderId,
          'product_name': item['name'],
          'price': item['price'],
          'quantity': item['qty'],
          'product_image': item['image'],
          'variant_weight':
              item['weight'] ??
              item['variant_weight'], // Ensure weight is tracked
        };
      }).toList();

      try {
        await Supabase.instance.client.from('order_items').insert(orderItems);
      } catch (itemError) {
        debugPrint("❌ ORDER ITEMS INSERT FAILED: $itemError");
        debugPrint("❌ Items attempted: $orderItems");
      }

      // 3. Direct Stock Deduction (No SQL/RPC needed!)
      for (var item in widget.items) {
        final variantId = item['variant_id'];
        final qtyOrdered = item['qty'] as int;

        if (variantId != null) {
          try {
            // A. Fetch the current stock from the database
            final variantData = await Supabase.instance.client
                .from('product_variants')
                .select('stock')
                .eq('id', variantId)
                .single();

            // B. Calculate the new stock
            int currentStock =
                int.tryParse(variantData['stock']?.toString() ?? '0') ?? 0;
            int newStock = currentStock - qtyOrdered;

            // Prevent stock from going into negative numbers
            if (newStock < 0) newStock = 0;

            // C. Update the database directly
            await Supabase.instance.client
                .from('product_variants')
                .update({'stock': newStock})
                .eq('id', variantId);
          } catch (e) {
            debugPrint("Failed to update stock for variant $variantId: $e");
          }
        }
      }

      // 👇 4. FIRE THE AUTOMATED EMAIL (to Customer AND Admin)!
      try {
        final firstName = _selectedAddress!['first_name'] ?? '';
        final lastName = _selectedAddress!['last_name'] == 'EMPTY'
            ? ''
            : (_selectedAddress!['last_name'] ?? '');
        final custName = '$firstName $lastName'.trim().isEmpty
            ? 'Customer'
            : '$firstName $lastName'.trim();

        // Grab the full address string for the Admin email
        final fullAddress =
            "${_selectedAddress!['address']}, ${_selectedAddress!['city']}, ${_selectedAddress!['pin_code']}";

        await EmailService.sendOrderConfirmation(
          customerEmail: email,
          customerName: custName,
          orderId: newOrderId.toString(),
          cartItems: widget.items,
          totalAmount: widget.total.toInt(),
          customerPhone: cleanPhone, // 👈 Passed to Admin
          customerAddress: fullAddress, // 👈 Passed to Admin
        );
      } catch (emailError) {
        // If the email fails, we catch the error silently so the user still sees the Success Screen!
        debugPrint("Failed to send order email: $emailError");
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("🎉 Order Placed Successfully!"),
            backgroundColor: Color(0xFF92D050),
          ),
        );

        context.pop(true);
      }
    } catch (e) {
      _showErrorPopup("Order Failed", "Something went wrong: $e");
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildStepCard({
    required String step,
    required String title,
    Widget? trailing,
    required Widget child,
    required bool isDark,
    required Color cardColor,
    required Color textColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    step,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }

  Widget _buildOrderReviewCard(bool isDark, Color cardColor, Color textColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
          Text(
            "ORDER REVIEW ($_totalItems ITEMS)",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 20),

          ...widget.items.map((item) {
            final itemPrice = (item['price'] as num?)?.toInt() ?? 0;

            final String imageUrl = item['image']?.toString() ?? "";
            final bool hasValidImage =
                imageUrl.isNotEmpty && imageUrl.startsWith('http');

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: hasValidImage
                        ? Image.network(
                            imageUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  width: 48,
                                  height: 48,
                                  color: Colors.grey[200],
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey[400],
                                    size: 24,
                                  ),
                                ),
                          )
                        : Container(
                            width: 48,
                            height: 48,
                            color: Colors.grey[200],
                            child: Icon(
                              Icons.image,
                              color: Colors.grey[400],
                              size: 24,
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['name'] ?? "Unknown",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${item['weight'] ?? ''}",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          "Qty: ${item['qty']}",
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "Rs. ${itemPrice * (item['qty'] as int)}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            );
          }),

          const Divider(height: 30),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Subtotal", style: TextStyle(color: Colors.grey[600])),
              Text(
                "Rs. ${_subtotalAmount.toInt()}",
                style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    style: TextStyle(fontSize: 14, color: textColor),
                    decoration: InputDecoration(
                      hintText: "PROMO CODE",
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[400],
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.grey[800] : Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.grey[700]!
                              : Colors.grey.shade300,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                          color: isDark
                              ? Colors.grey[700]!
                              : Colors.grey.shade300,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(
                          color: Colors.black,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.grey[800] : Colors.black,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    "Apply",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Shipping", style: TextStyle(color: Colors.grey[600])),
              Text(
                "Rs. ${_shippingFee.toInt()}",
                style: TextStyle(color: textColor, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Taxes", style: TextStyle(color: Colors.grey[600])),
              Text(
                "Included",
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),

          const Divider(height: 30),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "To Pay",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Text(
                "Rs. ${widget.total.toInt()}",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF92D050),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          "Checkout",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildStepCard(
                  step: "1",
                  title: "Contact Information",
                  isDark: isDark,
                  cardColor: cardColor,
                  textColor: textColor,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(color: textColor, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Email Address",
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFF92D050),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(color: textColor, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: "Phone Number",
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey.shade300,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey[700]!
                                    : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(
                                color: Color(0xFF92D050),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                _buildStepCard(
                  step: "2",
                  title: "Shipping Address",
                  isDark: isDark,
                  cardColor: cardColor,
                  textColor: textColor,
                  trailing: TextButton(
                    onPressed: () => context.push('/address-book').then((_) {
                      setState(() {
                        _addressesFuture = _fetchAddresses();
                      });
                    }),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF92D050),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    child: const Text("+ Add New Address"),
                  ),
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _addressesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return const Text("Failed to load addresses.");
                      }

                      final addresses = snapshot.data ?? [];

                      if (addresses.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 10.0),
                          child: Text("No addresses found. Please add one."),
                        );
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: addresses.length,
                        itemBuilder: (context, index) {
                          final addr = addresses[index];
                          final isSelected =
                              _selectedAddress != null &&
                              _selectedAddress!['id'] == addr['id'];
                          final firstName = addr['first_name'] ?? '';
                          final lastName = addr['last_name'] == 'EMPTY'
                              ? ''
                              : (addr['last_name'] ?? '');
                          final fullName = '$firstName $lastName'.trim();

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedAddress = addr;
                                _phoneController.text =
                                    addr['phone']?.toString() ?? '';
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF92D050).withOpacity(0.05)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF92D050)
                                      : Colors.grey.shade300,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                    color: isSelected
                                        ? const Color(0xFF92D050)
                                        : Colors.grey,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          fullName.isNotEmpty
                                              ? fullName
                                              : 'No Name',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: textColor,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "${addr['address']}, ${addr['city']}, ${addr['pin_code']}",
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            height: 1.4,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          addr['phone'] ?? '',
                                          style: TextStyle(
                                            color: Colors.grey[600],
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
                      );
                    },
                  ),
                ),

                _buildStepCard(
                  step: "3",
                  title: "Payment Method",
                  isDark: isDark,
                  cardColor: cardColor,
                  textColor: textColor,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.radio_button_unchecked,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Online Payment",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey,
                                  ),
                                ),
                                Text(
                                  "Coming Soon",
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF92D050).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF92D050),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.radio_button_checked,
                              color: Color(0xFF92D050),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Cash On Delivery",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                Text(
                                  "Pay when your order arrives",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
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

                _buildOrderReviewCard(isDark, cardColor, textColor),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: SafeArea(
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _showConfirmationDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1b5e20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isProcessing
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          "PLACE ORDER NOW →",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
