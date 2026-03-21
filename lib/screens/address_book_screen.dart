import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class AddressBookScreen extends StatefulWidget {
  const AddressBookScreen({super.key});

  @override
  State<AddressBookScreen> createState() => _AddressBookScreenState();
}

class _AddressBookScreenState extends State<AddressBookScreen> {
  late Future<List<Map<String, dynamic>>> _addressesFuture;

  @override
  void initState() {
    super.initState();
    _addressesFuture = _fetchAddresses();
  }

  Future<List<Map<String, dynamic>>> _fetchAddresses() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return [];

    // Fetches addresses and puts the default one at the very top of the list!
    final response = await Supabase.instance.client
        .from('addresses')
        .select()
        .eq('user_id', user.id)
        .order('is_default', ascending: false)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  void _refreshAddresses() {
    setState(() {
      _addressesFuture = _fetchAddresses();
    });
  }

  Future<void> _deleteAddress(String id) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          "Delete Address",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          "Are you sure you want to delete this address? This action cannot be undone.",
          style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text(
              "Delete",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.from('addresses').delete().eq('id', id);
        _refreshAddresses();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Address deleted successfully"),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    }
  }

  void _showAddressSheet(
    BuildContext context, {
    Map<String, dynamic>? existingAddress,
  }) {
    final isEditing = existingAddress != null;

    final firstNameCtrl = TextEditingController(
      text: isEditing ? existingAddress['first_name'] : '',
    );
    final lastNameCtrl = TextEditingController(
      text: isEditing && existingAddress['last_name'] != 'EMPTY'
          ? existingAddress['last_name']
          : '',
    );
    final phoneCtrl = TextEditingController(
      text: isEditing ? existingAddress['phone'] : '',
    );
    final addressCtrl = TextEditingController(
      text: isEditing ? existingAddress['address'] : '',
    );
    final cityCtrl = TextEditingController(
      text: isEditing ? existingAddress['city'] : '',
    );
    final pinCodeCtrl = TextEditingController(
      text: isEditing ? existingAddress['pin_code'] : '',
    );

    // 👇 NEW: State for the default address toggle
    bool isDefault = isEditing
        ? (existingAddress['is_default'] ?? false)
        : false;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEditing ? "Edit Address" : "Add New Address",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            "First Name",
                            firstNameCtrl,
                            Icons.person,
                            isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            "Last Name",
                            lastNameCtrl,
                            Icons.person_outline,
                            isDark,
                          ),
                        ),
                      ],
                    ),
                    _buildTextField(
                      "Phone Number",
                      phoneCtrl,
                      Icons.phone,
                      isDark,
                      isNumber: true,
                      maxLength: 10,
                    ),
                    _buildTextField(
                      "House/Flat, Street",
                      addressCtrl,
                      Icons.home,
                      isDark,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            "City",
                            cityCtrl,
                            Icons.location_city,
                            isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            "Pincode",
                            pinCodeCtrl,
                            Icons.pin_drop,
                            isDark,
                            isNumber: true,
                            maxLength: 6,
                          ),
                        ),
                      ],
                    ),

                    // 👇 NEW: The "Set as Default" Switch
                    SwitchListTile(
                      title: Text(
                        "Set as default address",
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      value: isDefault,
                      activeColor: const Color(0xFF16a34a),
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setModalState(() => isDefault = val);
                      },
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                if (firstNameCtrl.text.trim().isEmpty ||
                                    phoneCtrl.text.trim().isEmpty ||
                                    addressCtrl.text.trim().isEmpty ||
                                    cityCtrl.text.trim().isEmpty ||
                                    pinCodeCtrl.text.trim().isEmpty) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Please fill all required fields",
                                      ),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                  return;
                                }
                                if (phoneCtrl.text.trim().length != 10) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Phone number must be exactly 10 digits",
                                      ),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                  return;
                                }
                                if (pinCodeCtrl.text.trim().length != 6) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Pincode must be exactly 6 digits",
                                      ),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                  return;
                                }

                                setModalState(() => isLoading = true);
                                try {
                                  final user =
                                      Supabase.instance.client.auth.currentUser;

                                  // 👇 NEW: If this is set as default, remove default from all other addresses first!
                                  if (isDefault) {
                                    await Supabase.instance.client
                                        .from('addresses')
                                        .update({'is_default': false})
                                        .eq('user_id', user!.id);
                                  }

                                  final data = {
                                    'user_id': user!.id,
                                    'first_name': firstNameCtrl.text.trim(),
                                    'last_name':
                                        lastNameCtrl.text.trim().isEmpty
                                        ? 'EMPTY'
                                        : lastNameCtrl.text.trim(),
                                    'phone': phoneCtrl.text.trim(),
                                    'address': addressCtrl.text.trim(),
                                    'city': cityCtrl.text.trim(),
                                    'pin_code': pinCodeCtrl.text.trim(),
                                    'is_default':
                                        isDefault, // Saves the toggle state
                                  };

                                  if (isEditing) {
                                    await Supabase.instance.client
                                        .from('addresses')
                                        .update(data)
                                        .eq('id', existingAddress['id']);
                                  } else {
                                    await Supabase.instance.client
                                        .from('addresses')
                                        .insert(data);
                                  }

                                  if (ctx.mounted) {
                                    Navigator.pop(ctx);
                                    _refreshAddresses();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isEditing
                                              ? "Address updated!"
                                              : "Address saved!",
                                        ),
                                        backgroundColor: const Color(
                                          0xFF16a34a,
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text("Error: $e")),
                                  );
                                } finally {
                                  setModalState(() => isLoading = false);
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16a34a),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                isEditing ? "Update Address" : "Save Address",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon,
    bool isDark, {
    bool isNumber = false,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber
            ? [
                FilteringTextInputFormatter.digitsOnly,
                if (maxLength != null)
                  LengthLimitingTextInputFormatter(maxLength),
              ]
            : null,
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.grey),
          prefixIcon: Icon(icon, color: Colors.grey, size: 20),
          filled: true,
          fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF16a34a), width: 1),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
        title: Text(
          "Address Book",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddressSheet(context),
        backgroundColor: const Color(0xFF16a34a),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          "Add New",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _addressesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading addresses",
                style: TextStyle(color: textColor),
              ),
            );
          }

          final addresses = snapshot.data ?? [];

          if (addresses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "No saved addresses",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Add an address for a faster checkout",
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16.0),
            itemCount: addresses.length,
            itemBuilder: (context, index) {
              final addr = addresses[index];

              final firstName = addr['first_name'] ?? '';
              final lastName = addr['last_name'] == 'EMPTY'
                  ? ''
                  : (addr['last_name'] ?? '');
              final fullName = '$firstName $lastName'.trim();

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[50],
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
                        const Icon(
                          Icons.location_on,
                          color: Color(0xFF16a34a),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fullName.isNotEmpty ? fullName : 'No Name',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: textColor,
                            ),
                          ),
                        ),
                        if (addr['is_default'] == true)
                          Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              "DEFAULT",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),

                        SizedBox(
                          height: 24,
                          width: 24,
                          child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.more_vert,
                              size: 20,
                              color: Colors.grey,
                            ),
                            onSelected: (value) {
                              if (value == 'edit') {
                                _showAddressSheet(
                                  context,
                                  existingAddress: addr,
                                );
                              } else if (value == 'delete') {
                                _deleteAddress(addr['id'].toString());
                              }
                            },
                            itemBuilder: (BuildContext context) =>
                                <PopupMenuEntry<String>>[
                                  const PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit_outlined, size: 18),
                                        SizedBox(width: 8),
                                        Text('Edit'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                          color: Colors.redAccent,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Delete',
                                          style: TextStyle(
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      addr['address'] ?? '',
                      style: TextStyle(
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    Text(
                      "${addr['city']}, ${addr['pin_code']}",
                      style: TextStyle(
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Phone: ${addr['phone']}",
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
