import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/material.dart';

class EmailService {
  static const String _gmailAddress = 'prajjwalj02@gmail.com';
  static const String _appPassword = 'iwxedcnijtuvtuzr';

  // 👇 2. Put the Admin's email address here
  static const String _adminEmailAddress = 'prajjwalj02@gmail.com';

  static Future<void> sendOrderConfirmation({
    required String customerEmail,
    required String customerName,
    required String orderId,
    required List<Map<String, dynamic>> cartItems,
    required int totalAmount,
    String? customerPhone,
    String? customerAddress,
  }) async {
    final smtpServer = gmail(_gmailAddress, _appPassword);

    // --- BUILD THE ITEMS TABLE ROWS AND CALCULATE SUBTOTAL ---
    String itemsHtml = '';
    int subtotalAmount = 0; // 👈 ADDED: We calculate the true subtotal here!

    for (var item in cartItems) {
      final name = item['product_name'] ?? item['name'] ?? 'Item';
      final qty = int.tryParse(item['qty']?.toString() ?? '1') ?? 1;
      final price =
          double.tryParse(item['price']?.toString() ?? '0')?.toInt() ?? 0;
      final imageUrl = item['image']?.toString() ?? '';
      final weight =
          item['variant_weight']?.toString() ??
          item['weight']?.toString() ??
          '-';
      final int itemTotal = price * qty;

      subtotalAmount += itemTotal; // 👈 Add to subtotal

      final imageTag = imageUrl.isNotEmpty
          ? '<img src="$imageUrl" width="50" height="50" style="background-color: #ffffff; border-radius: 8px; padding: 4px; object-fit: contain;">'
          : '<div style="width: 50px; height: 50px; background-color: #ffffff; border-radius: 8px;"></div>';

      itemsHtml +=
          '''
        <tr style="border-bottom: 1px solid #333;">
          <td style="padding: 15px 5px;">
            <table width="100%" cellpadding="0" cellspacing="0" border="0">
              <tr>
                <td width="65" style="padding-right: 10px;">
                  $imageTag
                </td>
                <td style="color: #ffffff; vertical-align: middle; font-size: 14px;">
                  $name
                </td>
              </tr>
            </table>
          </td>
          <td style="padding: 15px 5px; color: #e4e4e7; text-align: center; font-size: 14px;">$weight</td>
          <td style="padding: 15px 5px; color: #e4e4e7; text-align: center; font-size: 14px;">$qty</td>
          <td style="padding: 15px 5px; color: #ffffff; text-align: right; font-size: 14px; font-weight: bold;">Rs. $itemTotal</td>
        </tr>
      ''';
    }

    // 👇 ADDED: Calculate shipping fee based on the difference
    int shippingFee = totalAmount - subtotalAmount;
    String shippingText = shippingFee > 0 ? 'Rs. $shippingFee' : 'FREE';

    // ==========================================
    // 🟢 EMAIL 1: FOR THE CUSTOMER
    // ==========================================
    final customerHtmlBody =
        '''
    <div style="font-family: 'Inter', Arial, sans-serif; background-color: #121212; padding: 20px; color: #ffffff;">
      <div style="max-width: 600px; margin: 0 auto; background-color: #1a1a1a; border-radius: 12px; overflow: hidden; border: 1px solid #333;">
        
        <div style="background-color: #16a34a; padding: 25px 20px; text-align: left;">
          <h2 style="color: #ffffff; margin: 0; font-size: 22px;">Order Confirmed! 🎉</h2>
        </div>

        <div style="padding: 20px;">
          <p style="color: #ffffff; font-size: 15px; margin-top: 0; margin-bottom: 25px;">Hi <strong>$customerName</strong>, your order has been placed!</p>
          
          <table width="100%" style="border-collapse: collapse;">
            <thead>
              <tr style="border-bottom: 1px solid #444; font-size: 12px; color: #a1a1aa; text-align: left; text-transform: uppercase;">
                <th style="padding-bottom: 10px; padding-left: 5px;">PRODUCT</th>
                <th style="padding-bottom: 10px; text-align: center;">SIZE</th>
                <th style="padding-bottom: 10px; text-align: center;">QTY</th>
                <th style="padding-bottom: 10px; text-align: right; padding-right: 5px;">TOTAL</th>
              </tr>
            </thead>
            <tbody>
              $itemsHtml
            </tbody>
          </table>

          <div style="margin-top: 20px; padding-bottom: 10px; text-align: right;">
            <p style="color: #d4d4d8; font-size: 14px; margin: 5px 0;">Subtotal: Rs. $subtotalAmount</p>
            <p style="color: #d4d4d8; font-size: 14px; margin: 5px 0;">Shipping: $shippingText</p>
            <h3 style="color: #22c55e; margin: 10px 0; font-size: 20px;">Total: Rs. $totalAmount</h3>
          </div>
          
          <div style="margin-top: 15px; padding: 20px; background-color: #27272a; border-radius: 12px; text-align: left;">
            <p style="margin: 0 0 5px 0; font-size: 13px; color: #ffffff; font-weight: bold;">Delivering to:</p>
            <p style="margin: 0; font-size: 14px; color: #e4e4e7; line-height: 1.5;">
              ${customerAddress ?? 'No address provided'}<br>
              ${customerPhone ?? ''}
            </p>
          </div>

          <div style="margin-top: 30px; text-align: center;">
            <p style="margin: 0; font-size: 13px; color: #71717a;">Payment: Cash On Delivery</p>
          </div>
        </div>
      </div>
    </div>
    ''';

    final customerMessage = Message()
      ..from = Address(_gmailAddress, 'GardenRich')
      ..recipients.add(customerEmail)
      ..subject = 'Order Confirmed! 🎉 — Rs. $totalAmount'
      ..html = customerHtmlBody;

    // ==========================================
    // ⚫ EMAIL 2: FOR THE ADMIN
    // ==========================================
    final adminHtmlBody =
        '''
    <div style="font-family: 'Inter', Arial, sans-serif; background-color: #121212; padding: 20px; color: #ffffff;">
      <div style="max-width: 600px; margin: 0 auto; background-color: #1a1a1a; border-radius: 12px; overflow: hidden; border: 1px solid #333;">
        <div style="background-color: #18181b; padding: 25px 20px; text-align: left; border-bottom: 1px solid #333;">
          <h2 style="color: white; margin: 0; font-size: 22px;">New Order Received! 🚨</h2>
        </div>
        <div style="padding: 20px;">
          
          <div style="margin-bottom: 20px; padding: 15px; background-color: #27272a; border-radius: 12px;">
            <p style="color: #fff; font-size: 14px; margin: 5px 0;"><strong>Customer:</strong> $customerName</p>
            <p style="color: #fff; font-size: 14px; margin: 5px 0;"><strong>Email:</strong> <a href="mailto:$customerEmail" style="color: #60a5fa;">$customerEmail</a></p>
            <p style="color: #fff; font-size: 14px; margin: 5px 0;"><strong>Phone:</strong> ${customerPhone ?? 'Not provided'}</p>
            <p style="color: #fff; font-size: 14px; margin: 5px 0; margin-top: 15px;"><strong>Shipping Address:</strong><br>${customerAddress ?? 'Not provided'}</p>
          </div>
          
          <table width="100%" style="border-collapse: collapse; margin-top: 20px;">
            <thead>
              <tr style="border-bottom: 1px solid #444; font-size: 12px; color: #a1a1aa; text-align: left; text-transform: uppercase;">
                <th style="padding-bottom: 10px; padding-left: 5px;">PRODUCT</th>
                <th style="padding-bottom: 10px; text-align: center;">SIZE</th>
                <th style="padding-bottom: 10px; text-align: center;">QTY</th>
                <th style="padding-bottom: 10px; text-align: right; padding-right: 5px;">TOTAL</th>
              </tr>
            </thead>
            <tbody>
              $itemsHtml
            </tbody>
          </table>
          
          <div style="margin-top: 20px; border-top: 1px solid #333; padding-top: 20px; text-align: right;">
            <p style="color: #d4d4d8; font-size: 14px; margin: 5px 0;">Subtotal: Rs. $subtotalAmount</p>
            <p style="color: #d4d4d8; font-size: 14px; margin: 5px 0;">Shipping: $shippingText</p>
            <h3 style="color: #22c55e; margin: 10px 0; font-size: 20px;">Total: Rs. $totalAmount</h3>
          </div>
          
          <div style="margin-top: 20px; text-align: center;">
            <p style="margin: 0; font-size: 13px; color: #71717a;">Payment: Cash On Delivery</p>
          </div>
        </div>
      </div>
    </div>
    ''';

    final adminMessage = Message()
      ..from = Address(_gmailAddress, 'GardenRich Alerts')
      ..recipients.add(_adminEmailAddress)
      ..subject = '🚨 New Order - Rs. $totalAmount ($customerName)'
      ..html = adminHtmlBody;

    // 👇 INDEPENDENT TRY/CATCH FOR EACH EMAIL
    try {
      await send(customerMessage, smtpServer);
      debugPrint('✅ Customer Email sent successfully to $customerEmail');
    } catch (e) {
      debugPrint('❌ Customer Email failed: $e');
    }

    // Give Google SMTP a 1-second breather before firing the next email
    await Future.delayed(const Duration(seconds: 1));

    try {
      await send(adminMessage, smtpServer);
      debugPrint('✅ Admin Email sent successfully to $_adminEmailAddress');
    } catch (e) {
      debugPrint('❌ Admin Email failed: $e');
    }
  }
}
