import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AboutUsScreen extends StatelessWidget {
  const AboutUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final borderColor = isDark ? Colors.grey[800]! : Colors.grey.shade200;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- HEADER SECTION ---
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF92D050).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.eco, // Using a leaf/eco icon for GardenRich
                size: 40,
                color: Color(0xFF92D050),
              ),
            ),
            const SizedBox(height: 20),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 32,
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
                    style: TextStyle(color: Color(0xFF92D050)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[800] : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                "Version 1.0.0",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ),
            const SizedBox(height: 40),

            // --- OUR MISSION CARD ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
                boxShadow: [
                  if (!isDark)
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.rocket_launch, color: Color(0xFF92D050)),
                      const SizedBox(width: 12),
                      Text(
                        "Our Mission",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "GardenRich is dedicated to bringing you the highest quality groceries, fresh produce, and daily essentials straight from farms to your doorstep. We partner with trusted suppliers to ensure that you get the best products at the best prices, delivered seamlessly.",
                    style: TextStyle(
                      color: mutedColor,
                      height: 1.6,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // --- CONTACT & SOCIALS ---
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  _buildListTile(
                    icon: Icons.language,
                    title: "Visit our Website",
                    subtitle: "www.gardenrich.online",
                    textColor: textColor,
                    mutedColor: mutedColor!,
                  ),
                  Divider(color: borderColor, height: 1),
                  _buildListTile(
                    icon: Icons.email_outlined,
                    title: "Email Us",
                    subtitle: "rp.singh4326@gmail.com",
                    textColor: textColor,
                    mutedColor: mutedColor,
                  ),
                  Divider(color: borderColor, height: 1),
                  _buildListTile(
                    icon: Icons.description_outlined,
                    title: "Terms & Conditions",
                    subtitle: "Read our policies",
                    textColor: textColor,
                    mutedColor: mutedColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Footer Text
            Text(
              "Made with ❤️ in India",
              style: TextStyle(color: mutedColor, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color mutedColor,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF92D050).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF92D050), size: 20),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: mutedColor, fontSize: 12),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: mutedColor),
      onTap: () {
        // You can add url_launcher here later to actually open the links!
      },
    );
  }
}
