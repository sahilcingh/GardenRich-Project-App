import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminStoreSettingsScreen extends StatefulWidget {
  const AdminStoreSettingsScreen({super.key});

  @override
  State<AdminStoreSettingsScreen> createState() =>
      _AdminStoreSettingsScreenState();
}

class _AdminStoreSettingsScreenState extends State<AdminStoreSettingsScreen> {
  final client = Supabase.instance.client;
  bool _isLoading = true;
  bool _isSaving = false;

  // Controllers
  final _shippingCostCtrl = TextEditingController(text: '0');
  final _freeShippingAboveCtrl = TextEditingController(text: '0');
  final _minOrderValueCtrl = TextEditingController(text: '0');
  final _couponCodeCtrl = TextEditingController();
  final _discountValueCtrl = TextEditingController(text: '0');
  final _discountMinOrderCtrl = TextEditingController(text: '0');

  String _discountType = 'none'; // 'none', 'percentage', 'flat'
  DateTime? _expiryDate;

  @override
  void initState() {
    super.initState();
    _fetchSettings();
  }

  // 👇 Fetches your Key-Value pairs and applies them to the UI
  Future<void> _fetchSettings() async {
    try {
      final response = await client.from('settings').select();

      // Convert the list of rows into a simple Dictionary/Map
      final settingsMap = {
        for (var item in response) item['key']: item['value'],
      };

      if (mounted) {
        setState(() {
          _shippingCostCtrl.text = settingsMap['shipping_cost'] ?? '0';
          _freeShippingAboveCtrl.text =
              settingsMap['free_shipping_above'] ?? '0';
          _minOrderValueCtrl.text = settingsMap['minimum_order_value'] ?? '0';
          _discountType = settingsMap['discount_type'] ?? 'none';
          _couponCodeCtrl.text = settingsMap['discount_code'] == 'EMPTY'
              ? ''
              : (settingsMap['discount_code'] ?? '');
          _discountValueCtrl.text = settingsMap['discount_value'] ?? '0';
          _discountMinOrderCtrl.text = settingsMap['discount_min_order'] ?? '0';

          final expiry = settingsMap['discount_expiry'];
          if (expiry != null && expiry != 'EMPTY' && expiry.isNotEmpty) {
            _expiryDate = DateTime.tryParse(expiry);
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching settings: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 👇 Upserts multiple Key-Value rows at once
  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final updates = [
        {'key': 'shipping_cost', 'value': _shippingCostCtrl.text.trim()},
        {
          'key': 'free_shipping_above',
          'value': _freeShippingAboveCtrl.text.trim(),
        },
        {'key': 'minimum_order_value', 'value': _minOrderValueCtrl.text.trim()},
        {'key': 'discount_type', 'value': _discountType},
        {
          'key': 'discount_code',
          'value': _couponCodeCtrl.text.trim().isEmpty
              ? 'EMPTY'
              : _couponCodeCtrl.text.trim(),
        },
        {'key': 'discount_value', 'value': _discountValueCtrl.text.trim()},
        {
          'key': 'discount_min_order',
          'value': _discountMinOrderCtrl.text.trim(),
        },
        {
          'key': 'discount_expiry',
          'value': _expiryDate == null
              ? 'EMPTY'
              : _expiryDate!.toIso8601String().split('T').first,
        },
      ];

      // Upsert updates existing keys or inserts them if they don't exist
      await client.from('settings').upsert(updates, onConflict: 'key');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Settings saved successfully!"),
            backgroundColor: Color(0xFF16a34a),
          ),
        );
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF16a34a)),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _expiryDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF3F4F6);
    final cardColor = isDark ? Colors.grey[900]! : Colors.white;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xFF16a34a)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: const Text(
          "Store Settings",
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
            const Text(
              "Manage shipping, discounts and order rules.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // 1. SHIPPING CARD
            _buildCard(
              cardColor,
              isDark,
              icon: Icons.local_shipping_outlined,
              iconColor: Colors.blueAccent,
              title: "Shipping",
              subtitle: "Set delivery charges and free shipping threshold",
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildSettingField(
                          "SHIPPING CHARGE (₹)",
                          _shippingCostCtrl,
                          isDark,
                          "Set 0 for always free shipping",
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildSettingField(
                          "FREE SHIPPING ABOVE (₹)",
                          _freeShippingAboveCtrl,
                          isDark,
                          "Set 0 to disable free shipping threshold",
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildPreviewBox(
                    "Orders under ₹${_freeShippingAboveCtrl.text} will be charged ₹${_shippingCostCtrl.text} . Orders ₹${_freeShippingAboveCtrl.text} + get FREE shipping.",
                    isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. ORDER RULES CARD
            _buildCard(
              cardColor,
              isDark,
              icon: Icons.assignment_outlined,
              iconColor: Colors.orangeAccent,
              title: "Order Rules",
              subtitle: "Set minimum order requirements",
              child: _buildSettingField(
                "MINIMUM ORDER VALUE (₹)",
                _minOrderValueCtrl,
                isDark,
                "Set 0 to allow any order value. Customers can't checkout below this amount.",
              ),
            ),
            const SizedBox(height: 16),

            // 3. DISCOUNT / COUPON CARD
            _buildCard(
              cardColor,
              isDark,
              icon: Icons.local_offer_outlined,
              iconColor: const Color(0xFF16a34a),
              title: "Discount / Coupon",
              subtitle:
                  "Create a discount code customers can apply at checkout",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "DISCOUNT TYPE",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildDiscountToggle(
                        "No Discount",
                        "Disabled",
                        'none',
                        isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildDiscountToggle(
                        "% Off",
                        "Percentage",
                        'percentage',
                        isDark,
                      ),
                      const SizedBox(width: 8),
                      _buildDiscountToggle(
                        "₹ Off",
                        "Flat Amount",
                        'flat',
                        isDark,
                      ),
                    ],
                  ),
                  if (_discountType != 'none') ...[
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSettingField(
                            "COUPON CODE",
                            _couponCodeCtrl,
                            isDark,
                            "Customers enter this code",
                            isText: true,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildSettingField(
                            "DISCOUNT VALUE (${_discountType == 'percentage' ? '%' : '₹'})",
                            _discountValueCtrl,
                            isDark,
                            "",
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSettingField(
                            "MIN. ORDER FOR DISCOUNT (₹)",
                            _discountMinOrderCtrl,
                            isDark,
                            "Set 0 for no minimum",
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "EXPIRY DATE (OPTIONAL)",
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 1.1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _pickExpiryDate,
                                child: Container(
                                  height:
                                      52, // Matches the height of TextFields
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.grey[700]!
                                          : Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        _expiryDate == null
                                            ? "dd-mm-yyyy"
                                            : DateFormat(
                                                'dd-MM-yyyy',
                                              ).format(_expiryDate!),
                                        style: TextStyle(
                                          color: _expiryDate == null
                                              ? Colors.grey
                                              : (isDark
                                                    ? Colors.white
                                                    : Colors.black),
                                        ),
                                      ),
                                      Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                "Leave blank for no expiry",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildPreviewBox(
                      "Code ${_couponCodeCtrl.text.isEmpty ? '[CODE]' : _couponCodeCtrl.text} gives ${_discountType == 'percentage' ? '${_discountValueCtrl.text}%' : '₹${_discountValueCtrl.text}'} off on orders above ₹${_discountMinOrderCtrl.text}.",
                      isDark,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // SAVE BUTTON
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16a34a),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        "Save All Settings",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildCard(
    Color cardColor,
    bool isDark, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }

  Widget _buildSettingField(
    String label,
    TextEditingController controller,
    bool isDark,
    String hintText, {
    bool isText = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: TextField(
            controller: controller,
            keyboardType: isText ? TextInputType.text : TextInputType.number,
            onChanged: (val) => setState(() {}), // Real-time preview updates
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              prefixIcon: isText
                  ? null
                  : const Icon(
                      Icons.currency_rupee,
                      size: 16,
                      color: Colors.grey,
                    ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 0,
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
        ),
        const SizedBox(height: 6),
        if (hintText.isNotEmpty)
          Text(
            hintText,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
      ],
    );
  }

  Widget _buildDiscountToggle(
    String title,
    String subtitle,
    String type,
    bool isDark,
  ) {
    final isActive = _discountType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _discountType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFF16a34a)
                : (isDark ? Colors.grey[800] : Colors.grey[50]),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? const Color(0xFF16a34a)
                  : (isDark ? Colors.grey[700]! : Colors.grey.shade200),
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isActive
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10,
                  color: isActive ? Colors.white70 : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewBox(String text, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFf0fdf4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Color(0xFF166534)),
          children: [
            const TextSpan(
              text: "Preview: ",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }
}
