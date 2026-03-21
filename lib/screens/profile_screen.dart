import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../providers/theme_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  String? _userName;
  String? _userMobile;

  // 👇 Tracks the background database check silently
  bool _isSyncingWithDatabase = true;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isSyncingWithDatabase = false);
      return;
    }

    // 1. Try to grab instant local data
    if (mounted) {
      setState(() {
        _userName = user.userMetadata?['name']?.toString();
        _userMobile = user.userMetadata?['mobile']?.toString();
      });
    }

    // 2. Silently fetch from the database in the background
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('name, mobile')
          .eq('email', user.email!)
          .maybeSingle();

      if (mounted && data != null) {
        setState(() {
          if (data['name'] != null && data['name'].toString().isNotEmpty) {
            _userName = data['name'].toString();
          }
          if (data['mobile'] != null && data['mobile'].toString().isNotEmpty) {
            _userMobile = data['mobile'].toString();
          }
        });
      }
    } catch (e) {
      debugPrint("Silent profile sync error: $e");
    } finally {
      // 3. Mark the sync as totally finished
      if (mounted) {
        setState(() => _isSyncingWithDatabase = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = Supabase.instance.client.auth.currentUser;
    final currentThemeMode = ref.watch(themeModeProvider);
    String themeText = "System Theme";
    if (currentThemeMode == ThemeMode.light) themeText = "Light Theme";
    if (currentThemeMode == ThemeMode.dark) themeText = "Dark Theme";

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    // 👇 THE MAGIC LOGIC: Decides exactly what text to show smoothly
    String displayTitle = "Your account";
    if (user != null) {
      if (_userName != null && _userName!.isNotEmpty) {
        displayTitle = _userName!; // We have the real name!
      } else if (_isSyncingWithDatabase) {
        displayTitle =
            " "; // 👈 It is currently checking the DB. Show a blank, invisible space! No spinners!
      } else {
        displayTitle =
            "GardenRich User"; // DB is finished, and they TRULY have no name.
      }
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person, size: 50, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // 👇 Displays our carefully calculated text
            Text(
              displayTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),

            if (user != null)
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8.0,
                runSpacing: 4.0,
                children: [
                  if (_userMobile != null && _userMobile!.isNotEmpty) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.phone_iphone,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _userMobile!,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Text("•", style: TextStyle(color: Colors.grey[600])),
                  ],
                  Text(
                    user.email ?? "",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),

            if (user == null) ...[
              const SizedBox(height: 8),
              const Text(
                "Log in to view your complete profile",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
            const SizedBox(height: 30),

            if (user == null)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => context
                          .push('/login', extra: true)
                          .then((_) => setState(() {})),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16a34a),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "Log in",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context
                          .push('/login', extra: false)
                          .then((_) => setState(() {})),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF16a34a),
                        side: const BorderSide(color: Color(0xFF16a34a)),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "Sign up",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            if (user != null)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        context
                            .push('/edit-profile')
                            .then((_) => _fetchUserProfile());
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: BorderSide(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "Edit profile",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await Supabase.instance.client.auth.signOut();
                        if (context.mounted) {
                          context.go('/login');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        "Log Out",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 30),

            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () {
                      if (user == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Please log in to view your orders"),
                          ),
                        );
                      } else {
                        context.push('/orders');
                      }
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: _buildQuickActionCard(
                      Icons.shopping_bag_outlined,
                      "My orders",
                      isDark,
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/help'),
                    borderRadius: BorderRadius.circular(12),
                    child: _buildQuickActionCard(
                      Icons.support_agent,
                      "Need help?",
                      isDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            InkWell(
              onTap: () => _showAppearanceModal(currentThemeMode),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.dark_mode_outlined, color: Colors.grey),
                    const SizedBox(width: 15),
                    Text(
                      "Appearance",
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      themeText,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 30),

            _buildSectionHeader("Your information", textColor),
            _buildMenuOption(
              Icons.book_outlined,
              "Address book",
              isDark,
              textColor,
              onTap: () {
                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please log in first")),
                  );
                } else {
                  context.push('/address-book');
                }
              },
            ),
            const SizedBox(height: 20),

            _buildSectionHeader("Other information", textColor),
            _buildMenuOption(
              Icons.share_outlined,
              "Share the app",
              isDark,
              textColor,
              onTap: () {
                Share.share(
                  'Check out GardenRich for the best fresh products! Download the app today: https://gardenrich.online',
                );
              },
            ),
            _buildMenuOption(
              Icons.info_outline,
              "About us",
              isDark,
              textColor,
              onTap: () => context.push('/about'),
            ),
            const SizedBox(height: 30),

            const Text(
              "GardenRich v1.0.0",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showAppearanceModal(ThemeMode currentMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black87;
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Appearance",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 20),
              _buildThemeOption(
                "Light Theme",
                Icons.light_mode_outlined,
                ThemeMode.light,
                currentMode,
                textColor,
              ),
              _buildThemeOption(
                "Dark Theme",
                Icons.dark_mode_outlined,
                ThemeMode.dark,
                currentMode,
                textColor,
              ),
              _buildThemeOption(
                "System Theme",
                Icons.settings_brightness_outlined,
                ThemeMode.system,
                currentMode,
                textColor,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildThemeOption(
    String title,
    IconData icon,
    ThemeMode mode,
    ThemeMode currentMode,
    Color textColor,
  ) {
    final bool isSelected = currentMode == mode;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: textColor),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w500, color: textColor),
      ),
      trailing: isSelected
          ? const Icon(Icons.radio_button_checked, color: Color(0xFF16a34a))
          : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
      onTap: () {
        ref.read(themeModeProvider.notifier).setTheme(mode);
        Navigator.pop(context);
      },
    );
  }

  Widget _buildQuickActionCard(IconData icon, String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey.shade200,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: isDark ? Colors.white : Colors.black87),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuOption(
    IconData icon,
    String title,
    bool isDark,
    Color textColor, {
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.grey),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w500, color: textColor),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey,
        ),
        onTap: onTap ?? () {},
      ),
    );
  }
}
