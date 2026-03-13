import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB);
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
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
        title: Text(
          "Help & Support",
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Contact Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF92D050).withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF92D050).withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.support_agent,
                  size: 40,
                  color: Color(0xFF92D050),
                ),
                const SizedBox(height: 12),
                Text(
                  "We're here to help!",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Reach out to our support team at\nrp.singh4326@gmail.com\nor call us at 9140104326",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),

          Text(
            "Frequently Asked Questions",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),

          // FAQs
          _buildFaqCard(
            "How do I track my order?",
            "You can track your order status in the 'My Orders' section of your profile.",
            cardColor,
            borderColor,
            textColor,
            isDark,
          ),
          _buildFaqCard(
            "Can I cancel my order?",
            "Orders can only be cancelled while they are in the 'Pending' state. Please contact support for assistance.",
            cardColor,
            borderColor,
            textColor,
            isDark,
          ),
          _buildFaqCard(
            "What is your refund policy?",
            "If you receive a damaged product, please reach out to us within 24 hours of delivery for a full refund or replacement.",
            cardColor,
            borderColor,
            textColor,
            isDark,
          ),
          _buildFaqCard(
            "How do I change my address?",
            "You can manage your delivery addresses in the 'Address Book' section of your profile.",
            cardColor,
            borderColor,
            textColor,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFaqCard(
    String question,
    String answer,
    Color cardColor,
    Color borderColor,
    Color textColor,
    bool isDark,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: ExpansionTile(
        title: Text(
          question,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: textColor,
          ),
        ),
        iconColor: const Color(0xFF92D050),
        collapsedIconColor: Colors.grey,
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Text(
            answer,
            style: TextStyle(
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
