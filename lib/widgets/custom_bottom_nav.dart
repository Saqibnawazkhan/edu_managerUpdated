import 'package:flutter/material.dart';
import '../utils/app_theme.dart';

class CustomBottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  State<CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<CustomBottomNav>
    with SingleTickerProviderStateMixin {
  AnimationController? _animationController;
  Animation<double>? _positionAnimation;
  int _previousIndex = 0;

  // Returns horizontal position (0.0 = left, 0.5 = center, 1.0 = right)
  double _getPositionForIndex(int index) {
    switch (index) {
      case 0:
        return 0.167; // 1/6 position (center of first third)
      case 1:
        return 0.5; // Center position
      case 2:
        return 0.833; // 5/6 position (center of last third)
      default:
        return 0.5;
    }
  }

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _positionAnimation = Tween<double>(
      begin: _getPositionForIndex(widget.currentIndex),
      end: _getPositionForIndex(widget.currentIndex),
    ).animate(CurvedAnimation(
      parent: _animationController!,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void didUpdateWidget(CustomBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex && _animationController != null) {
      _previousIndex = oldWidget.currentIndex;
      _positionAnimation = Tween<double>(
        begin: _getPositionForIndex(_previousIndex),
        end: _getPositionForIndex(widget.currentIndex),
      ).animate(CurvedAnimation(
        parent: _animationController!,
        curve: Curves.easeInOut,
      ));
      _animationController!.reset();
      _animationController!.forward();
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  double get _currentPosition {
    return _positionAnimation?.value ?? _getPositionForIndex(widget.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    const navHeight = 70.0;
    const floatingCircleSize = 56.0;
    const floatingCircleOffset = 28.0; // How much the circle sticks out above

    return SizedBox(
      height: navHeight + bottomPadding + floatingCircleOffset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Curved background with notch
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _animationController ?? const AlwaysStoppedAnimation(0.0),
              builder: (context, child) {
                return CustomPaint(
                  size: Size(screenWidth, navHeight + bottomPadding),
                  painter: _CurvedNavPainter(
                    notchPosition: _currentPosition,
                    bottomPadding: bottomPadding,
                  ),
                );
              },
            ),
          ),

          // Navigation items row
          Positioned(
            bottom: bottomPadding,
            left: 0,
            right: 0,
            height: navHeight,
            child: Row(
              children: [
                // Home
                Expanded(
                  child: _buildNavItem(
                    icon: Icons.dashboard_rounded,
                    index: 0,
                    label: 'Home',
                  ),
                ),
                // Attendance
                Expanded(
                  child: _buildNavItem(
                    icon: Icons.calendar_today_rounded,
                    index: 1,
                    label: 'Attendance',
                  ),
                ),
                // Statistics
                Expanded(
                  child: _buildNavItem(
                    icon: Icons.insert_chart_rounded,
                    index: 2,
                    label: 'Statistics',
                  ),
                ),
              ],
            ),
          ),

          // Floating circle that moves
          AnimatedBuilder(
            animation: _animationController ?? const AlwaysStoppedAnimation(0.0),
            builder: (context, child) {
              final xPosition = _currentPosition * screenWidth - (floatingCircleSize / 2);
              return Positioned(
                bottom: navHeight + bottomPadding - (floatingCircleSize / 2) + 5,
                left: xPosition,
                child: _buildFloatingCircle(floatingCircleSize),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required int index,
    required String label,
  }) {
    final isSelected = widget.currentIndex == index;

    return GestureDetector(
      onTap: () => widget.onTap(index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.only(top: 20),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isSelected ? 0.0 : 1.0,
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.7),
            size: 26,
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingCircle(double size) {
    return GestureDetector(
      onTap: () => widget.onTap(widget.currentIndex),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Icon(
            _getIconForIndex(widget.currentIndex),
            color: AppTheme.primaryPurple,
            size: 26,
          ),
        ),
      ),
    );
  }

  IconData _getIconForIndex(int index) {
    switch (index) {
      case 0:
        return Icons.dashboard_rounded;
      case 1:
        return Icons.calendar_today_rounded;
      case 2:
        return Icons.insert_chart_rounded;
      default:
        return Icons.dashboard_rounded;
    }
  }
}

// Custom painter for curved navigation background with moving notch at TOP
class _CurvedNavPainter extends CustomPainter {
  final double notchPosition;
  final double bottomPadding;

  _CurvedNavPainter({
    required this.notchPosition,
    required this.bottomPadding,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A2634)
      ..style = PaintingStyle.fill;

    final path = Path();

    // Notch parameters
    final centerX = size.width * notchPosition;
    const notchRadius = 35.0;
    const cornerRadius = 24.0;
    const navTop = 0.0;

    // Start from top-left, after the corner radius
    path.moveTo(0, cornerRadius);

    // Top-left corner
    path.quadraticBezierTo(0, navTop, cornerRadius, navTop);

    // Line to the left edge of the notch
    final notchLeft = centerX - notchRadius - 10;
    if (notchLeft > cornerRadius) {
      path.lineTo(notchLeft, navTop);
    }

    // Create the notch curve (semi-circle going up)
    path.quadraticBezierTo(
      centerX - notchRadius, navTop,
      centerX - notchRadius + 5, navTop - 8,
    );

    // Arc for the notch
    path.arcToPoint(
      Offset(centerX + notchRadius - 5, navTop - 8),
      radius: const Radius.circular(notchRadius),
      clockwise: false,
    );

    path.quadraticBezierTo(
      centerX + notchRadius, navTop,
      centerX + notchRadius + 10, navTop,
    );

    // Line to top-right corner
    final notchRight = centerX + notchRadius + 10;
    if (notchRight < size.width - cornerRadius) {
      path.lineTo(size.width - cornerRadius, navTop);
    }

    // Top-right corner
    path.quadraticBezierTo(size.width, navTop, size.width, cornerRadius);

    // Right edge
    path.lineTo(size.width, size.height);

    // Bottom edge
    path.lineTo(0, size.height);

    // Left edge back to start
    path.lineTo(0, cornerRadius);

    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CurvedNavPainter oldDelegate) {
    return oldDelegate.notchPosition != notchPosition;
  }
}
