import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/app_theme.dart';
import 'payment_screen.dart';

class AccountTypeSelectionScreen extends StatefulWidget {
  const AccountTypeSelectionScreen({super.key});

  @override
  State<AccountTypeSelectionScreen> createState() => _AccountTypeSelectionScreenState();
}

class _AccountTypeSelectionScreenState extends State<AccountTypeSelectionScreen>
    with TickerProviderStateMixin {
  late AnimationController _soloButtonController;
  late Animation<double> _soloButtonScale;
  late AnimationController _orgButtonController;
  late Animation<double> _orgButtonScale;

  @override
  void initState() {
    super.initState();
    _soloButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _soloButtonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _soloButtonController, curve: Curves.easeInOut),
    );

    _orgButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _orgButtonScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _orgButtonController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _soloButtonController.dispose();
    _orgButtonController.dispose();
    super.dispose();
  }

  void _selectSolo() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PaymentScreen(),
      ),
    );
  }

  void _selectOrganisation() {
    HapticFeedback.mediumImpact();
    Navigator.pushNamed(context, '/organization-payment');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Back Button
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
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
              ),

              const SizedBox(height: 40),

              // Title
              const Text(
                'Choose Account Type',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Select the account type that best fits your needs',
                style: TextStyle(
                  fontSize: 16,
                  color: AppTheme.textGrey.withValues(alpha: 0.8),
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),

              // Solo Account Card
              GestureDetector(
                onTapDown: (_) {
                  HapticFeedback.selectionClick();
                  _soloButtonController.forward();
                },
                onTapUp: (_) {
                  _soloButtonController.reverse();
                  _selectSolo();
                },
                onTapCancel: () => _soloButtonController.reverse(),
                child: AnimatedBuilder(
                  animation: _soloButtonScale,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _soloButtonScale.value,
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryGreen,
                              AppTheme.primaryGreen.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryGreen.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Solo Account',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'For individual teachers and educators',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Starting from',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'PKR 3,500',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
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
                ),
              ),

              const SizedBox(height: 24),

              // Organisation Account Card
              GestureDetector(
                onTapDown: (_) {
                  HapticFeedback.selectionClick();
                  _orgButtonController.forward();
                },
                onTapUp: (_) {
                  _orgButtonController.reverse();
                  _selectOrganisation();
                },
                onTapCancel: () => _orgButtonController.reverse(),
                child: AnimatedBuilder(
                  animation: _orgButtonScale,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _orgButtonScale.value,
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.primaryPurple,
                              AppTheme.primaryPurple.withValues(alpha: 0.8),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryPurple.withValues(alpha: 0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.business_rounded,
                                size: 60,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Organisation',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'For schools, institutes, and organizations',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Custom Pricing',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const Spacer(),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
