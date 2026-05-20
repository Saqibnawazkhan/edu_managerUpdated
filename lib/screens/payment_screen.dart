import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_theme.dart';

/// Admin Contact Configuration
class AdminConfig {
  static const String adminEmail = 'saqibfiverr2025@gmail.com';
  static const String adminWhatsApp = '923219655055'; // Without + sign
  static const String adminWhatsAppDisplay = '+92 321 9655055';
}

/// Pricing Packages
class PricingPackage {
  final String name;
  final int price;
  final String duration;
  final String description;
  final Color color;
  final IconData icon;
  final bool isPopular;

  const PricingPackage({
    required this.name,
    required this.price,
    required this.duration,
    required this.description,
    required this.color,
    required this.icon,
    this.isPopular = false,
  });
}

class PaymentScreen extends StatefulWidget {
  final String? prefillName;
  final String? prefillEmail;
  final String? prefillPhone;

  const PaymentScreen({
    super.key,
    this.prefillName,
    this.prefillEmail,
    this.prefillPhone,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _transactionIdController = TextEditingController();

  String _selectedPaymentMethod = 'JazzCash';
  String _selectedPackage = 'Monthly';
  bool _isLoading = false;
  bool _isSubmitted = false;

  late AnimationController _submitButtonController;
  late Animation<double> _submitButtonScale;

  final List<PricingPackage> _packages = [
    const PricingPackage(
      name: 'Monthly',
      price: 3500,
      duration: 'per device',
      description: 'Perfect for trying out',
      color: Color(0xFF3B82F6),
      icon: Icons.calendar_today_rounded,
    ),
    const PricingPackage(
      name: 'Yearly',
      price: 30000,
      duration: '12 Months',
      description: 'Best value',
      color: Color(0xFF8B5CF6),
      icon: Icons.calendar_month_rounded,
      isPopular: true,
    ),
    const PricingPackage(
      name: 'Permanent',
      price: 80000,
      duration: 'Forever',
      description: 'One-time payment',
      color: Color(0xFF4ADE80),
      icon: Icons.all_inclusive_rounded,
    ),
  ];

  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'name': 'JazzCash',
      'icon': Icons.phone_android_rounded,
      'color': const Color(0xFFE31837),
      'account': '0309-9865055',
    },
    {
      'name': 'EasyPaisa',
      'icon': Icons.account_balance_wallet_rounded,
      'color': const Color(0xFF00A550),
      'account': '0321-9655055',
    },
    {
      'name': 'Bank Transfer',
      'icon': Icons.account_balance_rounded,
      'color': const Color(0xFF1E3A8A),
      'account': 'ABL: PK60ABPA0010088535210011',
    },
  ];

  @override
  void initState() {
    super.initState();
    _submitButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _submitButtonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _submitButtonController, curve: Curves.easeInOut),
    );

    // Pre-fill user details if provided
    if (widget.prefillName != null) {
      _nameController.text = widget.prefillName!;
    }
    if (widget.prefillEmail != null) {
      _emailController.text = widget.prefillEmail!;
    }
    if (widget.prefillPhone != null) {
      _phoneController.text = widget.prefillPhone!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _transactionIdController.dispose();
    _submitButtonController.dispose();
    super.dispose();
  }


  int get _selectedPackagePrice {
    return _packages.firstWhere((p) => p.name == _selectedPackage).price;
  }

  Future<void> _submitPayment() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Save payment request to Firestore
      await FirebaseFirestore.instance.collection('payment_requests').add({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'transactionId': _transactionIdController.text.trim(),
        'paymentMethod': _selectedPaymentMethod,
        'package': _selectedPackage,
        'amount': _selectedPackagePrice,
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'notifyEmail': AdminConfig.adminEmail,
      });

      // Open WhatsApp with payment details
      await _sendWhatsAppWithScreenshot();

      setState(() {
        _isLoading = false;
        _isSubmitted = true;
      });

      HapticFeedback.mediumImpact();
    } catch (e) {
      setState(() => _isLoading = false);
      HapticFeedback.heavyImpact();
      debugPrint('Payment submission error: $e');
      _showSnackBar('Failed to submit. Please try again.', AppTheme.error, isError: true);
    }
  }

  Future<void> _sendWhatsAppWithScreenshot() async {
    final message = '''
*New Payment Request - Edu Manager*

*Package:* $_selectedPackage (PKR $_selectedPackagePrice)
*Name:* ${_nameController.text.trim()}
*Email:* ${_emailController.text.trim()}
*Phone:* ${_phoneController.text.trim()}
*Payment Method:* $_selectedPaymentMethod
*Transaction ID:* ${_transactionIdController.text.trim()}

Please verify and provide login credentials.
''';

    final encodedMessage = Uri.encodeComponent(message);
    final whatsappUrl = Uri.parse(
      'https://wa.me/${AdminConfig.adminWhatsApp}?text=$encodedMessage'
    );

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('WhatsApp error: $e');
    }
  }

  Future<void> _openWhatsAppForScreenshot() async {
    // Open WhatsApp directly to the admin number without text
    // User can then easily attach their screenshot
    final whatsappUrl = Uri.parse(
      'https://wa.me/${AdminConfig.adminWhatsApp}'
    );

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          _showSnackBar('Could not open WhatsApp', AppTheme.error, isError: true);
        }
      }
    } catch (e) {
      debugPrint('WhatsApp error: $e');
      if (mounted) {
        _showSnackBar('Could not open WhatsApp', AppTheme.error, isError: true);
      }
    }
  }

  void _showSnackBar(String message, Color color, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isSubmitted) {
      return _buildSuccessScreen();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  _buildHeader(),

                  const SizedBox(height: 24),

                  // Pricing Packages
                  _buildPricingPackages(),

                  const SizedBox(height: 24),

                  // Payment Methods
                  _buildPaymentMethodsSection(),

                  const SizedBox(height: 24),

                  // User Details
                  _buildUserDetailsSection(),

                  const SizedBox(height: 24),

                  // Transaction Details
                  _buildTransactionSection(),

                  const SizedBox(height: 32),

                  // Submit Button
                  _buildSubmitButton(),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTapDown: (_) => HapticFeedback.selectionClick(),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.textDark,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Text(
            'Complete Payment',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPricingPackages() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Package',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: _packages.map((package) {
            final isSelected = _selectedPackage == package.name;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedPackage = package.name);
                },
                child: Container(
                  margin: EdgeInsets.only(
                    right: package != _packages.last ? 10 : 0,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              package.color,
                              package.color.withValues(alpha: 0.8),
                            ],
                          )
                        : null,
                    color: isSelected ? null : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? package.color : AppTheme.borderGrey,
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSelected
                            ? package.color.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.05),
                        blurRadius: isSelected ? 12 : 6,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (package.isPopular)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.2)
                                : package.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Popular',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : package.color,
                            ),
                          ),
                        ),
                      Icon(
                        package.icon,
                        color: isSelected ? Colors.white : package.color,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        package.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PKR ${package.price}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? Colors.white : package.color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        package.duration,
                        style: TextStyle(
                          fontSize: 11,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.9)
                              : AppTheme.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        // Selected package description
        Center(
          child: Text(
            _packages.firstWhere((p) => p.name == _selectedPackage).description,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textGrey.withValues(alpha: 0.8),
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Payment Method',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        ...(_paymentMethods.map((method) => _buildPaymentMethodTile(method))),
        // Account Name
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.primaryBlue.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.person_rounded,
                color: AppTheme.primaryBlue.withValues(alpha: 0.7),
                size: 20,
              ),
              const SizedBox(width: 10),
              const Text(
                'Account Name: ',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textGrey,
                ),
              ),
              const Text(
                'Saqib Nawaz Khan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _copyAccountNumber(String account, String methodName) {
    // Extract just the number/account for copying
    String accountToCopy = account;
    if (account.contains(':')) {
      accountToCopy = account.split(':').last.trim();
    }
    accountToCopy = accountToCopy.replaceAll('-', '');

    Clipboard.setData(ClipboardData(text: accountToCopy));
    HapticFeedback.mediumImpact();
    _showSnackBar('$methodName account copied!', AppTheme.success);
  }

  Widget _buildPaymentMethodTile(Map<String, dynamic> method) {
    final isSelected = _selectedPaymentMethod == method['name'];

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedPaymentMethod = method['name']);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? method['color'] : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? (method['color'] as Color).withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (method['color'] as Color).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(method['icon'], color: method['color'], size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    method['account'],
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textGrey.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            // Copy button
            GestureDetector(
              onTap: () => _copyAccountNumber(method['account'], method['name']),
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: (method['color'] as Color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.copy_rounded,
                  color: method['color'],
                  size: 18,
                ),
              ),
            ),
            // Selection indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? method['color'] : AppTheme.borderGrey,
                  width: 2,
                ),
                color: isSelected ? method['color'] : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _nameController,
          label: 'Full Name',
          hint: 'Enter your full name',
          icon: Icons.person_outline_rounded,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your name';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _emailController,
          label: 'Email',
          hint: 'Enter your email',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your email';
            }
            if (!value.contains('@')) {
              return 'Please enter a valid email';
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _phoneController,
          label: 'Phone Number',
          hint: 'Enter your phone number',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your phone number';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTransactionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transaction Details',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppTheme.textDark,
          ),
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _transactionIdController,
          label: 'Transaction ID / Reference',
          hint: 'Enter transaction ID or reference number',
          icon: Icons.receipt_long_rounded,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter transaction ID';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return GestureDetector(
      onTapDown: (_) {
        HapticFeedback.selectionClick();
        _submitButtonController.forward();
      },
      onTapUp: (_) => _submitButtonController.reverse(),
      onTapCancel: () => _submitButtonController.reverse(),
      onTap: _isLoading ? null : _submitPayment,
      child: AnimatedBuilder(
        animation: _submitButtonScale,
        builder: (context, child) {
          return Transform.scale(
            scale: _submitButtonScale.value,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.success,
                    AppTheme.success.withValues(alpha: 0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.success.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_rounded, color: Colors.white, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'Submit via WhatsApp',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openWhatsApp() async {
    final message = Uri.encodeComponent(
      'Hi, I just submitted payment for Edu Manager app.\n\n'
      'Name: ${_nameController.text.trim()}\n'
      'Email: ${_emailController.text.trim()}\n'
      'Phone: ${_phoneController.text.trim()}\n'
      'Transaction ID: ${_transactionIdController.text.trim()}\n\n'
      'Please provide my login credentials.'
    );

    final whatsappUrl = Uri.parse(
      'https://wa.me/${AdminConfig.adminWhatsApp}?text=$message'
    );

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          _showSnackBar('Could not open WhatsApp', AppTheme.error, isError: true);
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Could not open WhatsApp', AppTheme.error, isError: true);
      }
    }
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 60),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppTheme.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.success,
                    size: 80,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Request Sent!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Your payment details have been sent via WhatsApp. We will verify your payment and send you login credentials soon.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textGrey.withValues(alpha: 0.8),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Share Screenshot Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF25D366).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF25D366).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.image_rounded,
                        color: Color(0xFF25D366),
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Share Screenshot',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF25D366),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap below to open WhatsApp and share your payment screenshot.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textGrey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          _openWhatsAppForScreenshot();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF25D366),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF25D366).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.image_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Share Screenshot',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        AdminConfig.adminWhatsAppDisplay,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textGrey.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Back to Login button
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    // Navigate to login and clear the entire stack
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/login',
                      (route) => false,
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryPurple,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryPurple.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Back to Login',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        onTap: () => HapticFeedback.selectionClick(),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: AppTheme.textGrey.withValues(alpha: 0.5)),
          prefixIcon: Icon(icon, color: AppTheme.primaryPurple),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          errorStyle: const TextStyle(
            color: AppTheme.error,
            fontSize: 12,
          ),
        ),
        validator: validator,
      ),
    );
  }
}
