import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeFooter extends StatelessWidget {
  const HomeFooter({super.key});

  Future<void> _launchQyroxisUrl() async {
    final Uri url = Uri.parse('https://www.qyroxis.com');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.grey[900] : const Color(0xFFF4F4F5);
    final logoColor = isDark ? Colors.white24 : Colors.black26;
    final textColor = isDark ? Colors.grey[500] : Colors.grey[600];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 100),
      color: bgColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "GardenRich",
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.5,
              color: logoColor,
            ),
          ),
          const SizedBox(height: 8),

          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                "Crafted By ",
                style: TextStyle(color: textColor, fontSize: 13),
              ),
              GestureDetector(
                onTap: _launchQyroxisUrl,
                child: Text(
                  "Qyroxis",
                  style: TextStyle(
                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
              Text(" with ", style: TextStyle(color: textColor, fontSize: 13)),
              const Icon(Icons.favorite, color: Color(0xFF16a34a), size: 14),
              Text(
                " in Bengaluru, India",
                style: TextStyle(color: textColor, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
